const assert = require('node:assert/strict');
const fs = require('node:fs');

const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const architecture = fs.readFileSync('docs/ARCHITECTURE.md', 'utf8');

assert(/@Entry\s+@Component\s+struct Index/.test(index), 'Index remains the single ArkUI entry component');
for (const [field, store] of [
  ['pin', 'PinmonyPinStore'], ['board', 'PinmonyBoardStore'], ['settings', 'PinmonySettingsStore'],
  ['profile', 'PinmonyProfileStore'], ['inbox', 'PinmonyInboxStore'], ['search', 'PinmonySearchStore'],
  ['home', 'PinmonyHomeStore']
]) {
  assert(index.includes('@State private ' + field + 'Store: ' + store), field + ' Store is owned by Index with @State');
}
for (const file of [
  'feature_pin/src/main/ets/stores/PinmonyPinStore.ets',
  'feature_board/src/main/ets/stores/PinmonyBoardStore.ets',
  'feature_settings/src/main/ets/stores/PinmonySettingsStore.ets',
  'feature_profile/src/main/ets/stores/PinmonyProfileStore.ets',
  'feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets',
  'feature_search/src/main/ets/stores/PinmonySearchStore.ets',
  'feature_home/src/main/ets/stores/PinmonyHomeStore.ets'
]) {
  assert(fs.readFileSync(file, 'utf8').includes('@Observed'), file + ' uses @Observed');
}
for (const event of [
  'about-to-appear', 'about-to-disappear', 'page-show', 'page-hide',
  'root-tabs-appear', 'root-tabs-disappear', 'root-tab-click', 'root-tab-request',
  'web-page-begin', 'web-page-end'
]) assert(index.includes("logPageLifecycle('" + event + "'"), 'PageLifecycle event is logged: ' + event);
assert(index.includes('this.nativeNetwork.invalidate()'), 'page disappearance invalidates native network');
assert(index.includes('this.detailReadNetwork.invalidate()'), 'page disappearance invalidates detail network');
assert(index.includes('this.shareBridge.onNetworkRequest = undefined'), 'page disappearance unbinds network bridge');
assert(index.includes('this.shareBridge.onNavigation = undefined'), 'page disappearance unbinds navigation bridge');
assert(index.includes('HdsTabs({'), 'root pages use HdsTabs');
assert.equal((index.match(/TabContent\(\)\s*\{/g) || []).length, 4, 'root pages use four TabContent roots');
assert(index.includes('.animationDuration(0)'), 'root tabs have no page transition');
assert(index.includes('nativeRootTabsVisible()'), 'secondary depth controls root tab visibility');
assert(index.includes('onPageBegin((event)'), 'web page begin invalidates stale page work');
assert(index.includes('.onPageEnd(() =>'), 'web page end synchronizes navigation/auth state');
assert(architecture.includes('## ArkUI 页面与状态管理'), 'architecture documents page/state ownership');
assert(!/屏幕旋转|横屏|折叠屏/.test(architecture.slice(architecture.indexOf('## ArkUI 页面与状态管理'))),
  'page lifecycle scope does not claim unsupported rotation behavior');
console.log('ArkUI page hierarchy, Store ownership, lifecycle cleanup, root-tab retention, and audit logging checks passed');
