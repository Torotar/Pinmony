const fs = require('node:fs'), assert = require('node:assert/strict'), path = require('node:path');
const aliases = require('./feature-state-aliases.json');
const base = 'entry/build/default/cache/default/default@CompileArkTS/esmodule/debug/';
const indexPath = 'entry/src/main/ets/pages/Index';
const homePath = 'feature_home/src/main/ets/controllers/PinmonyHomeController';
const searchPath = 'feature_search/src/main/ets/controllers/PinmonySearchController';
function currentCompiled(relative) {
  const compiled = path.join(base, relative + '.ts'), source = relative + '.ets';
  assert(fs.existsSync(compiled), 'Build entry HAP before checking ' + relative);
  assert(fs.statSync(compiled).mtimeMs >= fs.statSync(source).mtimeMs, 'Compiled output is older than source: ' + relative);
  return fs.readFileSync(compiled, 'utf8');
}
const index = currentCompiled(indexPath), search = currentCompiled(searchPath), home = currentCompiled(homePath);
for (const [name, state] of Object.entries(aliases)) {
  assert(!new RegExp('\\bthis\\.' + name + '\\b').test(index), 'Compiled ArkUI references a missing page field: ' + name);
  const owner = state.store === 'searchStore' ? index + '\n' + search : state.store === 'homeStore' ? index + '\n' + home : index;
  assert(owner.includes('this.' + state.store + '.' + state.field), 'Missing compiled Store access: ' + name);
}
assert.match(index, /this\.profileStore\.profileCache\.clear\(\)/);
assert.match(index, /this\.__searchStore = new ObservedPropertyObjectPU\(new PinmonySearchStore\(\)/);
assert.match(index, /this\.searchController = new PinmonySearchController\(this\.searchStore,/);
assert.equal((index.match(/new PinmonySearchStore\(\)/g) || []).length, 1);
assert.match(search, /this\.searchStore = searchStore/);
assert.match(search, /this\.searchStore\.searchCache/);
assert(index.indexOf('this.__searchStore =') < index.indexOf('this.searchController ='), 'Observed Store initializes before controller binding');
assert.match(index, /this\.__homeStore = new ObservedPropertyObjectPU\(new PinmonyHomeStore\(\)/);
assert.match(index, /this\.homeController = new PinmonyHomeController\(this\.homeStore,/);
assert.equal((index.match(/new PinmonyHomeStore\(\)/g) || []).length, 1);
assert(index.indexOf('this.__homeStore =') < index.indexOf('this.homeController ='));
assert.match(home, /this\.homeStore = homeStore/);
console.log('Current Hvigor output: initialized feature Stores, shared search binding, migrated business access and login cleanup passed');
