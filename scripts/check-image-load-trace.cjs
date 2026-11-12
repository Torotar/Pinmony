const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImageLoadTrace.ets', 'utf8');
const component = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets', 'utf8');
let now = 1000, reads = 0, enabled = 0, queryFails = false, info;
const logs = [];
const sandbox = { exports: {}, Date: { now: () => now },
  PinmonyRuntimeLog: { info: line => logs.push(line) },
  cacheDownload: { setDownloadInfoListSize: size => { assert.equal(size, 32); enabled++; },
    getDownloadInfo: () => { reads++; if (queryFails) throw new Error('private-url'); return info; } } };
vm.runInNewContext(ts.transpileModule(source.replace(/^import[^\n]*\n/gm, ''), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, sandbox);
const trace = new sandbox.exports.PinmonyImageLoadTrace();
const url = 'https://i.pinimg.com/private-image.jpg?secret=must-not-log';
const record = (phase, generation = 1, failureInfo) => trace.record(17, generation, 0, 900, url, phase, 0, failureInfo);
record('node-mounted'); assert.equal(reads, 0, 'mount enables statistics without querying or sending a request');
now = 7000; record('native-data-ready');
assert.match(logs.at(-2), /sinceMountMs=6000/);
assert.match(logs.at(-1), /availability=unavailable.*currentRequestConfirmed=false/);
now = 7050; record('data-ready'); assert.match(logs.at(-1), /callbackQueueMs=50/);
now = 7060; record('native-decoded'); now = 7065; record('decoded');
assert.match(logs.at(-1), /sinceNativeDataMs=65 callbackQueueMs=5/);
assert.match(logs.at(-1), /frameConfirmed=false/);
info = { resource: { size: 12345 }, network: { ip: 'private-ip', dnsServers: ['private-dns'] },
  performance: { dnsTime: 2, connectTime: 3, tlsTime: 4, firstSendTime: 9,
    firstReceiveTime: 100, totalTime: 150, redirectTime: 0 } };
now = 8000; record('native-data-ready', 2);
assert.match(logs.at(-2), /sinceMountMs=-1/);
assert.match(logs.at(-1), /evidence=latest-url-record currentRequestConfirmed=false/);
assert.match(logs.at(-1), /bytes=12345 dnsMs=2 connectMs=3 tlsMs=4 firstSendMs=9 firstReceiveMs=100 totalMs=150/);
const before = reads; record('native-failed', 3, info);
assert.equal(reads, before, 'error callback data must not be replaced by a potentially older URL lookup');
assert.match(logs.at(-1), /evidence=error-callback currentRequestConfirmed=true/);
queryFails = true; record('native-data-ready', 4);
assert.match(logs.at(-1), /availability=query-failed/);
assert.equal(enabled, 1, 'download statistics list is configured once per process');
assert(!logs.join('\n').match(/private-image|must-not-log|private-ip|private-dns|private-url/));
assert(!source.match(/\.download\(|\.prefetch\(|\.fetch\(|setInterval|setTimeout/), 'diagnostics cannot add traffic or timers');
const audit = component.match(/  private auditImage\([\s\S]*?\r?\n  \}/)[0];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + audit + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { PinmonyRuntimeLog: { warn() {} } });
let records = 0;
const host = new Host();
Object.assign(host, { traceLoading: false, visible: true, tracePhases: new Set(),
  loadTrace: { record() { records++; } } });
host.auditImage('node-mounted'); assert.equal(records, 0, 'untraced callers do not collect statistics');
host.traceLoading = true; host.visible = false; host.auditImage('node-mounted'); assert.equal(records, 0);
host.visible = true; host.auditImage('node-mounted'); host.auditImage('node-unmounted'); host.auditImage('node-mounted');
assert.equal(records, 3, 'same-generation image mount cycles must remain observable during slow scrolling');
host.auditImage('native-decoded'); host.auditImage('native-decoded'); assert.equal(records, 4, 'completion phases remain deduplicated');
assert(component.includes("this.auditImage('host-disposed')") && component.includes("this.auditImage('node-unmounted')"));
host.loadTrace.record = () => { throw new Error('instrumentation failure'); };
assert.doesNotThrow(() => host.auditImage('native-decoded'), 'diagnostic failure cannot interrupt image completion');
const callback = component.slice(component.indexOf('.onComplete((event)'), component.indexOf('  build()'));
assert.match(callback, /if \(!this\.visible \|\| generation !== this\.generation\) return;/);
assert(callback.indexOf("auditImage('native-data-ready')") < callback.indexOf('queueImageEvent(generation, 0)'));
assert(callback.indexOf("auditImage('native-decoded')") < callback.indexOf('queueImageEvent(generation, 1)'));
assert.match(callback, /auditImage\('native-failed',[^\n]*event\?\.downloadInfo/);
console.log('Image diagnostics: timing, generations, absent statistics, uncorrelated URL records, callback evidence, privacy and failure isolation passed');
