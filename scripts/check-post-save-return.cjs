const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = readSourceFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const method = source.match(/  private async handleBack\(\): Promise<void> \{[\s\S]*?(?=\n  private reload\()/)[0];
const code = ts.transpileModule('class Native { ' + method + ' } globalThis.Native = Native;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const context = { Date, console }; require('./product-coordination-harness.cjs').run(ts,code, context);
function harness() {
  const value = require('./product-coordination-harness.cjs').createHost(context.Native, ts); let details = 0, sheets = 0, exits = 0;
  Object.assign(value, {
    showNativeSheet: false, activeSheetKind: '',
    backInProgress: false, lastRootBackAt: Date.now(), currentPinUrl: () => '',
    returnFromSearchQuiz: () => false,
    pageHistory: { isPending: () => false }, backOnePage: () => false,
    controller: { runJavaScript: async () => 'false' },
    backFromDetail: () => { details++; }, onBackPress: () => { sheets++; },
    getUIContext: () => ({ getHostContext: () => ({ terminateSelf: () => { exits++; } }) }),
    pinStore: Object.assign(value.pinStore, {
        shareBackHandledUntil: 0
    }),
    homeStore: Object.assign(value.homeStore, {
        pendingHomeMorePin: ''
    })
});
  return { value, details: () => details, sheets: () => sheets, exits: () => exits };
}
(async () => {
  const root = harness(); await root.value.handleBack(); await root.value.handleBack();
  assert.equal(root.exits(), 0, 'Repeated root delivery cannot terminate the application');
  const pin = harness(); pin.value.pinStore.detail = { pinUrl: 'https://www.pinterest.com/pin/123/' };
  await pin.value.handleBack(); assert.equal(pin.details(), 1); assert.equal(pin.exits(), 0);
  const sheet = harness(); sheet.value.activeSheetKind = 'save';
  await sheet.value.handleBack(); assert.equal(sheet.sheets(), 1);
  const late = harness(); late.value.controller.runJavaScript = async () => {
    late.value.activeSheetKind = 'share'; return 'false';
  };
  await late.value.handleBack(); assert.equal(late.exits(), 0); assert.equal(late.value.lastRootBackAt, 0);
  console.log('Post-save return: repeated root events, Pin, sheet and late state guards passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
