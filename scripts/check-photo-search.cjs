const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const ts = require(process.argv[2]);
function load(path, exports, context = {}) {
  const source = fs.readFileSync(path, 'utf8').replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
  return vm.runInNewContext(ts.transpileModule(source + '\n' + exports, {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, context);
}
const parse = load('feature_search/src/main/ets/services/PinmonyPhotoSearch.ets', 'parsePhotoSearch;');
const body = { success: true, status: 'success', code: 0, endpoint_name: 'v3_lens_search_handler', data: [
  { id: '123', type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/test.jpg', width: 474, height: 600 } } }
] };
const origin = 'https://www.pinterest.com';
const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const gate = indexSource.match(/searchResultsVisible: \(\): boolean => ([\s\S]*?),\s*floatingTabsMounted:/)[1];
const hideSearchBar = vm.runInNewContext('(function () { return ' + gate + '; })');
const root = { activeTab: 1, searchStore: { photoSearchVisible: true, searchInputFocused: false },
  currentSearchPageKey: () => 'https://www.pinterest.com/search/' };
assert.equal(hideSearchBar.call(root), true, 'Photo page must hide bar without query or input focus');
root.searchStore.photoSearchVisible = false;
assert.equal(hideSearchBar.call(root), false, 'Closing photo page restores root bar policy');
root.activeTab = 0; root.searchStore.photoSearchVisible = true;
assert.equal(hideSearchBar.call(root), false, 'Other tabs retain their own policy');
if (process.argv[3]) {
  const har = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
  const entry = har.log.entries.find(e => new URL(e.request.url).pathname === '/upload-lens-image/');
  assert(entry && entry.response.status === 200);
  const content = entry.response.content;
  const text = content.encoding === 'base64' ? Buffer.from(content.text, 'base64').toString('utf8') : content.text;
  assert(parse(text, new URL(entry.request.url).origin).length > 0);
  console.log('Captured upload response maps to valid photo search results');
}
assert.equal(parse(JSON.stringify(body), origin)[0].targetUrl, origin + '/pin/123/');
assert.equal(parse(JSON.stringify({ ...body, data: [] }), origin).length, 0);
for (const patch of [{ success: false }, { code: 1 }, { endpoint_name: 'other' }, { data: {} }]) {
  assert.throws(() => parse(JSON.stringify({ ...body, ...patch }), origin));
}
assert.throws(() => parse(JSON.stringify({ ...body, data: [{ ...body.data[0], images: { '474x': { url: 'http://example.com/photo', width: 1, height: 1 } } }] }), origin));
const Flow = load('entry/src/main/ets/app/PinmonyPhotoSearchFlow.ets', 'PinmonyPhotoSearchFlow;', { parsePhotoSearch: parse });
(async () => {
  let selected, uploaded = 0, opened = 0;
  const session = { authenticated: true, accountId: 'test-account', generation: 1, origin };
  const ports = { session: () => session, page: () => origin + '/search/', active: () => true,
    pick: () => new Promise(resolve => { selected = resolve; }), read: async () => new ArrayBuffer(12),
    network: () => ({ cancel() {}, searchUploadedPhoto: async () => { uploaded++; return JSON.stringify(body); } }),
    open: () => { opened++; } };
  const flow = new Flow(ports);
  const cancelled = flow.search(); flow.cancel(); selected('photo-uri'); await cancelled;
  assert.equal(uploaded, 0, 'Closing picker flow must prevent upload');
  const switched = flow.search(); session.generation++; selected('photo-uri'); await switched;
  assert.equal(uploaded, 0, 'Session changes must prevent upload');
  const valid = flow.search(); selected('photo-uri'); assert.equal((await valid).length, 1);
  const requests = [];
  const fullPhoto = new ArrayBuffer(24);
  ports.read = async (uri, ...extra) => {
    assert.equal(uri, 'photo-uri'); assert.equal(extra.length, 0, 'Region search must read the complete original photo');
    return fullPhoto;
  };
  ports.network = () => ({ cancel() {}, searchUploadedPhoto: (bytes, page, session, current, job, region) => {
    assert.equal(bytes, fullPhoto);
    return new Promise(resolve => requests.push({ region, resolve }));
  } });
  const firstRegion = { x: .1, y: .1, w: .5, h: .5 };
  const newerRegion = { x: .3, y: .2, w: .4, h: .6 };
  const first = flow.crop(firstRegion); await new Promise(resolve => setImmediate(resolve));
  const second = flow.crop(newerRegion); await new Promise(resolve => setImmediate(resolve));
  assert.equal(JSON.stringify(requests[0].region), JSON.stringify(firstRegion));
  assert.equal(JSON.stringify(requests[1].region), JSON.stringify(newerRegion));
  requests[1].resolve(JSON.stringify(body)); assert.equal((await second).length, 1);
  requests[0].resolve(JSON.stringify({ ...body, data: [] }));
  assert.equal(await first, undefined, 'Old selection results must not overwrite the latest region');
  flow.open('not-returned'); assert.equal(opened, 0);
  flow.open('123'); assert.equal(opened, 1);
  session.generation++; flow.open('123'); assert.equal(opened, 1);
  console.log('photo search response, cancellation, session and result checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
