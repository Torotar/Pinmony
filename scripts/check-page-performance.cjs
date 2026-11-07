const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript'), exportsObject = {}, logs = []; let now = 1000;
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(fs.readFileSync('common_foundation/src/main/ets/services/PinmonyPagePerformance.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
{ exports: exportsObject, require: () => ({ PinmonyRuntimeLog: { info() {} } }) });
const perf = new exportsObject.PinmonyPagePerformance(() => now, message => logs.push(message));
perf.begin(3, 'return'); now += 20; perf.mark(3, 'visible'); perf.mark(3, 'visible');
perf.mark(2, 'content-ready'); assert.equal(logs.filter(s => s.includes('event=visible')).length, 1);
now += 100; perf.mark(3, 'content-ready'); assert(logs.at(-1).includes('elapsedMs=120'));
perf.count(3, 'read'); perf.count(3, 'read'); assert(logs.at(-1).includes('reads=2'));
perf.count(3, 'cancel', 4); assert(logs.at(-1).includes('cancelledTasks=4'));
perf.cancel(); const count = logs.length; perf.mark(3, 'document-ready'); assert.equal(logs.length, count);
perf.begin(0, 'return'); now += 16; assert.equal(perf.restoreHome(), true);
const restored = logs.filter(s => s.includes('event=content-ready tab=0')).at(-1);
assert(restored.includes('elapsedMs=16'));
assert(restored.includes('evidence=deferred-check') && restored.includes('frameConfirmed=false'));
now += 12000; assert.equal(perf.restoreHome(), false); perf.mark(0, 'content-ready');
const completed = logs.length; perf.mark(0, 'document-ready'); assert.equal(logs.length, completed, 'later document callbacks do not become cached return durations');
assert.equal(logs.filter(s => s.includes('event=content-ready tab=0')).at(-1), restored, 'later pagination cannot stretch a completed return sample');
perf.begin(1, 'return'); assert.equal(perf.restoreHome(), false);
perf.begin(1, 'tab'); now += 64; perf.mark(1, 'cache-visible');
const cachedVisit = logs.filter(s => s.includes('event=content-ready tab=1')).at(-1);
assert(cachedVisit.includes('elapsedMs=64'));
now += 5000; perf.mark(1, 'content-ready');
assert.equal(logs.filter(s => s.includes('event=content-ready tab=1')).at(-1), cachedVisit, 'pagination cannot become first content after cached presentation');
perf.begin(0, 'tab'); assert.equal(perf.restoreHome(), false, 'restored home timings only apply to actual returns');
const isolatedLogs = []; let clock = 1000;
const isolated = new exportsObject.PinmonyPagePerformance(() => clock, message => isolatedLogs.push(message));
isolated.begin(0, 'tab'); clock += 900; isolated.mark(0, 'visible', 'visible-area');
isolated.begin(0, 'return'); isolated.mark(0, 'state-ready'); clock += 16; isolated.restoreHome();
const isolatedReturn = isolatedLogs.filter(s => s.includes('event=visible')).at(-1);
assert(isolatedReturn.includes('samples=1') && isolatedReturn.includes('p50Ms=16'), 'tab durations never pollute return percentiles');
assert(isolatedReturn.includes('reason=return') && isolatedReturn.includes('frameConfirmed=false'));
assert(isolatedLogs.some(s => s.includes('event=state-ready') && s.includes('elapsedMs=0')));
for (let i = 0; i < 90; i++) { perf.begin(3, 'tab'); now += i; perf.mark(3, 'visible'); }
assert(logs.at(-1).includes('samples=64')); assert(!logs.some(s => /https:|cookie|account_id/.test(s)));
for (const page of ['detail','board','chat','share']) {
  const identity='https://private.example/synthetic';
  perf.beginSecondary(page,identity); now+=30;
  const count=logs.length; perf.markSecondary(page,'old','content-ready'); assert.equal(logs.length,count);
  perf.markSecondary(page,identity,'content-ready');perf.markSecondary(page,identity,'content-ready');assert.equal(logs.length,count+1);
  assert(logs.at(-1).includes('elapsedMs=30'));assert(!logs.at(-1).includes(identity));
}
perf.cancel();const secondaryCount=logs.length;perf.markSecondary('chat','https://private.example/synthetic','image-ready');assert.equal(logs.length,secondaryCount);
for(let i=0;i<90;i++){perf.beginSecondary('detail','synthetic');now+=i;perf.markSecondary('detail','synthetic','image-ready');}
assert(logs.at(-1).includes('samples=64'));assert.equal(perf.secondary.size,1);assert(perf.durations.size<=28);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert(fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets','utf8').includes("this.ports.pagePerformance().begin(performanceRoot, 'return')"));
assert(source.includes("this.pagePerformance.mark(index, 'visible', 'visible-area')"));
assert(source.includes("this.pagePerformance.mark(index, 'visible', 'deferred-check')"));
for(const page of ['detail','board','chat','share']) {
  assert(source.includes("beginSecondary('"+page+"'"),'Product begins '+page);
  assert(source.includes("this.pagePerformance.markSecondary('"+page+"'"),'Index marks '+page);
}
console.log('Page performance: bounded percentiles, stage deduplication, stale tab and cancellation passed');

perf.beginSecondary('detail','return-case');now+=33;perf.begin(1,'return');
assert.equal(perf.secondary.size,0,'root return ends secondary sample immediately');
assert(logs.some(s=>s.includes('event=end page=detail')&&s.includes('outcome=interrupted')&&s.includes('elapsedMs=33')));
