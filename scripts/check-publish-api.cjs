const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('feature_profile/src/main/ets/services/PinmonyPublishApiScript.ets', 'utf8');
const script = source.slice(source.indexOf('String.raw' + String.fromCharCode(96)) + 11, source.lastIndexOf(String.fromCharCode(96)));
const flush = async () => { for (let i = 0; i < 12; i++) await new Promise(r => setImmediate(r)); };
const success = (data, endpoint) => ({ resource_response: { status: 'success', code: 0, endpoint_name: endpoint, data }, client_context: { user: { id: '100' } } });
const board = { type: 'board', id: '200', name: 'Board', privacy: 'public', access: ['write'], owner: { id: '100' } };
function harness() {
  const calls = [], location = new URL('https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com/sample/');
  let responder = async (name, options) => {
    if (name === 'UserResource') return success({ type: 'user', id: '100', username: 'sample' });
    if (name === 'FindPinImagesResource') return success({ title: 'Site', destination_url: 'https://example.org/', items: [0, 1].map(i => ({ type: 'pinnable', url: 'https://images.example.org/' + i + '.png', link: 'https://example.org/' })) }, 'v3_find_image');
    if (name === 'BoardPickerBoardsResource') return success({ all_boards: [board, { ...board, id: '201', access: ['read'] }] });
    if (name === 'BoardResource') return success({ ...board, name: options.name, privacy: options.privacy }, 'v3_create_board');
    if (name === 'PinResource') return success({ type: 'pin', id: String(300 + calls.length), is_repin: false, board: { id: options.boardId }, pinner: { id: '100' }, images: { '236x': { url: 'https://images.example.org/result.png' } } }, 'v3_create_pin_handler');
  };
  const ctx = { URL, AbortController, setTimeout, clearTimeout, location, fetch: async (url, args) => {
    const u = new URL(url, location.href); const params = args.body ? new URLSearchParams(args.body) : u.searchParams;
    const options = JSON.parse(params.get('data')).options, name = u.pathname.split('/')[2];
    calls.push({ name, options, method: args.method || 'GET', headers: args.headers, source: params.get('source_url') });
    const payload = await responder(name, options);
    return { ok: true, json: async () => payload };
  } };
  ctx.window = ctx; ctx.top = ctx; vm.runInNewContext(script, ctx);
  return { api: ctx.PinmonyPublishApi, calls, location, setResponder(fn) { const previous = responder; responder = (n, o) => fn(n, o, previous); } };
}
async function open(h, kind, token = 1) { assert(h.api.open(h.location.href, kind, token)); await flush(); assert.equal(h.api.read(token).loading, false); }
async function selected(h) { await open(h, 'website'); assert(h.api.action(1, 'scrape', 'https://example.org/', false)); await flush(); assert.equal(h.api.read(1).pins.length, 2); assert(h.api.action(1, 'all', '', false)); assert(h.api.action(1, 'next', '', false)); await flush(); assert.equal(h.api.read(1).phase, 'boards'); }
(async () => {
  const web = harness(); await selected(web);
  assert.equal(web.api.action(1, 'move', '201', false), false, 'read-only boards cannot receive writes');
  assert(web.api.action(1, 'move', '200', false)); assert.equal(web.api.action(1, 'move', '200', false), false, 'double tap does not replay writes');
  await flush(); assert.equal(web.api.read(1).phase, 'done'); assert.equal(web.api.read(1).completed, 2);
  assert.equal(web.calls.filter(c => c.name === 'PinResource').length, 2);
  assert.equal(web.calls.find(c => c.name === 'PinResource').options.method, 'scraped');
  assert.equal(web.calls.find(c => c.name === 'FindPinImagesResource').headers['X-Pinterest-Pws-Handler'], 'www/pin-builder.js');
  assert.equal(web.calls.find(c => c.name === 'BoardPickerBoardsResource').source, '/pin/create/pinbuilder/');
  assert.equal(web.calls.find(c => c.name === 'PinResource').source, '/pin/create/pinbuilder/');
  const photo = harness(); await open(photo, 'photo');
  assert(photo.api.photoChunk(1, 'data:image/png;base64,', 'file://media/Photo/test.png', false));
  assert(photo.api.photoChunk(1, 'aGVsbG8=', 'file://media/Photo/test.png', true));
  assert(!JSON.stringify(photo.api.read(1)).includes('aGVsbG8'), 'image bytes never appear in snapshots');
  assert(photo.api.action(1, 'next', '', false)); await flush(); assert(photo.api.action(1, 'move', '200', false)); await flush();
  assert.equal(photo.api.read(1).completed, 1); const write = photo.calls.find(c => c.name === 'PinResource').options;
  assert.equal(write.method, 'uploaded'); assert.equal(write.imageBase64, write.image_base64); assert.equal(write.imageUrl, '');
  const create = harness(); await open(create, 'board'); assert(create.api.action(1, 'create', 'New board', true)); await flush();
  assert.equal(create.api.read(1).phase, 'done'); assert.equal(create.calls.filter(c => c.name === 'PinResource').length, 0);
  assert.equal(create.calls.find(c => c.name === 'BoardResource').options.privacy, 'secret');
  const unknown = harness(); await selected(unknown);
  unknown.setResponder(async (n, o, previous) => n === 'PinResource' ? { resource_response: { status: 'success', code: 0, endpoint_name: 'wrong', data: {} } } : previous(n, o));
  assert(unknown.api.action(1, 'move', '200', false)); await flush(); assert(unknown.api.read(1).uncertain);
  assert.equal(unknown.api.action(1, 'move', '200', false), false, 'unknown result cannot replay');
  const partial = harness(); await selected(partial); let writes = 0;
  partial.setResponder(async (n, o, previous) => { if (n === 'PinResource' && ++writes === 2) throw new Error('timeout'); return previous(n, o); });
  assert(partial.api.action(1, 'move', '200', false)); await flush(); assert.equal(partial.api.read(1).completed, 1); assert.equal(partial.api.read(1).pins.length, 1); assert(partial.api.read(1).uncertain);
  const rejected = harness(); await selected(rejected);
  rejected.setResponder(async (n, o, previous) => n === 'PinResource' ? { resource_response: { status: 'failure', code: 12 } } : previous(n, o));
  assert(rejected.api.action(1, 'move', '200', false)); await flush(); assert.equal(rejected.api.read(1).uncertain, false); assert.equal(rejected.api.read(1).completed, 0);
  const delayed = harness(); await open(delayed, 'website'); let release;
  delayed.setResponder((n, o, previous) => n === 'FindPinImagesResource' ? new Promise(r => { release = r; }) : previous(n, o));
  assert(delayed.api.action(1, 'scrape', 'https://example.org/', false)); assert(delayed.api.action(1, 'close', '', false)); await open(delayed, 'website', 2);
  release(success({ items: [] }, 'v3_find_image')); await flush(); assert.equal(delayed.api.read(2).phase, 'website'); assert.equal(delayed.api.read(1), null);
  delayed.location.href = 'https://www.pinterest.com/search/'; assert.equal(delayed.api.read(2), null, 'full-page route change invalidates flow');
  const foreign = harness(); foreign.setResponder((n, o, previous) => n === 'UserResource' ? success({ type: 'user', id: '999', username: 'sample' }) : previous(n, o));
  await open(foreign, 'board'); assert(foreign.api.read(1).error); assert.equal(foreign.api.action(1, 'create', 'New', false), false, 'foreign identity cannot write');
  const invalidLink = harness(); await open(invalidLink, 'website'); assert.equal(invalidLink.api.action(1, 'scrape', 'javascript:alert(1)', false), true); await flush(); assert.equal(invalidLink.calls.filter(c => c.name === 'FindPinImagesResource').length, 0);
  const empty = harness(); await open(empty, 'website'); empty.setResponder((n, o, previous) => n === 'FindPinImagesResource' ? success({ items: [] }, 'v3_find_image') : previous(n, o));
  empty.api.action(1, 'scrape', 'https://example.org/', false); await flush(); assert.equal(empty.api.read(1).phase, 'empty');
  console.log('Publish website/photo/board contracts, identity, selection, duplicate writes, partial/unknown results, cancellation and empty states passed');
})().catch(e => { console.error(e); process.exitCode = 1; });
