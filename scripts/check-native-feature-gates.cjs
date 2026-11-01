const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const modules = ['PinmonyHomeNativeReads', 'PinmonySearchNativeReads', 'PinmonySearchDiscoveryNativeReads',
  'PinmonyDetailNativeReads', 'PinmonyDetailNativeAuxiliary', 'PinmonyBoardNativeReads',
  'PinmonyProfileNativeReads', 'PinmonyProfileSettingsClient', 'PinmonyInboxMessagesNativeReads',
  'PinmonyInboxUpdatesNativeReads', 'PinmonyPostNativeOperations', 'PinmonyPinMenuNative',
  'PinmonyCommentNativeWrites', 'PinmonySharePublishClient'];
function declarations(name) {
  const source = fs.readFileSync('entry/src/main/ets/app/' + name + '.ets', 'utf8');
  const local = source.match(/const (PIN_NATIVE_\w+_ROLLOUT_ENABLED): boolean = true;/);
  const effective = source.match(/export const (PIN_NATIVE_\w+_ENABLED): boolean = ([^;]+);/);
  assert(local && effective, name + ': explicit local and effective gates must exist');
  assert(effective[2].includes('PIN_BUSINESS_PIN_READ_ENABLED && ' + local[1]), name + ': local gate cannot bypass transport safety');
  return { local: local[1], effective: effective[1], source: local[0] + '\n' + effective[0] };
}
const definitions = modules.map(declarations);
function evaluate(disabledLocal, master = true, prerequisite) {
  const code = definitions.map(item => item.local === disabledLocal ?
    item.source.replace(': boolean = true;', ': boolean = false;') : item.source).join('\n');
  const exports = {}, context = { exports, PIN_BUSINESS_PIN_READ_ENABLED: master,
    PIN_POST_API_ENABLED: true, PIN_POST_EXTENSIONS_ENABLED: true };
  if (prerequisite) context[prerequisite] = false;
  vm.runInNewContext(ts.transpileModule(code, {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText, context);
  return exports;
}
const defaults = evaluate();
for (const item of definitions) assert.equal(defaults[item.effective], true, item.effective + ': preserve current default');
for (const disabled of definitions) {
  const values = evaluate(disabled.local);
  for (const item of definitions) assert.equal(values[item.effective], item !== disabled,
    item.effective + ': changing one local setting must not change another setting');
}
const stopped = evaluate(undefined, false);
for (const item of definitions) assert.equal(stopped[item.effective], false, 'master gate must disable every native feature');
const postDisabled = evaluate(undefined, true, 'PIN_POST_API_ENABLED');
assert.equal(postDisabled.PIN_NATIVE_POST_OPERATIONS_ENABLED, false);
assert.equal(postDisabled.PIN_NATIVE_PIN_MENUS_ENABLED, false);
assert.equal(postDisabled.PIN_NATIVE_HOME_READS_ENABLED, true);
assert.equal(evaluate(undefined, true, 'PIN_POST_EXTENSIONS_ENABLED').PIN_NATIVE_COMMENT_WRITES_ENABLED, false);
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function modeField(name) {
  const match = index.match(new RegExp('private readonly ' + name + ': boolean = [^;]+;'));
  assert(match, name + ': initialized runtime field is required');
  return match[0];
}
const installer = index.match(/install: \(script: string\): void => \{ ([^\n]+) \},/);
assert(installer, 'actual background script installer must be covered');
const modeCode = ts.transpileModule('class Host {' +
  modeField('nativeBusinessRoutesEnabled') + modeField('nativeLoginEnabled') +
  ' install(script: string): void {' + installer[1] + '} } Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText;
function checkMode(values, lifecycle = true) {
  const Host = vm.runInNewContext(modeCode, { ...values, PIN_NATIVE_LOGIN_LIFECYCLE_ENABLED: lifecycle });
  const host = new Host();
  assert.equal(host.nativeBusinessRoutesEnabled, true, 'business request gates cannot enable Web business routing');
  assert.equal(host.nativeLoginEnabled, lifecycle, 'only the explicit login lifecycle setting controls login mode');
  let scripts = 0;
  host.runSessionScript = async () => { scripts++; };
  host.install('synthetic-business-script');
  assert.equal(scripts, 0, 'disabled requests cannot reinstall legacy business scripts');
}
checkMode(defaults);
for (const disabled of definitions) checkMode(evaluate(disabled.local));
checkMode(stopped);
checkMode(postDisabled);
checkMode(evaluate(undefined, true, 'PIN_POST_EXTENSIONS_ENABLED'));
checkMode(stopped, false);
console.log('Native feature gates: defaults, per-feature/master/prerequisite gates, independent login/routing and no legacy script installation passed');
