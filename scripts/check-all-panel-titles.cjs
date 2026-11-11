const fs = require('node:fs');
const cp = require('node:child_process');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const roots = ['entry', 'common_ui', 'feature_board', 'feature_profile', 'feature_search', 'feature_inbox', 'feature_pin', 'feature_settings'];
const read = p => fs.readFileSync(p, 'utf8');
const files = cp.execFileSync('rg', ['-l', '\\.bindSheet\\(', ...roots, '-g', '*.ets'], {encoding: 'utf8'}).trim().split(/\r?\n/);
function callAt(source, start) {
  let depth = 0, quote = '';
  for (let i = source.indexOf('(', start); i < source.length; i++) {
    const c = source[i];
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = ''; continue; }
    if ('\'"`'.includes(c)) { quote = c; continue; }
    if (c === '(') depth++;
    if (c === ')' && --depth === 0) return source.slice(start, i + 1);
  }
  throw Error('Unclosed call');
}
const expected = {
  'Index.ets': {boardRecoveryVisible: 'presentedBoardRecoverySheet', showNativeSheet: 'buildPresentedNativeSheet'},
  'PinmonyProfilePage.ets': {sortVisible: 'presentedBoardSortSheet', pinViewOpen: 'presentedPinViewSheet', aboutVisible: 'presentedAboutSheet'},
  'PinmonyBoardPage.ets': {viewOpen: 'presentedBoardViewSheet', privacyOpen: 'presentedPrivacySheet', menuOpen: 'presentedOptionsSheet', targetCreateSheetOpen: 'presentedTargetCreateForm', moveSheetOpen: 'presentedMoveSheet'},
  'PinmonyInboxFlowPage.ets': {showUpdatesMenu: 'presentedUpdatesMenu', showMessageMenu: 'presentedMessageMenu'},
  'PinmonyCommentsSheet.ets': {menuOpen: 'presentedCommentMenu'},
  'PinmonySearchPage.ets': {quizSheetOpen: 'presentedQuizSheet'},
  'PinmonyVisibilitySettingsPage.ets': {'store.confirmOpen': 'presentedPrivacySheet'},
  'PinmonyImageSearchView.ets': {sheetVisible: 'presentedResultsPanel'},
  'PinmonyPublishBoardPage.ets': {createVisible: 'createSheet'},
  'PinmonyBoardSectionPage.ets': {visible: 'sectionSheet'}
};
let count = 0;
const seen = new Set();
for (const file of files) {
  const source = read(file), name = file.split(/[\\/]/).pop();
  assert(expected[name], 'Unreviewed sheet file: ' + file);
  for (const match of source.matchAll(/\.bindSheet\(/g)) {
    const call = callAt(source, match.index), state = /^\.bindSheet\(\$\$this\.([\w.]+)/.exec(call)?.[1];
    const builder = expected[name][state];
    assert(builder, 'Unreviewed sheet: ' + file + ':' + state);
    assert(call.includes('this.' + builder), name + ':' + state + ' content owner');
    if (name === 'PinmonyPublishBoardPage.ets' || name === 'PinmonyBoardSectionPage.ets') {
      assert(source.includes('HdsNavigationTitleMode.MODAL'));
    } else if (state === 'showNativeSheet') {
      assert(call.includes('!this.nativeSheetHasHdsTitle()'));
    } else {
      assert(call.endsWith('this.sheetMaterialMode, false))'), name + ':' + state + ' no whole-sheet material');
      assert(/showClose\s*:\s*false/.test(call));
      assert(!/\btitle\s*:/.test(call), name + ':' + state + ' no duplicate native header');
      assert(source.includes('private ' + builder + '()'));
    }
    seen.add(name + ':' + state); count++;
  }
}
assert.equal(count, 19, 'Every sheet mounting point is audited');
assert.equal(seen.size, 18, 'Two profile layout hosts intentionally share one sheet');
// Execute the actual HDS title option expressions and their close callbacks.
const cases = [
  ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets', ['presentedBoardSortSheet', 'presentedPinViewSheet', 'presentedAboutSheet']],
  ['feature_board/src/main/ets/components/PinmonyBoardPage.ets', ['presentedBoardViewSheet', 'presentedPrivacySheet', 'presentedOptionsSheet', 'presentedTargetCreateForm', 'presentedMoveSheet']],
  ['feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', ['presentedUpdatesMenu', 'presentedMessageMenu']],
  ['feature_search/src/main/ets/components/PinmonySearchPage.ets', ['presentedQuizSheet']],
  ['feature_settings/src/main/ets/components/PinmonyVisibilitySettingsPage.ets', ['presentedPrivacySheet']],
  ['feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets', ['presentedCommentMenu']],
  ['common_ui/src/main/ets/components/PinmonyImageSearchView.ets', ['presentedResultsPanel']],
  ['entry/src/main/ets/pages/Index.ets', ['presentedBoardRecoverySheet']]
];
for (const [file, builders] of cases) for (const builder of builders) {
  const source = read(file), at = source.indexOf('private ' + builder + '()');
  const start = source.indexOf('PinmonyModalNavigation(', at);
  assert(at >= 0 && start >= 0);
  const args = callAt(source, start).slice('PinmonyModalNavigation('.length, -1);
  const Options = vm.runInNewContext(ts.transpileModule('function options(){return ' + args + ';} options;', {}).outputText);
  for (const busy of [false, true]) for (const uncertain of [false, true]) for (const lang of ['zh', 'en']) {
    let closes = 0;
    const host = {snapshot: {privacy: 'secret', flow: {busy, uncertain}}, store: {busy, pendingPrivate: true, confirmOpen: true}, settingsStore: {busy}, profile: {displayName: 'name'},
      creatingBoardTarget: false, creatingTarget: false, mergeOpen: false, messageMenuKind: 'message', snapshotQuizMode: '',
      uiText: key => key + ':' + lang, phase: () => 'section', closePinView: () => closes++, closeTargetCreate: () => closes++, requestMoveClose: () => closes++, closeMessageMenu: () => closes++, requestQuizClose: () => closes++,
      alive: true, presentationActive: true, relatedOpening: false, closing: false, closeRequested: false, onClose: () => closes++, viewOpen: true, viewPage: 'board', viewScope: 'section'};
    // Dynamic titles may read the current quiz snapshot or title helper.
    host.snapshot.quiz = {mode: 'picker'};host.activeSheetTitle = () => 'title:' + lang;
    const opts = Options.call(host);
    assert.equal(typeof opts.titleText, 'string', file + ':' + builder);
    assert.equal(typeof opts.closeEnabled, 'boolean');
    opts.onClose();
    if (builder === 'presentedBoardViewSheet') {
      assert.equal(opts.titleText, 'pm_board_view_title:' + lang);
      assert.equal(opts.fillContent, false, 'view panel retains intrinsic height');
      assert.equal(host.viewOpen, false);
      assert.equal(host.viewPage, 'board', 'view identity remains during exit');
      assert.equal(host.viewScope, 'section', 'section scope remains during exit');
    }
    if (builder === 'presentedPrivacySheet') {
      assert.equal(opts.closeEnabled, !busy);
      assert.equal(file.includes('Visibility') ? host.store.confirmOpen : host.privacyOpen, busy ? (file.includes('Visibility') ? true : undefined) : false);
    }
    if (builder === 'presentedTargetCreateForm' || builder === 'presentedMoveSheet') assert.equal(opts.closeEnabled, !busy && !uncertain);
    if (builder === 'presentedResultsPanel') { opts.onClose(); assert.equal(closes, 1, 'visual search close is dispatched once'); }
  }
}
const board = read('feature_board/src/main/ets/components/PinmonyBoardPage.ets');
assert.equal((board.match(/this\.boardViewButton\(\)/g) || []).length, 2, 'board and section entries share the upgraded panel');
const viewTrigger = board.slice(board.indexOf('private boardViewButton()'), board.indexOf('private boardActionEnabled('));
assert(!viewTrigger.includes('.systemMaterial('), 'view trigger button remains unchanged');
assert(viewTrigger.includes('onDisappear: () => { this.closeBoardView(); }'), 'view cleanup still waits for native disappearance');
assert(board.indexOf('private presentedPrivacySheet()') > board.indexOf('struct PinmonyBoardSurface'), 'builders belong to the actual Sheet-owning component');
const comments = read('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets');
assert(/if \(this.deleteOpen\) \{ this.commentMenu\(\) \} else/.test(comments), 'delete confirmation retains no title or close button');
const index = read('entry/src/main/ets/pages/Index.ets');
assert(index.includes("this.activeSheetKind === 'profileMenu' ? this.uiText('pm_profile_options_344df243')"));
const edit = read('feature_pin/src/main/ets/components/PinmonyEditPinSheet.ets');
assert(edit.includes("onClose: () => { if (!this.result.busy && !this.result.picker.busy) this.act('editPhase', ',\"edit\"'); }"), 'edit board picker returns one level with busy guards');
console.log('All panel titles: 19 mounts, 18 host identities, HDS ownership, board/section view panel, retained exit identity, dynamic title options, close guards, localized titles and nested edit return passed');
