const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
function method(text, name) {
  const file = ts.createSourceFile('test.ts', text.replace(/\bstruct\b/g, 'class'), 99, true);
  let found;
  function visit(node) {
    if (ts.isMethodDeclaration(node) && node.name.getText(file) === name) found = node.getText(file);
    ts.forEachChild(node, visit);
  }
  visit(file); assert(found, name); return found;
}
const Host = vm.runInNewContext(ts.transpileModule(`class Host {
  ${method(source, 'selectDetailEntryMotion')}
  ${method(source, 'backFromDetail')}
} Host;`, { compilerOptions: { target: 99 } }).outputText, {
  PinmonyRuntimeLog: { info() {} }, display: { getDefaultDisplaySync: () => ({ width: 400, height: 900 }) }
});
const home = 'https://www.pinterest.com/', pin = id => home + 'pin/' + id + '/';
const id = value => String(value || '').match(/\/pin\/(\d+)/)?.[1] || '';
const n = new Host(), parents = new Map([[pin(1), home], [pin(2), pin(1)], [pin(3), pin(2)]]);
const cache = new Map([['1', { detail: { pinUrl: pin(1), kind: 'cached' }, scrollOffset: 120 }],
  ['2', { detail: { pinUrl: pin(2), kind: 'cached' }, scrollOffset: 240 }]]);
let generation = 1;
Object.assign(n, { detailEntryPhotos: new Map(), detailEntryCards: new Map(), detailEntryGeneration: -1,
  nativeBusinessSessionContext: () => ({ generation }), extractPinUrl: value => id(value) ? value : '', pinIdentity: id,
  pinStore: { detailCache: { get: key => cache.get(key) }, detailOrigin: key => parents.get(pin(key)) },
  activeSheetKind: '', pageHistory: { isPending: () => false },
  getUIContext: () => ({ px2vp: x => x, getComponentUtils: () => ({ getRectangleById: () => ({
    windowOffset: { x: 12, y: 100 }, size: { width: 160, height: 220 } }) }) }) });
function open(key, parent, card) {
  n.homeEntryPhoto = { pinUrl: pin(key), imageUrl: 'cover-' + key, x: 12, y: 100, width: 160, height: 220 };
  n.homeEntryCardId = card; n.selectDetailEntryMotion(pin(key), false, parent);
}
async function resume(key, card) {
  n.homeEntryClosing = true; n.homeEntryBackCommitted = true;
  n.selectDetailEntryMotion(pin(key), true, '');
  assert.equal(n.homeEntryPhoto.pinUrl, pin(key)); assert.equal(n.homeEntryCardId, card);
  assert(n.homeEntryResumed); assert.equal(n.homeEntryClosing, false); assert.equal(n.homeEntryBackCommitted, false);
  n.pinStore.detail = { pinUrl: pin(key) };
  await n.backFromDetail(); assert(n.homeEntryClosing, 'restored parent must enter the real close animation branch');
}
async function main() {
  open(1, home, 'pinmony-home-photo-1'); open(2, pin(1), 'pinmony-related-photo-2');
  // Document authentication epochs may change while traversing the same account.
  n.authEpoch = 45;
  await resume(1, 'pinmony-home-photo-1');
  open(1, home, 'pinmony-home-photo-1'); open(2, pin(1), 'pinmony-related-photo-2');
  open(3, pin(2), 'pinmony-related-photo-3');
  await resume(2, 'pinmony-related-photo-2');
  assert.equal(n.relatedEntryParent.pinUrl, pin(1)); assert.equal(n.relatedEntryParentOffset, 120);
  await resume(1, 'pinmony-home-photo-1'); assert.equal(n.relatedEntryParent, undefined);
  generation++; n.selectDetailEntryMotion(pin(1), true, '');
  assert.equal(n.homeEntryPhoto, undefined); assert.equal(n.homeEntryResumed, false);
  open(1, home, 'old'); open(2, home + 'search/', 'new');
  assert.equal(n.detailEntryPhotos.has(pin(1)), false, 'new root journey discards old geometry');
  for (let i = 3; i < 50; i++) open(i, pin(i - 1), 'related-' + i);
  assert.equal(n.detailEntryPhotos.size, 32); assert.equal(n.detailEntryCards.size, 32);
  n.homeEntryPhoto = undefined; n.selectDetailEntryMotion(pin(49), false, pin(48));
  assert.equal(n.detailEntryPhotos.has(pin(49)), false, 'unmeasured reopening cannot reuse stale geometry');
  const Page = vm.runInNewContext(ts.transpileModule(`class Page { ${method(page, 'aboutToAppear')} } Page;`,
    { compilerOptions: { target: 99 } }).outputText);
  for (const resumed of [false, true]) {
    const p = new Page(); Object.assign(p, { entryPhoto: {}, entryResumed: resumed, entryOpacity: 1, entryMotionComplete: false,
      displayedDetail: () => ({ pinUrl: pin(1) }), syncDetailFlow() {}, updateDetailLayout() {}, auditRecommendationGate() {},
      auditRecommendationLayout() {}, startSearchLabel() {}, detailPathStack: { clear() {}, pushPath() {} } });
    p.aboutToAppear(); assert.equal(p.entryOpacity, resumed ? 1 : 0); assert.equal(p.entryMotionComplete, resumed);
  }
  assert.match(page, /!this\.entryMotionComplete \|\| this\.entryClosing/);
  assert.match(source, /entryResumed: _identity === this\.detailRootIdentity\(\) && this\.homeEntryResumed/);
  assert.match(source, /resetAuthenticatedContent\(\): void \{[^}]*this\.detailEntryPhotos\.clear\(\); this\.detailEntryCards\.clear\(\)/);
  // Execute the actual opening statements around cache restoration. Returning
  // from a child and explicitly tapping a cached collage are different intents.
  const openingText=method(source,'beginDetailOpening');
  const openingAst=ts.createSourceFile('opening.ts','class Opening {'+openingText+'}',99,true);
  let openingMethod;
  ts.forEachChild(openingAst,node=>{if(ts.isClassDeclaration(node))openingMethod=node.members.find(member=>ts.isMethodDeclaration(member));});
  const statements=openingMethod.body.statements;
  const freshReset=statements.find(statement=>ts.isIfStatement(statement)&&statement.expression.getText(openingAst)==='!returning && !collageItem');
  const cacheRestore=statements.find(statement=>statement.getText(openingAst)==='this.restoreCachedDetail(pinUrl);');
  const heroReset=statements.find(statement=>ts.isIfStatement(statement)&&statement.getText(openingAst).includes('fresh-collage-entry'));
  assert(freshReset&&cacheRestore&&heroReset);
  const Fresh=vm.runInNewContext(ts.transpileModule('class Fresh { prepare(pinUrl,returning,collageItem) {'+
    [freshReset,cacheRestore,heroReset].map(statement=>statement.getText(openingAst)).join('\n')+'} } Fresh;', {compilerOptions:{target:99}}).outputText,
    {PinmonyRuntimeLog:{info(){}}});
  for(const scenario of [
    {detail:{shuffle:{id:'collage'}},returning:false,item:false,photo:true,expected:0},
    {detail:{shuffleId:'collage'},returning:false,item:false,photo:true,expected:0},
    {detail:{shuffle:{id:'collage'}},returning:true,item:false,photo:true,expected:350},
    {detail:{shuffle:{id:'collage'}},returning:false,item:true,photo:true,expected:350},
    {detail:{},returning:false,item:false,photo:true,expected:350},
    {detail:{shuffle:{}},returning:false,item:false,photo:false,expected:350}
  ]) {
    const fresh=new Fresh();Object.assign(fresh,{pinStore:{detailScrollOffset:0},homeEntryPhoto:scenario.photo?{pinUrl:pin(1)}:undefined,
      shuffleReturnParent:pin(1),shuffleReturnItem:'selected',detailOpeningCoordinator:{pauseShufflePreviews(){}},
      restoreCachedDetail(){this.pinStore.detail=scenario.detail;this.pinStore.detailScrollOffset=350;}});
    fresh.prepare(pin(1),scenario.returning,scenario.item);
    assert.equal(fresh.pinStore.detailScrollOffset,scenario.expected,'fresh measured collage expands onto hero; actual returns retain cached position');
    assert.equal(fresh.shuffleReturnItem,!scenario.returning&&!scenario.item?'':'selected','fresh tap cannot replay old thumbnail reveal');
  }
  console.log('Collage re-entry: fresh cached card restores photo flight, child return preserves scroll, stale thumbnail reveal reset and ordinary Pin isolation passed');
  console.log('Nested detail motion: home-A-B-A-home, three levels, restored parent, close branch, session isolation and bounded origins passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
