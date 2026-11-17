const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync(path.join(process.argv[3] || '.', 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets'), 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const names = ['modern', 'legacyPagerEnabled', 'legacySnapshot', 'retainLegacySnapshot', 'legacyPagerHeight',
  'beginLegacyPaging', 'finishLegacyPaging', 'updateLegacyContentHeight', 'interactionChanged'];
const methods = [];
function visit(node) { if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast)); ts.forEachChild(node, visit); }
visit(ast);
let copies = 0;
const Host = vm.runInNewContext(ts.transpileModule('class Host{' + methods.join('\n') + '}Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { Curve: { EaseOut: 'ease-out' }, JSON: { parse: JSON.parse, stringify(value) { copies++; return JSON.stringify(value); } } });
function fixture() {
  const animations = [];
  const host = Object.assign(new Host(), {
    profile: { kind: 'state', profileUrl: 'synthetic/visitor', session: 1, section: 'saved', isOwn: false,
      displayName: 'Visitor', handle: 'visitor', avatarUrl: '', followers: '1', following: '2', actions: [],
      boards: [{ id: 'board' }], createdPins: [], contentError: 'saved-only-error', contentHasMore: true,
      contentLoadingMore: true, unorganizedFeedback: 'saved-only-feedback' },
    legacySnapshots: [], legacyPendingSnapshots: new Map(), legacyProfile: false,
    hubPane: false, legacyContentPane: false, interactionReady: true, legacyPaging: false,
    legacyPagingHeight: 0, legacySavedHeight: 900, legacyCreatedHeight: 240,
    legacyIndicatorPosition: -1, legacyIndicatorClickTarget: -1,
    getUIContext: () => ({ animateTo(options, action) { animations.push(options); action(); } }),
    stopHubChromeAnimation() {}
  });
  return { host, animations };
}
let { host, animations } = fixture();
host.retainLegacySnapshot();
const pending = host.legacySnapshot('created');
for (let frame = 0; frame < 60; frame++) assert.equal(host.legacySnapshot('created'), pending, 'animation frames must reuse one pending snapshot');
assert.equal(copies, 0, 'pending section must not serialize the active section data');
assert.equal(pending.boards.length, 0); assert.equal(pending.createdPins.length, 0);
assert.equal(pending.contentLoading, true); assert.equal(pending.contentLoadingMore, false);
assert.equal(pending.contentHasMore, false); assert.equal(pending.contentError, '');
assert.equal(pending.unorganizedFeedback, undefined, 'saved feedback cannot leak into the pending created section');
assert.equal(host.legacyPendingSnapshots.size, 1);
assert.equal(host.legacySnapshot('saved'), host.profile, 'real current data remains authoritative');
host.beginLegacyPaging(1);
assert.equal(host.legacyPagerHeight(), 900);
host.profile = { ...host.profile, section: 'created', createdPins: [{ id: 'pin' }], contentLoading: false, contentError: '' };
host.retainLegacySnapshot();
host.updateLegacyContentHeight('created', 1500, host.profile.profileUrl, 1);
assert.equal(host.legacyPagerHeight(), 900, 'late data and measurement cannot resize a horizontal animation');
host.beginLegacyPaging(0); assert.equal(host.legacyPagerHeight(), 900, 'duplicate start does not replace the source-height lock');
host.finishLegacyPaging(0);
assert.equal(animations.length, 1); assert.equal(animations[0].duration, 180);
assert.equal(host.legacyPagerHeight(), 1500, 'target content fits after horizontal animation; no permanent max-height spacer');
assert.equal(host.legacySnapshot('saved').boards.length, 1, 'outgoing saved content stays retained');
assert.equal(host.legacySnapshot('created'), host.profile, 'loaded data replaces pending snapshot');
host.beginLegacyPaging(0); host.profile = { ...host.profile, section: 'saved' };
host.updateLegacyContentHeight('saved', 600, host.profile.profileUrl, 1);
assert.equal(host.legacyPagerHeight(), 1500, 'reverse switch also keeps source size');
host.legacyIndicatorClickTarget = 1; host.finishLegacyPaging(0);
assert.equal(host.legacyPaging, true, 'obsolete completion cannot end the current click transition');
host.finishLegacyPaging(1); assert.equal(host.legacyPagerHeight(), 600);
for (const bad of [0, -1, NaN, Infinity, 600.5]) host.updateLegacyContentHeight('saved', bad, host.profile.profileUrl, 1);
assert.equal(host.legacySavedHeight, 600);
host.updateLegacyContentHeight('saved', 3000, 'synthetic/another', 1);
host.updateLegacyContentHeight('saved', 3000, host.profile.profileUrl, 2);
assert.equal(host.legacySavedHeight, 600, 'old profile/session measurements ignored');
host.beginLegacyPaging(1); host.interactionReady = false; host.interactionChanged();
assert.equal(host.legacyPaging, false); assert.equal(host.legacyPagingHeight, 0);
const count = animations.length; host.finishLegacyPaging(1); assert.equal(animations.length, count, 'hidden/cancelled pager cannot settle from a late completion');
host.interactionReady = true;
host.profile = { ...host.profile, profileUrl: 'synthetic/another', session: 2 }; host.retainLegacySnapshot();
assert.equal(host.legacyPendingSnapshots.size, 0); assert.equal(host.legacySavedHeight, 240);
const nextPending = host.legacySnapshot('created'); assert.notEqual(nextPending, pending); assert.equal(nextPending.session, 2);
for (const state of [
  { contentLoading: true, contentError: '', createdPins: [] },
  { contentLoading: false, contentError: 'synthetic-failure', createdPins: [] },
  { contentLoading: false, contentError: '', createdPins: [] },
  { contentLoading: false, contentError: '', createdPins: [{ id: 'ready' }] }
]) {
  host.profile = { ...host.profile, ...state, section: 'created' };
  host.retainLegacySnapshot();
  const actual = host.profile;
  assert.equal(host.legacySnapshot('created'), actual, 'loading/error/empty/success must use the real snapshot');
  host.profile = { ...host.profile, section: 'saved' }; host.retainLegacySnapshot();
  assert.equal(host.legacySnapshot('created'), actual, 'all real state branches survive switching away');
}
assert(source.includes('.height(this.legacyPagerHeight())'));
assert(source.includes('this.onLegacyContentHeight(height, this.profile.profileUrl, this.profile.session)'));
assert(source.includes('.onAnimationEnd((index: number) => this.finishLegacyPaging(index))'));
const click = source.slice(source.indexOf('private sectionTab('), source.indexOf('private profileHeaderLeading('));
assert(click.indexOf('this.beginLegacyPaging(') < click.indexOf('this.legacySwiper.changeIndex('), 'click locks source height before Swiper starts');
assert(/aboutToDisappear\(\)[\s\S]*?this\.legacyPendingSnapshots\.clear\(\)/.test(source));
console.log('Pager stability: 60 frames zero copies/stable pending identity, source height lock, smooth settle, reverse/cancel/duplicate, late data, invalid measurements, user/session and hidden lifecycle passed.');
