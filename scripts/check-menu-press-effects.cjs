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
function noPress(source, label, minimum) {
  const buttons = Array.from(source.matchAll(/\bButton\(\{[^}]*\}\)/g));
  assert(buttons.length >= minimum, label + ': expected option buttons');
  assert.equal(buttons.length, (source.match(/\bButton\s*\(/g) || []).length,
    label + ': every button constructor is checked');
  for (let i = 0; i < buttons.length; i++) {
    const button = buttons[i], tail = source.slice(button.index, buttons[i + 1]?.index ?? source.length);
    assert(/stateEffect\s*:\s*false/.test(button[0]) || /\.stateEffect\(false\)/.test(tail),
      label + ': option ' + (i + 1) + ' must disable press feedback');
  }
}
noPress(read(root + 'PinmonyAccountPage.ets'), 'account rows and country choices', 2);
noPress(read(root + 'PinmonySettingsPage.ets'), 'settings root rows and profile entry', 2);
noPress(read('feature_home/src/main/ets/components/PinmonyHomeMenuSheet.ets'), 'photo card menu', 2);
noPress(read('feature_pin/src/main/ets/components/PinmonyMoreSheet.ets'), 'detail more menu', 1);
const profile = read('feature_profile/src/main/ets/components/PinmonyProfilePage.ets');
noPress(method(profile, 'boardSortOption'), 'profile board sorting', 1);
noPress(method(profile, 'pinViewOption'), 'profile card layout choices', 1);
const chat = read('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets');
noPress(method(chat, 'reactionChoices'), 'chat reaction popup', 1);
noPress(method(chat, 'messageMenuContent'), 'chat reaction and message actions', 5);
noPress(method(chat, 'messageSideActions'), 'chat reaction entry', 1);
noPress(method(chat, 'updatesMenuContent'), 'inbox update menu', 3);
console.log('Menu press effects: account/country, settings, profile choices, photo/detail menus, chat feedback and inbox updates passed');
