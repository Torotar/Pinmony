const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const src=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
function method(name){const a=src.indexOf('  private '+name);assert(a>=0);const b=src.indexOf('\n  private ',a+1);return src.slice(a,b<0?src.lastIndexOf('\n}'):b).replace('private ','');}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('committedQuery(')+method('closeInputPanel(')+method('onInputFocus(')+method('onSnapshotChanged(')+'}\nHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const h=new Host(),events=[];h.snapshot={pageKey:'https://www.pinterest.com/search/pins/?q=old+query',query:'draft',session:2,heroes:[]};h.inputController={stopEditing(){events.push('stop')}};h.onQueryChange=(value,refresh)=>events.push([value,refresh]);h.onInputFocusChange=(focus)=>events.push(focus);h.ensureSearchDestination=()=>{};h.tracePresentation=()=>{};h.syncQuizPresentation=()=>{};h.fillInitialViewport=()=>{};
h.query='draft';h.inputEditing=true;h.onSnapshotChanged();assert.equal(h.query,'draft');h.closeInputPanel(true);assert.equal(h.inputEditing,false);assert.equal(h.query,'old query');assert.equal(events.at(-2)[0],'old query');
h.onInputFocus(true);assert.deepEqual(events.at(-2),['old query',true]);h.snapshot={pageKey:'https://www.pinterest.com/search/pins/?q=new',query:'new',session:3,heroes:[]};h.onSnapshotChanged();h.closeInputPanel(false);assert.equal(h.query,'new');assert.equal(h.inputEditing,false);
h.snapshot.pageKey='https://www.pinterest.com/search/';assert.equal(h.committedQuery(),'');assert(src.includes('.onBlur(() => { /* Keyboard focus does not dismiss'));
h.snapshot.heroes=[{id:'first'},{id:'second'}];h.onSnapshotChanged();h.currentHeroIndex=1;
h.snapshot.session++;h.onSnapshotChanged();assert.equal(h.currentHeroIndex,1,'return document session rebind preserves carousel position on the same route');
const resultBody=src.slice(src.indexOf('  private searchResultsContent('),src.indexOf('  private inputSuggestionsContent('));
assert(!resultBody.includes('LoadingProgress')&&!resultBody.includes('searchLoading('),'result loading and pagination never replace cards with an animation');
assert(!src.includes("searchLoading('正在加载搜索内容"),'return landing content stays mounted during refresh');
console.log('Search draft, committed route, cancel, navigation and panel refresh passed');
