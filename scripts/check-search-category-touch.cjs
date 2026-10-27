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
const material=method('searchMaterialContent'),overlay=method('searchCategoriesOverlay');
assert(!material.includes('categoryChip('),'Interactive chips must be outside the nested HDS destination');
assert(!material.includes('categoriesCollapsed'),'Chip visibility must not change the content viewport');
assert(overlay.includes('ScrollDirection.Horizontal'));assert(overlay.includes('HitTestMode.Block'));
assert(!overlay.includes('backgroundColor('),'Overlay must not add an opaque backing');
assert(overlay.includes('!this.inputEditing && !this.categoriesCollapsed'));
const build=source.slice(source.indexOf('  build() {'));
assert(build.indexOf('this.searchCategoriesOverlay()')>build.indexOf('this.searchHeader()'));
console.log('Search chips: outer interaction layer, horizontal scroll, sibling hit blocking, transparent overlay and stable feed inset passed');
