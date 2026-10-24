const { runtime } = require('./return-coordinator-harness.cjs');
function create(ts, globals = {}) {
  const r = runtime(ts, globals);
  const fs = require('node:fs');
  const copy = Object.fromEntries(JSON.parse(fs.readFileSync('common_foundation/src/main/resources/base/element/string.json', 'utf8')).string.map(row => [row.name, row.value]));
  r.foundation.PinmonyI18n = { message: key => copy[key] || key, render: value => value };
  return r.compile('feature_pin/src/main/ets/controllers/PinmonyPostPanelsController.ets', () => r.foundation);
}
function bind(native, ts, globals = {}) {
  const { PinmonyPostPanelsController } = create(ts, globals);
  native.postPanelsController = new PinmonyPostPanelsController(native.pinStore, {
    authenticated: () => native.authStatus === 'authenticated', foreground: () => !native.businessSuspended,
    document: () => native.controller.getUrl(), sheet: () => native.activeSheetKind,
    show: kind => { native.activeSheetKind = kind; native.showNativeSheet = !!kind; }, currentPin: () => native.currentPinUrl(),
    pinIdentity: pin => native.pinIdentity(pin), moreCurrent: pin => native.isCurrentMorePin(pin),
    runScript: script => native.controller.runJavaScript(script), jsonText: raw => native.webJsonText(raw), feedback: message => native.showMessage(message),
    saveDismissed() {}, editCompleted: async () => {}, prepareComment: async encoded => encoded
  });
}
module.exports = { create, bind };
