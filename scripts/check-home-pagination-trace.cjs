const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
const method = source.match(/  private paginationTrace\([\s\S]*?\n  \}/)[0];
const logs = []; let now = 10000;
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
{ Date: { now: () => now }, PinmonyRuntimeLog: { info: s => logs.push(s) } });
const host = new Host();
Object.assign(host, { paneActive: false, home: { pins: [] }, visibleFirst: 0, visibleLast: -1,
  paginationTraceAt: 0, paginationTraceKey: '' });
host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 0);
host.home.pins = [1]; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 0);
host.paneActive = true; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 1);
now += 60000; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 1, 'unchanged state stays quiet');
host.visibleLast = 0; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 2);
host.visibleLast = 1; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 2, 'rapid changes remain bounded');
now += 1001; host.paginationTrace('speculative-disabled'); assert.equal(logs.length, 3);
host.paneActive = false; now += 1001; host.paginationTrace('request-failed');
assert(logs.at(-1).includes('request-failed'), 'non-speculative diagnostics remain available');
console.log('Home pagination diagnostics: inactive/empty panes stay quiet, unchanged state is deduplicated, changes are throttled and other reasons remain observable');
