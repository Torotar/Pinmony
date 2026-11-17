const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync(path.join(process.argv[3] || '.', 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets'), 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
const names = ['modern', 'legacyPagerEnabled', 'retainLegacySnapshot', 'legacySnapshot', 'selectLegacySection', 'onProfileChanged'];
const methods = [];
function visit(node) { if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast)); ts.forEachChild(node, visit); }
visit(ast); assert.equal(methods.length, names.length);
const Host = vm.runInNewContext(ts.transpileModule('const PinmonyRuntimeLog={info(){}};class Host{' + methods.join('\n') + '} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
function fixture() {
  const scrolls = [], selected = [];
  const host = Object.assign(new Host(), {
    profile: { profileUrl: 'synthetic/visitor/', session: 7, section: 'created', isOwn: false },
    legacyProfile: false, legacyContentPane: false, hubPane: false, onBack() {}, interactionReady: true,
    legacySnapshots: [], legacyPendingSnapshots: new Map(), legacyCreatedHeight: 600, legacySavedHeight: 900,
    activeProfile: 'synthetic/visitor/', activeSection: 'created', hubChromeSession: 7,
    pinRenderKeys: new Map(), retainHubSnapshot() {}, scroller: { scrollTo: p => scrolls.push(p) },
    onTab: section => selected.push(section), sortVisible: false, pendingVisibility: undefined,
    stopHubChromeAnimation() {}, hubPaneChromeOffsets: new Map()
  });
  return { host, scrolls, selected };
}
for (const legacy of [false, true]) {
  const { host, scrolls, selected } = fixture(); host.legacyProfile = legacy;
  assert.equal(host.legacyPagerEnabled(), true, 'visitor must reuse retained horizontal pager in either app layout');
  host.retainLegacySnapshot(); const created = host.profile;
  host.selectLegacySection('saved'); assert.deepEqual(selected, ['saved']);
  host.profile = { ...created, section: 'saved' }; host.onProfileChanged();
  assert.equal(scrolls.length, 0, 'created to saved must not scroll the outer profile to top');
  assert.equal(host.legacySnapshot('created'), created, 'outgoing section snapshot survives');
  host.profile = created; host.onProfileChanged();
  assert.equal(scrolls.length, 0, 'saved to created must not scroll the outer profile to top');
  assert.equal(host.legacySnapshots.length, 2);
  host.profile = { ...created, profileUrl: 'synthetic/another/', session: 8 }; host.onProfileChanged();
  assert.equal(scrolls.length, 1, 'a different user still resets the outer scroll');
  assert(host.legacySnapshots.every(p => p.profileUrl === 'synthetic/another/' && p.session === 8), 'old user/session snapshots discarded');
}
const { host, selected } = fixture();
for (const field of ['privateRestricted', 'hubPane', 'legacyContentPane']) {
  const target = field === 'privateRestricted' ? host.profile : host;
  target[field] = true; assert.equal(host.legacyPagerEnabled(), false); target[field] = false;
}
host.profile.isOwn = true; host.onBack = undefined;
assert.equal(host.legacyPagerEnabled(), false, 'modern own-profile hub stays unchanged');
host.legacyProfile = true; assert.equal(host.legacyPagerEnabled(), true);
host.interactionReady = false; host.selectLegacySection('saved'); assert.equal(selected.length, 0);
host.interactionReady = true; host.profile.suggestionWriting = true; host.selectLegacySection('saved'); assert.equal(selected.length, 0);
assert(source.includes('.onChange((index: number) => this.selectLegacySection(index === 1 ? \'saved\' : \'created\'))'));
assert(source.includes('this.legacySwiper.changeIndex(target, true)'));
assert(source.includes(".hitTestBehavior(this.profile.section === section ? HitTestMode.Default : HitTestMode.None)"));
assert(source.includes(".accessibilityLevel(this.profile.section === section ? 'auto' : 'no-hide-descendants')"));
console.log('Visitor pager: both layouts, created/saved swipe and click route, no section top reset, retained snapshots, user/session isolation, private/nested and interaction guards passed.');
