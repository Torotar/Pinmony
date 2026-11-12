const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets', 'utf8');
const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
const ast = ts.createSourceFile('network.ts', source, ts.ScriptTarget.Latest, true);
const declarations = ast.statements.filter(node => ts.isClassDeclaration(node) && ['RequestScheduler', 'NetworkManager'].includes(node.name.text));
assert.equal(declarations.length, 2);
const sessions = [], logs = [];
let pendingPreconnect;
const rcp = { Request: class { constructor(url, method) { Object.assign(this, { url, method }); } },
  createSession(config) {
    const session = { config, closed: false, cancelCount: 0,
      close() { this.closed = true; }, cancel() { this.cancelCount++; },
      async fetch(request) {
        assert(!this.closed);
        if (request.connectOnly && pendingPreconnect) return pendingPreconnect;
        return { statusCode: 200 };
      } };
    sessions.push(session); return session;
  } };
class Policy { acquire() { return { allowed: true }; } canSend() { return true; } finish() {} }
const Host = vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, declarations.map(node => node.getText(ast).replace(/^export /, '')).join('\n') + '\nNetworkManager;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { rcp, PinmonyRequestPolicy: Policy, PinmonyRuntimeLog: { info: msg => logs.push(msg), warn: msg => logs.push(msg) },
  priorityName: value => String(value), responseMetrics: () => '', Promise, setTimeout, clearTimeout, Date, Math, Error });
const flush = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  Host.setForeground(true); const first = Host.getSession();
  Host.setForeground(true); assert.equal(Host.getSession(), first, 'initial/duplicate foreground retains pool');
  Host.setForeground(false); assert.equal(first.closed, false, 'background must preserve active writes and background reads');
  assert.equal(Host.getSession(), first, 'background polling retains transport');
  Host.setForeground(true); assert(first.closed); assert.equal(first.cancelCount, 0, 'renew is not cancellation');
  const second = Host.getSession(); assert.notEqual(first, second);
  assert.deepEqual(Object.keys(second.config.requestConfiguration).sort(), ['tracing', 'transfer'], 'no TLS override added');
  let finishWrite, writes = 0;
  const write = Host.enqueue(0, async () => { writes++; assert.equal(Host.getSession(), second); return new Promise(resolve => { finishWrite = resolve; }); });
  await flush(); Host.setForeground(false); Host.setForeground(true);
  assert.equal(second.closed, false, 'in-flight write blocks pool closure');
  const during = await Host.enqueue(1, async () => Host.getSession()); assert.equal(during, second);
  finishWrite({ statusCode: 200 }); await write; await flush();
  const third = await Host.enqueue(1, async () => Host.getSession()); await flush();
  assert.notEqual(third, second, 'next idle acquisition completes deferred renew');
  assert(second.closed); assert.equal(writes, 1, 'resume never replays write'); assert.equal(second.cancelCount, 0);
  let finishPreconnect;
  pendingPreconnect = new Promise(resolve => { finishPreconnect = resolve; });
  const connecting = Host.preConnect('https://www.pinterest.com');
  Host.setForeground(false); Host.setForeground(true); assert.equal(third.closed, false, 'preconnect must finish before pool closure');
  finishPreconnect({ statusCode: 200 }); await connecting; pendingPreconnect = undefined;
  const fourth = Host.getSession(); assert.notEqual(fourth, third); assert(third.closed);
  let attempts = 0;
  const certificateError = new Error('certificate'); certificateError.code = 1007900060;
  await assert.rejects(Host.requestWithRetry({ fetch: async () => { attempts++; throw certificateError; } }, { method: 'GET' }, 2), error => error === certificateError);
  assert.equal(attempts, 1, 'certificate failures are neither bypassed nor replayed');
  assert(logs.some(msg => msg.includes('transport-renew reason=foreground')));
  assert(/onForeground\(\): void \{\s*NetworkManager.setForeground\(true\);\s*PinmonyInboxBackgroundLifecycle.change\(false\)/.test(ability), 'renew before foreground business callbacks');
  assert(/onBackground\(\): void \{\s*NetworkManager.setForeground\(false\)/.test(ability));
  Host.destroy();
  console.log('Foreground transport: idle renew, background continuity, deferred in-flight/preconnect, no write replay and certificate failure propagation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
