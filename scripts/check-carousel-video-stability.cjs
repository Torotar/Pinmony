const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const { createRequire } = require('node:module');
const assert = require('node:assert/strict'), ts = require(process.argv[2] || 'typescript');
const carousel = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets', 'utf8');
const player = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyVideoPlayer.ets', 'utf8');
function hostOf(source, names) {
  const tree = ts.createSourceFile('host.ts', source.replace(/\bstruct\b/g, 'class'), 99, true), methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(tree))) methods.push(node.getText(tree));
    ts.forEachChild(node, visit);
  }
  visit(tree); assert.equal(methods.length, names.length);
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: 99 }
  }).outputText, { PinmonyRuntimeLog: { info() {} }, Promise });
}
const Carousel = hostOf(carousel, ['videoSlotMounted']);
const Player = hostOf(player, ['applySource', 'activeChanged', 'autoplayChanged', 'togglePlayback']);
// Reuse the existing AVPlayer fake while running the real playback service.
const harnessSource = fs.readFileSync('scripts/check-video-playback.cjs', 'utf8');
const harness = vm.runInNewContext(harnessSource.slice(0, harnessSource.indexOf('async function main()')) + '\nharness;', {
  require: createRequire(path.resolve('scripts/check-video-playback.cjs')), process, setTimeout, clearTimeout, setImmediate
});
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const view = new Carousel();
  Object.assign(view, { page: 0, carousel: { items: [{ video: {} }, { video: {} }, { video: {} }, {}, { video: {} }] } });
  const mounted = new Map();
  function renderPage(page, autoplay = true) {
    view.page = page;
    for (let index = 0; index < view.carousel.items.length; index++) {
      if (!view.carousel.items[index].video || !view.videoSlotMounted(index)) {
        if (mounted.has(index)) { mounted.get(index).backend.playback.release(); mounted.delete(index); }
        continue;
      }
      if (!mounted.has(index)) {
        const backend = harness(false, { fakeTime: true }), ui = new Player();
        Object.assign(ui, { mounted: true, sourceKey: '', pendingRetry: false, dragging: false,
          active: index === page, visible: true, sessionReady: true, readingAddress: false,
          networkType: 'wifi', autoplayWifi: autoplay, autoplayCellular: false,
          manualPlayback: false, autoplayStarted: false, mediaOwner: 'pin:slot-' + index,
          video: { ...backend.video, pinId: 'slot-' + index }, playback: backend.playback });
        Object.defineProperty(ui, 'state', { get: () => backend.states.at(-1) });
        ui.applySource(); mounted.set(index, { ui, backend });
      }
      const slot = mounted.get(index); slot.ui.active = index === page; slot.ui.activeChanged();
    }
    assert(mounted.size <= 3, 'retained video surfaces are bounded');
    assert([...mounted].filter(([index, slot]) => slot.ui.active).every(([index]) => index === page));
  }
  renderPage(0); await flush();
  const first = mounted.get(0), neighbor = mounted.get(1);
  assert.equal(first.backend.players[0].state, 'playing');
  assert.equal(neighbor.backend.players.length, 0, 'pre-mounted neighbor must not create AVPlayer or start a media request');
  first.backend.players[0].events.startRenderFrame();
  renderPage(1); await flush();
  assert.equal(mounted.get(0), first, 'outgoing node is retained through the visible swipe');
  assert.equal(mounted.get(1), neighbor, 'incoming node already existed before the index changed');
  assert.equal(first.backend.players[0].releases, 0, 'outgoing frame is not cleared by releasing its player');
  assert.equal(first.backend.states.at(-1).rendered, true);
  assert.equal(first.backend.players[0].state, 'paused', 'only the current slot plays');
  assert.equal(neighbor.backend.players[0].state, 'playing', 'selected pre-mounted neighbor can still start playback');
  renderPage(0); await flush(); assert.equal(mounted.get(0), first);
  assert.equal(first.backend.players[0].state, 'playing', 'reverse swipe can resume through the existing autoplay policy');
  renderPage(2); await flush(); assert(!mounted.has(0), 'distant player is released outside the adjacent window');
  assert.equal(first.backend.players[0].releases, 1);
  renderPage(3); await flush(); assert([...mounted.values()].every(slot => !slot.ui.active), 'photo slot does not activate video neighbors');
  for (const slot of mounted.values()) slot.backend.playback.release(); mounted.clear();
  renderPage(0, false); await flush();
  assert([...mounted.values()].every(slot => slot.backend.players.length === 0), 'autoplay off remains off for current and adjacent slots');
  mounted.get(0).ui.togglePlayback(); await flush();
  assert.equal(mounted.get(0).backend.players[0].state, 'playing', 'manual playback remains available');
  assert.equal(mounted.get(1).backend.players.length, 0);
  for (const slot of mounted.values()) { slot.ui.active = false; slot.ui.activeChanged(); }
  await flush(); assert([...mounted.values()].every(slot => slot.ui.state.phase !== 'playing'), 'background gate pauses every retained player');
  for (const slot of mounted.values()) slot.backend.playback.release();
  assert.match(carousel, /if \(item.video && this.videoSlotMounted\(index\)\)/);
  assert.match(carousel, /active: this.active && index === this.page/);
  assert(!carousel.includes('videoReadyKey') && !carousel.includes('switchingPage'), 'no poster or animation gate can block playing');
  const identity = player.match(/private readonly surfaceNodeId: string = ([^;]+);/)[1];
  const makeIdentity = new Function('let nextPinmonyVideoSurfaceId = 0; return () => ' + identity)();
  assert.notEqual(makeIdentity(), makeIdentity(), 'retained video nodes have distinct native surface identities');
  assert.match(player, /XComponent\(\{ id: this.surfaceNodeId, type: XComponentType.SURFACE/);
  console.log('Carousel video stability: adjacent node/frame retention, bounded surfaces, inactive no-load, selected autoplay/manual playback, reverse, photos, background and unique surface IDs passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
