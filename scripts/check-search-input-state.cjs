const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const src=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
function method(name){const a=src.indexOf('  private '+name);assert(a>=0);const b=src.indexOf('\n  private ',a+1);return src.slice(a,b<0?src.lastIndexOf('\n}'):b).replace('private ','');}
const timers=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('committedQuery(')+method('closeInputPanel(')+method('beginSearchInput(')+method('focusMountedSearchInput(')+method('onInputFocus(')+method('showSearchHistoryDestination(')+method('closeSearchHistoryDestination(')+method('onSnapshotChanged(')+'}\nHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){},warn(){}},setTimeout: (callback)=>timers.push(callback)});
const h=new Host(),events=[];h.snapshot={pageKey:'https://www.pinterest.com/search/pins/?q=old+query',query:'draft',session:2,heroes:[]};h.inputController={stopEditing(){events.push('stop')}};h.onQueryChange=(value,refresh)=>events.push([value,refresh]);h.onInputFocusChange=(focus)=>events.push(focus);h.closePhotoSearch=()=>{};h.restoreHeroPosition=()=>{};h.ensureSearchDestination=()=>{};h.tracePresentation=()=>{};h.syncQuizPresentation=()=>{};h.fillInitialViewport=()=>{};
h.rememberDiscoverySnapshot=()=>{};h.discoverySnapshot=()=>h.snapshot;h.setCategoriesCollapsed=value=>{h.categoriesCollapsed=value;};h.restoreResultsScroll=()=>{};h.displayInputController={stopEditing(){},caretPosition(){}};
const paths=['pin-web-search'];h.searchPathStack={getAllPathName:()=>paths.slice(),pushPath:info=>paths.push(info.name),pop:()=>paths.pop()};
h.activeSession=h.snapshot.session;h.activePage=h.snapshot.pageKey;h.query='draft';h.inputEditing=true;h.onSnapshotChanged();assert.equal(h.query,'draft');h.closeInputPanel(true);assert.equal(h.inputEditing,false);assert.equal(h.query,'old query');assert.equal(events.at(-2)[0],'old query');
h.onInputFocus(true);assert.deepEqual(events.at(-2),['old query',true]);h.snapshot={pageKey:'https://www.pinterest.com/search/pins/?q=new',query:'new',session:3,heroes:[]};h.onSnapshotChanged();assert.equal(h.inputEditing,false,'route change dismisses history on mounted HDS destination');h.closeInputPanel(false);assert.equal(h.query,'new');assert.equal(h.inputEditing,false);
h.snapshot.pageKey='https://www.pinterest.com/search/';assert.equal(h.committedQuery(),'');assert(src.includes('.onBlur(() => { /* Keyboard focus does not dismiss'));
h.snapshot.heroes=[{id:'first'},{id:'second'}];h.onSnapshotChanged();h.currentHeroIndex=1;
h.snapshot.session++;h.onSnapshotChanged();assert.equal(h.currentHeroIndex,1,'return document session rebind preserves carousel position on the same route');
const resultBody=src.slice(src.indexOf('  private searchResultsContent('),src.indexOf('  private inputSuggestionsContent('));
assert(!resultBody.includes('LoadingProgress')&&!resultBody.includes('searchLoading('),'result loading and pagination never replace cards with an animation');
assert(!src.includes("searchLoading('正在加载搜索内容"),'return landing content stays mounted during refresh');
console.log('Search draft, committed route, cancel, navigation and panel refresh passed');

// Tab activation/focus alone must not enter editing; only explicit input activation does.
h.inputFocusRevision=0;h.pendingInputFocus=false;h.inputEditing=false;h.active=false;h.beginSearchInput();assert.equal(h.inputEditing,false);
h.active=true;h.query='old query';assert.equal(h.inputEditing,false);h.beginSearchInput();assert.equal(h.inputEditing,true);
assert.equal(h.pendingInputFocus,true,'explicit click queues focus for the replacement input');
assert.equal(h.query,'old query','editing keeps the committed keyword');
h.pagePresent=true;h.getUIContext=()=>({getFocusController:()=>({requestFocus:(id)=>events.push(['focus',id])})});
h.inputController.caretPosition=(offset)=>events.push(['caret',offset]);
h.focusMountedSearchInput();assert.equal(timers.length,1);timers.shift()();
assert.deepEqual(events.slice(-2),[['focus','pinmony-search-edit-input'],['caret',9]]);
h.inputEditing=false;h.beginSearchInput();h.focusMountedSearchInput();h.closeInputPanel(false);const afterClose=events.length;timers.shift()();assert.equal(events.length,afterClose,'closed panel ignores delayed focus');
h.beginSearchInput();
const eventCount=events.length;h.beginSearchInput();assert.equal(events.length,eventCount,'repeated clicks do not refresh history');
const focusHandler=src.slice(src.indexOf('.onFocus(() =>'),src.indexOf('.onBlur(() =>'));
assert(!focusHandler.includes('onInputFocus(true)'),'automatic focus cannot open history');
console.log('Search tab focus and explicit user editing checks passed');

assert(src.includes("this.searchTitleBarOptions(name)"), 'history owns an editable search node in its HDS title');
assert(src.includes('controller: historyPage ? this.inputController : this.displayInputController'), 'root and history use separate Search controllers');
assert(src.includes(".onAppear(() => { if (editing) this.focusMountedSearchInput(); })"), 'focus waits for the editing input to mount');

// Returning to the root must release the old theme host even when no editor was open.
h.inputEditing=false;h.historyDestinationRetained=true;paths.splice(0,paths.length,'pin-web-search','search-history');
h.activePage='https://www.pinterest.com/search/pins/?q=theme';h.activeSession=8;
h.snapshot={pageKey:'https://www.pinterest.com/search/',query:'',session:8,heroes:[]};
h.lastSnapshotQuery='';h.query='theme';h.onSnapshotChanged();
assert.equal(h.query,'','root URL clears the display even if snapshot.query did not change');
assert.deepEqual(paths,['pin-web-search']);assert.equal(h.historyDestinationRetained,false);
h.beginSearchInput();assert.equal(h.query,'');assert.deepEqual(paths,['pin-web-search','search-history']);
assert.equal(h.inputEditing,true,'clicking root opens history without exposing a retained theme result');
console.log('Root return clears stale theme text and releases old history/result destination before re-entry');
