const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const timers = new Map(); let id = 0;
const { PinmonyBoardStateController: Controller } = require('./board-state-controller-harness.cjs').create(ts, {
  setTimeout: fn => { timers.set(++id, fn); return id; }, clearTimeout: key => timers.delete(key)
});
const page = 'https://www.pinterest.com/sample/board/', other = 'https://www.pinterest.com/sample/other/';
const pin = { id: '101', pinUrl: 'https://www.pinterest.com/pin/101/', imageUrl: 'https://example.invalid/image', imageWidth: 100, imageHeight: 100, title: '' };
function state(extra = {}) { return { kind: 'state', session: 2, pageKey: page, boardId: '1', title: 'Board', pinCount: '1', ownerName: '', ownerAvatar: '',
  loading: false, loadingMore: false, ready: true, error: '', hasMore: false, pins: [pin], ...extra }; }
function harness() {
  const store = { boardOpeningToken: 0 }, events = []; let current = page, auth = true, foreground = true, root = false, detail = false, retained;
  const controller = new Controller(store, { authenticated: () => auth, foreground: () => foreground, rootOnly: () => root,
    currentBoard: () => current, boardAddress: address => [page, other].includes(address) ? address : '', profileAddress: () => '',
    pinAddress: address => address === pin.pinUrl ? address : '', addressKey: address => address || '', publishReturn: () => '',
    hasDetail: () => detail, backTarget: () => '', retainedContent: () => retained, movePage: () => '', clearMovePage() {},
    confirmInvitation: key => events.push(['invitation', key]), invalidateProfile: () => events.push(['invalidate']),
    feedback: value => events.push(['feedback', value]), closeFlow: () => events.push(['close']), back: () => events.push(['back']), navigate: value => events.push(['navigate', value]) });
  return { store, controller, events, current: value => current = value, auth: value => auth = value, foreground: value => foreground = value,
    root: value => root = value, detail: value => detail = value, retain: value => retained = value, update: extra => controller.update(JSON.stringify(state(extra))) };
}
const h = harness(); h.controller.syncRoute(page); assert.equal(timers.size, 1); const abandoned = [...timers.values()][0];
h.controller.pause(); assert.equal(timers.size, 0); h.foreground(false); abandoned(); assert.equal(h.store.boardDetail.error, '');
h.foreground(true); h.controller.resume(); assert.equal(timers.size, 1); h.controller.resume(); assert.equal(timers.size, 1);
h.update({ session: 0, loading: true, ready: false, pins: [] }); assert.equal(timers.size, 1, 'initial snapshot keeps readiness timeout');
h.update(); assert.equal(timers.size, 0); assert.equal(h.store.boardDetail.ready, true);
const snapshot = h.store.boardDetail; h.controller.syncRoute(pin.pinUrl); assert.equal(h.store.boardDetail, snapshot); assert.equal(snapshot.session, 0); assert.equal(h.store.presentationOnly, true);
h.update({ session: 3, ready: false, loading: true, pins: [] }); assert.equal(h.store.boardDetail, snapshot); assert.equal(snapshot.pins.length, 1);
h.update({ session: 3, pins: [] }); assert.equal(h.store.boardDetail.pins.length, 0); assert.equal(h.store.presentationOnly, false);
h.update({ session: 2 }); assert.equal(h.store.boardDetail.session, 3);
for (const extra of [{ session: -1 }, { session: 1.5 }, { ready: 'true' }, { privacy: 'invalid' }, { pins: null }, { revision: -1 }, { nextPage: 4 }]) { const old = h.store.boardDetail; h.update(extra); assert.equal(h.store.boardDetail, old); }
h.foreground(false); const before = h.store.boardDetail; h.update({ session: 8 }); assert.equal(h.store.boardDetail, before); h.foreground(true);
h.auth(false); h.update({ session: 8 }); assert.equal(h.store.boardDetail, before); h.auth(true);
h.detail(true); h.update({ session: 8 }); assert.equal(h.store.boardDetail, before); h.detail(false);
h.retain(state({ pinCount: 'retained' })); h.update({ session: 4, pins: [] }); assert.equal(h.store.boardDetail.pins.length, 1); assert.equal(h.store.boardDetail.pinCount, 'retained');
h.update({ session: 4, revision: 1 }); assert.equal(h.events.filter(e => e[0] === 'invalidate').length, 1); h.update({ session: 4, revision: 1 }); assert.equal(h.events.filter(e => e[0] === 'invalidate').length, 1);
h.update({ session: 4, nextPage: other }); assert.equal(h.store.pendingBoardUrl, other); assert.equal(h.events.at(-1)[0], 'navigate');
h.controller.syncRoute(other); assert.equal(h.store.boardDetail.pageKey, page, 'wait for actual document'); h.current(other); h.controller.syncRoute(other); assert.equal(h.store.boardDetail.pageKey, other);
const oldTimer = [...timers.values()][0]; h.current(page); h.controller.syncRoute(page); oldTimer(); assert.equal(h.store.boardDetail.error, '');
[...timers.values()][0](); assert.match(h.store.boardDetail.error, /重试/); h.controller.pause();
console.log('Board state controller: route/document guards, preserved list, session validation, initial timeout, cancellation/resume, revision and next-page ports passed');
