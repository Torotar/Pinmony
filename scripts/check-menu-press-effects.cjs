const fs = require('node:fs');
const assert = require('node:assert/strict');
const root = 'feature_settings/src/main/ets/components/';
function read(file) { return fs.readFileSync(file, 'utf8'); }
function method(source, name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name + ': method exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n  (?:private |@Builder|aboutTo|build\()/);
  assert(next >= 0, name + ': method boundary exists');
  return source.slice(start, start + 1 + next);
}
function nativePress(source, label, minimum, enabled = true) {
  const buttons = Array.from(source.matchAll(/\bButton\(\{[^}]*\}\)/g));
  assert(buttons.length >= minimum, label + ': expected option buttons');
  assert.equal(buttons.length, (source.match(/\bButton\s*\(/g) || []).length,
    label + ': every button constructor is checked');
  for (let i = 0; i < buttons.length; i++) {
    const button = buttons[i], tail = source.slice(button.index, buttons[i + 1]?.index ?? source.length);
    assert(new RegExp('stateEffect\\s*:\\s*' + enabled).test(button[0]) || new RegExp('\\.stateEffect\\(' + enabled + '\\)').test(tail),
      label + ': option ' + (i + 1) + ' native press feedback must be ' + enabled);
  }
}
nativePress(read(root + 'PinmonyAccountPage.ets'), 'account rows and country choices', 2);
nativePress(read(root + 'PinmonySettingsPage.ets'), 'settings root rows and profile entry', 2);
nativePress(read('feature_home/src/main/ets/components/PinmonyHomeMenuSheet.ets'), 'photo card menu', 2, false);
nativePress(read('feature_pin/src/main/ets/components/PinmonyMoreSheet.ets'), 'detail more menu', 1, false);
const detail = read('feature_pin/src/main/ets/components/PinmonyDetailPage.ets');
const expansion = detail.slice(detail.indexOf('Button(this.expanded ?'), detail.indexOf('}.width(\'100%\')', detail.indexOf('Button(this.expanded ?')));
assert(expansion.includes('.stateEffect(false)') && expansion.includes('.onClick(() => this.expanded = !this.expanded)'), 'description more/less keeps expansion without press overlay');
const commentsLabel = detail.indexOf('pm_view_all_comments_11ef17e2');
const commentsEntry = detail.slice(detail.lastIndexOf('Button(', commentsLabel), detail.indexOf('if (this.displayedDetail().sourceLabel', commentsLabel));
assert(commentsEntry.includes('.stateEffect(false)') && commentsEntry.includes('this.onComments()') && commentsEntry.includes('.enabled('), 'all-comments retains handler and readiness gate without press overlay');
const comments = read('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets');
const translationLabel = comments.indexOf('pm_translating_07f81963');
const translation = comments.slice(comments.lastIndexOf('Button(', translationLabel), comments.indexOf('if (item.canReply)', translationLabel));
assert(translation.includes('.stateEffect(false)') && translation.includes('this.onTranslate(item.id)') && translation.includes('.enabled(') && translation.includes('.accessibilityText('), 'translate/original/retry share no-press button and retain guards/accessibility');
const profile = read('feature_profile/src/main/ets/components/PinmonyProfilePage.ets');
nativePress(method(profile, 'boardSortOption'), 'profile board sorting', 1);
nativePress(method(profile, 'pinViewOption'), 'profile card layout choices', 1);
const chat = read('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets');
nativePress(method(chat, 'reactionChoices'), 'chat reaction popup', 1);
nativePress(method(chat, 'messageMenuContent'), 'chat reaction and message actions', 5);
nativePress(method(chat, 'messageSideActions'), 'chat reaction entry', 1);
nativePress(method(chat, 'updatesMenuContent'), 'inbox update menu', 3);
console.log('Menu press effects: account/country, settings, profile choices, photo/detail menus, chat feedback and inbox updates passed');

// Ordinary native feedback remains enabled except explicit product exceptions.
const path = require('node:path');
let scannedFiles = 0, nativeButtons = 0;
function auditButtons(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) auditButtons(file);
    else if (file.endsWith('.ets')) {
      const source = read(file); scannedFiles++;
      nativeButtons += (source.match(/\bButton\s*\(/g) || []).length;
      const blurOnlyControl = ['common_ui/src/main/ets/components/PinmonyBackToTopButton.ets', 'common_ui/src/main/ets/components/PinmonyDraggablePublishButton.ets', 'feature_profile/src/main/ets/components/PinmonyPublishPage.ets', 'feature_board/src/main/ets/components/PinmonyBoardPage.ets'].includes(file.split(path.sep).join('/'));
      if (blurOnlyControl) assert(!source.includes('PinmonyButtonInteractionModifier'), file + ': preserve original glass without the visually regressed material');
      const disabled = source.match(/stateEffect\s*:\s*false|\.stateEffect\(false\)/g) || [];
      const pinExceptions = {
        'feature_home/src/main/ets/components/PinmonyHomeMenuSheet.ets': 2,
        'feature_pin/src/main/ets/components/PinmonyMoreSheet.ets': 1,
        'feature_pin/src/main/ets/components/PinmonyDetailPage.ets': 2,
        'feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets': 1
      };
      assert.equal(disabled.length, blurOnlyControl ? 1 : pinExceptions[file.split(path.sep).join('/')] || 0, file + ': only explicit Pin text/menu and original glass exceptions disable the ordinary press overlay');
    }
  }
}
for (const name of fs.readdirSync('.')) {
  if (/^(?:common_|feature_)/.test(name) || name === 'entry') auditButtons(path.join(name, 'src/main/ets'));
}
assert(scannedFiles >= 350 && nativeButtons >= 150, 'audit covers app-wide native buttons');
console.log('Native press audit: ' + scannedFiles + ' source files, ' + nativeButtons + ' Button controls; six Pin menu/text buttons and four original glass controls have explicit exceptions');
