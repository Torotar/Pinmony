const fs = require('node:fs'), vm = require('node:vm');
function loadSnackBarLifecycle(ts, log) {
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync('common_ui/src/main/ets/services/PinmonySnackBarLifecycle.ets', 'utf8'),
    { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
  vm.runInNewContext(code, { exports, Promise, BlurStyle: { COMPONENT_ULTRA_THICK: 6 },
    require: name => name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {}, ...log } } :
      name === '@kit.UIDesignKit' ? { BlurStrategy: { ENABLE: 1 } } : {} });
  return exports.PinmonySnackBarLifecycle;
}
module.exports = { loadSnackBarLifecycle };
