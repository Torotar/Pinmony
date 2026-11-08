const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');

function loadSession() {
  const geometry = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets', 'utf8')
    .replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
  const measureImageFlightOrigin = vm.runInNewContext(ts.transpileModule(geometry + ';measureImageFlightOrigin;', {
    compilerOptions: { target: 99 }
  }).outputText);
  const output = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageViewerSession.ets', 'utf8'), {
    compilerOptions: { target: 99, module: ts.ModuleKind.CommonJS, experimentalDecorators: true }
  }).outputText, { exports: output, Observed: value => value,
    require: name => name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {} } } : { measureImageFlightOrigin } });
  return output.PinmonyImageViewerSession;
}
function fixture() {
  const Session = loadSession();
  const session = new Session();
  const events = [];
  let valid = true, shift = 0;
  const source = { x: 58, y: 173 }, root = { x: 0, y: 0 };
  const ui = { px2vp: n => n / 2,
    getComponentUtils: () => ({ getRectangleById: () => ({ size: { width: 164, height: 220 } }) }),
    getFrameNodeById: id => ({ getPositionToWindowWithTransform: () => id === session.hostId ? root : source }) };
  const request = { owner: 'pin-test', detail: { imageUrl: 'photo' }, imageUrl: 'photo', previewUrl: 'preview', sourceRadius: 18,
    sourceId: () => 'source', isCurrent: () => valid, prepareReturn: () => shift,
    onReady: () => events.push('ready'), onClose: () => events.push('close'), onClosed: () => events.push('closed') };
  return { session, request, ui, source, root, events, invalidate: () => valid = false, shift: n => shift = n };
}
function run() {
  const f = fixture();
  assert(f.session.open(f.request));
  const revision = f.session.revision;
  assert(!f.session.open({ ...f.request, owner: 'comments' }), 'both entries share one presentation slot');
  assert(f.session.measure(f.ui, revision));
  assert.equal(f.session.origin.y, 173);
  f.session.rendered(revision); f.session.rendered(revision);
  assert.deepEqual(f.events, ['ready']);
  f.source.y += 16; f.root.y = 8; f.shift(120);
  f.session.close('comments'); assert(!f.session.closing, 'unrelated owner cannot close this viewer');
  f.session.close(f.request.owner); f.session.close();
  assert.equal(f.session.origin.y, 301, 'return remeasures transformed source and preserves Pin scroll compensation');
  assert(f.session.visible && f.session.closing);
  assert.deepEqual(f.events, ['ready', 'close']);
  f.session.finish(revision - 1); assert(f.session.visible);
  f.session.finish(revision); assert(!f.session.visible); assert.deepEqual(f.events, ['ready', 'close', 'closed']);
  assert(f.session.open(f.request));
  f.session.hostGone(revision); assert(f.session.visible, 'old host disposal cannot clear a reopened viewer');
  f.session.close(); assert(!f.session.visible, 'system back before decode cancels without waiting for render');
  const stale = fixture(); stale.session.open(stale.request); const old = stale.session.revision;
  stale.invalidate(); stale.session.rendered(old); assert.equal(stale.events.length, 0);
  stale.session.close(); assert(!stale.session.visible);
  const pin = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
  const comments = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets', 'utf8');
  const host = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyImageViewerHost.ets', 'utf8');
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const ast = ts.createSourceFile('pin.ts', pin.replace(/\bstruct\b/g, 'class'), 99, true);
  const names = ['onImageLayerChanged', 'viewerOwner', 'viewerSourceId', 'prepareViewerReturn', 'onViewerPageActiveChanged'];
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast); assert.equal(methods.length, names.length);
  const PinEntry = vm.runInNewContext(ts.transpileModule('class PinEntry {' + methods.join('\n') + '} PinEntry;', {
    compilerOptions: { target: 99 }
  }).outputText);
  const p = fixture(), entry = new PinEntry(); let scroll = 120;
  const detail = { pinUrl: 'current-pin', imageUrl: 'first', originalImageUrl: 'original',
    carousel: { freeScroll: true, items: [{ imageUrl: 'first' }, { imageUrl: 'second' }] } };
  Object.assign(entry, { imageLayer: 'zoom', traceId: 7, pageActive: true, viewerMounted: false, zoomImageUrl: 'first',
    displayedDetail: () => detail, viewportHeight: 720,
    measureViewerOrigin: () => ({ x: 18, y: 80, width: 324, height: 500 }),
    detailScroller: { offset: () => ({ yOffset: scroll }), scrollTo: opts => scroll = opts.yOffset },
    onViewerOpen: request => p.session.open(request), onViewerClose: owner => p.session.close(owner),
    onViewerCancel: owner => p.session.cancel(owner),
    onImageLayer: layer => { entry.imageLayer = layer; entry.onImageLayerChanged(); } });
  entry.onImageLayerChanged(); assert(p.session.visible && entry.viewerMounted);
  assert.equal(entry.viewerImageReady, false);
  p.session.request.onImageChange('second'); assert.equal(p.session.request.sourceId(), 'pinmony-photo-source-7-1');
  const pinRevision = p.session.revision;
  p.session.measure(p.ui, pinRevision); p.session.rendered(pinRevision); assert(entry.viewerImageReady);
  p.session.close(); assert.equal(scroll, 0); assert.equal(p.session.origin.y, 293);
  assert.equal(entry.imageLayer, ''); assert(p.session.closing && entry.viewerMounted);
  p.session.finish(pinRevision); assert(!entry.viewerMounted && !entry.viewerImageReady);
  entry.imageLayer = 'zoom'; entry.onImageLayerChanged(); assert(p.session.visible);
  entry.pageActive = false; entry.onViewerPageActiveChanged(); assert(!p.session.visible);
  for (const entry of [pin, comments]) {
    assert(!entry.includes('PinmonyImageViewer({'), 'entry points cannot retain independent viewer instances');
    assert(!entry.includes('.bindContentCover('), 'entry points cannot retain independent full-screen hosts');
    assert(entry.includes('this.onViewerOpen'), 'all entries dispatch through the shared session');
  }
  assert.equal((host.match(/PinmonyImageViewer\(\{/g) || []).length, 1);
  assert(index.includes('.bindContentCover($$this.imageViewer.visible, this.sharedImageViewer()'));
  assert(index.includes('enableSafeArea: false'), 'native cover must not inset the shared viewport');
  assert(host.includes('.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])'));
  assert(index.includes('this.imageViewer.close(); return true;'), 'back closes viewer before comments or Pin');
  console.log('Shared viewer: single host, both entry points, full-window safe areas, render handoff, reverse return, scroll compensation, owner/session isolation, cancellation and stale disposal passed');
}
module.exports = { loadSession, fixture };
if (require.main === module) run();
