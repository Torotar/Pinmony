const fs = require('node:fs'), vm = require('node:vm');
function runtime(ts, globals = {}) {
  const base = { setTimeout, clearTimeout, setInterval, clearInterval, ...globals };
  function compile(file, deps) {
    const exports = {};
    vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
      compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
    }).outputText, { ...base, exports, require: deps });
    return exports;
  }
  const foundation = compile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets', () => ({}));
  const { PinmonyReturnCoordinator } = compile('entry/src/main/ets/app/PinmonyReturnCoordinator.ets', () => foundation);
  return { PinmonyReturnCoordinator, foundation, compile };
}
function bind(native, ts, globals = {}) {
  native.boardStore ||= {};
  const { PinmonyReturnCoordinator } = runtime(ts, globals);
  native.returnCoordinator = new PinmonyReturnCoordinator({
    isCurrent: token => !native.businessSuspended && token === native.pageBackToken,
    isPending: target => !!native.nativeBackTarget && native.pageHistory.key(native.nativeBackTarget) === native.pageHistory.key(target),
    isHome: target => native.isHomeRootAddress(target),
    isBoard: target => !!native.boardUrlFromAddress(target),
    documentMatches: target => native.pageHistory.key(native.controller.getUrl()) === native.pageHistory.key(target),
    runScript: script => native.controller.runJavaScript(script),
    useHistory: target => native.returnToHistoryEntry(target),
    load: (target, token) => native.loadReturnTarget(target, token),
    confirm: (target, bindDetail) => {
      native.recordPageNavigation(target, 'observe');
      if (bindDetail) native.bindCurrentDetailDocument(target);
      native.syncAuthentication();
    }, cancelHistory: () => native.pageHistory.cancelBack(),
    mark: event => native.detailReturnJourney?.mark(event)
  });
}
module.exports = { runtime, bind };
