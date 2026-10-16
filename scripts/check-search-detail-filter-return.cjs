const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  private completeNativeBack(');
const method = source.slice(start, source.indexOf('\n  private ', start + 1));
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { PIN_NATIVE_DETAIL_READS_ENABLED: true, PIN_NATIVE_BOARD_READS_ENABLED: true,
  PIN_NATIVE_PROFILE_READS_ENABLED: true, PIN_NATIVE_SEARCH_READS_ENABLED: true });
const h = new Host(), calls = [], page = 'https://www.pinterest.com/search/pins/?q=art';
Object.assign(h, { nativeBusinessSessionContext: () => ({ authenticated: true, origin: 'https://www.pinterest.com' }),
  returnToNativeProfile: () => false, searchUrlFromAddress: p => p === page ? p : '',
  clearDetail: () => calls.push('clear'), searchNativeReads: { pause: () => calls.push('pause') },
  commitNativeSearchReturn: p => calls.push(p) });
assert.equal(h.completeNativeBack(page), true);
assert.deepEqual(calls, ['clear', 'pause', page]);
const closeStart = source.indexOf('        if (!this.showNativeSheet && this.activeSheetKind === \'searchFilter\') {', source.indexOf('.bindSheet($$this.showNativeSheet'));
const closeEnd = source.indexOf('        if (this.publishSheetClosing)', closeStart);
assert(closeStart > 0 && closeEnd > closeStart);
const close = vm.runInNewContext(ts.transpileModule('(function(){' + source.slice(closeStart, closeEnd) + '})', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
for (const stale of [false, true]) {
  const navigated = [], state = { showNativeSheet: false, activeSheetKind: 'searchFilter',
    pendingSearchFilterTarget: page + '&rs=filter', pendingSearchFilterSource: page,
    authStatus: 'authenticated', activeTab: 1, pinStore: {}, currentSearchPageKey: () => stale ? 'other' : page,
    searchNativeReads: { navigate: p => navigated.push(p) } };
  close.call(state); close.call(state);
  assert.equal(state.activeSheetKind, ''); assert.equal(state.pendingSearchFilterTarget, '');
  assert.equal(navigated.length, stale ? 0 : 1);
}
console.log('Pin return resumes native search; filter navigation waits for Sheet disappearance and rejects stale routes');
