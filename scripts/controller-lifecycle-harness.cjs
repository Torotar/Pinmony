const fs = require('node:fs'), vm = require('node:vm');
function bind(native, ts) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyControllerLifecycle.ets', 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
  { exports, require: () => ({ PinmonyRuntimeLog: { warn() {} } }) });
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  exports.assembleControllerLifecycle = require('./product-coordination-harness.cjs').runtime(ts).loadFile('entry/src/main/ets/app/PinmonyControllerAssembly.ets').assembleControllerLifecycle;
  const start = source.indexOf('  private controllerLifecycle():');
  const end = source.indexOf('\n  private markRootPerformance', start);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} Host;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, exports);
  native.controllerLifecycle = Host.prototype.controllerLifecycle;
  native.homeStore ||= {};
  require('./product-coordination-harness.cjs').bind(native, ts, {}, ['NativeBoardReads', 'NativeProfileReads', 'NativeHomeReads', 'NativeSearchDiscovery', 'NativeSearchReads', 'NativeInboxUpdates', 'NativeInboxMessages']);
  native.photoMenuCoordinator ||= { pause() {}, notify() {} };
  native.rootContextCoordinator ||= { pause() {}, notify() {} };
  native.boardOperationsController ||= { pause() {} };
  native.settingsController ||= { pause() {} };
  native.inboxActionsController ||= { pause() {} };
  if (!native.coordinatorTasks) {
    const tasks = require('./arkts-module-loader.cjs').createArktsLoader(ts).loadFile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets');
    native.coordinatorTasks = new tasks.PinmonyTaskRegistry();
  }
  native.inboxReadController ||= { pause() {}, resume() {} };
  native.pagePerformance ||= { begin() {}, mark() {}, count() {}, cancel() {} };
  native.pagePerformance.beginSecondary ||= () => {};
  native.pagePerformance.markSecondary ||= () => {};
  native.markRootPerformance ||= () => {};
}
module.exports = { bind };
