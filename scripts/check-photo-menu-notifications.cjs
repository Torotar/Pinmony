const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const loader = require('./product-coordination-harness.cjs').runtime(ts);
const { PinmonyPhotoMenuCoordinator } = loader.loadFile('entry/src/main/ets/app/PinmonyPhotoMenuCoordinator.ets');
const tick = () => new Promise(setImmediate);
(async () => {
  const url = 'https://www.pinterest.com/pin/42/', page = 'https://www.pinterest.com/';
  const home = { customHomeMenuToken: 0 }, pin = {};
  let value, commits = 0, reads = 0, loading = true, coordinator;
  Object.defineProperty(home, 'customHomeMenu', { get: () => value, set: v => { value = v; commits++; } });
  const ports = { homeStore: () => home, pinStore: () => pin, inboxStore: () => ({}), boardStore: () => ({}),
    rejectOfflineAction: () => false, clearRootTabGuard() {}, currentHomePageKey: () => page,
    isCurrentBoardMenuPin: () => false, isCurrentSearchMenuPin: () => false,
    setActiveSheetKind() {}, setShowNativeSheet() {}, pinIdentity: v => v,
    dismissShareSheet() { home.customHomeMenuToken++; home.customHomeMenu = undefined; coordinator.notify(); },
    controller: () => ({ runJavaScript: async source => {
      if (source.includes('homeMenuOpen')) return 'true';
      reads++;
      return JSON.stringify({ session: home.customHomeMenuToken, pinUrl: url, loading, busy: false,
        error: '', feedback: '', options: [], actions: [] });
    } }) };
  coordinator = new PinmonyPhotoMenuCoordinator(ports);
  const task = coordinator.openCustomHomeMenu(url, page);
  await tick();
  assert.equal(reads, 1);
  coordinator.menuChanged(999);
  await tick();
  assert.equal(reads, 1, 'old sessions cannot wake current menu');
  coordinator.menuChanged(home.customHomeMenuToken);
  await tick();
  assert.equal(reads, 2);
  assert.equal(commits, 2, 'identical snapshot is not committed twice');
  loading = false;
  coordinator.menuChanged(home.customHomeMenuToken);
  await tick();
  assert.equal(home.customHomeMenu.loading, false, 'notification applies completion immediately');
  ports.dismissShareSheet();
  await task;
  assert.equal(reads, 3, 'close stops further reads');
  const background = coordinator.openCustomHomeMenu(url, page);
  await tick();
  coordinator.pause();
  await background;
  const stopped = reads;
  coordinator.menuChanged(home.customHomeMenuToken);
  await tick();
  assert.equal(reads, stopped, 'background cancellation stops menu reads');
  let completeRead;
  ports.controller = () => ({ runJavaScript: async source => {
    if (source.includes('homeMenuOpen')) return 'true';
    return new Promise(resolve => { completeRead = resolve; });
  } });
  const late = coordinator.openCustomHomeMenu(url, page);
  await tick();
  const beforePause = commits;
  coordinator.pause();
  completeRead(JSON.stringify({ session: home.customHomeMenuToken, pinUrl: url, loading: false,
    busy: false, error: '', feedback: '', options: [], actions: [] }));
  await late;
  assert.equal(commits, beforePause, 'a read already underway cannot commit after background cancellation');
  console.log('Photo menu: notifications, unchanged-state deduplication, stale session, close and background cancellation passed');
})().catch(e => { console.error(e); process.exitCode = 1; });
