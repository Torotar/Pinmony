const fs = require('fs');
const vm = require('vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const context = { setTimeout() {} };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' + ['openUserProfile', 'backFromUserProfile'].map(method).join('\n') + '} globalThis.Native = Native;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText, context);
const native = new context.Native(), loads = [], back = [], cached = [];
let page = 'https://www.pinterest.com/pin/123/';
Object.assign(native, { authStatus: 'authenticated', activeTab: 0,
  profileStore: { origins: [], profileScrollOffset: 48 },
  pinStore: { detail: { pinUrl: page }, detailScrollOffset: 64, detailCache: { put(...args) { cached.push(args); } } },
  tabsController: { changeIndex() {} }, pageHistory: { visit() {} },
  controller: { getUrl: () => page, loadUrl: url => loads.push(url) },
  currentProfileUrl: () => '', profileUrlFromAddress: url => /^https:\/\/www\.pinterest\.com\/sample\/$/.test(url) ? url : '',
  clearRootTabGuard() {},
  closeProfilePanel() { this.profileStore.panel = undefined; }, clearDetail() {}, clearProfile() {},
  pinIdentity: url => url, backOnePage: (...args) => back.push(args),
});
native.openUserProfile('https://example.com/sample/');
assert.equal(loads.length, 0, 'external avatar targets are rejected');
native.openUserProfile('https://www.pinterest.com/sample/');
assert.equal(loads.length, 1);
assert.equal(native.activeTab, 0, 'avatar navigation must not select the My root tab');
assert.equal(native.profileStore.origins[0].page, page);
assert.equal(native.profileStore.origins[0].tab, 0);
assert.equal(cached[0][2], 64, 'post scroll is cached before leaving');
native.backFromUserProfile();
assert.equal(native.activeTab, 0);
assert.equal(back[0][1], page, 'return targets the originating post');
assert.equal(native.profileStore.origins.length, 0);
native.authStatus = 'unauthenticated';
native.openUserProfile('https://www.pinterest.com/sample/');
assert.equal(loads.length, 1, 'logged out navigation is rejected');
native.authStatus = 'authenticated';
const notices = [];
native.showMessage = value => notices.push(value);
native.controller.getUrl = () => { throw Error('unavailable controller'); };
native.openUserProfile('https://www.pinterest.com/sample/');
assert.equal(native.profileStore.origins.length, 0, 'failed document read cannot create a navigation origin');
assert.equal(loads.length, 1);
native.controller.getUrl = () => page;
native.controller.loadUrl = () => { throw Error('unavailable navigation'); };
const retained = { profileUrl: 'https://www.pinterest.com/origin/' };
native.profileStore.profile = retained;
native.openUserProfile('https://www.pinterest.com/sample/');
assert.equal(native.profileStore.origins.length, 0, 'failed load rolls back the new origin');
assert.equal(native.profileStore.profile, retained);
assert.equal(native.profileStore.profileActionsReady, false);
assert.equal(notices.length, 2, 'both failures produce explicit native feedback');
console.log('User avatar origin, URL guard, post scroll and return checks passed');
