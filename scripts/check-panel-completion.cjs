const fs = require('node:fs');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const read = p => fs.readFileSync(p, 'utf8');
function host(path, names) {
  const source = read(path);
  const methods = names.map(name => {
    const start = new RegExp('^  (?:private )?(?:async )?' + name + '\\(', 'm').exec(source);
    assert(start, name);
    const next = /\n  (?:private |@|(?:async )?\w+\()/g;
    next.lastIndex = start.index + 1;
    const end = next.exec(source);
    return source.slice(start.index, end ? end.index : source.length - 2);
  });
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { PinmonyRuntimeLog: { warn() {} } });
}
async function main() {
  const Search = host('feature_search/src/main/ets/controllers/PinmonySearchController.ets',
    ['dismissSearchFilters', 'finishSearchFiltersClose', 'retrySearchFilters', 'selectSearchFilter', 'refreshSearchFilters']);
  for (const loading of [true, false]) {
    const h = new Search(); let canceled = 0, requests = 0;
    Object.assign(h, { filterClosing: false, searchStore: { searchFilterToken: 1, searchFilterLoading: loading,
      searchFilterError: 'error', searchFilterOptions: [{ id: 'a' }] }, searchFilterScript: () => '',
      ports: { sheetKind: () => 'searchFilter', nativeSearch: () => true,
        nativeSearchCancelFilters(preserve) { assert.equal(preserve, true); canceled++; },
        setFilterVisible(value) { assert.equal(value, false); }, nativeSearchFilters() { requests++; } } });
    const rows = h.searchStore.searchFilterOptions;
    h.dismissSearchFilters(); h.dismissSearchFilters();
    assert.equal(canceled, 1); assert.equal(h.searchStore.searchFilterToken, 2);
    assert.equal(h.searchStore.searchFilterOptions, rows);
    assert.equal(h.searchStore.searchFilterLoading, loading); assert.equal(h.searchStore.searchFilterError, 'error');
    await h.retrySearchFilters(); await h.selectSearchFilter('a'); await h.refreshSearchFilters(); assert.equal(requests, 0);
    h.finishSearchFiltersClose(); h.finishSearchFiltersClose();
    assert.equal(h.searchStore.searchFilterOptions.length, 0); assert.equal(h.searchStore.searchFilterLoading, false);
  }
  const Reads = host('entry/src/main/ets/app/PinmonySearchNativeReads.ets', ['cancelFilters']);
  const r = new Reads(); let cancellations = 0;
  Object.assign(r, { filterRevision: 0, filterId: 'request', store: {searchFilterLoading: true, searchFilterOpen: true},
    ports: {network: () => ({cancel() {cancellations++;}})} });
  r.cancelFilters(true); assert.equal(cancellations, 1); assert.equal(r.filterRevision, 1);
  assert.equal(r.store.searchFilterLoading, true); assert.equal(r.store.searchFilterOpen, false);
  r.cancelFilters(); assert.equal(r.store.searchFilterLoading, false);
  const Profile = host('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', ['closeAboutFor', 'finishAboutClose']);
  for (const stale of [false, true]) {
    const h = new Profile(), events = [];
    Object.assign(h, {aboutVisible: true, aboutPendingAction: '', interactionReady: true,
      profile: {profileUrl: 'profile', session: 1}, perform(action) {events.push(action);} });
    h.closeAboutFor('followers'); h.closeAboutFor('edit'); assert.equal(events.length, 0); assert.equal(h.aboutVisible, false);
    if (stale) h.profile.session++;
    h.finishAboutClose(); h.finishAboutClose(); assert.equal(events.length, stale ? 0 : 1);
  }
  const Comments = host('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets', ['requestCommentDelete', 'finishCommentMenuClose']);
  const Sort = host('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', ['requestSortDestination', 'finishSortClose']);
  for (const custom of [true, false]) for (const stale of [true, false]) {
    const h = new Sort(); let recovery = 0;
    Object.assign(h, {sortVisible:true, interactionReady:true, profile:{profileUrl:'profile',session:1,isOwn:true},
      customOrderVisible:false,onBoardRecovery(){recovery++;}});
    h.requestSortDestination(custom); assert.equal(h.customOrderVisible,false); assert.equal(recovery,0);
    if(stale)h.profile.session++;
    h.finishSortClose();h.finishSortClose();
    assert.equal(h.customOrderVisible,custom&&!stale);assert.equal(recovery,!custom&&!stale?1:0);
  }
  for (const stale of [false, true]) {
    const h = new Comments(), events = [];
    Object.assign(h, {menuOpen: true, pendingDeleteId: '', deleteOpen: true, menuItem: {id: 'c', canDelete: true},
      result: {pin: 'pin', mutationVersion: 1}, onWrite(raw) {events.push(JSON.parse(raw));} });
    h.requestCommentDelete(); h.requestCommentDelete(); assert.equal(events.length, 0); assert.equal(h.deleteOpen, true);
    if (stale) h.result.pin = 'other';
    h.finishCommentMenuClose(); h.finishCommentMenuClose(); assert.equal(events.length, stale ? 0 : 1);
  }
  const Detail = host('entry/src/main/ets/app/PinmonyDetailNativeReads.ets', ['cancelComments']);
  const d = new Detail(), result = {pin:'pin', loading:true, items:[{repliesLoading:true}]};
  Object.assign(d, {pin:'pin', commentsBusy:true, commentsRevision:0, store:{commentResult:result},
    requests:new Set(['native_comments_test']), ports:{network:()=>({cancel(){}})},
    publishComments(){throw Error('presentation rewritten during exit');}, cancelTranslation(){throw Error('presentation rewritten');} });
  d.cancelComments(true); assert.equal(result.loading,true); assert.equal(result.items[0].repliesLoading,true); assert.equal(d.commentsRevision,1);
  const Writes = host('entry/src/main/ets/app/PinmonyCommentNativeWrites.ets', ['pause']);
  const w = new Writes(); Object.assign(w,{revision:0,requests:new Set(),waits:new Map(),pending:true,submitted:true,result:{},
    store:{commentResult:{busy:true}},publish(){throw Error('presentation rewritten');},ports:{network:()=>({cancel(){}})}});
  w.pause(true); assert.equal(w.store.commentResult.busy,true); assert.equal(w.pending,false); assert.equal(w.revision,1);
  const Panels = host('feature_pin/src/main/ets/controllers/PinmonyPostPanelsController.ets', ['pause','dismiss']);
  const panels = new Panels(); let hidden = 0;
  Object.assign(panels,{mode:'comments',nativeComments:true,store:{commentToken:1},generation:0,
    tasks:{invalidate(){}},ports:{cancelNativeCommentWrites:p=>w.pause(p),cancelNativeComments:p=>d.cancelComments(p),
      show(kind){assert.equal(kind,'');hidden++;}}});
  panels.dismiss('comments'); panels.dismiss('comments');
  assert.equal(hidden,1);assert.equal(panels.store.commentToken,2);assert.equal(result.loading,true);
  assert.equal(w.store.commentResult.busy,true,'real controller cancellation preserves native presentation');
  const Index = host('entry/src/main/ets/pages/Index.ets', ['dismissProfileMenu','requestMoreSheetClose','requestShareSheetClose']);
  const i = new Index(); let paused = 0;
  Object.assign(i,{activeSheetKind:'profileMenu',showNativeSheet:true}); i.dismissProfileMenu(); assert.equal(i.activeSheetKind,'profileMenu');
  Object.assign(i,{pinStore:{},homeStore:{customHomeMenu:false},sharePanelsController:{pause(p){assert.equal(p,true);paused++;}}});
  for(const kind of ['share','more']) {i.activeSheetKind=kind;i.showNativeSheet=false;i[kind==='share'?'requestShareSheetClose':'requestMoreSheetClose']();}
  assert.equal(paused,2,'interactive callbacks still cancel after two-way visibility update');
  console.log('Panel completion: retained loading/error/content, request cancellation, exit action gates, delayed navigation/delete, stale contexts and callback ordering passed');
}
main().catch(error => {console.error(error);process.exitCode=1;});
