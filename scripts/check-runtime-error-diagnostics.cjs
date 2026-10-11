const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
const method = source.match(/  private recordRuntimeError\([\s\S]*?\n  \}/)[0];
const logs = [], context = { PinmonyRuntimeLog: { error: line => logs.push(line), recentActionContext: () => 'stage=share-close ageMs=3' } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Ability { ${method} } globalThis.Ability = Ability;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const ability = new context.Ability(); ability.runtimeErrorSequence = 0;
ability.recordRuntimeError({ name: 'Error', message: 'ForEach duplicate key secret-payload',
  stack: 'Error: secret-payload\n    at update (entry/src/main/ets/pages/Index.ets:123:8)\nother (PinmonyDetailPage.ets:44:2)' }, 'exception');
assert(logs[0].includes('kind=exception category=node-identity sequence=1'));
assert(logs.some(line => line.includes('Runtime action context: stage=share-close ageMs=3')));
assert(logs.includes('Runtime stack: Index.ets:123:8'));
assert(logs.includes('Runtime stack: PinmonyDetailPage.ets:44:2'));
assert(!logs.join('\n').includes('secret-payload'));
assert(!logs.join('\n').includes('entry/src/'));
ability.recordRuntimeError({ name: 'Error', message: 'abort current read' }, 'rejection');
assert(logs.some(line => line.includes('kind=rejection category=cancellation')));
assert.equal(logs.at(-1), 'Runtime stack: unavailable');
assert(source.includes("errorManager.on('globalUnhandledRejectionDetected', this.rejectionObserver)"));
assert(source.includes("errorManager.off('globalUnhandledRejectionDetected', this.rejectionObserver)"));
console.log('Runtime diagnostics: exception/rejection classification, both stack formats, missing-stack reporting and payload exclusion passed');
