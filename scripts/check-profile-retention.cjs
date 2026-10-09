const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); } catch (_) { ts = require(process.argv[2]); }
const root = 'entry/src/main/ets/';
const source = readSourceFileSync(root + 'services/PinWebProfileApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const window = { PinWebProfileApiEnabled: true }; window.top = window;
  const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/sample/' };
  const requests = [];
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, console,
    fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) });
  const api = window.PinWebProfileApi, profile = location.origin + '/sample/';
  const current = () => location.pathname === '/sample/';
  const respond = async (index, data, bookmark = '') => {
    requests[index].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data, bookmark } }) });
    await flush();
  };
  api.read(profile, () => {}, current);
  await respond(0, { type: 'user', id: '1', username: 'sample', full_name: 'Sample' });
  api.readContent(profile, 'saved', () => {}, current);
  await respond(1, [{ type: 'board', id: 'board', name: 'Board', url: '/sample/board/', images: {} }], 'next');
  const before = api.readContent(profile, 'saved', () => {}, current);
  api.more(profile, 'saved', () => {}, current);
  location.pathname = '/sample/board/';
  assert.equal(api.retainForRoute(), true);
  api.suspend();
  assert.equal(requests[2].options.signal.aborted, true);
  await respond(2, [{ type: 'board', id: 'late', name: 'Late', url: '/sample/late/', images: {} }]);
  location.pathname = '/sample/';
  assert.equal(api.read(profile, () => {}, current).kind, 'ready');
  const restored = api.readContent(profile, 'saved', () => {}, current);
  assert.equal(restored, before, 'completed feed is retained');
  assert.equal(restored.items.length, 1, 'late pagination does not overwrite retained content');
  assert.equal(restored.loading, false);
  assert.equal(restored.bookmark, 'next');
  assert.equal(requests.length, 3, 'return does not request profile or first page again');
  api.more(profile, 'saved', () => {}, current);
  const options = JSON.parse(new URL(requests[3].url, location.origin).searchParams.get('data')).options;
  assert.equal(options.bookmarks[0], 'next', 'pagination resumes from retained cursor');
  await respond(3, [], '-end-');
  location.pathname = '/pin/123/'; assert.equal(api.retainForRoute(), true);
  location.pathname = '/other/board/'; assert.equal(api.retainForRoute(), false);
  location.pathname = '/login/'; assert.equal(api.retainForRoute(), false);
  location.pathname = '/sample/';
  api.reset(); api.read(profile, () => {}, current);
  assert.equal(requests.length, 5, 'explicit reset forces a fresh request');
  api.reset();
  await respond(4, { type: 'user', username: 'sample' });

  const cacheSource = readSourceFileSync(root + 'services/PinWebProfileCache.ets', 'utf8').replace(/^import .*;\r?\n/m, '');
  const cacheCode = ts.transpileModule(cacheSource.replace(/export /g, '') + '\nglobalThis.Cache = PinWebProfileCache;',
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const context = {}; vm.runInNewContext(cacheCode, context);
  const cache = new context.Cache();
  const snapshot = { kind: 'state', profileUrl: profile, section: 'saved', boards: [{ id: 'board' }] };
  cache.put(snapshot, 520);
  assert.equal(cache.get(profile, 'saved').scrollOffset, 520);
  assert.equal(cache.get(profile, 'created'), undefined, 'sections cannot share cached cards');
  assert.equal(cache.get(location.origin + '/other/', 'saved'), undefined, 'users cannot share cached data');
  cache.put({ ...snapshot, contentLoading: true, boards: [] }, 0);
  assert.equal(cache.get(profile, 'saved').snapshot.boards.length, 1, 'loading state does not erase content');
  cache.clear(); assert.equal(cache.get(profile, 'saved'), undefined);
  console.log('Profile return retention, request cancellation, pagination and scroll cache checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
