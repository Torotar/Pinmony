const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
function method(name){
  const start=source.indexOf('  private '+name+'(');assert(start>=0,name);
  const rest=source.slice(start);
  const end=rest.slice(1).search(/\n  (?:private |@Builder|@State|@Prop)/);
  return rest.slice(0,end+1);
}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+
  ['searchFeedInset','updateCategoriesOnScroll'].map(method).join('\n')+'} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{ScrollState:{Scroll:1},Curve:{EaseOut:1}});
const h=new Host();Object.assign(h,{active:true,inputEditing:false,restoringResultsScroll:false,refreshing:false,
  committedQuery:()=>true,searchHeaderInset:()=>80,visibleCategories:()=>[{}],categoriesCollapsed:false,
  categoryScrollDistance:0,resultsScroller:{offset:()=>({yOffset:120})},getUIContext:()=>({animateTo:(_,fn)=>fn()})});
const inset=h.searchFeedInset();h.updateCategoriesOnScroll(24,1);assert.equal(h.categoriesCollapsed,true);
assert.equal(h.searchFeedInset(),inset,'Collapsing chips must not resize/reposition the feed');
h.updateCategoriesOnScroll(-24,1);assert.equal(h.categoriesCollapsed,false);
assert.equal(h.searchFeedInset(),inset,'Expanding chips must not push photos down or expose a white band');
h.inputEditing=true;assert.equal(h.searchFeedInset(),80);
const material=method('searchMaterialContent'),tabs=method('searchCategoriesTitleBar');
const titleBarOptions=method('searchTitleBarOptions');
assert(!titleBarOptions.includes('this.searchHeader()')&&!titleBarOptions.includes('this.searchCategoriesTitleBar()'),'interactive controls must stay outside HDS material title builders');
assert(titleBarOptions.includes('this.searchTitleMaterialSlot()'),'HDS retains the category material height');
assert(method('searchTitleMaterialSlot').includes('HitTestMode.None'),'material placeholder cannot intercept touches');
assert(tabs.includes('ScrollDirection.Horizontal')&&tabs.includes('HitTestMode.Default'));
assert(!tabs.includes('HitTestMode.Block'),'category scroll must not block child button hit testing');
assert(method('searchStatus').includes('top: this.searchFeedInset()'),'empty status stays below the header and system area');
assert(!tabs.includes('backgroundColor('));
assert(tabs.includes('this.searchCategoriesVisible()'));
const build=source.slice(source.indexOf('  build() {'));
const overlay=method('searchInteractiveHeader');
const destination=method('searchRootDestination');
assert(destination.includes('Stack({ alignContent: Alignment.Top })')&&destination.includes('this.searchMaterialContent()')&&destination.includes('this.searchInteractiveHeader()'),'controls share the displayed destination stack with material');
assert(!build.includes('this.searchInteractiveHeader()'),'controls must not be a sibling outside the active navigation destination');
assert(overlay.includes('.height(56 + (this.searchCategoriesVisible() ? 54 : 0))'),'interactive layer is bounded to visible header');
assert(overlay.includes('this.searchHeader()')&&overlay.includes('this.searchCategoriesTitleBar()'),'both controls share an independent bounded header');
assert(overlay.includes('.zIndex(1)')&&overlay.includes('HitTestMode.Transparent'),'overlay is above material and passes empty space touches through');
assert(overlay.includes('px2vp(this.statusBarHeightPx)'),'preserve status safe-area placement');
assert(!build.includes('linearGradientBlur('),'retain HDS blur rather than replacing its material');
console.log('Search touch layering: independent controls above HDS material, horizontal chips, stable feed inset and safe area passed');
