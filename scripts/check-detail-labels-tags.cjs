const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function compile(file) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: () => ({ PinmonyRuntimeLog: { info() {}, warn() {} } }), console });
  return exports;
}
const { splitDescriptionTags, descriptionTagSearchUrl } = compile('feature_pin/src/main/ets/services/PinmonyDescriptionTags.ets');
const { mapPrefetchedDetail, PinmonyDetailPrefetch } = compile('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets');
const pin = 'https://uk.pinterest.com/pin/101/';
const text = '风景 #aiart #海边 #여자일러스트 #seasidefantasy, #colorfularchitecture';
const parts = splitDescriptionTags(text);
assert.equal(parts.map(p => p.text).join(''), text);
assert.deepEqual(Array.from(parts.filter(p => p.query), p => p.query), ['aiart', '海边', '여자일러스트', 'seasidefantasy', 'colorfularchitecture']);
assert.equal(descriptionTagSearchUrl(pin, text, 'aiart'), 'https://uk.pinterest.com/search/pins/?q=aiart');
assert.equal(descriptionTagSearchUrl(pin, text, '海边'), 'https://uk.pinterest.com/search/pins/?q=%E6%B5%B7%E8%BE%B9');
assert.equal(descriptionTagSearchUrl(pin, text, 'unrelated'), '');
assert.equal(descriptionTagSearchUrl('https://evil.invalid/pin/101/', text, 'aiart'), '');
assert.equal(splitDescriptionTags('word#embedded ##invalid').some(p => p.query), false);
const base = { id: '101', type: 'pin', images: { '736x': { url: 'https://i.pinimg.com/test.jpg', width: 736, height: 1000 } } };
const envelope = fields => JSON.stringify({ resource_response: { status: 'success', data: { ...base, ...fields } } });
const bridgeSource = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailScript.ets', 'utf8');
const bridge = Function('return `' + bridgeSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
const snapshotBody = bridge.match(/function apiSnapshot\(pin\) \{([\s\S]*?)\n  function snapshot\(pin\)/)[1];
const context = { window: {}, location: { origin: 'https://uk.pinterest.com', href: pin }, URL,
  session: 1, schedule() {}, findHero: () => null, webFlowActive: false };
vm.runInNewContext('function apiSnapshot(pin) {' + snapshotBody, context);
for (const [fields, expected] of [
  [{ ai_disclosures: [1] }, '由 AI 修改'],
  [{ gen_ai_topics: [{ name: '艺术' }], digital_media_source_type: 16 }, '由 AI 修改'],
  [{ gen_ai_topics: [{ name: '艺术' }], digital_media_source_type: 11 }, '由 AI 修改'],
  [{ gen_ai_topics: null, digital_media_source_type: 16 }, ''],
  [{ gen_ai_topics: [null, { name: ' ' }, { name: 1 }] }, ''], [{}, '']
]) {
  assert.equal(mapPrefetchedDetail(envelope(fields), pin).aiLabel, expected);
  context.window.PinmonyDetailApi = { read: () => ({ detail: { ...base, ...fields }, image: { url: 'https://i.pinimg.com/test.jpg' } }) };
  assert.equal(context.apiSnapshot(pin).aiLabel, expected);
}
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = index.indexOf('  private openDetailTagSearch(');
const end = index.indexOf('\n  private ', start + 1);
const nav = { descriptionTagSearchUrl };
vm.runInNewContext(ts.transpileModule('class Navigation {' + index.slice(start, end) + '} globalThis.Navigation = Navigation;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, nav);
const calls = [];
const n = new nav.Navigation();
Object.assign(n, { authStatus: 'authenticated', activeSheetKind: '', pinIdentity: () => '101',
  pinStore: { detail: { pinUrl: pin, description: text }, detailPin: pin, detailScrollOffset: 5,
    detailCache: { put: () => calls.push('cache') } }, pageHistory: { visit: () => calls.push('history') },
  clearDetail: () => calls.push('clear'), tabsController: { changeIndex: () => calls.push('tab') },
  prepareSearchNavigation: () => calls.push('prepare'), controller: { loadUrl: url => calls.push(url) }, searchStore: {} });
n.openDetailTagSearch('aiart', 'https://uk.pinterest.com/pin/999/');
n.openDetailTagSearch('unrelated', pin);
assert.equal(calls.length, 0, 'stale Pin or unrelated query cannot navigate');
n.openDetailTagSearch('aiart', pin);
assert.deepEqual(calls, ['cache', 'history', 'clear', 'tab', 'prepare', 'https://uk.pinterest.com/search/pins/?q=aiart']);
assert.equal(n.activeTab, 1); assert.equal(n.nativeRootOnly, true);
(async () => {
  const prefetch = new PinmonyDetailPrefetch();
  const body = await prefetch.open(pin, async () => envelope({ gen_ai_topics: [{ name: '艺术' }], digital_media_source_type: 16,
    link: 'https://example.invalid/article',
    ignored_private_field: 'never retained' }), () => true, () => {});
  const selected = JSON.parse(body).resource_response.data;
  assert.equal(selected.gen_ai_topics[0].name, '艺术');
  assert.equal(selected.digital_media_source_type, 16);
  assert.equal(selected.link, 'https://example.invalid/article', 'verified detail handoff retains source links for the existing visit action');
  assert.equal(selected.ignored_private_field, undefined);
  assert.equal(prefetch.get(pin).aiLabel, '由 AI 修改');
  console.log('AI labels through selected native fields, bridge, cache and guarded multilingual tag search OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
