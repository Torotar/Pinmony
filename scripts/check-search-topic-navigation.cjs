const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const runtime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const fs=require('node:fs'),vm=require('node:vm');
const pageSource=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
const geometryStart=pageSource.indexOf('  private wideDiscoveryLayout(');
const geometrySource=pageSource.slice(geometryStart,pageSource.indexOf('  private discoverySlots(',geometryStart));
const GeometryHost=vm.runInNewContext(ts.transpileModule('class GeometryHost {'+geometrySource+'} GeometryHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const geometry=new GeometryHost();
for(const width of [360,599,600,960,1440,1920]){geometry.viewportWidth=width;geometry.contentWidth=width;assert.equal(geometry.discoveryColumns(),width<600?1:2);if(width<600)assert.equal(geometry.discoveryPhotoHeight(),176);else assert(Math.abs(((width/2-50)/4)/geometry.discoveryPhotoHeight()-0.56)<1e-9);}
const discoveryBlock=pageSource.slice(pageSource.indexOf('  private discoveryContent('),pageSource.indexOf('  private discoveryInitialLoading('));
assert(discoveryBlock.indexOf('this.heroCarousel()')<discoveryBlock.indexOf('this.discoveryRows()'),'carousel stays above theme rows below the search header');
const keyStart=pageSource.indexOf('  private discoveryRowKey(');
const keyMethod=pageSource.slice(keyStart,pageSource.indexOf('\n  @State',keyStart));
const KeyHost=vm.runInNewContext(ts.transpileModule('class KeyHost {'+keyMethod+'} KeyHost;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const keyHost=new KeyHost();keyHost.discoverySnapshot=()=>keyHost.snapshot;keyHost.discoveryColumns=()=>1;keyHost.uiLanguage='zh_CN';
keyHost.snapshot={ideaSections:[{id:'first',actionId:'first',targetUrl:'a',items:[]}]};
const oldKey=keyHost.discoveryRowKey(0);
keyHost.snapshot={ideaSections:[{id:'second',actionId:'second',targetUrl:'b',items:[]}]};
assert.notEqual(keyHost.discoveryRowKey(0),oldKey,'Replacing a row must rebuild old click closures');
const sameKey=keyHost.discoveryRowKey(0);keyHost.snapshot.loading=true;
assert.equal(keyHost.discoveryRowKey(0),sameKey,'Loading alone preserves recommendation nodes');
keyHost.snapshot.ideaSections[0].items=[{id:'photo',targetUrl:'b',imageUrl:'image'}];
assert.notEqual(keyHost.discoveryRowKey(0),sameKey,'Updated previews rebuild their closures');
async function main() {
  const h = runtime.harness(), host = h.controller, page = 'https://www.pinterest.com/search/';
  h.setPage(page);
  const topic = (id, q) => ({ id, actionId: id, title: '角色插画', eyebrow: '热门',
    targetUrl: 'https://www.pinterest.com/search/pins/?q=' + q,
    items: [{ id: id + '-0', title: '角色插画', imageUrl: 'https://i.pinimg.com/a.jpg',
      targetUrl: 'https://www.pinterest.com/search/pins/?q=' + q, enabled: true }] });
  let sections = host.mergeSearchIdeaSections([], [topic('first', 'art')]);
  assert.equal(sections[0].targetUrl, topic('first', 'art').targetUrl);
  assert.equal(host.mergeSearchIdeaSections(sections, [])[0].targetUrl, sections[0].targetUrl);
  const lastTarget = () => h.events.filter(e => e[0] === 'search').at(-1)[1];
  for (const next of [sections, host.mergeSearchIdeaSections(sections, [topic('updated', 'new')])]) {
    h.store.search = { pageKey: page, discoveryApi: true, ideaSections: next };
    await host.performSearchAction(next[0].actionId, 'ideaSection');
    assert.equal(lastTarget(), next[0].targetUrl);
    await host.performSearchAction(next[0].items[0].id, 'idea');
    assert.equal(lastTarget(), next[0].targetUrl);
  }
  h.setActive(false); const count = h.events.length;
  await host.performSearchAction('updated', 'ideaSection');
  assert.equal(h.events.length, count);
  h.setActive(true);
  const current = topic('current', 'current');
  h.store.search = {pageKey:page,discoveryApi:true,ideaSections:[current]};
  let before = h.events.filter(e=>e[0]==='search').length;
  await host.performSearchAction('removed', 'ideaSection');
  assert.equal(h.events.filter(e=>e[0]==='search').length,before,'Removed section cannot navigate');
  assert(h.events.some(e=>JSON.stringify(e).includes('pm_search_recommendation_updated') || JSON.stringify(e).includes('推荐内容已更新')));
  current.targetUrl='https://untrusted.example/search/pins/?q=x';
  await host.performSearchAction('current','ideaSection');
  assert.equal(h.events.filter(e=>e[0]==='search').length,before,'Invalid current URL remains blocked');
  const retained = topic('retained', 'cached'); delete retained.targetUrl;
  h.store.search = { pageKey: page, discoveryApi: true, ideaSections: [retained] };
  await host.performSearchAction('retained', 'ideaSection');
  assert.equal(lastTarget(), retained.items[0].targetUrl);
  h.store.search = { kind: 'state', pageKey: page, api: true, categories: [{ id: 'guide', enabled: true,
    targetUrl: 'https://www.pinterest.com/search/pins/?q=character%20art' }] };
  await host.performSearchAction('guide', 'category');
  assert.equal(lastTarget(), h.store.search.categories[0].targetUrl);
  const beforeGuide = h.events.length; h.setActive(false);
  await host.performSearchAction('guide', 'category');
  assert.equal(h.events.length, beforeGuide, 'signed-out guides cannot navigate');
  h.setActive(true); h.store.search.categories[0].targetUrl = 'https://untrusted.example/search/pins/?q=x';
  await host.performSearchAction('guide', 'category');
  assert.equal(h.events.length, beforeGuide, 'foreign guide URL is rejected');
  for(const kind of ['idea','ideaSection']) {
    const r=runtime.harness();r.setPage(page);
    const parent={kind:'state',session:4,pageKey:page,query:'',placeholder:'',selectedCategory:'',categories:[],suggestions:[],heroes:[],ideaSections:[topic('return','art')],results:[],discoveryApi:true};
    r.store.search=parent;r.store.searchScrollOffset=137;
    const target=parent.ideaSections[0].targetUrl;
    await r.controller.performSearchAction(kind==='idea'?'return-0':'return',kind);
    r.setPage(target);r.store.search={...parent,pageKey:target,query:'art',ideaSections:[],discoveryApi:false};
    const count=r.events.length;
    assert.equal(r.controller.restoreCategorySearchParent(),false,'theme result must fall through to search history, not jump to discovery');
    assert.equal(r.events.length,count,'back to history cannot call native navigation with a root URL');
    assert.equal(r.store.search.pageKey,target,'result route stays current while history body opens');
    assert.equal(r.store.searchCache.get(page).snapshot,parent,'discovery cache remains for the later history-to-root return');
  }
  const failed=runtime.harness({navigateSearch(){throw Error('navigation failed');}});failed.setPage(page);
  failed.store.search={pageKey:page,query:'',discoveryApi:true,ideaSections:[topic('failure','art')],results:[]};
  await failed.controller.performSearchAction('failure','ideaSection');failed.setPage(failed.store.search.ideaSections[0].targetUrl);
  assert.equal(failed.controller.restoreCategorySearchParent(),false,'failed navigation releases its parent context');
  const backIndex=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  const backBlock=backIndex.slice(backIndex.indexOf('  private backFromSearch('),backIndex.indexOf('  private ',backIndex.indexOf('  private backFromSearch(')+1));
  assert(backBlock.indexOf('restoreCategorySearchParent()')<backBlock.indexOf('searchOpenHistory()'),'existing category exceptions remain ahead of ordinary history; themes register no category shortcut');
  const destination=pageSource.slice(pageSource.indexOf('  private searchRootDestination('),pageSource.indexOf('  private searchCategoriesTitleBar('));
  const resultStart=destination.indexOf("this.searchMaterialContent('results')"), titleStart=destination.indexOf('.titleBar(');
  assert(resultStart>=0 && destination.slice(resultStart,titleStart).includes("TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut })"),'theme slides only result body using the same entry/exit timing');
  assert(!destination.slice(titleStart).includes('.transition('),'title is outside body transitions');
  host.invalidatePending();
  console.log('Topic URL retention, refreshed actions, section/card navigation and stale-page rejection passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
