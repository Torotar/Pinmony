const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const read = path => fs.readFileSync(path, 'utf8');
const board = read('feature_board/src/main/ets/components/PinmonyBoardPage.ets');
const detail = read('feature_pin/src/main/ets/components/PinmonyDetailPage.ets');
const inbox = read('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets');
const publish = read('feature_profile/src/main/ets/components/PinmonyPublishPhotoEditor.ets');
const profile = read('feature_profile/src/main/ets/components/PinmonyProfilePage.ets');
const collaborators = read('feature_board/src/main/ets/components/PinmonyBoardCollaboratorsPage.ets');
const invitations = read('feature_inbox/src/main/ets/components/PinmonyBoardInvitationList.ets');
function block(source, from, to) {
  const start = source.indexOf(from), end = source.indexOf(to, start + from.length);
  assert(start >= 0 && end > start, from); return source.slice(start, end);
}
function hostFor(source, names) {
  const ast = ts.createSourceFile('page.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast); assert.equal(methods.length, names.length);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { FontWeight: { Medium: 'medium', Bold: 'bold' }, WordBreak: { BREAK_WORD: 'word' },
    PinmonyI18n: { message: key => key, render: key => labels.get(key) || key } });
  const host = new Host();
  host.uiText = host.text = key => labels.get(key) || key;
  host.getUIContext = () => ({ px2vp: px => px / 2, getMeasureUtils: () => ({
    measureTextSize: o => ({ width: Math.min(widthOf(o.textContent, o.fontSize), o.constraintWidth || Infinity) * 2,
      height: o.fontSize * scale * 1.3 * Math.max(1, Math.ceil(widthOf(o.textContent, o.fontSize) / (o.constraintWidth || Infinity))) * 2 })
  }) });
  return host;
}
let labels = new Map(), scale = 1;
const widthOf = (text, size) => Array.from(text).reduce((sum, c) => sum + (/[^\x00-\xff]/.test(c) ? size : size * 0.7), 0) * scale;
const bh = hostFor(board, ['boardActionBarHeight', 'boardActionEnabled', 'modernBoardActions']);
const dh = hostFor(detail, ['imageSearchLabelSize']);
const ih = hostFor(inbox, ['segmentBarMinWidth', 'segmentBarHeight', 'inboxTopInset']);
const ph = hostFor(publish, ['productTabBarHeight']);
bh.contentWidth = 360; bh.boardActionBarWidth = 0;
let phase = '', discovery = false;
bh.phase = () => phase; bh.isDiscoveryBoard = () => discovery;
const readyBoard = () => ({ ready: true, editable: true, pins: [{}], flow: { pins: [{}] } });
bh.legacyProfile = false;
for (phase of ['', 'section']) {
  bh.snapshot = readyBoard();
  assert.equal(bh.modernBoardActions(), true);
  for (const index of [0, 1, 2]) assert.equal(bh.boardActionEnabled(index), true);
  (phase ? bh.snapshot.flow : bh.snapshot).pins = [];
  assert.equal(bh.boardActionEnabled(0), false, 'empty current scope disables organize');
  for (const index of [1, 2]) assert.equal(bh.boardActionEnabled(index), true);
  for (const flag of ['loading', 'refreshing', 'notReady', 'flow.loading', 'flow.busy', 'flow.uncertain']) {
    bh.snapshot = readyBoard();
    if (flag === 'notReady') bh.snapshot.ready = false;
    else if (flag.startsWith('flow.')) bh.snapshot.flow[flag.slice(5)] = true;
    else bh.snapshot[flag] = true;
    for (const index of [0, 1, 2]) assert.equal(bh.boardActionEnabled(index), false, flag);
  }
}
bh.snapshot = readyBoard(); phase = 'select';
assert.equal(bh.modernBoardActions(), false);
phase = ''; bh.snapshot.editable = false;
assert.equal(bh.modernBoardActions(), false);
bh.snapshot = readyBoard(); bh.legacyProfile = true;
assert.equal(bh.modernBoardActions(), false);
bh.legacyProfile = false; discovery = true;
assert.equal(bh.modernBoardActions(), false);
discovery = false;
ih.snapshot = {}; ih.statusBarHeightPx = 80;
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  labels = new Map(JSON.parse(read(`common_foundation/src/main/resources/${locale}/element/string.json`)).string.map(r => [r.name, r.value]));
  for (scale of [1, 1.5, 2, 3]) {
    for (const viewport of [240, 320, 360, 600, 1000]) {
      for (const inset of [0, 48]) {
        bh.contentWidth = viewport; bh.boardActionBarWidth = viewport - inset;
        const labelWidth = bh.boardActionBarWidth / 3 - 24;
        const maxHeight = Math.max(...['pm_organize_ff093473', 'pm_publish_b61f333b', 'pm_more_ideas_8f569818'].map(key =>
          Math.max(1, Math.ceil(widthOf(labels.get(key), 11) / labelWidth)) * 11 * scale * 1.3));
        assert(bh.boardActionBarHeight() >= maxHeight + 34, 'every fixed-width action has room for its full wrapped label');
      }
    }
    for (const viewport of [240, 320, 600, 1000]) {
      dh.detailMediaWidth = () => viewport;
      const size = dh.imageSearchLabelSize(), natural = widthOf(labels.get('pm_search_image_8f938fb8'), 14);
      assert(size.width + 44 <= viewport - 16, 'image search stays inside photo margins');
      assert(size.height >= 14 * scale * 1.3 * Math.max(1, Math.ceil(natural / size.width)), 'expanded label has room for every wrapped line');
    }
    assert(ph.productTabBarHeight() >= 17 * scale * 1.3 + 32);
    for (const unread of [false, true]) {
      ih.updatesUnread = unread; ih.messagesUnread = false;
      const longest = Math.max(...['pm_updates_3055a035', 'pm_inbox_63a5e7b7'].map(k => widthOf(labels.get(k), 16)));
      assert((ih.segmentBarMinWidth() - 8) / 2 >= longest + 32 + (unread ? 72 : 0));
      assert(ih.segmentBarHeight() >= 16 * scale * 1.3 + 24);
      assert.equal(ih.inboxTopInset(), 40 + ih.segmentBarHeight() + 8);
    }
  }
}
// Exercise supplied labels too: API snapshots may carry longer text than app resources.
ih.snapshot = { updateLabel: 'Long update label '.repeat(12), inboxLabel: 'Long inbox label '.repeat(15) };
assert(ih.segmentBarMinWidth() > 448, 'wide labels must expand beyond the old cap');
const tabs = block(board, 'private boardActionTab(', 'private actionTile(');
assert(!/Ellipsis|maxLines|\.height\(14\)/.test(tabs));
assert(tabs.includes('barMode(BarMode.Fixed)') && !tabs.includes('barMode(BarMode.Scrollable)'));
assert(tabs.includes("}.width('100%').height(this.boardActionBarHeight())") && !board.includes('boardActionTabWidth('));
assert(tabs.includes('.wordBreak(WordBreak.BREAK_WORD).flexShrink(0)') && tabs.includes('.onSizeChange('));
assert(tabs.includes('Number(newSize.width) * 3'), 'measure the actual floating bar, not just the screen width');
assert(tabs.includes('.scrollable(false)') && tabs.includes('.onContentWillChange((): boolean => false)'));
for (const token of ["this.phase() === 'section' ? 'sectionOrganize' : 'select'", 'this.onPublish()', "this.phase() === 'section' ? 'sectionIdeas' : 'ideas'", 'barBottomMargin:28', 'PinmonyImmersiveLight.effect(this.immersiveLightMode)']) assert(tabs.includes(token));
assert(board.includes('132 + this.boardActionBarHeight() - 56'), 'body compensates growing bottom actions');
const imageSearch = block(detail, 'Text(this.uiText("pm_search_image_8f938fb8"))', '.accessibilityText(this.uiText("pm_find_related');
assert(!imageSearch.includes('? 64 :') && !imageSearch.includes('? 108 :'));
assert(!imageSearch.includes('maxLines('), 'narrow photo permits label wrapping');
assert(imageSearch.includes('this.imageSearchLabelSize().width + 44'));
const toolbar = block(profile, 'private contentToolbar()', 'private emptyKind()');
assert(!/Ellipsis|maxLines/.test(toolbar));
assert(toolbar.includes('constraintSize({ minHeight: 48 })') && !toolbar.includes('layoutWeight(1).height(48)'));
const userRow = block(collaborators, 'private userRow(', 'private destination(');
assert(!userRow.includes('.width(88).height(40)'));
assert(userRow.includes("maxWidth: '50%', minHeight: 40"));
const invitationActions = block(invitations, 'Row({ space: 6 })', 'Text(this.invitationTime(item))');
assert(!/maxWidth|maxLines/.test(invitationActions));
for (const token of ['this.onDecline(item)', 'this.onAccept(item)', "item.status === 'new'", '!this.snapshot.uncertain']) assert(invitationActions.includes(token));
const targetActions = block(board, "if ((targetSheet || this.phase() === 'targets')", 'private showSectionRefreshIndicator()');
assert(targetActions.includes('Row({ space: 12 })') && !targetActions.includes('height(52)'));
assert.equal((targetActions.match(/layoutWeight\(1\)\.constraintSize\(\{ minHeight: 52 \}\)/g) || []).length, 2, 'both original side-by-side actions grow vertically');
for (const token of ['this.beginTargetCreate(true)', 'this.beginTargetCreate(false)', '!this.snapshot.flow?.uncertain']) assert(targetActions.includes(token));
const productTabs = block(publish, 'private tagTabs()', 'private productSearchPage()');
assert(productTabs.includes('barMode(BarMode.Scrollable)') && !productTabs.includes('barMode(BarMode.Fixed)'));
assert(!/titleContentInset\(\) \+ (56|72)/.test(productTabs));
const segments = block(inbox, 'private inboxSegments()', 'private suppressContentLoading()');
assert(segments.includes('ScrollDirection.Horizontal') && segments.includes('minWidth: this.segmentBarMinWidth()'));
assert.equal((segments.match(/itemMinHeight:/g) || []).length, 2, 'API24 and API26 use the same height');
assert(segments.includes('backgroundSystemMaterial:') && segments.includes('this.selectSection('));
assert(inbox.includes('.bindToScrollable([this.updatesScroller, this.scroller])'), 'stable actual content scrollers preserved');
console.log('Full button labels: 9 locales x 4 simulated font scales; measured dimensions, expanded scroll areas, wrapping controls, body insets, both API branches and action gates passed. Device rendering remains unverified.');
