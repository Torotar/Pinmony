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
