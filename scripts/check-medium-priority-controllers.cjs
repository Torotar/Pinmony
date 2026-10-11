const assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const {bind,runtime}=require('./medium-priority-controller-harness.cjs');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function harness(){
  let page='https://www.pinterest.com/sample/',next=0;
  const timers=new Map(),calls=[],pending=[],feedback=[];
  const globals={setTimeout(fn){timers.set(++next,fn);return next;},clearTimeout(id){timers.delete(id);}};
  const loader=runtime(ts,globals);
  const settingsStore=new (loader.loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets').PinmonySettingsStore)();
  const inboxStore=new (loader.loadFile('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets').PinmonyInboxStore)();
  const n={settingsStore,inboxStore,authStatus:'authenticated',authEpoch:1,businessSuspended:false,activeTab:3,profileSettingsVisible:true,
    currentProfileUrl:()=>page,profileUrlFromAddress:s=>s,currentInboxUrl:()=>page,webJsonText:s=>s,
    ensureRootActionContext:async()=>true,showMessage:s=>feedback.push(s),
    controller:{getUrl:()=>page,runJavaScript:s=>{calls.push(s);if(s.includes('.close()'))return Promise.resolve('true');return new Promise((resolve,reject)=>pending.push({resolve,reject}));}}};
  bind(n,ts,globals);
  const result=(saved=false)=>({page,token:settingsStore.token,loading:false,error:'',saved,ready:true,email:'',birthdate:'',gender:'',customGender:'',countries:[],topics:[],activities:[]});
  return {n,settingsStore,inboxStore,calls,pending,feedback,timers,result,visit:s=>page=s};
}
(async()=>{
  const preparation=harness();let release;
  preparation.n.ensureRootActionContext=()=>new Promise(resolve=>release=resolve);
  const preparing=preparation.n.settingsController.request('privateProfile','true');
  assert(preparation.settingsStore.busy);preparation.n.settingsController.pause();release(true);await preparing;
  assert.equal(preparation.settingsStore.busy,false,'pause releases a write waiting for context');assert.equal(preparation.calls.length,0);
  preparation.settingsStore.busy=true;preparation.n.settingsController.pause();assert(preparation.settingsStore.busy,'does not clear product logout busy state');
  const read=harness(),reading=read.n.settingsController.request('read','');await flush();
  read.pending.shift().resolve('true');await flush();read.pending.shift().resolve(JSON.stringify(read.result()));await reading;
  assert.equal(read.settingsStore.data.ready,true);assert.equal(read.settingsStore.loading,false);
  const write=harness(),saving=write.n.settingsController.request('privateProfile','true');await flush();
  await write.n.settingsController.request('privateProfile','true');assert.equal(write.calls.length,1,'single dispatch while saving');
  write.pending.shift().resolve('true');await flush();const late=write.pending.shift();write.n.settingsController.pause();
  late.resolve(JSON.stringify(write.result(true)));await saving;
  assert.equal(write.settingsStore.data,undefined);assert.equal(write.settingsStore.writeUncertain,true);
  await write.n.settingsController.request('privateProfile','false');assert.equal(write.calls.filter(s=>s.includes('.start(')).length,1,'unknown write requires reading, no replay');
  const confirm=write.n.settingsController.request('read','');await flush();write.pending.shift().resolve('true');await flush();write.pending.shift().resolve(JSON.stringify(write.result()));await confirm;
  assert.equal(write.settingsStore.writeUncertain,false);
  const delay=harness(),delayed=delay.n.settingsController.request('read','');await flush();delay.pending.shift().resolve('true');await flush();
  delay.pending.shift().resolve(JSON.stringify({...delay.result(),loading:true}));await flush();assert.equal(delay.timers.size,1);
  delay.n.settingsController.pause();await delayed;assert.equal(delay.timers.size,0,'cancelled wait settles and stops polling');
  const notification=harness();notification.settingsStore.screen='notifications';const notifying=notification.n.settingsController.readNotifications();
  notification.pending.shift().resolve('true');await flush();const response=notification.pending.shift();notification.n.settingsController.pause();
  response.resolve(JSON.stringify({groups:[{key:'old',label:'old',categories:[]}],error:''}));await notifying;
  assert.equal(notification.settingsStore.notifications.length,0);
  const inbox=harness();inbox.n.activeTab=2;Object.assign(inbox.inboxStore,{inboxActionsReady:true,inboxUrl:inbox.n.currentInboxUrl(),inboxSession:1,inbox:{}});
  const opening=inbox.n.inboxActionsController.open('compose');await flush();await inbox.n.inboxActionsController.open('compose');assert.equal(inbox.pending.length,1);
  inbox.visit('https://www.pinterest.com/search/');inbox.pending.shift().reject(Error('old document'));await opening;assert.equal(inbox.feedback.length,0);
  const actions=harness();actions.n.activeTab=2;actions.inboxStore.inboxSession=1;
  actions.inboxStore.inboxFlow={pageUrl:actions.n.currentInboxUrl(),session:1,screen:'chat',conversationId:'synthetic-a',loading:false};
  const sending=actions.n.inboxActionsController.action('send','hello');await actions.n.inboxActionsController.action('send','hello');assert.equal(actions.pending.length,1);
  actions.inboxStore.inboxFlow={...actions.inboxStore.inboxFlow,conversationId:'synthetic-b'};actions.pending.shift().reject(Error('old chat'));await sending;assert.equal(actions.feedback.length,0);
  actions.inboxStore.inboxFlow={...actions.inboxStore.inboxFlow,sending:true};await actions.n.inboxActionsController.action('send','hello');assert.equal(actions.pending.length,0);
  const back=actions.n.inboxActionsController.action('back');actions.pending.shift().resolve('true');await back;
  actions.inboxStore.inboxFlow={...actions.inboxStore.inboxFlow,screen:'compose',loading:true,sending:false};
  const first=actions.n.inboxActionsController.action('search','old'),second=actions.n.inboxActionsController.action('search','new');
  actions.pending.shift().reject(Error('old query'));actions.pending.shift().resolve('true');await Promise.all([first,second]);assert.equal(actions.feedback.length,0);
  const task=actions.n.coordinatorTasks,waiting=task.wait(1000);task.timeout(()=>{throw Error('late work');},1000);task.invalidate();
  assert.equal(await waiting,false);assert.equal(actions.timers.size,0);
  console.log('Medium controllers: real Store/Index ports, context cancellation, unknown writes, notifications, inbox single dispatch, stale errors, latest search and cancelled tasks passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
