const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const method = index.match(/  private markReturnedHome\([\s\S]*?(?=\n  private onRootPageVisible)/)[0];
const perfExports = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_foundation/src/main/ets/services/PinmonyPagePerformance.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: perfExports, require: () => ({}) });
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
let now = 0;
function fixture() {
  const native = new Host(), timers = [], logs = [];
  Object.assign(native, { tabRequestToken: 1, authStatus: 'authenticated', activeTab: 0, businessSuspended: false,
    nativeBusinessSessionContext: () => ({ generation: 1 }), nativeRootTabsVisible: () => true,
    homePresentationPageKey: () => 'synthetic-page', retainedHomeRootPageKey: () => '',
    homeStore: { homeForPresentation: () => ({ kind: 'state', pins: [] }) },
    coordinatorTasks: { timeout(fn) { timers.push(fn); } },
    pagePerformance: new perfExports.PinmonyPagePerformance(() => now, message => logs.push(message)) });
  native.pagePerformance.begin(0, 'return'); native.markReturnedHome(0);
  return { native, timers, logs };
}
let f = fixture(); now += 16; f.timers.shift()();
assert(f.logs.some(x => x.includes('event=cache-visible')));
assert(f.logs.some(x => x.includes('event=content-ready') && x.includes('elapsedMs=16')), 'normal empty retained content also counts');
for (const change of [n => n.tabRequestToken++, n => n.authStatus = 'unauthenticated', n => n.activeTab = 1,
  n => n.businessSuspended = true, n => n.nativeRootTabsVisible = () => false,
  n => n.nativeBusinessSessionContext = () => ({ generation: 2 }), n => n.homeStore.homeError = 'error',
  n => n.homeStore.homeForPresentation = () => ({ kind: 'loading' })]) {
  f = fixture(); change(f.native); f.timers.shift()();
  assert(!f.logs.some(x => x.includes('event=content-ready')), 'stale, hidden, unready or failed content cannot complete return');
}
// Execute the actual production home callback: metadata and pagination must not
// finish any pending return sample, even if cache restoration could not finish it.
const callback = index.match(/committed: \(snapshot: PinmonyHomeSnapshot, kind:[\s\S]*?\r?\n    }(?=\r?\n  } as PinmonyHomeNativeReadsPorts)/)[0].replace(/^committed: /, '');
const out = {};
vm.runInNewContext(ts.transpileModule('export function callback(){return ' + callback + ';}', {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: out, PinmonyUpdateNotice:{start(){}} });
f = fixture(); const marks = [];
Object.assign(f.native, { getUIContext:()=>({getHostContext:()=>({})}),rootTabAddresses: new Map(), persistHomeDiskCache() {}, rootContextCoordinator: { notify() {} },
  controller: { runJavaScript: () => Promise.resolve() }, detailReturnJourney: { mark: x => marks.push(x) } });
const committed = out.callback.call(f.native);
committed({ pageKey: 'synthetic-page' }, 'pagination'); committed({ pageKey: 'synthetic-page' }, 'metadata');
assert(!f.logs.some(x => x.includes('event=content-ready'))); assert.equal(marks.length, 0);
committed({ pageKey: 'synthetic-page' }, 'feed'); assert(f.logs.some(x => x.includes('event=content-ready')));
console.log('Return performance: cache completion, empty content, stale/visibility/error guards and separate pagination/metadata passed');
