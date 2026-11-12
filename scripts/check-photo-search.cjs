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
const searchPage = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const photoPage = fs.readFileSync('feature_search/src/main/ets/components/PinmonyPhotoSearchPage.ets', 'utf8');
const titleMethod = photoPage.slice(photoPage.indexOf('  private photoSearchTitleBarOptions()'), photoPage.indexOf('  build()'));
const Title = vm.runInNewContext(ts.transpileModule('class Title {' + titleMethod + '} Title;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { BlurStrategy: { ENABLE: 1, DISABLE: 0 }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 1 }, Color: { Transparent: 'transparent' },
    $r: key => key, PinmonyImmersiveLight: { effect: mode => mode } });
let closed = 0;
for (const mode of ['off', 'gentle', 'immersive', 'always']) {
  const title = new Title(); Object.assign(title, { immersiveLightMode: mode, uiText: key => key, onClose: () => { closed++; } });
  const options = title.photoSearchTitleBarOptions();
  assert.equal(options.style.systemMaterialEffect, undefined, 'photo search does not tint the header with system material');
  assert.equal(options.style.blurStrategy, 0, 'photo search uses an opaque header without title blur');
  assert.equal(options.style.thermoCtrl, false);
  assert.equal(options.style.scrollEffectOpts.enableScrollEffect, false);
  assert.equal(options.enableComponentSafeArea, true, 'preserve photo transition safe-area coordinates');
  for (const state of ['originalStyle', 'scrollEffectStyle']) {
    assert.equal(options.style[state].backgroundStyle.blurRadius, 0);
    assert.equal(options.style[state].backgroundStyle.backgroundColor, 'app.color.page_background', 'search header owns an opaque background');
    assert.equal(options.style[state].contentStyle.backIconStyle.iconColor, 'app.color.primary_text');
    assert.equal(options.style[state].contentStyle.backIconStyle.backgroundColor, ['off','gentle'].includes(mode) ? 'transparent' : undefined);
  }
  assert.equal(options.content.title.mainTitle, 'pm_detail_photo_search');
  assert.equal(options.content.menu.value.length, 0, 'the search title must not inherit the history delete action');
  options.content.backIcon.action();
}
assert.equal(closed, 4);
assert(photoPage.includes('.titleBar(PinmonyHdsTitleBar.resolve(this.getUIContext(), this.photoSearchTitleBarOptions(), this.hdsDarkMode))'),
  'dedicated photo search options pass through the shared theme-aware title resolver');
assert(photoPage.includes('.mode(NavDestinationMode.STANDARD)'), 'search is its own full page destination');
assert(photoPage.includes('.hideTitleBar(false)'));
assert(!photoPage.includes('NavDestinationMode.DIALOG'));
assert(!photoPage.includes('pm_photo_history'));
assert(searchPage.includes('PinmonyPhotoSearchPage({'));
assert(searchPage.includes('interactionActive: this.active && !this.photoPreview'), 'the covered history cannot receive title or content actions');
for (const [locale, expected] of [['zh_CN', '搜索照片'], ['en_US', 'Search photos']]) {
  const strings = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
  assert.equal(strings.find(item => item.name === 'pm_detail_photo_search').value, expected);
}
console.log('Photo pages: independent standard destination, dedicated localized header, opaque background and no inherited history menu passed');

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
  const fullPhoto = new ArrayBuffer(24);
  let reads = 0;
  ports.read = async () => { reads++; return fullPhoto; };
  const valid = flow.search(); selected('photo-uri'); assert.equal((await valid).length, 1);
  const requests = [];
  ports.read = async (uri, ...extra) => {
    assert.equal(uri, 'photo-uri'); assert.equal(extra.length, 0, 'Region search must read the complete original photo');
    reads++;
    return fullPhoto;
  };
  ports.network = () => ({ cancel() {}, searchUploadedPhoto: (bytes, page, session, current, job, region) => {
    assert.equal(bytes, fullPhoto);
    return new Promise(resolve => requests.push({ region, job, resolve }));
  } });
  const firstRegion = { x: .1, y: .1, w: .5, h: .5 };
  const newerRegion = { x: .3, y: .2, w: .4, h: .6 };
  const first = flow.crop(firstRegion); await new Promise(resolve => setImmediate(resolve));
  const second = flow.crop(newerRegion); await new Promise(resolve => setImmediate(resolve));
  assert.equal(JSON.stringify(requests[0].region), JSON.stringify(firstRegion));
  assert.equal(JSON.stringify(requests[1].region), JSON.stringify(newerRegion));
  assert.notEqual(requests[0].job,requests[1].job,'rapid region updates use independent request IDs');
  requests[1].resolve(JSON.stringify(body)); assert.equal((await second).length, 1);
  requests[0].resolve(JSON.stringify({ ...body, data: [] }));
  assert.equal(await first, undefined, 'Old selection results must not overwrite the latest region');
  assert.equal(reads, 1, 'region changes reuse the original prepared bytes');
  flow.open('not-returned'); assert.equal(opened, 0);
  flow.open('123'); assert.equal(opened, 1);
  session.generation++; flow.open('123'); assert.equal(opened, 1);
  let finishRead, sharedReads=0, sharedUploads=0;
  const sharedFlow=new Flow({...ports,pick:async()=> 'shared-photo',read:()=>{sharedReads++;return new Promise(resolve=>{finishRead=resolve;});},
    network:()=>({cancel(){},searchUploadedPhoto:async()=>{sharedUploads++;return JSON.stringify(body);}})});
  const originalRead=sharedFlow.search();await new Promise(resolve=>setImmediate(resolve));
  const duringRead=sharedFlow.crop(firstRegion);await new Promise(resolve=>setImmediate(resolve));
  assert.equal(sharedReads,1,'crop while preparing shares the in-flight image read');
  finishRead(fullPhoto);assert.equal(await originalRead,undefined);assert.equal((await duringRead).length,1);
  assert.equal(sharedUploads,1,'superseded initial flow does not upload');
  sharedFlow.cancel();const freshRead=sharedFlow.search();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(sharedReads,2,'closing clears prepared image bytes');finishRead(fullPhoto);await freshRead;
  let attempts=0;
  const retryFlow=new Flow({...ports,pick:async()=> 'retry-photo',read:async()=>{if(++attempts===1)throw Error('read');return fullPhoto;},
    network:()=>({cancel(){},searchUploadedPhoto:async()=>JSON.stringify(body)})});
  await assert.rejects(retryFlow.search());assert.equal((await retryFlow.crop(firstRegion)).length,1);
  assert.equal(attempts,2,'failed image preparation is not cached');
  const isolatedReads=[];let isolatedUploads=0;
  const isolatedFlow=new Flow({...ports,pick:async()=> 'same-uri',read:()=>new Promise(resolve=>isolatedReads.push(resolve)),
    network:()=>({cancel(){},searchUploadedPhoto:async()=>{isolatedUploads++;return JSON.stringify(body);}})});
  const oldImage=isolatedFlow.search();await new Promise(resolve=>setImmediate(resolve));isolatedFlow.cancel();
  const newImage=isolatedFlow.search();await new Promise(resolve=>setImmediate(resolve));assert.equal(isolatedReads.length,2);
  isolatedReads[0](fullPhoto);assert.equal(await oldImage,undefined);assert.equal(isolatedUploads,0);
  isolatedReads[1](fullPhoto);await newImage;assert.equal(isolatedUploads,1,'old read cannot clear or populate the new image preparation');
  console.log('photo search response, cancellation, session and result checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
