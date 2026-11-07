const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  }', start) + 4);
}
const appearStart = source.indexOf('  aboutToAppear(): void');
const appear = source.slice(appearStart, source.indexOf('\n  }', appearStart) + 4);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + appear + '\n' +
  ['segmentBackgroundColor', 'syncSegmentItems', 'onSnapshotChanged', 'selectSection', 'swipeSection', 'inboxTitleBarOptions'].map(method).join('\n') +
  '} Host;', {compilerOptions: {target: ts.ScriptTarget.ES2021}}).outputText, {
  $r: key => key,
  ColorMetrics: {resourceColor: key => {
    assert.equal(key, 'app.color.surface_muted');
    if (colorReadError) throw new Error('resource unavailable');
    return segmentColor;
  }},
  PinmonyI18n: {render: (text, lang) => lang + ':' + text, message: key => key},
  BlurStrategy: {ENABLE: 1, DISABLE: 0}, ScrollEffectType: {IMMERSIVE_GRADIENT_BLUR: 1},
  PinmonyImmersiveLight: {effect: mode => mode}, Curve: {EaseOut: 0}
});
let colorReadError = false, segmentColor = {theme: 'light'};
const h = new Host(); let index = 0, selectedWrites = 0, labelWrites = 0;
assert(source.includes('buttonBackgroundColor: this.segmentBackgroundColor()'));
assert.equal(h.segmentBackgroundColor(), segmentColor);
segmentColor = {theme: 'dark'};
assert.equal(h.segmentBackgroundColor(), segmentColor, 'theme changes read the current resource without caching');
colorReadError = true;
assert.equal(h.segmentBackgroundColor(), undefined, 'missing resources fall back to the component theme default');
colorReadError = false;
assert.equal(h.segmentBackgroundColor(), segmentColor, 'resource reads recover after a transient failure');
Object.defineProperty(h, 'segmentSelectedIndex', {get: () => index, set: value => {index = value; selectedWrites++;}});
const items = [0, 1].map(() => Object.defineProperty({}, 'text', {set() {labelWrites++;}}));
Object.assign(h, {snapshot: {section: 'messages', updateLabel: 'updates', inboxLabel: 'inbox'}, uiLanguage: 'zh',
  segmentUpdateLabel: '', segmentInboxLabel: '', segmentItems: items, immersiveLightMode: 'immersive',
  inboxSegmentsBuilder: () => {}});
h.syncSegmentItems(); assert.equal(index, 1); assert.equal(selectedWrites, 1); assert.equal(labelWrites, 2);
const builder = h.inboxTitleBarOptions().content.stackBuilder;
for (let i = 0; i < 100; i++) {
  h.snapshot = {...h.snapshot, items: [], moreLoading: i % 2 === 0}; h.syncSegmentItems();
  assert.equal(h.inboxTitleBarOptions().content.stackBuilder, builder, 'polling must retain the title builder');
}
assert.equal(selectedWrites, 1, 'unchanged section must not reapply the selection');
assert.equal(labelWrites, 2, 'content refresh must not rewrite segment labels');
for (const section of ['updates', 'messages', 'updates']) {
  h.snapshot = {...h.snapshot, section}; h.syncSegmentItems(); assert.equal(index, section === 'messages' ? 1 : 0);
}
assert.equal(selectedWrites, 4, 'each real section switch applies once');
h.uiLanguage = 'en'; h.syncSegmentItems(); assert.equal(labelWrites, 4); assert.equal(selectedWrites, 4);
h.uiLanguage = 'zh'; h.syncSegmentItems(); assert.equal(labelWrites, 6); assert.equal(selectedWrites, 4);
assert(source.includes('selectedIndex: this.segmentSelectedIndex'));
assert(source.includes('enableStateAnimation: true'), 'real selection transitions keep their animation');
assert(source.includes("@Watch('onSnapshotChanged')"));
assert(source.includes("@Watch('syncSegmentItems')"));
let restores = 0, animations = 0, closes = 0;
Object.assign(h, {initialScrollOffset: 0, rowHeights: new Map(),
  updateListHeight() {}, closeConversationActions() {closes++;}, restoreScroll() {restores++;},
  getUIContext: () => ({animateTo: (_options, callback) => {animations++; callback();}})});
h.aboutToAppear(); assert.equal(h.activeSection, 'updates'); assert.equal(h.restoringScroll, false);
for (let i = 0; i < 50; i++) {
  h.snapshot = {...h.snapshot, items: [], moreLoading: i % 2 === 0, apiError: i % 2 ? 'retry' : ''};
  h.onSnapshotChanged();
}
assert.equal(restores, 0); assert.equal(animations, 0); assert.equal(selectedWrites, 4);
h.snapshot = {...h.snapshot, section: 'messages'}; h.onSnapshotChanged();
assert.equal(index, 1); assert.equal(restores, 1); assert.equal(animations, 1); assert.equal(closes, 1);
h.initialScrollOffset = 120; h.aboutToAppear();
assert.equal(index, 1); assert.equal(h.restoringScroll, true, 'retained messages initialize without resetting the selected segment');
const selections = [];
Object.assign(h, {refreshing: false, interactionReady: true, loading: false, error: '',
  onSection: section => selections.push(section), conversationSwipeActive: false});
h.selectSection('messages'); assert.equal(selections.length, 0, 'repeated active selection is a no-op');
h.refreshing = true; h.selectSection('updates'); assert.equal(selections.length, 0);
h.refreshing = false; h.interactionReady = false; h.selectSection('updates'); assert.equal(selections.length, 0);
h.interactionReady = true; h.loading = true; h.snapshot.dataSource = 'dom';
h.selectSection('updates'); assert.equal(selections.length, 0, 'unready DOM state does not dispatch');
h.snapshot.dataSource = 'api'; h.selectSection('updates'); assert.equal(selections.at(-1), 'updates');
h.conversationSwipeActive = true; h.swipeSection(100, 0); assert.equal(selections.length, 1);
h.conversationSwipeActive = false; h.swipeSection(100, 200); assert.equal(selections.length, 1);
h.swipeSection(100, 0); assert.equal(selections.length, 2); assert.equal(index, 1, 'input cannot invent a confirmed section');
console.log('Inbox segment stability: polling, retained entry, lifecycle, loading/error gates, swipe conflict, stable title and live language passed');
