const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const code = ts.transpileModule(fs.readFileSync('common_session/src/main/ets/services/PinmonySessionHistory.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText;
let persisted = false, fail = false;
function boot() {
  const state = new Map(), exports = {};
  let pending;
  vm.runInNewContext(code, {
    exports,
    AppStorage: { setOrCreate: (key, value) => state.set(key, value) },
    require: () => ({ preferences: { getPreferencesSync: () => ({
      getSync: () => persisted,
      putSync: (key, value) => { assert.equal(key, 'confirmed'); assert.equal(typeof value, 'boolean'); pending = value; },
      flushSync: () => { if (fail) throw Error(); persisted = pending; }
    }) } })
  });
  exports.PinmonySessionHistory.initialize({});
  return { service: exports.PinmonySessionHistory, state };
}
let runtime = boot();
assert.equal(runtime.state.get('pinmonySessionConfirmed'), false);
assert.equal(runtime.service.save(true), true);
runtime = boot();
assert.equal(runtime.state.get('pinmonySessionConfirmed'), true, 'fresh process restores confirmed history');
assert.equal(runtime.service.save(false), true);
assert.equal(boot().state.get('pinmonySessionConfirmed'), false, 'logout is durable');
fail = true;
assert.equal(boot().service.save(true), false, 'failed flush is reported');
assert.equal(boot().state.get('pinmonySessionConfirmed'), false);
console.log('Session history: fresh-process restore, explicit reset, boolean-only storage and flush failure passed');
