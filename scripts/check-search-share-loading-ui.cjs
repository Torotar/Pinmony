const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const page = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const root = fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets', 'utf8');
const share = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyShareSheet.ets', 'utf8');
assert(root.includes('submittedLinkLoading: view.searchStore.submittedPinLoading'), 'propagate real link request lifecycle');
assert(page.includes('@Prop submittedLinkLoading: boolean = false;'));
const status = page.slice(page.indexOf('private searchStatus()'), page.indexOf('private searchStatus()') + 700);
assert.match(status, /Column\(\{ space: 14 \}\) \{\s*if \(([^)]+)\) \{\s*Blank\(\)\s*\} else if/);
const condition = status.match(/if \(([^)]+)\)/)[1];
for (const busy of [true, false, true, false]) {
  assert.equal(vm.runInNewContext('(function(){ return ' + condition + '; }).call(state)', {
    state: { submittedLinkLoading: busy, loading: false, query: '', error: '' }
  }), busy, 'suppress background status only while resolving/opening a link');
}
const system = share.slice(share.indexOf("if (option.id === 'native-system-share') {"), share.indexOf('    } else {', share.indexOf('private buildShareActionRow')));
const board = share.slice(share.indexOf("Button(this.uiText(this.pinStore.shareBoardInviteBusy"));
for (const token of [".width('100%').height(48)", ".backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))", ".padding({ left: 20, right: 20, top: 12 }).flexShrink(0)"]) {
  assert(system.includes(token) && board.includes(token), 'system and board footer share geometry and theme: ' + token);
}
assert(system.includes('.enabled(option.enabled)'));
assert(system.includes('if (option.enabled) this.onAction(option.id)'));
assert(system.includes('.accessibilityText(this.actionLabel(option))'));
assert(share.includes("option.id !== 'native-system-share' &&"), 'plain action divider is omitted for system-only footer');
console.log('PASS search link background guard and system share footer style/state contracts');
