const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
function method(name) {
  let found;
  function visit(node) {
    if (ts.isMethodDeclaration(node) && node.name.getText(ast) === name) found = node.getText(ast);
    ts.forEachChild(node, visit);
  }
  visit(ast); assert(found, name); return found;
}
let serializations = 0;
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['pinRenderKey', 'onProfileChanged'].map(method).join('\n') + '} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
  {JSON:{stringify(value){serializations++;return JSON.stringify(value);}}});
const h = Object.assign(new Host(), {pinRenderKeys:new Map(),uiLanguage:'zh',legacyContentPane:true});
const pins = Array.from({length:500}, (_,index)=>({id:String(index),title:'Pin '+index,imageUrl:'synthetic-'+index}));
const first = pins.map(pin=>h.pinRenderKey(pin));
for(let frame=0;frame<30;frame++)assert.deepEqual(pins.map(pin=>h.pinRenderKey(pin)),first);
assert.equal(serializations,500,'unchanged card data serializes once, not on every title/layout frame');
assert.equal(h.pinRenderKeys.size,500);
h.uiLanguage='en';assert.notEqual(h.pinRenderKey(pins[0]),first[0]);
assert.equal(serializations,500,'language updates preserve cached data while changing the display key');
h.uiLanguage='zh';assert.equal(h.pinRenderKey(pins[0]),first[0]);
pins[0].title='Updated';h.onProfileChanged();assert.equal(h.pinRenderKeys.size,0,'snapshot changes release all previous key entries');
assert.notEqual(h.pinRenderKey(pins[0]),first[0],'same-object content mutation is refreshed on snapshot notification');
const replacement={...pins[1],imageUrl:'replacement'};
assert.notEqual(h.pinRenderKey(replacement),first[1],'same business ID with replaced image invalidates its key');
const chromePane=source.slice(source.indexOf('private hubPager()'),source.indexOf('private hubSnapshot('));
assert(!source.includes('hubChromeOffsetVp'),'no unused per-frame prop reaches retained page components');
assert(source.includes('(pin: PinmonyCreatedPin) => this.pinRenderKey(pin)'),'actual WaterFlow uses the cached content-aware key');
assert(source.includes('this.onHubScroll(offset,state,this.scroller.offset()?.yOffset || 0)'),'header motion continues to receive actual scroll position');
console.log('Profile scroll cost: 500 cards across 30 frames reuse keys, language/content/image invalidation, cache release and isolated title frames passed');
