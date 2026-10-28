const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const start = source.indexOf('  private handleSearchBack(');
const end = source.indexOf('\n  private ', start + 1);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  source.slice(start, end).replace('private ', '') + '}\nHost;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const host = new Host();
let page = 'results';
host.snapshot = {};
host.inputEditing = false;
host.committedQuery = () => 'query';
host.openSearchHistory = () => { host.inputEditing = true; page = 'history'; };
host.closeInputPanel = () => { host.inputEditing = false; };
host.onBack = () => { if (!host.inputEditing) { host.openSearchHistory(); return; } page = 'root'; };
host.handleSearchBack();
assert.equal(page, 'history');
host.handleSearchBack();
assert.equal(page, 'root');
assert.equal(host.inputEditing, false, 'mounted HDS destination must leave history even without parent stop callback');
host.committedQuery = () => '';
host.inputEditing = true;
host.closeInputPanel = () => { host.inputEditing = false; page = 'root'; };
host.handleSearchBack();
assert.equal(page, 'root');
const navigation = fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets', 'utf8');
const branch = navigation.slice(navigation.indexOf('else if (this.searchStore.searchInputFocused'),
  navigation.indexOf('else if (this.pinStore.detailWebFlow)'));
assert(branch.includes('this.ports.backFromSearch()'));
assert(!branch.includes('searchInputFocused = false'), 'Preserve history state until backFromSearch consumes it');
console.log('search history return checks passed');
