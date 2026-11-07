const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const base='entry/src/main/ets/app/';
const turn=async()=>{for(let i=0;i<30;i++)await Promise.resolve();};
function fixture(options={}) {
  let now=1000000,sequence=0,session={authenticated:true,accountId:'synthetic',generation:1,origin:'https://www.pinterest.com'},enabled=options.enabled!==false,readGate=options.readGate;
  const timers=new Map(),requests=[],observed=[],networks=[],leases=[],released=[],expiryCallbacks=[];let stops=0,permissionChecks=0,leaseSequence=0;
  const store={inboxMessagesUnread:false,inboxMessagesUnreadCount:0,inboxFlow:{draft:'source'},inbox:{items:['retained']}};
  class ClockDate extends Date {static now(){return now;}}
  const common={PinmonyRuntimeLog:{info(){},warn(){}},PinmonyI18n:{message:()=> 'New message'}};
  const schedule=(fn,ms,repeat)=>{const id=++sequence;timers.set(id,{fn,at:now+ms,repeat:repeat?ms:0});return id;};
  function load(name,deps={}){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(base+name+'.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{exports,require:n=>{return deps[n]||{};},Date:ClockDate,setTimeout:(fn,ms)=>schedule(fn,ms,false),setInterval:(fn,ms)=>schedule(fn,ms,true),clearTimeout:id=>timers.delete(id),clearInterval:id=>timers.delete(id)});return exports;}
  const lifecycle=load('PinmonyInboxBackgroundLifecycle');
  class Network {
    constructor(){this.foreground=true;this.cancelled=[];networks.push(this);}
    setForeground(v){this.foreground=v;}
    cancel(id){this.cancelled.push(id);}
    async requestBusinessInboxMessagesRead(job,context,current){
      assert(this.foreground&&current());assert.equal(job.method,'GET');assert.equal(job.body,'');assert(job.url.includes('/resource/ConversationsResource/get/'));
      requests.push(job);if(readGate)await readGate;
      return {status:200,error:'',body:options.invalid?'invalid':JSON.stringify({resource_response:{status:'success',endpoint_name:'v3_get_conversations',data:[{id:'100',unread:1,last_message:{id:'1'}}]}})};
    }
    requestBusinessInboxUpdatesRead(){throw Error('background must not poll updates');}
  }
  const reader=load('PinmonyInboxUnreadNativeReads',{
    'feature_inbox':{PinmonyInboxHiddenConversations:{hidden:()=>false}},'common_foundation':common,
    './PinmonyInboxUpdatesNativeReads':{PIN_NATIVE_INBOX_UPDATES_ENABLED:true,INBOX_UPDATE_FIELDS:[]},
    './PinmonyInboxMessagesNativeReads':{PIN_NATIVE_INBOX_MESSAGES_ENABLED:true}
  });
  const background=load('PinmonyInboxBackgroundSync',{
    '@kit.BackgroundTasksKit':{backgroundTaskManager:{requestSuspendDelay:(reason,expire)=>{assert.equal(typeof reason,'string');if(options.taskDenied)throw Error('quota unavailable');const requestId=++leaseSequence;leases.push(requestId);expiryCallbacks.push(expire);if(options.immediateExpiry)expire();return {requestId,actualDelayTime:options.duration===undefined?900000:options.duration};},cancelSuspendDelay:id=>{released.push(id);if(options.releaseError)throw Error('release unavailable');}}},
    '@kit.NotificationKit':{notificationManager:{isNotificationEnabled:async()=>{permissionChecks++;if(options.permissionGate)await options.permissionGate;if(options.permissionError){options.permissionError=false;throw Error('permission unavailable');}return enabled;}}},
    'common_network':{PinmonyNativeNetwork:Network},'common_foundation':common,
    './PinmonyInboxBackgroundLifecycle':lifecycle,'./PinmonyInboxUnreadNativeReads':reader
  });
  const service=new background.PinmonyInboxBackgroundSync({session:()=>session,store:()=>store,observed:rows=>observed.push(rows),stopped:()=>stops++});
  const state=lifecycle.PinmonyInboxBackgroundLifecycle;
  async function advance(ms){const target=now+ms;let count=0;while(true){let id,next;for(const [key,value]of timers)if(value.at<=target&&(!next||value.at<next.at)){id=key;next=value;}if(!next)break;assert(++count<200,'timer loop');now=next.at;if(next.repeat)next.at+=next.repeat;else timers.delete(id);next.fn();await turn();}now=target;await turn();}
  function freeze(ms){now+=ms;for(const timer of timers.values())if(timer.repeat||timer.at<now)timer.at=now;}
  return {service,state,requests,observed,networks,store,timers,leases,released,expiryCallbacks,advance,freeze,makeForegroundReader:()=>new reader.PinmonyInboxUnreadNativeReads({session:()=>session,active:()=>true,store:()=>store,network:()=>networks[0]}),setSession:s=>session=s,session:()=>session,setEnabled:v=>enabled=v,setReadGate:v=>readGate=v,stops:()=>stops,permissionChecks:()=>permissionChecks};
}
async function main(){
  const f=fixture();f.service.install();f.service.install();const flow=f.store.inboxFlow,list=f.store.inbox;
  f.state.change(true);await turn();assert(f.service.active());assert.equal(f.requests.length,1);assert.equal(f.observed.length,1);assert.equal(f.store.inboxMessagesUnread,true);
  assert.equal(f.store.inboxFlow,flow);assert.equal(f.store.inbox,list,'background synchronization never replaces source pages');
  await f.advance(2999);assert.equal(f.requests.length,1);await f.advance(1);assert.equal(f.requests.length,2);
  await f.advance(117000);assert(f.service.active());assert.equal(f.requests.length,41,'checking continues after sixty seconds while callbacks still run');
  await f.advance(60000);assert.equal(f.requests.length,61,'there is no arbitrary lifetime cutoff');assert.equal(f.stops(),0);
  f.state.change(true);await turn();assert.equal(f.timers.size,2,'duplicate background events cannot start duplicate loops');assert.equal(f.leases.length,1);
  f.freeze(60000);assert.equal(f.service.active(),false,'old callbacks lose authority during a long scheduling gap');const prior=f.requests.length;
  await f.advance(0);assert(f.service.active());assert.equal(f.requests.length,prior+1,'resume performs one read, not a burst for all missed intervals');assert.equal(f.stops(),1,'suspension discards old notification/portrait work');
  await f.advance(3000);assert.equal(f.requests.length,prior+2);
  f.state.change(false);assert.equal(f.service.active(),false);assert.equal(f.timers.size,0);assert.equal(f.networks[0].foreground,false);const stopped=f.requests.length;await f.advance(120000);assert.equal(f.requests.length,stopped);
  f.state.change(true);await turn();assert.equal(f.timers.size,2,'a later real background transition can start again');assert.equal(f.leases.length,2);
  const denied=fixture({enabled:false});denied.service.install();denied.state.change(true);await turn();assert.equal(denied.requests.length,0);assert.equal(denied.timers.size,0);assert.equal(denied.service.active(),false);
  const revoked=fixture();revoked.service.install();revoked.state.change(true);await turn();revoked.setEnabled(false);await revoked.advance(3000);assert.equal(revoked.requests.length,1);assert.equal(revoked.timers.size,0,'revocation stops future reads without a permission prompt');
  const broken=fixture({permissionError:true});broken.service.install();broken.state.change(true);await turn();assert.equal(broken.requests.length,0);assert.equal(broken.timers.size,2);await broken.advance(3000);assert.equal(broken.requests.length,1,'transient permission lookup failure retries on normal interval');
  const cold=fixture();cold.service.install();cold.state.change(true);await turn();assert.equal(cold.requests.length,1,'background can establish its own silent baseline without a foreground list read');
  const lateInstall=fixture();lateInstall.state.change(true);lateInstall.service.install();await turn();assert.equal(lateInstall.requests.length,1,'host mounted after background event still starts');
  let permit;const permission=fixture({permissionGate:new Promise(r=>permit=r)});permission.service.install();permission.state.change(true);await permission.advance(10000);assert.equal(permission.permissionChecks(),1,'slow permission checks are single flight');permission.state.change(false);permit();await turn();assert.equal(permission.requests.length,0,'permission result cannot restart cancelled background work');
  let release;const late=fixture({readGate:new Promise(r=>release=r)});late.service.install();late.state.change(true);await turn();assert.equal(late.requests.length,1);
  late.setSession({...late.session(),accountId:'other',generation:2});release();await turn();assert.equal(late.observed.length,0);assert.equal(late.store.inboxMessagesUnread,false);await late.advance(10000);assert.equal(late.timers.size,0);
  let resume;const cancelled=fixture({readGate:new Promise(r=>resume=r)});cancelled.service.install();cancelled.state.change(true);await turn();cancelled.state.change(false);assert.equal(cancelled.networks[0].cancelled.length,1);resume();await turn();assert.equal(cancelled.observed.length,0,'cancelled results cannot update unread or notify');
  let unfreeze;const frozen=fixture({readGate:new Promise(r=>unfreeze=r)});frozen.service.install();frozen.state.change(true);await turn();frozen.freeze(180000);unfreeze();await turn();assert.equal(frozen.observed.length,0,'a response resumed before the next timer cannot submit stale data');frozen.setReadGate(undefined);await frozen.advance(0);assert.equal(frozen.observed.length,1);assert.equal(frozen.requests.length,2);
  let oldRead;const overlap=fixture({readGate:new Promise(r=>oldRead=r)});overlap.service.install();overlap.state.change(true);await turn();overlap.freeze(180000);overlap.setReadGate(undefined);await overlap.advance(0);assert.equal(overlap.networks[0].cancelled.length,1);assert.equal(overlap.observed.length,1);oldRead();await turn();assert.equal(overlap.observed.length,1,'old completion cannot overwrite the resumed read');
  const bad=fixture({invalid:true});bad.store.inboxMessagesUnread=true;bad.store.inboxMessagesUnreadCount=7;bad.service.install();bad.state.change(true);await turn();assert.equal(bad.observed.length,0);assert.equal(bad.store.inboxMessagesUnreadCount,7,'failed reads retain prior evidence');
  const disposed=fixture();disposed.service.install();disposed.state.change(true);await turn();disposed.service.dispose();disposed.state.change(false);disposed.state.change(true);assert.equal(disposed.requests.length,1);assert.equal(disposed.timers.size,0);
  assert.equal(disposed.released.length,1,'destroy releases the task');
  const quota=fixture({taskDenied:true});quota.service.install();quota.state.change(true);await turn();assert.equal(quota.requests.length,0);assert.equal(quota.timers.size,0);quota.state.change(true);await turn();assert.equal(quota.leases.length,0,'denial cannot start unprotected polling or retry behind the user');
  const budget=fixture({duration:25000});budget.service.install();budget.state.change(true);assert.equal(budget.leases.length,1,'task is requested synchronously before background callback returns');await turn();await budget.advance(24999);assert(budget.service.active());await budget.advance(1);assert.equal(budget.service.active(),false);assert.equal(budget.timers.size,0);assert.deepEqual(budget.released,[1]);const readsAtExpiry=budget.requests.length;await budget.advance(120000);assert.equal(budget.requests.length,readsAtExpiry);assert.equal(budget.leases.length,1,'expiration never renews a hidden task');
  const early=fixture();early.service.install();early.state.change(true);await turn();early.expiryCallbacks[0]();assert.equal(early.service.active(),false);assert.deepEqual(early.released,[1]);early.state.change(false);early.state.change(true);await turn();assert(early.service.active());early.expiryCallbacks[0]();assert(early.service.active(),'old task callback cannot stop a new task');early.state.change(false);assert.deepEqual(early.released,[1,2]);
  const zero=fixture({duration:0});zero.service.install();zero.state.change(true);await turn();assert.equal(zero.requests.length,0);assert.deepEqual(zero.released,[1]);assert.equal(zero.timers.size,0);
  const immediate=fixture({immediateExpiry:true});immediate.service.install();immediate.state.change(true);await turn();assert.equal(immediate.requests.length,0);assert.deepEqual(immediate.released,[1]);
  let expiredRead;const expiring=fixture({duration:15000,readGate:new Promise(resolve=>expiredRead=resolve)});expiring.service.install();expiring.state.change(true);await turn();await expiring.advance(15000);assert.equal(expiring.networks[0].cancelled.length,1);expiredRead();await turn();assert.equal(expiring.observed.length,0,'expiry revokes in-flight responses and notification submission');
  const releasing=fixture({releaseError:true});releasing.service.install();releasing.state.change(true);await turn();releasing.state.change(false);assert.equal(releasing.timers.size,0);assert.equal(releasing.service.active(),false,'release exception cannot retain reader authority');
  let finishSlow;const slow=fixture({readGate:new Promise(resolve=>finishSlow=resolve)});slow.service.install();slow.state.change(true);await turn();await slow.advance(9000);assert.equal(slow.requests.length,1,'three-second ticks do not overlap an unfinished request');slow.setReadGate(undefined);finishSlow();await turn();await slow.advance(3000);assert.equal(slow.requests.length,2);
  const foreground=fixture();foreground.networks[0].setForeground(true);const foregroundReader=foreground.makeForegroundReader();await foregroundReader.pollMessages();await foreground.advance(3000);await foregroundReader.pollMessages();assert.equal(foreground.requests.length,1,'foreground reader retains ten-second throttle');await foreground.advance(6999);await foregroundReader.pollMessages();assert.equal(foreground.requests.length,1);await foreground.advance(1);await foregroundReader.pollMessages();assert.equal(foreground.requests.length,2);
  let permissionReady;const jitter=fixture({permissionGate:new Promise(resolve=>permissionReady=resolve)});jitter.service.install();jitter.state.change(true);await jitter.advance(1);permissionReady();await turn();assert.equal(jitter.requests.length,1);await jitter.advance(2999);assert.equal(jitter.requests.length,2,'permission latency cannot turn a three-second tick into a six-second read');
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8'),ability=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');
  assert(index.includes('this.inboxBackgroundSync.install()'));assert(index.includes('this.inboxBackgroundSync.dispose()'));
  assert.match(index,/resetNativeBusinessSession\(\): void \{ this.inboxBackgroundSync.stop\(\)/);
  assert.match(index,/resetAuthenticatedContent\(\): void \{ this.inboxBackgroundSync.stop\(\)/);
  assert.match(index,/onPageShow\(\): void \{\s*this.inboxBackgroundSync.stop\(\)/);
  assert.match(ability,/onBackground\(\): void \{\s*PinmonyInboxBackgroundLifecycle.change\(true\)/);
  assert.match(ability,/onForeground\(\): void \{\s*PinmonyInboxBackgroundLifecycle.change\(false\)/);
  assert.match(ability,/onDestroy\(\): void \{\s*PinmonyInboxBackgroundLifecycle.change\(false\)/);
  assert(fs.readFileSync(base+'PinmonyInboxBackgroundSync.ets','utf8').includes('requestSuspendDelay'));
  assert(!fs.readFileSync('entry/src/main/module.json5','utf8').includes('KEEP_BACKGROUND_RUNNING'),'no unrelated long-running mode');
  console.log('Background inbox: granted transient lease, no artificial 60s cutoff, 3s background cadence, foreground defaults unchanged, permission/single flight, frozen recovery without catch-up, stale read isolation, retained pages, cancellation and lifecycle cleanup passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
