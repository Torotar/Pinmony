const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { runtime } = require('./product-coordination-harness.cjs');
const { PinmonyBoardNativeReads } = runtime(ts).loadFile('entry/src/main/ets/app/PinmonyBoardNativeReads.ets');
function fixture(phase, sectionId) {
  const reader = Object.create(PinmonyBoardNativeReads.prototype);
  const flow = { phase, sectionId };
  Object.assign(reader, { flow, verified: true, ready: true, store: { boardDetail: { flow } }, ports: {},
    bind: () => true, contributes: () => true, cancelFlow() {}, apply() { this.store.boardDetail.flow = this.flow; }, syncAuxiliary() { this.apply(); } });
  return reader;
}
async function main() {
  const organizer = fixture('select');
  assert(!organizer.contentReady());
  assert(organizer.contentReady(true));
  assert.equal(organizer.beginSectionSelection(' New section ', true), '');
  assert.equal(organizer.flow.phase, 'sectionSelect');
  assert.equal(organizer.flow.sectionTitle, 'New section');
  await organizer.auxiliaryAction({ action: 'close' });
  assert.equal(organizer.flow.phase, 'select');
  assert(!organizer.organizerSectionCreation);
  const publish = fixture('');
  assert(publish.contentReady());
  assert(!publish.contentReady(true));
  assert.equal(publish.beginSectionSelection('New section'), '');
  assert.equal(publish.flow.phase, 'sectionSelect');
  assert(!publish.organizerSectionCreation);
  assert(!fixture('select','101').contentReady(true));
  const busy = fixture('select'); busy.flow.busy = true; assert(!busy.contentReady(true));
  const uncertain = fixture('select'); uncertain.flow.uncertain = true; assert(!uncertain.contentReady(true));
  const page = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
  const footer = page.slice(page.indexOf('private boardActionTabs('), page.indexOf('private actionTile('));
  const labels = ['pm_board_organizer_move_to','pm_section_6d4e3a60','pm_delete_2f9daa82'];
  assert(labels.every((key, i) => footer.includes(key) && (i === 0 || footer.indexOf(key) > footer.indexOf(labels[i-1]))));
  assert.match(footer,/HdsTabs\(\{ barPosition: BarPosition.End, controller: organizer \? this\.organizerTabsController : undefined \}\)/);
  assert.match(footer,/if \(!this.organizerActionEnabled\(index\)\) return/);
  assert.match(footer,/onCreateOrganizerSection/);
  assert.match(page,/if \(!targetSheet && this.phase\(\) === 'select'\) \{\s*this.boardActionTabs\(true\)/);
  assert(!page.includes('private organizerToolbarItem'));
  assert.match(footer,/sys\.symbol\.puzzle'\)/);
  assert.doesNotMatch(footer,/puzzle_fill|board_organize_puzzle/);
  assert.match(page,/sectionSelect' \? \[\{ content:[\s\S]*?action:'sectionCreate'/);
  assert(!page.includes('this.selectingPins() ? [{ content:'));
  assert.match(page,/action: 'targets', value: this.selectedIds.slice\(\)/);
  assert.equal((page.match(/this\.confirmDeleteSelected\(\)/g)||[]).length,1);
  // Exercise the actual page guards and captured delete confirmation callback.
  const methods = [['confirmationKey', 'confirmDelete'], ['confirmDeleteSelected', 'confirmMerge'],
    ['organizerToolbarReady', 'moveOrganizerSelection'], ['moveOrganizerSelection', 'organizerActionEnabled'],
    ['organizerActionEnabled', 'organizeContent']].map(([name, next]) =>
    page.slice(page.indexOf(`  private ${name}(`), page.indexOf(`  private ${next}(`)).replace(/\s*@Builder\s*$/, ''));
  const Surface = require('node:vm').runInNewContext(ts.transpileModule(`class Surface {${methods.join('\n')}} Surface;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText,
    { PinmonyImmersiveLight: { alertOptions: options => options } });
  const surface = new Surface();
  let dialog;
  const writes = [], moves = [];
  Object.assign(surface, { selectedIds: ['1'], snapshot: { pageKey: 'board', session: 1, flow: {}, nativeReadsReady: true, editable: true },
    phase: () => 'select', boardOrganizer: () => true, uiText: key => key, act: (...args) => writes.push(args),
    onAction: payload => moves.push(JSON.parse(payload)), onCreateOrganizerSection() {},
    getUIContext: () => ({ showAlertDialog: options => { dialog = options; } }) });
  for (const index of [0, 1, 2]) assert(surface.organizerActionEnabled(index));
  surface.moveOrganizerSelection();
  assert.deepEqual(moves, [{ action: 'targets', value: ['1'] }]);
  for (const block of [() => { surface.snapshot.session++; }, () => { surface.snapshot.flow.sectionId = 'other'; },
    () => { surface.snapshot.flow.loading = true; }, () => { surface.selectedIds = ['2']; }]) {
    surface.snapshot.flow = {};
    surface.selectedIds = ['1'];
    surface.confirmDeleteSelected();
    block();
    dialog.secondaryButton.action();
    assert.equal(writes.length, 0);
  }
  surface.selectedIds = [];
  assert(!surface.organizerActionEnabled(0) && surface.organizerActionEnabled(1) && !surface.organizerActionEnabled(2));
  surface.snapshot.editable = false;
  assert(!surface.organizerActionEnabled(1));
  surface.snapshot.canContribute = true;
  assert(surface.organizerActionEnabled(1));
  surface.selectedIds = ['1'];
  surface.confirmDeleteSelected();
  dialog.primaryButton.action();
  assert.equal(writes.length, 0);
  dialog.secondaryButton.action();
  assert.deepEqual(writes, [['deleteSelected', '["1"]']]);
  const motionMethods = page.slice(page.indexOf('  private setOrganizerTabsMounted('), page.indexOf('  private organizerToolbarReady('));
  const ScrollSource = { DRAG: 0, FLING: 1, EDGE_EFFECT: 2, PROGRAMMATIC: 3 };
  const Motion = require('node:vm').runInNewContext(ts.transpileModule(`class Motion {${motionMethods}} Motion;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText,
    { ScrollSource, HdsAnimationMode: { SCROLL_ANIMATION: 'scroll' } });
  let phase = 'select';
  const animations = [], motion = new Motion();
  Object.assign(motion, { phase: () => phase, organizerTabsController: {
    applyHideAnimation: mode => animations.push(['hide', mode]), applyShowAnimation: mode => animations.push(['show', mode]) } });
  const scroll = (offset, source = ScrollSource.DRAG, atTop = false) => motion.updateOrganizerTabsScroll(offset, source, atTop);
  motion.setOrganizerTabsMounted(true);
  scroll(200, ScrollSource.FLING); scroll(30, ScrollSource.EDGE_EFFECT); scroll(30, ScrollSource.PROGRAMMATIC);
  scroll(12, ScrollSource.DRAG, true); scroll(-8); scroll(12);
  assert.deepEqual(animations, []);
  scroll(8); scroll(25); scroll(-50, ScrollSource.FLING);
  assert.deepEqual(animations, [['hide', 'scroll']]);
  motion.organizerDragId = '1'; scroll(-50); motion.organizerDragId = '';
  scroll(-10); scroll(-10);
  assert.deepEqual(animations, [['hide', 'scroll'], ['show', 'scroll']]);
  scroll(20); scroll(-30, ScrollSource.DRAG, true);
  motion.setOrganizerTabsHidden(false); // onReachStart, including inertia returning to the top
  assert.deepEqual(animations.slice(-2), [['hide', 'scroll'], ['show', 'scroll']]);
  phase = 'sectionSelect'; scroll(30); phase = 'select';
  motion.setOrganizerTabsMounted(false); scroll(30);
  assert.equal(animations.length, 4);
  assert.match(page, /\.onWillScroll\(\(_xOffset: number, yOffset: number, _state: ScrollState, source: ScrollSource\) => \{[\s\S]*?this\.updateOrganizerTabsScroll\(yOffset, source,/);
  assert.match(page, /\.onReachStart\(\(\) => \{[\s\S]*?this\.setOrganizerTabsHidden\(false\)/);
  assert.match(page, /divider: this\.selectingPins\(\) \? \{ showType: DividerShowType\.OFF \}/);
  const titleStart = page.indexOf('  private titleBarOptions()');
  const titleOptions = page.slice(titleStart, page.indexOf('      content: {', titleStart));
  assert.doesNotMatch(titleOptions, /dividerColor:/, 'use the official OFF option rather than hiding by color');
  assert.match(page, /const targets: boolean = this\.phase\(\) === 'targets';\s*const gradient: boolean = !targets && this\.immersiveLightMode !== 'off';/);
  assert.match(page, /enableComponentSafeArea: targets,/);
  assert.match(page, /private titleContentInset\(\): number \{ return this\.phase\(\) === 'targets' \? 0 : this\.getUIContext\(\)\.px2vp\(this\.statusBarHeightPx\) \+ 56;/);
  const organizerStart = page.indexOf('  private organizeContent(');
  const organizerBody = page.slice(organizerStart, page.indexOf('  private showSectionRefreshIndicator(', organizerStart));
  assert.match(organizerBody, /if \(this\.selectedIds\.length > 0 \|\| targetSheet \|\| this\.phase\(\) === 'targets'\) \{\s*Column\(\) \{\s*this\.selectedPreview\(\)\s*if \(targetSheet \|\| this\.phase\(\) === 'targets'\) \{\s*Divider\(\)[\s\S]*?\.zIndex\(1\)\s*\}\s*Scroll\(/);
  assert.match(page, /Scroll\(targetSheet \? this\.targetScroller : this\.contentScroll\(\)\)[\s\S]*?padding\(\{ left: 16, right: 16, top: \(targetSheet \? 0 : this\.titleContentInset\(\)\)/);
  assert.match(page, /enableScrollEffect: gradient, scrollEffectType: ScrollEffectType\.IMMERSIVE_GRADIENT_BLUR/);
  assert.match(page, /\.bindToScrollable\(\[this\.contentScroll\(\)\]\)/);
  assert.match(page, /\.friction\(!targetSheet && this\.phase\(\) === 'select' \? 0\.85 : -1\)/);
  assert.match(page, /\.edgeEffect\(!targetSheet && this\.phase\(\) === 'select' \? EdgeEffect\.Spring : EdgeEffect\.None\)/);
  const host = fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  assert.match(host,/openSection: \(\): void => this.openBoardSection\(\)/);
  assert.match(host,/onCreateOrganizerSection: \(\) => this.openBoardSection\(true\)/);
  console.log('Organizer toolbar, existing publish section flow, organizer cancellation, permissions and action contracts passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
