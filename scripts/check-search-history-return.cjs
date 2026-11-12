const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const destination = source.slice(source.indexOf('  private searchRootDestination('), source.indexOf('  private searchCategoriesTitleBar('));
assert(destination.includes('this.showingSearchHistory(name)'), 'history and results switch body within the current destination');
assert(destination.includes("name !== 'search-history' && this.historyDestinationRetained"),'retained root cannot mount a second results scroller');
assert(!destination.includes('if (this.inputEditing || this.historyRetained)'), 'editing cannot replace root body with a history layer');
assert(destination.includes("this.searchMaterialContent('discovery')") && destination.includes("this.searchMaterialContent('results')"));
assert(destination.includes(".titleBar(PinmonyHdsTitleBar.resolve") && destination.includes("this.searchTitleBarOptions(name)"));
assert(destination.includes("this.showingSearchHistory(name) ? this.historyScroller"), 'history title binds to the actual history scroller');
assert(source.includes('List({ scroller: this.historyScroller })'));
assert(destination.includes('TransitionEffect.IDENTITY'), 'keyword results keep in-place loading');
assert(destination.includes(".hitTestBehavior(this.inputEditing || !!this.committedQuery() || !this.rootDiscoveryVisible() ? HitTestMode.None : HitTestMode.Default)"));
assert(destination.includes(".accessibilityLevel(this.inputEditing || !!this.committedQuery() || !this.rootDiscoveryVisible() ? 'no-hide-descendants' : 'auto')"));
const start = source.indexOf('  private handleSearchBack(');
const end = source.indexOf('\n  private ', start + 1);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  source.slice(start, end).replace('private ', '') + '}\nHost;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const host = new Host();
let page = 'results';
host.snapshot = {};
host.searchPathStack = { getAllPathName: () => [] };
host.requestQuizClose=()=>host.onQuizAction();
host.inputEditing = false;
host.committedQuery = () => 'query';
host.openSearchHistory = () => { host.inputEditing = true; page = 'history'; };
host.closeInputPanel = () => { host.inputEditing = false; };
host.onBack = () => { if (!host.inputEditing) { host.openSearchHistory(); return; } page = 'root'; };
host.handleSearchBack();
assert.equal(page, 'history');
host.handleSearchBack();
assert.equal(page, 'root');
assert.equal(host.inputEditing, false, 'mounted HDS destination must leave history even without parent stop callback');
host.committedQuery = () => '';
host.inputEditing = true;
host.closeInputPanel = () => { host.inputEditing = false; page = 'root'; };
host.handleSearchBack();
assert.equal(page, 'root');
let rootBacks=0, childBacks=0;
host.onRootBack=()=>{rootBacks++;};host.onBack=()=>{childBacks++;};
host.handleSearchBack();assert.equal(rootBacks,1,'HDS search root forwards system back to the app exit policy');assert.equal(childBacks,0);
host.inputEditing=true;host.handleSearchBack();assert.equal(rootBacks,1,'closing root history does not also arm exit');
host.committedQuery=()=> 'query';host.handleSearchBack();assert.equal(childBacks,1,'search results retain child back behavior');assert.equal(rootBacks,1);
host.committedQuery=()=>'';host.snapshot.quiz={mode:'results'};host.onQuizAction=()=>{childBacks++;};host.handleSearchBack();assert.equal(childBacks,2,'quiz child consumes back before exit');assert.equal(rootBacks,1);
const rootView=fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets','utf8');assert(rootView.includes('onRootBack: () => { view.rootBack(); }'));
const rootIndex=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');assert(rootIndex.includes('rootBack: (): boolean => this.onBackPress()'),'root back uses the full overlay-aware app policy');
const navigation = fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets', 'utf8');
const branch = navigation.slice(navigation.indexOf('else if (this.searchStore.searchInputFocused'),
  navigation.indexOf('else if (this.pinStore.detailWebFlow)'));
assert(branch.includes('this.ports.backFromSearch()'));
assert(!branch.includes('searchInputFocused = false'), 'Preserve history state until backFromSearch consumes it');
function inputMethod(name) {
  const a=source.indexOf('  private '+name+'('),b=source.indexOf('\n  private ',a+1);
  assert(a>=0);return source.slice(a,b<0?source.lastIndexOf('\n}'):b);
}
const Input=vm.runInNewContext(ts.transpileModule('class Input {'+
  ['onInputFocus','openSearchHistory','closeInputPanel','committedQuery','showSearchHistoryDestination','closeSearchHistoryDestination','finishSearchHistoryClose','submitSearchInput','showingSearchHistory'].map(inputMethod).join('\n')+'} Input;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const input=new Input();let stopEditing;
const paths=['pin-web-search'], navEvents=[];
input.setCategoriesCollapsed=value=>{input.categoriesCollapsed=value;};input.ensureSearchDestination=()=>{};input.focusMountedSearchInput=()=>{};
input.searchPathStack={getAllPathName:()=>paths.slice(),pushPath:(info,animated)=>{paths.push(info.name);navEvents.push(['push',info.name,animated]);},pop:animated=>{navEvents.push(['pop',paths.pop(),animated]);}};
Object.assign(input,{pagePresent:true,active:true,snapshot:{pageKey:'https://www.pinterest.com/search/pins/?q=test',query:'test',session:1},
  inputController:{stopEditing(){}},displayInputController:{stopEditing(){}},inputFocusRevision:0,onQueryChange(){},
  onInputFocusChange(focused,stop){if(focused)stopEditing=stop;}});
input.onInputFocus(true);
assert.deepEqual(paths,['pin-web-search','search-history'],'explicit click enters a separate page');
input.showSearchHistoryDestination();assert.equal(paths.length,2,'repeat click cannot duplicate pages');
input.closeInputPanel(false);
assert.equal(input.inputEditing,false);assert.equal(paths.length,2,'submission keeps the history/result destination mounted');
assert.equal(input.historyDestinationRetained,true);
const submittedNavigationCount=navEvents.length;
input.openSearchHistory();assert.equal(input.inputEditing,true);
assert.equal(input.showingSearchHistory('search-history'),true);assert.equal(input.showingSearchHistory('pin-web-search'),false);
assert.equal(navEvents.length,submittedNavigationCount,'results return changes only body and never pushes, pops or animates a destination');
assert.equal(input.pendingInputFocus,false,'returning to history cannot force a keyboard');
stopEditing();assert.deepEqual(paths,['pin-web-search'],'second back exits history only once');
assert.equal(input.historyDestinationRetained,true,'retain outgoing host until native exit completes');
input.finishSearchHistoryClose();
assert.equal(input.historyDestinationRetained,false);
// Direct recommendation results install a nonanimated history host for the next exit.
const rootNavCount=navEvents.length;input.openSearchHistory();
assert.equal(input.showingSearchHistory('search-history'),true);assert.equal(input.showingSearchHistory('pin-web-search'),false);
assert.equal(navEvents.length,rootNavCount+1);assert.deepEqual(navEvents.at(-1),['push','search-history',false]);
input.closeInputPanel(true);assert.deepEqual(paths,['pin-web-search']);
input.finishSearchHistoryClose();
input.active=true;input.interactionReady=true;
let submitted='';input.onSubmit=value=>{submitted=value;};
input.onInputFocus(true);input.submitSearchInput('   ');assert.equal(input.inputEditing,true,'blank submission keeps history');
input.query='draft term';const submitNavCount=navEvents.length;input.submitSearchInput('  draft term  ');
assert.equal(submitted,'draft term');assert.equal(input.inputEditing,false);assert.equal(navEvents.length,submitNavCount,'keyword submission replaces only body');
input.openSearchHistory();input.closeInputPanel(true);assert.deepEqual(paths,['pin-web-search']);
input.finishSearchHistoryClose();
assert(source.includes('this.closeInputPanel(false); this.onSuggestion(item.id);'), 'history/suggestion selection closes the destination before dispatching the original action');
paths.push('photo-search');input.closeSearchHistoryDestination(true);assert.equal(paths.at(-1),'photo-search','history close cannot pop an unrelated photo page');
assert(source.includes('.enableKeyboardOnFocus(editing)') && source.includes('.focusable(editing)'), 'only the history search may acquire keyboard focus');
console.log('Search history/result body-only submit and return, independent entry, single-level back, retained host/controller and photo isolation passed');
