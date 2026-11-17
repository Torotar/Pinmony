const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const { PinmonyDetailSources: Sources } = loader.loadPackage('common_ui');
const { PinmonyDetailSiblingNavigation: Navigation } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailSiblingNavigation.ets');
const { PinmonyDetailSwipe: Swipe } = loader.loadFile('feature_pin/src/main/ets/services/PinmonyDetailSwipe.ets');
function host(file, names, globals = {}) {
  const text = fs.readFileSync(file, 'utf8').replace(/\bstruct\b/g, 'class');
  const ast = ts.createSourceFile('host.ts', text, 99, true), methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast); assert.equal(methods.length, names.length);
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: 99 }
  }).outputText, { Curve: { EaseOut: 0 }, Date, PinmonyRuntimeLog: { info() {} }, ...globals });
}
const pin = 'https://www.pinterest.com/pin/1/';
let cards = [{ pinUrl: pin, cardId: 'one' }];
Sources.stage({ identity: 'home:one', pageUrl: 'https://www.pinterest.com/', session: 1, cards: () => cards, locate() {} });
const nav = new Navigation(); nav.enter(pin, 'one', 7, false);
const Gate = host('entry/src/main/ets/pages/Index.ets', ['canSwitchDetailSibling']);
const gate = new Gate();
Object.assign(gate, { detailSiblings: nav, nativeBusinessSessionContext: () => ({ generation: 7 }),
  pinStore: { detail: { pinUrl: pin, kind: 'cached' }, videoForeground: true }, authStatus: 'authenticated' });
assert.equal(gate.canSwitchDetailSibling(), true, 'one-card source still recognizes boundary intent');
assert.equal(gate.canSwitchDetailSibling(false, 1), false);
assert.equal(gate.canSwitchDetailSibling(false, -1), false);
gate.showNativeSheet = true; assert.equal(gate.canSwitchDetailSibling(), false); gate.showNativeSheet = false;
cards = []; assert.equal(gate.canSwitchDetailSibling(), false, 'deleted card cannot produce boundary feedback');
const Page = host('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', ['siblingPanEnd', 'animateSiblingBoundary', 'commitPinPresentation']);
const page = new Page(), animations = [], positions = [], boundaryEvents = [];
let ready = true, switches = 0;
Object.assign(page, { siblingBoundaryVersion: 0, siblingBoundaryOffset: 0, heroVisible: true,
  siblingSwipe: new Swipe(), traceId: 1, displayedDetail: () => ({ pinUrl: pin }),
  siblingOnMedia: false, siblingSwipeReady: step => ready && (!step), onSwitchSibling: () => switches++,
  onSiblingBoundary: step => boundaryEvents.push(step),
  getUIContext: () => ({ animateTo(options, update) { update(); positions.push(page.siblingBoundaryOffset); animations.push(options); } }) });
for (const dx of [-100, 100]) {
  page.siblingSwipe.start(100, 200, pin + ':1', true, 0);
  page.siblingPanEnd({ offsetX: dx, offsetY: 0 });
  for (let i = 0; i < 3; i++) animations.shift().onFinish();
  assert.equal(page.siblingBoundaryOffset, 0, 'feedback returns to exact origin');
}
assert.equal(switches, 0, 'first/last overscroll never opens another detail or requests pagination');
assert.deepEqual(positions, [-8, 4, 0, 8, -4, 0], 'physical directions give mirrored subtle feedback');
assert.deepEqual(boundaryEvents, [1, -1], 'one notice per boundary gesture, not per animation phase');
page.animateSiblingBoundary(1, 0, ++page.siblingBoundaryVersion);
ready = false; animations.shift().onFinish();
assert.equal(page.siblingBoundaryOffset, 0, 'covering layer stops feedback and restores origin');
ready = true; page.animateSiblingBoundary(1, 0, ++page.siblingBoundaryVersion);
const stale = animations.shift(); page.siblingBoundaryVersion++; page.siblingBoundaryOffset = 0;
stale.onFinish(); assert.equal(page.siblingBoundaryOffset, 0, 'retired animation cannot move replacement Pin');
const arrival = new Page(), notices = [];
let arrivalPin = pin;
Object.assign(arrival, { traceId: 1, displayedDetail: () => ({ pinUrl: arrivalPin }),
  siblingSwipeReady: step => !step, siblingBoundaryVersion: 0, siblingSwipe: new Swipe(),
  animateSiblingBoundary: step => notices.push(step), onSiblingBoundary: step => notices.push(step),
  siblingMotion: { present() {} }, viewerOwner: () => '', uiCommits: { post(_key, action) { action(); } }, resetEntryMotion() {},
  restoreScrollPosition() {}, startSearchLabel() {}, syncDetailFlow() {}, updateDetailLayout() {},
  auditRecommendationGate() {}, queuePhotoFitAudit() {} });
for (const target of [pin, 'https://www.pinterest.com/pin/2/', pin]) {
  arrivalPin = target;
  arrival.commitPinPresentation(); arrival.commitPinPresentation();
}
assert.equal(notices.length, 0, 'arriving at either edge, returning and snapshot refresh never shake or show notice without a new gesture');
const text = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8').replace(/\bstruct\b/g, 'class');
const ast = ts.createSourceFile('photo.ts', text, 99, true), creators = [];
function findCreator(node) {
  if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text === 'onClick' &&
    node.arguments[0]?.getText(ast).includes('this.onUser')) creators.push(node);
  ts.forEachChild(node, findCreator);
}
findCreator(ast); assert.equal(creators.length, 1, 'avatar and creator row share one profile entry');
assert.equal(Number(creators[0].arguments[1]?.getText(ast)), 8, 'profile click has bounded movement and yields to drag');
const creatorFactory = vm.runInNewContext(ts.transpileModule('(function() { return (' + creators[0].arguments[0].getText(ast) + '); })', {
  compilerOptions: { target: 99 }
}).outputText, { PinmonyRuntimeLog: { info() {} } });
const profileOpens = [], creatorHost = { displayedDetail: () => ({ creatorUrl: 'synthetic-profile' }), onUser: value => profileOpens.push(value) };
const creatorTap = creatorFactory.call(creatorHost);
for (const distance of [0, 3, 100, 150]) { if (distance <= 8) creatorTap(); }
assert.deepEqual(profileOpens, ['synthetic-profile', 'synthetic-profile'], 'creator taps still navigate while drag dispatch is excluded');
assert.match(text, /Column\(\) \{ this\.detailContent\(\) \}[\s\S]{0,260}translate\(\{ x: this\.siblingBoundaryOffset \+ this\.siblingMotionOffset \}\)/, 'feedback moves body rather than title bar');
assert.match(text, /siblingBoundaryVersion\+\+; this\.siblingBoundaryOffset = 0/, 'Pin change and teardown invalidate feedback');
const snackEvents = [], dismissEvents = [];
const SnackHost = host('entry/src/main/ets/pages/Index.ets', [
  'showSiblingBoundarySnack', 'syncSiblingBoundarySnack', 'dismissSiblingBoundarySnack',
  'preparePostSnack', 'isCurrentPostSnack', 'dismissPostSnack', 'releasePostSnack',
  'handlePostSnackClose', 'handlePostSnackBack', 'refreshSystemShareLoadingLanguage'
], { HdsSnackBar: class {}, $r: x => x,
  SnackBarIconType: { NORMAL: 0 }, SnackBarOperationType: { CLOSE_BUTTON_ONLY: 0 },
  PinmonySnackBarLifecycle: { show: (...args) => snackEvents.push(args),
    dismiss: () => dismissEvents.push('dismiss'), isCurrent: () => true } });
const snackHost = new SnackHost();
let boundary = true, valid = true, language = 'zh_CN';
const texts = locale => JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
Object.assign(snackHost, { postSnackToken: 0, postSnackExpiresAt: 0, getUIContext: () => ({}),
  canSwitchDetailSibling: (_trace, step = 0) => valid && (!step || !boundary),
  uiText: key => texts(language).find(row => row.name === key).value, syncSystemShareLoading() {} });
snackHost.showSiblingBoundarySnack(-1);
assert.equal(snackEvents.at(-1)[2].title, '已到第一条');
const expiry = snackHost.postSnackExpiresAt;
language = 'en_US'; snackHost.refreshSystemShareLoadingLanguage();
assert.equal(snackEvents.at(-1)[2].title, 'You’ve reached the first Pin');
assert.equal(snackHost.postSnackExpiresAt, expiry, 'language refresh preserves expiry');
assert(snackEvents.at(-1)[4].duration > 0 && snackEvents.at(-1)[4].duration <= 4000);
snackHost.showSiblingBoundarySnack(1);
assert.equal(snackEvents.at(-1)[2].title, 'You’ve reached the last Pin');
assert.equal(dismissEvents.length, 1, 'repeated boundary replaces previous notice');
boundary = false; snackHost.syncSiblingBoundarySnack();
assert.equal(snackHost.siblingBoundarySnackToken, 0, 'new neighbor invalidates old boundary');
const count = snackEvents.length;
snackHost.showSiblingBoundarySnack(1); boundary = true; valid = false; snackHost.showSiblingBoundarySnack(-1);
assert.equal(snackEvents.length, count, 'middle card and stale source do not notify');
valid = true; snackHost.showSiblingBoundarySnack(-1);
const staleClose = snackEvents.at(-1)[3].onCloseButtonClick;
snackHost.showSiblingBoundarySnack(1); staleClose();
assert(snackHost.siblingBoundarySnackToken, 'old close cannot retire current notice');
snackHost.dismissSiblingBoundarySnack();
assert.equal(snackHost.siblingBoundarySnackToken, 0, 'navigation/reset cleanup releases boundary owner');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(!text.includes('siblingEntryStep') && !index.includes('siblingArrivalStep'), 'remove arrival-trigger state throughout host and detail');
assert.match(index, /onSiblingBoundary:.*_identity === this\.detailRootIdentity\(\).*showSiblingBoundarySnack\(step\)/);
assert.match(index, /if \(this\.siblingBoundarySnackToken\) this\.dismissPostSnack\('detail-boundary-navigation'\)/);
assert.match(index, /onBackPress\(\): boolean \{\s*if \(this\.siblingBoundarySnackToken\) this\.dismissPostSnack/);
for (const locale of ['base','zh_CN','zh_TW','en_US','en_GB','ja','ko','ru','pt_BR','ar']) {
  for (const key of ['pm_detail_source_first','pm_detail_source_last']) assert(texts(locale).find(row => row.name === key)?.value);
}
console.log('Sibling boundaries: first/last and single-card feedback, both physical directions, modal/deleted-source guards, animation retirement and bounded creator clicks passed');
