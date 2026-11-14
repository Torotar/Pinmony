const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const root = process.argv[3] || '.';
const read = p => fs.readFileSync(root + '/' + p, 'utf8');
function compile(code, globals = {}) {
  return vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, globals);
}
function methods(source, names) {
  const ast = ts.createSourceFile('host.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true), found = new Map();
  function visit(n) {
    if (ts.isMethodDeclaration(n) && names.includes(n.name?.getText(ast))) found.set(n.name.getText(ast), n.getText(ast).replace(/@Builder\s*/g, ''));
    ts.forEachChild(n, visit);
  }
  visit(ast);
  for (const name of names) assert(found.has(name), name);
  return names.map(n => found.get(n)).join('\n');
}
const page = read('feature_home/src/main/ets/components/PinmonyHomePage.ets');
assert(!/@State\s+private pagerPosition/.test(page), 'continuous pager position must not invalidate the HDS host');
assert(!/@State\s+private backdropState/.test(page), 'the parent must not subscribe to the child backdrop state');
assert(page.includes('class PinmonyHomeChromeState') && page.includes('@State private chromeState: PinmonyHomeChromeState'), 'the parent observes a holder, while only the child observes nested frame values');
assert(page.includes('state: this.chromeState.backdrop'), 'ObjectLink receives the nested observed instance');
assert(page.includes('@ObjectLink state: PinmonyHomeBackdropState'), 'backdrop child owns continuous observation');
assert.match(page, /ForEach\(this.categories,[\s\S]*?this.categoryButton\(tab.id\)[\s\S]*?\(tab: PinmonyHomeTab\) => tab.id\)/);
assert(page.includes('this.prefetchedImageUrls : this.emptyPrefetchedImageUrls'));
const names = ['pageTabs', 'paneChromeOpacity', 'paneBackdropOpacity', 'categoryBackdropOpacity',
  'syncPagerChrome', 'updatePagerBackdrop', 'categoryTabSelected', 'currentCategory', 'categorySelected', 'categoryMaterial', 'categoryButton', 'syncCategories', 'categoryId'];
let drawn, attributes, selected;
const native = new Proxy({}, { get: (_t, k) => (...args) => { attributes[k] = args; return native; } });
const Home = compile('class Home {' + methods(page, names) + '} Home;', {
  Button: (label) => { drawn = label; return native; }, ButtonType: { Capsule: 1 }, FontWeight: { Medium: 1 }, Color: { White: 'white' },
  $r: key => key, PinmonyI18n: { render: (label, lang) => label + ':' + lang },
  PinmonyHomeCategoryMaterial: class { constructor(...args) { this.args = args; } update(...args) { this.args = args; } }
});
const h = new Home(), counters = new Map(), changes = [];
Object.assign(h, { categories: [{id:'all',label:'All',selected:true,enabled:true}, {id:'disabled',enabled:false}, {id:'board',label:'Board',enabled:true}],
  selectedId:'all', pagerPosition:-1, pagerChromeIndex:-1, pagerBindingKey:'', pagerBindingRevision:0,
  paneChrome:new Map(), paneKey:id=>id, homeChromeCollapsed:false,
  snapshotFor:id=>id==='board'?{board:{},pins:[{}]}:{pins:[{}]},
  chromeState:{backdrop:new Proxy({opacity:0,moving:false},{set(t,k,v){if(t[k]!==v)changes.push([k,v]); t[k]=v; return true;}})},
  categoryMaterials:new Map(), immersiveLightMode:'immersive', systemDarkMode:false, uiLanguage:'zh', interactionReady:true,
  getUIContext:()=>({vp2px:n=>n}), selectTab:tab=>{selected=tab;} });
const observed = new Proxy(h, {set(t,k,v){ if(t[k]!==v)counters.set(k,(counters.get(k)||0)+1);t[k]=v;return true;}});
for(let i=1;i<240;i++) observed.updatePagerBackdrop(0,0,-i/240);
assert.equal(counters.get('pagerChromeIndex'), 2, 'category highlight changes only when crossing midpoint');
assert.equal(counters.get('pagerBindingRevision'), 1, 'same visible pair must retain HDS scroller binding');
assert.equal(changes.filter(([k])=>k==='opacity').length,239, 'backdrop still follows every frame');
assert.equal(h.categorySelected('board'),true, 'disabled tabs do not shift enabled pager indices');
observed.updatePagerBackdrop(0,0,0);
assert.equal(h.chromeState.backdrop.opacity,0,'cancel restores source background');
h.pagerPosition=-1; h.syncPagerChrome();
attributes={};h.categoryButton('all');assert.equal(drawn,'All:zh');
const material=h.categoryMaterials.get('all');
h.categories=[{id:'all',label:'Updated',selected:false,enabled:false},{id:'board',enabled:true,selected:true}];
h.uiLanguage='en';h.immersiveLightMode='off';h.systemDarkMode=true;
attributes={};h.categoryButton('all');assert.equal(drawn,'Updated:en');
assert.equal(attributes.enabled[0],false);assert.equal(attributes.accessibilitySelected[0],false);
assert.equal(h.categoryMaterials.get('all'),material);assert.deepEqual(material.args,['off',false,true]);
attributes.onClick[0]();assert.equal(selected,h.categories[0], 'stable button resolves latest metadata at click time');
h.home={tabs:h.categories};h.selectedId='board';h.syncCategories();
h.categoryMaterial('board');assert.equal(h.categoryMaterials.size,2);
h.home={tabs:[{id:'board',enabled:true,selected:true}]};h.syncCategories();
assert.equal(h.categoryMaterials.size,1,'removed categories release their material cache entries');
assert(!h.categoryMaterials.has('all'));

const runtime=read('common_foundation/src/main/ets/services/PinmonyRuntimeLog.ets');
let mirrored=0;
const Log=compile('class Log { static lines=[]; static pending=[]; static pendingBytes=0; static actionAt=0;'+
  methods(runtime,['sanitize','info','warn','diagnostic','record']).replaceAll('PinmonyRuntimeLog','Log')+'} Log;',
  {console:{info(){mirrored++;}},Date});
Log.diagnostic('ImageLoadTrace: task=17 phase=decoded callbackQueueMs=5 frameConfirmed=false');
assert.equal(mirrored,0);assert.match(Log.lines[0],/callbackQueueMs=5/);
Log.warn('ImageLoadTrace: phase=native-failed code=401');assert.equal(mirrored,1);
Log.info('other diagnostic');assert.equal(mirrored,2,'ordinary diagnostics retain console behavior');
Log.path='/internal';
Log.diagnostic('ImageLoadTrace: phase=decoded callbackQueueMs=7');
assert.equal(Log.pending.length,1,'quiet diagnostics still enter the existing persistent queue');
assert.match(Log.pending[0],/callbackQueueMs=7/);assert.equal(mirrored,2);
console.log('Home render cost: continuous backdrop isolation, discrete highlight/binding, stable current button state, per-button modifier reuse and retained diagnostics without duplicate console passed.');
