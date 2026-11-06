const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { createSearchRuntime } = require('./search-controller-harness.cjs');
const linkModule = createArktsLoader(ts).loadFile('feature_search/src/main/ets/services/PinmonySearchPinLink.ets');
const parse = linkModule.searchPinLinkIdentity;
assert.equal(linkModule.searchShortPinLink(' https://pin.it/Example '),'https://pin.it/Example');
assert.equal(linkModule.searchShortPinLink('https://pin.it.evil.test/Example'),'');
for (const value of ['https://www.pinterest.com/pin/123/', ' http://pinterest.com/pin/123 ',
  'https://uk.pinterest.com/pin/123?tracking=anything', 'https://m.pinterest.com/pin/123/#image',
  'https://www.pinterest.com/pin/123/sent/?invite_code=example']) {
  assert.equal(parse(value), '123');
}
for (const value of ['https://pinterest.com.evil.test/pin/123/', 'https://evil.test/pin/123/',
  'https://user@pinterest.com/pin/123/', 'https://pinterest.com/pin/123evil/',
  'https://pinterest.com/pin/123/extra', 'https://evil.test/?url=https://pinterest.com/pin/123/',
  'https://pinterest.com/pin/123/\nhttps://evil.test', 'https://pin.it/example',
  'javascript:https://pinterest.com/pin/123/', 'look https://pinterest.com/pin/123/',
  'https://pinterest.com/pin/' + '1'.repeat(31), 'https://pinterest.com/pin/123/?x=' + 'x'.repeat(2048)]) {
  assert.equal(parse(value), '', value);
}
const page = 'https://www.pinterest.com/search/pins/?q=art';
const snapshot = { kind: 'state', session: 2, pageKey: page, query: 'art', categories: [],
  suggestions: [], results: [], heroes: [], ideaSections: [], api: true, inputReady: true, apiActive: true };
function fixture(overrides = {}) {
  const calls = [];
  const h = createSearchRuntime(ts).harness({nativeSearch: () => true,
    openSubmittedPin: (id, source) => calls.push([id, source]), ...overrides});
  h.store.search = {...snapshot};
  h.store.searchNativeInputReady = true;
  h.store.searchScrollOffset = 93;
  return { h, calls };
}
async function main() {
  // Run the actual Search callback: closing the editing layer can emit a
  // programmatic value restoration after submission has started resolving.
  const ui = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
  const input = ui.indexOf(".id(editing ? 'pinmony-search-edit-input'");
  const change = ui.indexOf('.onChange(', input);
  const submit = ui.indexOf('.onSubmit(', change);
  assert(input >= 0 && change > input && submit > change);
  const callback = ui.slice(change + '.onChange('.length, submit).trim().replace(/\)$/, '');
  const callbackCode = ts.transpileModule('(function() { return (' + callback + '); })',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
  const createOnChange = vm.runInNewContext(callbackCode);
  let finishRestore;
  const restored = fixture({resolveSubmittedPin:()=>new Promise(resolve=>finishRestore=resolve)});
  const restoredPending = restored.h.controller.submitSearch('https://pin.it/Example');
  assert.equal(restored.h.store.submittedPinLoading,true,'pending short link blocks underlying content');
  let edits = 0;
  const view = {active:true,inputEditing:false,query:'https://pin.it/Example',
    onQueryChange(value) { edits++; return restored.h.controller.updateSearchQuery(value); }};
  const onChange = createOnChange.call(view);
  onChange.call(view,'art');
  assert.equal(edits,0,'restoring an inactive input must not cancel link resolution');
  finishRestore('456'); await restoredPending;
  assert.equal(restored.h.store.submittedPinLoading,false,'success releases loading mask');
  const maskSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  const mask = maskSource.slice(maskSource.indexOf('        if (this.searchStore.submittedPinLoading'));
  assert(mask.includes(".backgroundColor('#66808080').hitTestBehavior(HitTestMode.Block).zIndex(100)"),
    'pending link mask is grey, intercepts touches and covers sibling overlays');
  assert.deepEqual(restored.calls,[['456',page]],'restored input still opens resolved detail');
  view.inputEditing=true; onChange.call(view,'edited');
  assert.equal(edits,1,'active user edits still reach the controller');
  view.active=false; onChange.call(view,'hidden');
  assert.equal(edits,1,'hidden search does not submit edits');
  const { h, calls } = fixture();
  let stopped = 0;
  h.store.searchInputFocused = true;
  h.store.searchInputStopEditing = () => stopped++;
  const before = h.store.searchQueryToken;
  await h.controller.submitSearch('https://uk.pinterest.com/pin/123/?tracking=value');
  assert.deepEqual(calls, [['123', page]]);
  assert.equal(stopped, 1);
  assert.equal(h.store.searchInputFocused, false);
  assert.equal(h.store.searchScrollOffset, 93, 'keep return position');
  assert(h.store.searchQueryToken > before, 'invalidate pending suggestions');
  assert.equal(h.events.filter(e => ['search', 'js', 'read'].includes(e[0])).length, 0);
  await h.controller.submitSearch('ordinary query');
  assert(h.events.some(e => e[0] === 'search' && e[1].endsWith('q=ordinary%20query')));
  const short=fixture({resolveSubmittedPin:async (link,current)=>{assert.equal(link,'https://pin.it/Example');assert(current());return '456';}});
  await short.h.controller.submitSearch('https://pin.it/Example');assert.deepEqual(short.calls,[['456',page]]);
  assert.equal(short.h.events.filter(e=>e[0]==='search').length,0,'short link must not become a search query');
  const completions=[];
  const repeated=fixture({resolveSubmittedPin:()=>new Promise(resolve=>completions.push(resolve))});
  const first=repeated.h.controller.submitSearch('https://pin.it/Example');
  const second=repeated.h.controller.submitSearch('https://pin.it/Another');
  completions[0]('111'); await first;
  assert.equal(repeated.h.store.submittedPinLoading,true,'old completion cannot dismiss a newer loading mask');
  assert.equal(repeated.calls.length,0,'old completion cannot open a detail');
  assert.equal(repeated.h.controller.cancelSubmittedPin(),true,'back consumes a pending link');
  assert.equal(repeated.h.store.submittedPinLoading,false,'back immediately dismisses the mask');
  completions[1]('222'); await second;
  assert.equal(repeated.calls.length,0,'cancelled link cannot open after back');
  assert.equal(repeated.h.controller.cancelSubmittedPin(),false,'idle search retains its normal back behavior');
  const hostSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  const backStart=hostSource.indexOf('  onBackPress(): boolean {');
  const backEnd=hostSource.indexOf('\n  private ',backStart);
  const backType=vm.runInNewContext(ts.transpileModule('class Host {'+hostSource.slice(backStart,backEnd)+'} Host;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
  const busyHost=new backType();
  busyHost.searchController={cancelSubmittedPin:()=>true};
  assert.equal(busyHost.onBackPress(),true,'host consumes pending-link back before underlying navigation');
  for(const action of ['edit','submit','page','inactive','invalidate']) {
    let finish;let cancelled=0;
    const stale=fixture({resolveSubmittedPin:()=>new Promise(resolve=>finish=resolve),cancelSubmittedPin:()=>cancelled++});
    const waiting=stale.h.controller.submitSearch('https://pin.it/Example');
    assert.equal(typeof finish,'function');
    if(action==='edit')await stale.h.controller.updateSearchQuery('edited');
    if(action==='submit')await stale.h.controller.submitSearch('new query');
    if(action==='page')stale.h.setPage(page+'&changed=1');
    if(action==='inactive')stale.h.setActive(false);
    if(action==='invalidate')stale.h.controller.invalidatePending();
    finish('456');await waiting;assert.equal(stale.calls.length,0,action);assert(cancelled>0);
    assert.equal(stale.h.store.submittedPinLoading,false,'stale submission releases loading mask: '+action);
  }
  const failure=fixture({resolveSubmittedPin:async()=>{throw Error('network');}});
  await failure.h.controller.submitSearch('https://pin.it/Example');
  assert.equal(failure.h.store.submittedPinLoading,false,'failure releases loading mask');
  assert.equal(failure.calls.length,0);assert.equal(failure.h.events.filter(e=>e[0]==='notice').length,2,'loading and actual failure');
  for (const block of ['inactive', 'sheet', 'stale', 'unready']) {
    const f = fixture();
    if (block === 'inactive') f.h.setActive(false);
    if (block === 'sheet') f.h.setSheet('searchFilter');
    if (block === 'stale') f.h.setPage(page + '&changed=true');
    if (block === 'unready') Object.assign(f.h.store, {searchNativeInputReady: false, searchInputReady: false, searchActionsReady: false});
    await f.h.controller.submitSearch('https://pinterest.com/pin/123/');
    assert.equal(f.calls.length, 0, block);
  }
  // Exercise the actual product binding, including session-origin normalization.
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const begin = source.indexOf('    openSubmittedPin:');
  const end = source.indexOf('    navigateResult:', begin);
  const code = ts.transpileModule('function bind() { return ({' + source.slice(begin, end) + '}); } bind;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
  const opened = [];
  const host = {authStatus: 'authenticated', activeTab: 1, activeSheetKind: '', businessSuspended: false,
    currentSearchPageKey: () => page, nativeBusinessSessionContext: () => ({origin: 'https://uk.pinterest.com'}),
    pageHistory: { visit: () => {} }, beginDetailOpening: (...args) => opened.push(args)};
  const binding = vm.runInNewContext(code, {PIN_NATIVE_DETAIL_READS_ENABLED: true}).call(host);
  binding.openSubmittedPin('123', page);
  assert.deepEqual(opened, [['https://uk.pinterest.com/pin/123/', page]]);
  for (const patch of [{authStatus: 'unknown'}, {businessSuspended: true}, {activeTab: 0}, {activeSheetKind: 'save'}]) {
    const old = {...host}; Object.assign(host, patch); binding.openSubmittedPin('123', page); Object.assign(host, old);
  }
  binding.openSubmittedPin('../settings', page);
  binding.openSubmittedPin('123', page + '&stale=1');
  assert.equal(opened.length, 1, 'product rejects unauthorized or obsolete entry');
  let checked;
  let session = {origin:'https://uk.pinterest.com',authenticated:true,accountId:'synthetic-account',generation:1};
  Object.assign(host,{authEpoch:1,nativeSearchPageVisible:()=>true,nativeBusinessSessionContext:()=>session,
    submittedPinResolver:{resolve:async(link,current)=>{checked=current;return '123';},cancel(){}}});
  await binding.resolveSubmittedPin('https://pin.it/Example',()=>true);assert(checked());
  session={...session,accountId:'other-account'};assert.equal(checked(),false,'old account cannot open a short link');
  session={...session,accountId:'synthetic-account',generation:2};assert.equal(checked(),false,'old session cannot open a short link');
  session={...session,generation:1};host.authEpoch++;assert.equal(checked(),false,'old auth epoch cannot open a short link');
  host.authEpoch=1;host.businessSuspended=true;assert.equal(checked(),false,'background cannot open a short link');
  h.controller.invalidatePending();
  console.log('Search Pin link: trusted URLs, normal queries, session guards, native detail and return position passed');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
