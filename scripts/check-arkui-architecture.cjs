const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
const index = read('entry/src/main/ets/pages/Index.ets');
const uiSources = [index,
  read('feature_home/src/main/ets/components/PinWebHomePage.ets'),
  read('feature_search/src/main/ets/components/PinWebSearchPage.ets'),
  read('feature_pin/src/main/ets/components/PinWebDetailPage.ets'),
  read('common_ui/src/main/ets/components/SmartImage.ets')].join('\n');
const systemActions = read('entry/src/main/ets/app/PinWebSystemActions.ets');
const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
const moduleConfig = read('entry/src/main/module.json5');
const network = read('common_network/src/main/ets/PinWebNativeNetwork.ets');
const image = read('common_ui/src/main/ets/components/SmartImage.ets');
const playback = read('common_ui/src/main/ets/services/PinWebVideoPlayback.ets');
const tasks = read('common_foundation/src/main/ets/services/PinWebTaskRegistry.ets');
const architecture = read('docs/ARCHITECTURE.md');

assert.match(moduleConfig, /"type":\s*"entry"/);
assert.match(moduleConfig, /"mainElement":\s*"EntryAbility"/);
assert.match(index, /@Entry\s+@Component\s+struct Index/);
assert.equal((index.match(/TabContent\(\)\s*\{/g) || []).length, 4);
assert.match(index, /HdsTabs\(/);
assert.match(index, /animationDuration\(0\)/);
assert.match(index, /PinWebNavigationHistory/);
assert.match(index, /nativeRootTabsVisible\(\)/);

for (const event of ['create-start', 'window-stage-create', 'content-load-start',
  'content-load-complete', 'foreground', 'background', 'window-stage-destroy',
  'destroy-start', 'destroy-complete', 'configuration-update']) {
  assert(ability.includes("logLifecycle('" + event + "'"), `missing Ability event: ${event}`);
}
for (const marker of ['avoidAreaChange', 'setWindowLayoutFullScreen', 'setWindowSystemBarProperties',
  "this.mainWindow?.off('avoidAreaChange')", 'NetworkManager.destroy()']) {
  assert(ability.includes(marker), `missing window/lifecycle marker: ${marker}`);
}

for (const marker of ['@kit.ArkWeb', 'PinWebAuth', 'onPageBegin', 'onPageEnd', 'no-hide-descendants']) {
  assert(index.includes(marker), `missing ArkWeb boundary marker: ${marker}`);
}
for (const marker of ['@kit.ShareKit', '@kit.CoreFileKit', '@kit.MediaLibraryKit', '@kit.BasicServicesKit']) {
  assert(index.includes(marker) || systemActions.includes(marker), `missing product system capability marker: ${marker}`);
}
assert.match(network, /@kit\.RemoteCommunicationKit/);
assert.match(network, /new RequestScheduler\(8\)/);
assert.match(network, /pending\.size >= 12/);
assert.match(network, /invalidate\(\)/);
assert.match(playback, /media\.AVPlayer/);
assert.match(image, /FINITE_COVER_TIERS/, 'finite source tiers bound recommendation decoding');
assert.match(image, /objectFit\(ImageFit\.Cover\)/);
assert.match(image, /accessibilityText\(/);
assert.match(tasks, /class PinWebTaskRegistry/);
assert.match(tasks, /invalidate\(\)/);
assert.match(tasks, /clearAll\(\)/);
assert.match(index, /PinWebTaskRegistry/);
assert.match(index, /pageTasks\.invalidate\(\)/);
assert.match(index, /pageTasks\.timeout\(/);
assert.match(index, /tasks-invalidated pendingBefore=/);
assert.match(index, /pendingAfter=.*pendingCount\(\)/s);

for (const marker of ['accessibilityText', 'accessibilitySelected', 'layoutWeight', 'onAreaChange',
  'animateTo', 'transition', 'PersistentStorage', 'AppStorage', 'setTimeout', 'clearTimeout']) {
  assert(uiSources.includes(marker) || ability.includes(marker), `missing ArkUI foundation marker: ${marker}`);
}
for (const heading of ['## 工程边界', '## Ability 与生命周期', '## ArkUI 页面与状态管理',
  '## 网络请求与并发生命周期', '## 缓存与数据一致性']) {
  assert(architecture.includes(heading), `architecture contract missing: ${heading}`);
}
console.log('HarmonyOS ArkUI architecture evidence and static boundary checks passed');
