const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySocialPermissionsPage.ets', 'utf8');
const methods = source.slice(source.indexOf('  private dismissErrorSnack('), source.indexOf('  private uiText('));
const shown = [], requests = []; let dismissed = 0, backs = 0;
const Page = vm.runInNewContext(ts.transpileModule('class Page {' + methods + '} Page;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, {
  HdsSnackBar: class { show(icon, message, operation, style) { shown.push({ icon, message, operation, style }); } dismiss() { dismissed++; } },
  $r: name => name, SnackBarIconType: { NORMAL: 1 }, SnackBarOperationType: { TEXT_ONLY: 0 },
  PinmonyI18n: { render: (message, language) => language + ':' + message, isUnconfirmed: () => false }
});
const page = new Page(); page.visible = true; page.uiLanguage = 'zh'; page.uiText = key => key;
page.getUIContext = () => ({}); page.onRequest = (...args) => requests.push(args); page.onBack = () => backs++;
page.store = { screen: 'socialComments', token: 1, error: 'unknown save', writeUncertain: true, busy: false, loading: false };
page.syncErrorSnack(); assert.equal(shown.length, 1); const first = shown[0];
assert.equal(first.operation.content, 'pm_reload_df7392cc'); page.syncErrorSnack(); assert.equal(shown.length, 1);
first.operation.onContentClick(); assert.equal(requests.length, 1); assert.equal(requests[0][0], 'socialRead');
assert.equal(page.store.writeUncertain, true, 'reading must not unlock unknown writes');
page.store.token++; page.syncErrorSnack(); first.operation.onContentClick(); first.style.pressBackCallback();
assert.equal(requests.length, 1); assert.equal(backs, 0, 'stale callback cannot navigate');
page.uiLanguage = 'en'; page.syncErrorSnack(); assert.equal(shown.at(-1).message.title, 'en:unknown save');
page.store.busy = true; page.syncErrorSnack(); assert.equal(page.errorSnackKey, '');
page.store.busy = false; page.store.screen = 'socialBlocked'; page.store.token++; page.syncErrorSnack();
shown.at(-1).operation.onContentClick(); assert.equal(requests.at(-1)[0], 'socialBlocked');
page.syncErrorSnack(); page.visible = false; const latest = shown.at(-1); page.syncErrorSnack(); latest.operation.onContentClick();
assert.equal(requests.length, 2); assert(dismissed > 0);
assert(!source.includes('if (this.store.error) { Text('), 'inline duplicate error and retry are removed');
assert(source.includes("@Watch('syncErrorSnack') store"));
console.log('Official social settings snackbar: read-only retry, uncertain write lock, stale callbacks, language, busy and leave cleanup passed');
