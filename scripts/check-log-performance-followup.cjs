const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const logs = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['markReturnedHome', 'markRootPerformance', 'commentApiAction'].map(method).join('\n') + '} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
  {PinmonyRuntimeLog:{info:s=>logs.push(s),warn:s=>logs.push(s)}});
function fixture(tab) {
  const host = new Host(), tasks = [], marks = [];
  Object.assign(host, {
    activeTab:tab, authStatus:'authenticated', businessSuspended:false, tabRequestToken:1,
    nativeBusinessSessionContext:()=>({generation:1}), nativeRootTabsVisible:()=>true,
    rootContextCoordinator:{notify(){}}, rootActionContextReady:()=>false,
    pagePerformance:{mark:(...args)=>marks.push(args)}, coordinatorTasks:{timeout:fn=>tasks.push(fn)},
    searchStore:{search:{pageKey:'search',api:true},searchNativeReadsReady:true},
    inboxStore:{inbox:{dataSource:'api',section:'messages'},inboxNativeMessagesReady:true},
    profileStore:{profile:{contentLoading:false},profileNativeReadsReady:true},homeStore:{}
  });
  return {host,tasks,marks};
}
for (const tab of [1,2,3]) {
  const {host,tasks,marks} = fixture(tab);
  host.markReturnedHome(tab); assert.equal(marks.length,0);
  tasks.shift()();
  assert(marks.some(([t,s])=>t===tab && s==='visible'));
  assert(marks.some(([t,s])=>t===tab && s==='cache-visible'), 'retained subtree does not need a new visible-area callback');
  assert(marks.some(([t,s])=>t===tab && s==='content-ready'), 'native data does not wait for Web write readiness');
}
for (const invalidate of [h=>h.tabRequestToken++, h=>h.activeTab=0,
  h=>h.authStatus='checking', h=>h.businessSuspended=true,
  h=>h.nativeRootTabsVisible=()=>false, h=>h.nativeBusinessSessionContext=()=>({generation:2})]) {
  const {host,tasks,marks}=fixture(1);host.markReturnedHome(1);invalidate(host);tasks.shift()();
  assert.equal(marks.length,0,'stale return cannot publish timing');
}
for (const tab of [1,2,3]) {
  const {host,marks}=fixture(tab);
  if(tab===1)host.searchStore.searchError='error';
  if(tab===2)host.inboxStore.inboxError='error';
  if(tab===3)host.profileStore.profile.contentError='error';
  host.markRootPerformance(tab);assert.equal(marks.length,0,'failure is not successful content');
}
const wrongSection=fixture(2);wrongSection.host.inboxStore.inbox.section='updates';
wrongSection.host.markRootPerformance(2);assert.equal(wrongSection.marks.length,0,'message readiness cannot authorize updates timing');
const nav=fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets','utf8');
assert(nav.includes('this.ports.rootPresented?.(index)'));
const ReturnHost=vm.runInNewContext(ts.transpileModule('class ReturnHost {'+method('returnToNativeProfile')+'} ReturnHost;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_PROFILE_READS_ENABLED:true});
for(const visitor of [false,true]) {
  const returned=new ReturnHost(),events=[];
  Object.assign(returned,{profileUrlFromAddress:()=>'/sample/',profileStore:{profile:{profileUrl:'/sample/'},origins:visitor?[{}]:[]},
    returnCoordinator:{cancel(){}},pageHistory:{cancelBack(){},visit(){}},pageBackToken:0,
    clearDetail(){events.push('clear')},boardNativeReads:{pause(){}},boardStore:{},tabsController:{changeIndex(){}},
    pagePerformance:{begin:(...args)=>events.push(args)},profileNativeReads:{select(){}},
    markReturnedHome:i=>events.push(['presented',i]),syncFloatingTabsMotion(){}});
  assert.equal(returned.returnToNativeProfile('/sample/'),true);
  assert.equal(events.some(e=>Array.isArray(e)&&e[0]===3&&e[1]==='return'),!visitor);
  assert.equal(events.some(e=>Array.isArray(e)&&e[0]==='presented'),!visitor,'visitor return does not create root sample');
}
const rejected=fixture(1);rejected.host.postPanelsController={commentAction:async()=>{throw Error('private payload');}};
rejected.host.commentApiAction('commentTranslate','private-id');
setImmediate(()=>{
  assert(logs.includes('CommentsNativeTrace: action-rejected operation=commentTranslate'));
  assert(!logs.join('\n').includes('private payload'));assert(!logs.join('\n').includes('private-id'));
  console.log('Log followup: retained-root timing, native readiness, stale/error guards and handled comment rejection passed');
});
