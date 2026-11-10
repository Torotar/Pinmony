const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name);
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1)).replace('private ', '').replace(/\s*@Builder\s*$/, '');
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method('restoreHeroPosition(') + method('selectHeroPosition(') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const cacheExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_search/src/main/ets/services/PinmonySearchCache.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: cacheExports });
const cache = new cacheExports.PinmonySearchCache();
const snapshot = { pageKey: 'discovery', heroes: [{ id: 'a' }, { id: 'b' }, { id: 'c' }] };
cache.rememberHero(snapshot, 'b'); cache.rememberHero(snapshot, 'invalid');
assert.equal(cache.heroPosition('discovery'), 'b');
function remount() {
  const host = new Host();
  Object.assign(host, { active: true, currentHeroIndex: 0, currentHeroId: '', initialHeroId: cache.heroPosition('discovery'), snapshot,
    wideDiscoveryLayout: () => false, updateHeroBackground() {},
    onHeroPosition: (page, id) => cache.rememberHero(snapshot, id) });
  host.restoreHeroPosition(); return host;
}
const host = remount(); assert.equal(host.currentHeroIndex, 1);
host.selectHeroPosition(2); assert.equal(remount().currentHeroIndex, 2, 'return after component recreation retains the clicked hero');
host.active = false; host.selectHeroPosition(0); assert.equal(host.currentHeroIndex, 2, 'hidden changes cannot overwrite position');
host.snapshot = { ...snapshot, heroes: [] }; host.restoreHeroPosition(); assert.equal(host.currentHeroId, 'c');
host.snapshot = { ...snapshot, heroes: [{ id: 'c' }, { id: 'a' }, { id: 'b' }] }; host.restoreHeroPosition(); assert.equal(host.currentHeroIndex, 0);
host.snapshot = { ...snapshot, heroes: [{ id: 'a' }] }; host.restoreHeroPosition(); assert.equal(host.currentHeroIndex, 0);
cache.clear(); assert.equal(cache.heroPosition('discovery'), '', 'existing session cache clear removes retained hero');
console.log('Hero return: recreation, identity reordering, transient loading, inactive changes, invalid IDs and session clear passed');
const AdmissionHost=vm.runInNewContext(ts.transpileModule('class AdmissionHost {'+method('heroImageLoadingEnabled(')+'} AdmissionHost;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const admission=new AdmissionHost();Object.assign(admission,{active:true,mediaActive:true,inputEditing:false,heroCarouselInViewport:true,currentHeroIndex:0,heroTransitionIndex:-1,snapshot:{heroes:[{id:'a'},{id:'b'},{id:'c'},{id:'d'},{id:'e'},{id:'f'}]}});
const admitted=()=>admission.snapshot.heroes.filter(hero=>admission.heroImageLoadingEnabled(hero)).map(hero=>hero.id);
assert.deepEqual(admitted(),['a','b','c','f'],'current, previous and two upcoming slides form a bounded warm window');
admission.currentHeroIndex=1;assert.deepEqual(admitted(),['a','b','c','d'],'prefetch window advances without changing image identities');
admission.currentHeroIndex=5;assert.deepEqual(admitted(),['a','b','e','f'],'last slide warms adjacent loop slides');
admission.heroTransitionIndex=2;assert.deepEqual(admitted(),['a','b','c','e','f'],'in-flight transition target stays admitted');admission.heroTransitionIndex=-1;
for(const field of ['active','mediaActive','heroCarouselInViewport']){admission[field]=false;assert.deepEqual(admitted(),[]);admission[field]=true;}
admission.inputEditing=true;assert.deepEqual(admitted(),[]);admission.inputEditing=false;
admission.snapshot={heroes:[{id:'only'}]};assert.deepEqual(admitted(),['only']);admission.snapshot={heroes:[]};assert.deepEqual(admitted(),[]);
assert.match(source,/loadingActive: this\.heroImageLoadingEnabled\(hero\)[\s\S]{0,150}viewportOnly: false, loadPriority: this\.heroImagePriority\(hero\)/);
assert.match(source,/this\.heroCarouselInViewport = visible && ratio > 0/);
console.log('Carousel prefetch: bounded current/next, wraparound, single/empty, hidden/history/offscreen pause passed');
const ColorHost=vm.runInNewContext(ts.transpileModule('class ColorHost {'+method('updateHeroBackground(')+'} ColorHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){}}});
const colors=new ColorHost();colors.active=true;colors.heroBackgrounds={};colors.snapshot={heroes:[{imageUrl:'red'},{imageUrl:'blue'}]};
colors.updateHeroBackground({imageUrl:'red'},200,40,20);colors.updateHeroBackground({imageUrl:'blue'},20,40,200);
assert.notEqual(colors.heroBackgrounds.red,colors.heroBackgrounds.blue,'different photos produce different backgrounds');
colors.updateHeroBackground({imageUrl:'removed'},100,100,100);assert.equal(colors.heroBackgrounds.removed,undefined);
colors.active=false;colors.snapshot.heroes.push({imageUrl:'hidden'});colors.updateHeroBackground({imageUrl:'hidden'},100,100,100);assert.equal(colors.heroBackgrounds.hidden,undefined);
assert(!source.includes('getComponentSnapshot()'),'hero colors use actual decoded pixels rather than black component snapshots');
async function verifyDecodedColor(){
  const cdn=fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets','utf8');
  const start=cdn.indexOf('  private async samplePhotoColor('),end=cdn.indexOf('  private loadingChanged(',start);
  let finish;const bitmap={fixture:true};
  const SampleHost=vm.runInNewContext(ts.transpileModule('class SampleHost {'+cdn.slice(start,end)+'} SampleHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{effectKit:{createColorPicker:async pixels=>{assert.equal(pixels,bitmap);return{getMainColor:()=>new Promise(resolve=>finish=resolve)}}}});
  const sample=new SampleHost(),received=[];Object.assign(sample,{visible:true,generation:1,onPhotoColor:(...rgb)=>received.push(rgb)});
  let pending=sample.samplePhotoColor(bitmap,1);await new Promise(setImmediate);finish({red:180,green:120,blue:60});await pending;assert.deepEqual(received,[[180,120,60]]);
  pending=sample.samplePhotoColor(bitmap,1);await new Promise(setImmediate);sample.generation++;finish({red:10,green:20,blue:30});await pending;assert.equal(received.length,1,'replaced image cannot submit its late color');
  sample.visible=false;await sample.samplePhotoColor(bitmap,2);assert.equal(received.length,1);
  console.log('Photo color: decoded bitmap sampling, distinct backgrounds, stale and hidden callback rejection passed');
}
verifyDecodedColor().catch(error=>{console.error(error);process.exitCode=1;});
