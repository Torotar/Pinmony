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
  ['searchFeedInset','setCategoriesCollapsed','updateCategoriesOnScroll'].map(method).join('\n')+'} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{ScrollState:{Scroll:1},Curve:{EaseOut:1}});
const h=new Host();Object.assign(h,{active:true,inputEditing:false,restoringResultsScroll:false,refreshing:false,
  committedQuery:()=>true,searchHeaderInset:()=>80,visibleCategories:()=>[{}],categoriesCollapsed:false,
  categoryScrollDistance:0,resultsScroller:{offset:()=>({yOffset:120})},getUIContext:()=>({animateTo:(_,fn)=>fn()})});
h.categoryBarController={setCollapsed(){}};
const inset=h.searchFeedInset();h.updateCategoriesOnScroll(24,1);assert.equal(h.categoriesCollapsed,true);
assert.equal(h.searchFeedInset(),inset,'Collapsing chips must not resize/reposition the feed');
h.updateCategoriesOnScroll(-24,1);assert.equal(h.categoriesCollapsed,false);
assert.equal(h.searchFeedInset(),inset,'Expanding chips must not push photos down or expose a white band');
h.inputEditing=true;assert.equal(h.searchFeedInset(),inset,'covered root retains feed geometry while independent history is open');
const material=method('searchMaterialContent'),tabs=method('searchCategoriesTitleBar');
const titleBarOptions=method('searchTitleBarOptions');
assert(titleBarOptions.includes('stackBuilder:') && titleBarOptions.includes("this.searchHeader(this.showingSearchHistory(name), name === 'search-history')"), 'shared editable header lives in HDS main title slot');
assert(titleBarOptions.includes('bottomBuilder:') && titleBarOptions.includes('this.categoriesTitleBuilder'), 'interactive chips live in HDS bottom title slot with a stable builder');
assert(source.includes('private readonly categoriesTitleBuilder:') && source.includes('this.searchCategoriesTitleBar();'));
assert(titleBarOptions.includes("height: !this.showingSearchHistory(name) && !(name !== 'search-history' && this.historyDestinationRetained) && this.visibleCategories().length > 0 ? 54 : 0"), 'editing removes the category slot while collapse preserves feed geometry');
const category=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchCategoryBar.ets','utf8');
assert(category.includes('ScrollDirection.Horizontal') && category.includes('HitTestMode.Default'));
assert(category.includes('.opacity(this.collapsed ? 0 : 1)') && category.includes('.translate({ y: this.collapsed ? -12 : 0 })'));
assert(category.includes("this.collapsed ? 'no-hide-descendants' : 'auto'"));
assert(category.includes('this.collapsed ? HitTestMode.None : HitTestMode.Default'));
assert(!source.includes('@State private categoriesCollapsed'), 'collapse must not invalidate the search page');
assert(!method('updateCategoriesOnScroll').includes('animateTo'), 'animation belongs only to category component');
assert(tabs.includes('PinmonySearchCategoryBar({ controller: this.categoryBarController })'));
assert(!tabs.includes('if (this.searchCategoriesVisible())'));
assert(!category.includes('if (this.collapsed)'), 'scroll stays mounted throughout collapse');
const controller=category.slice(0,category.indexOf('@Component')).replace(/^export /gm,'');
const Control=vm.runInNewContext(ts.transpileModule(controller+'\nPinmonySearchCategoryBarController;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const c=new Control(),events=[],fn=v=>events.push(v);
c.bind(fn);assert.deepEqual(events,[],'binding must not trigger an animation during appearance');
c.setCollapsed(true);c.setCollapsed(true);assert.deepEqual(events,[true]);
const retained=[],next=v=>retained.push(v);c.bind(next);c.bind(next);
assert.equal(c.isCollapsed(),true,'a remounted title reads its initial collapsed state before rendering');
c.setCollapsed(false);assert.deepEqual(events,[true,false]);assert.deepEqual(retained,[false],'retained title instances each receive changes once');
c.unbind(fn);c.unbind(fn);c.setCollapsed(true);
assert.deepEqual(events,[true,false]);assert.deepEqual(retained,[false,true],'disposing an older title cannot steal the current binding');
c.setCollapsed(false);c.setCollapsed(true);assert.equal(c.isCollapsed(),true);
assert.deepEqual(retained,[false,true,false,true],'quick direction changes preserve the latest target');
c.unbind(next);c.setCollapsed(false);assert.equal(c.listeners.size,0,'all disposed listeners are released');
assert(category.includes('this.collapsed = this.controller.isCollapsed();'));
assert(!category.includes('animateTo'), 'no explicit animation transaction may flush pending feed updates or run during mount');
assert(category.includes('.animation({ duration: 180, curve: Curve.EaseOut })'), 'only category visual attributes animate');
assert(!method('updateSearchHeaderSurface').includes('animateTo'),'scroll threshold must not animate pending WaterFlow updates');
const card=method('pinCard');
assert(card.includes('PinmonyCdnImage({ url: result.imageUrl') && !card.includes('Image(result.imageUrl)'), 'result photos use the retained shared decode host');
assert(card.includes('viewportOnly: false') && card.includes('loadingActive: this.active && this.mediaActive && !this.quizSheetOpen'),
  'mounted cached result photos load offscreen while retaining page/background admission gates');
assert(card.includes('traceLoading: true') && card.includes('this.markImageFailed(result.imageUrl)'));
assert(!material.includes('upcomingImageUrls') && !source.includes('@State private upcomingImageUrls'), 'scroll prefetch must not invalidate the page or mount hidden Image nodes');
assert(source.includes('this.imagePrefetch.update(urls, this.imagePrefetchCount())'));
assert(!titleBarOptions.includes('categoriesCollapsed'));
assert(method('searchStatus').includes('top: this.searchFeedInset()'));
const build=source.slice(source.indexOf('  build() {'));
const destination=method('searchRootDestination');
assert.equal((destination.match(/HdsNavigation\(\)/g)||[]).length,1,'shared HDS structure for each independent destination');
assert(destination.includes('.titleBar(') && destination.includes("this.searchTitleBarOptions(name)"));
assert(!material.includes('HdsNavigation('),'body modes cannot recreate title hosts');
assert(!source.includes('searchInteractiveHeader') && !source.includes('searchTitleMaterialSlot'),'remove detached controls and empty material placeholder');
assert(destination.includes("this.searchMaterialContent('history')") && destination.includes("this.searchMaterialContent('results')"));
assert(destination.includes("name !== 'search-history' && this.historyDestinationRetained ? this.discoveryScroller : this.showingSearchHistory(name) ? this.historyScroller : this.committedQuery() ? this.resultsScroller : this.discoveryScroller"));
assert(titleBarOptions.includes('avoidLayoutSafeArea: true') && titleBarOptions.includes('enableComponentSafeArea: false'));
assert(!build.includes('linearGradientBlur('),'retain HDS material');
console.log('Search HDS title slots, persistent host, horizontal chip touch, stable feed inset and safe area passed');
