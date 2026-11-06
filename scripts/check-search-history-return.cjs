const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const destination = source.slice(source.indexOf('  private searchRootDestination('), source.indexOf('  private searchCategoriesTitleBar('));
const discovery = destination.indexOf("this.searchMaterialContent('discovery')");
const results = destination.indexOf("this.searchMaterialContent('results')");
const history = destination.indexOf("this.searchMaterialContent('history')");
assert(discovery >= 0 && discovery < history && results < history);
assert(destination.slice(results, history).includes('.zIndex(this.historyExitToRoot ? 0 : 2)'), 'results must remain above history when returning to history, and below it on the way to root');
assert(destination.slice(history).includes('.zIndex(1)'), 'history exits above the root destination');
assert.match(destination.slice(history), /TransitionEffect\.translate\(\{ x: '100%' \}\)\.animation\(\{ duration: 150, curve: Curve\.EaseIn \}\)/);
assert(!destination.slice(history, destination.indexOf('.hideTitleBar(true)')).includes('this.historyExitToRoot ?'),
  'history exit must be installed while visible, not selected in the removal update');
assert(destination.slice(0, discovery).includes('if (!this.committedQuery())'), 'keep the discovery root mounted below history');
assert(destination.slice(discovery, results).includes(".accessibilityLevel(this.inputEditing ? 'no-hide-descendants' : 'auto')"),
  'covered discovery root must not receive accessibility focus');
const start = source.indexOf('  private handleSearchBack(');
const end = source.indexOf('\n  private ', start + 1);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  source.slice(start, end).replace('private ', '') + '}\nHost;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const host = new Host();
let page = 'results';
host.snapshot = {};
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
  ['onInputFocus','openSearchHistory','closeInputPanel','committedQuery'].map(inputMethod).join('\n')+'} Input;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const input=new Input();let stopEditing;
Object.assign(input,{snapshot:{pageKey:'https://www.pinterest.com/search/pins/?q=test',query:'test'},
  inputController:{stopEditing(){}},inputFocusRevision:0,onQueryChange(){},
  onInputFocusChange(focused,stop){if(focused)stopEditing=stop;}});
for(const enter of [()=>input.onInputFocus(true),()=>input.openSearchHistory()]){
  enter();assert.equal(input.historyExitToRoot,false);assert.equal(input.inputEditing,true);
  stopEditing();assert.equal(input.historyExitToRoot,true,'host system back uses root-return layering');
  assert.equal(input.inputEditing,false,'host callback closes history without recursive parent navigation');
}
input.onInputFocus(true);input.closeInputPanel(false);
assert.equal(input.historyExitToRoot,false,'submitting a search retains the results entrance layering');
console.log('search history return checks passed');
