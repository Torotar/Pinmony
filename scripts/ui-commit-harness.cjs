const fs = require('node:fs');
const vm = require('node:vm');
function createUiCommitHarness(ts) {
  const timers = new Map(); let serial = 0;
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync('common_ui/src/main/ets/services/PinmonyUiCommitQueue.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
  }).outputText;
  vm.runInNewContext(code, { exports,
    setTimeout: fn => { const id = ++serial; timers.set(id, fn); return id; },
    clearTimeout: id => timers.delete(id) });
  function flush() {
    for (let turns = 0; timers.size; turns++) {
      if (turns > 100) throw Error('UI commit loop did not settle');
      const entries = [...timers.entries()];
      for (const [id, fn] of entries) if (timers.delete(id)) fn();
    }
  }
  return { Queue: exports.PinmonyUiCommitQueue, flush, timers };
}
module.exports = { createUiCommitHarness };
