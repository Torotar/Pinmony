const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const harness = require('./product-coordination-harness.cjs');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const parsed = ts.createSourceFile('Index.ts', source.replace('struct Index', 'class Index'), ts.ScriptTarget.Latest, true);
const host = parsed.statements.find(v => ts.isClassDeclaration(v) && v.name.text === 'Index');
const methods = ['requestNativeNetwork', 'cancelNativeNetwork'].map(name => {
  const method = host.members.find(v => v.name?.getText(parsed) === name);
  assert(method?.body);
  return method.getText(parsed);
});
const context = { PinmonyRuntimeLog: { info() {}, warn() {} } };
harness.run(ts, ts.transpileModule('class Host {' + methods.join('\n') + '} globalThis.Host=Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, context);
const flush = () => new Promise(setImmediate);
const native = harness.createHost(context.Host, ts);
const page = 'https://www.pinterest.com/example/board/';
const scripts = [], cancellations = [];
let requests = 0, complete;
Object.assign(native, {
  authEpoch: 1, authStatus: 'authenticated', nativeBackTarget: '', nativeRootOnly: false, detailReturnedToRoot: false,
  nativeNetworkContext: () => ({ authenticated: native.authStatus === 'authenticated', epoch: native.authEpoch, page, userAgent: 'synthetic' }),
  nativeNetwork: { request() { requests++; return new Promise(resolve => { complete = resolve; }); }, cancel: id => cancellations.push(id) },
  detailReadNetwork: { invalidate: () => cancellations.push('read-invalidated') },
  detailReadCache: { retained: () => undefined, clear() {}, store() { assert.fail('board response cannot enter detail cache'); } },
  detailJourney: { current: () => 0 }, detailRequestOwners: new Map(), pageHistory: { isPending: () => false },
  controller: { runJavaScript: async value => { scripts.push(value); return 'delivered'; } },
  pinIdentity: context.PinmonyRouteParser.pinIdentity,
  extractPinUrl: context.PinmonyRouteParser.extractPinUrl,
  currentPinUrl: () => '', showNetworkNotice() { assert.fail('cancellation is not a network failure'); }, clearNetworkNotice() {}
});
const job = { id: 'synthetic-read', epoch: 1, page, url: 'https://www.pinterest.com/resource/BoardResource/get/', method: 'GET', body: '', headers: {} };
const reply = request => ({ ...request, status: 200, body: '{}', headers: {} });
(async () => {
  native.requestNativeNetwork(JSON.stringify(job));
  assert.equal(requests, 1);
  native.authEpoch++;
  complete(reply(job)); await flush(); await flush();
  assert.equal(scripts.length, 0, 'new session rejects a late bridge response');
  const current = { ...job, id: 'current-read', epoch: native.authEpoch };
  native.requestNativeNetwork(JSON.stringify(current));
  complete(reply(current)); await flush(); await flush();
  assert.equal(scripts.length, 1, 'current response reaches the existing same-document JS adapter');
  const pin = 'https://www.pinterest.com/pin/123/';
  native.pinStore.detailPresentationOnly = true;
  native.requestNativeNetwork(JSON.stringify({ ...current, id: 'departed-preview', page: pin,
    url: 'https://www.pinterest.com/resource/UnifiedCommentsPreviewResource/get/' }));
  assert.equal(requests, 2, 'departed preview has no native transport dispatch');
  assert(scripts.at(-1).includes('cancelled'));
  native.sharedDetailRequestId = 'shared'; native.openingRelated = Promise.resolve({});
  native.pinStore.detailPrefetch.pause = () => cancellations.push('prefetch-paused');
  native.cancelNativeNetwork('shared');
  assert.deepEqual(cancellations, ['shared', 'prefetch-paused', 'read-invalidated']);
  assert.equal(native.sharedDetailRequestId, ''); assert.equal(native.openingRelated, undefined);
  console.log('Actual Index network Ports: late session rejection, current delivery, departed preview suppression and shared-read cancellation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
