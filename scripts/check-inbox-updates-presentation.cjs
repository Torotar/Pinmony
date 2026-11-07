const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const end = source.indexOf('\n  }', start) + 4;
  return source.slice(start, end);
}
const timers = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['activeContentScroller', 'restoreScroll', 'reportScroll', 'measureListPart', 'updateListHeight'].map(method).join('\n') + '} Host;', {
  compilerOptions: {target: ts.ScriptTarget.ES2021}
}).outputText, {setTimeout: callback => timers.push(callback), console, Number});
const listCalls = [], updateCalls = [], reports = [];
const h = Object.assign(new Host(), {
  snapshot: {section: 'updates', pageUrl: 'synthetic', items: []}, scrollRestoreGeneration: 0, initialScrollOffset: 125,
  scroller: {scrollTo: value => listCalls.push(value), offset: () => ({yOffset: 40})},
  updatesScroller: {scrollTo: value => updateCalls.push(value), offset: () => ({yOffset: 125})},
  rowHeights: new Map(), contentHeight: 900, lastReportedScrollOffset: -1,
  reportScrollAvailability() {}, onScrollPosition: (...args) => reports.push(args)
});
h.restoreScroll(); timers.splice(0).forEach(callback => callback());
assert.equal(updateCalls.length, 1); assert.equal(updateCalls[0].yOffset, 125); assert.equal(listCalls.length, 0);
h.reportScroll(); assert.equal(reports.at(-1)[1], 'updates'); assert.equal(reports.at(-1)[2], 125);
h.measureListPart('footer', 10); assert.equal(h.contentHeight, 900, 'old message item callbacks cannot replace update height');
h.restoreScroll(); h.snapshot = {...h.snapshot, section: 'messages'}; h.initialScrollOffset = 40; h.restoreScroll();
timers.splice(0).forEach(callback => callback());
assert.equal(updateCalls.length, 1, 'late update restoration is cancelled after switching section');
assert.equal(listCalls.length, 1); assert.equal(listCalls[0].yOffset, 40);
h.reportScroll(); assert.equal(reports.at(-1)[1], 'messages'); assert.equal(reports.at(-1)[2], 40);
h.snapshot = {...h.snapshot, section: 'updates'}; h.initialScrollOffset = 0; h.restoreScroll();
timers.splice(0).forEach(callback => callback());
assert.equal(updateCalls.at(-1).yOffset, 0, 'return to top uses the update scroller');
const builder = source.slice(source.indexOf('  private updatesContent()'), source.indexOf('  private inboxContent()'));
assert(builder.includes('Scroll(this.updatesScroller)')); assert(!builder.includes('ListItem('));
assert(builder.includes('.padding({ top: this.inboxTopInset(), bottom: 120 })'));
assert.equal((builder.match(/this\.updatesGroup\(/g) || []).length, 3, 'unread, read, and unclassified groups retained');
assert(builder.includes('this.loadMoreUpdatesAtEnd()')); assert(builder.includes('this.snapshot.moreError'));
assert(source.includes('.bindToScrollable([this.updatesScroller, this.scroller])'));
assert(source.includes('List({ scroller: this.scroller })')); assert(source.includes('.swipeAction({ end:'));
console.log('Updates presentation: original Scroll/group layout, title binding, physical inset, native message swipe, isolated offsets and rapid section/late-layout guards passed');
