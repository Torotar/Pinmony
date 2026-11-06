const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
assert(!source.includes('boardRefreshTranslation'), 'preserve native Refresh content movement');
assert(!source.includes('boardRefreshOffset'), 'do not cancel pull or rebound displacement');
assert(source.includes('builder: this.boardRefreshPlaceholder'));
assert(source.includes('this.snapshot.loading && !this.snapshot.refreshing && !this.boardRefreshActive'), 'refresh does not insert a second spinner after board metadata');
const indicator = source.slice(source.indexOf('  private boardRefreshPlaceholder()'), source.indexOf('  private boardDestination('));
assert(indicator.includes('.height(64).justifyContent(FlexAlign.Center)'));
assert(indicator.includes('.offset({ y: this.titleContentInset() })'), 'indicator starts below the existing title and status safe area');
assert(indicator.includes('this.snapshot.refreshing || this.boardRefreshActive ? Visibility.Visible : Visibility.Hidden'));
assert(indicator.includes("this.phase() === 'section'"), 'section refresh keeps its existing presentation');
const status = { Drag: 1, OverDrag: 2, Refresh: 3, Done: 4, Inactive: 5 };
const callback = source.match(/\.onStateChange\(\(state: RefreshStatus\): void => \{([\s\S]*?)\n      \}\)/);
assert(callback);
const update = vm.runInNewContext(ts.transpileModule('(function(state: RefreshStatus) {' + callback[1] + '})', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { RefreshStatus: status });
const host = {};
for (const state of [status.Drag, status.OverDrag, status.Refresh]) { update.call(host, state); assert.equal(host.boardRefreshActive, true); }
for (const state of [status.Done, status.Inactive]) { update.call(host, state); assert.equal(host.boardRefreshActive, false); }
let refreshes = 0;
const refreshCallback = source.match(/\.onRefreshing\(\(\) => \{([\s\S]*?)\n      \}\)/);
assert(refreshCallback);
const refresh = vm.runInNewContext('(function() {' + refreshCallback[1] + '})', { PinmonyRuntimeLog: { info() {} } });
refresh.call({ onRefresh() { refreshes++; } }); assert.equal(refreshes, 1);
console.log('Board refresh: native drag/hold/rebound movement retained, indicator lifecycle and refresh callback passed');
