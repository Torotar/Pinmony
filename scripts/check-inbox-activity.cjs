const assert = require('node:assert/strict');
const fs = require('node:fs');
const {createArktsLoader} = require('./arkts-module-loader.cjs');
const ts = require(process.argv[2] || 'typescript');
const loader = createArktsLoader(ts, {'@kit.RemoteCommunicationKit':{},'@kit.BasicServicesKit':{},common_foundation:{PinmonyRuntimeLog:{info(){}}},common_session:{PinmonySessionCredentials:class{}},common_network:{PIN_BUSINESS_PIN_READ_ENABLED:true}});
const Activity = loader.loadFile('entry/src/main/ets/app/PinmonyInboxActivityNativeReads.ets').PinmonyInboxActivityNativeReads;
const Network = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets').PinmonyNativeNetwork;
const relations = (followed=false) => [{relationship_type:8,followed_by_me:followed,last_action_time:'2026-11-06T00:00:00Z',user:{id:'2',username:'synthetic_peer',full_name:'Synthetic peer',image_large_url:'https://i.pinimg.com/avatar.jpg'}}];
function fixture() {
  let active=true, session={authenticated:true,accountId:'1',generation:1,origin:'https://www.pinterest.com',userAgent:'synthetic'};
  const requests=[],cancelled=[],feedback=[];let changes=0;
  const activity=new Activity({session:()=>session,current:()=>active,changed:()=>changes++,feedback:m=>feedback.push(m),
    network:()=>({cancel:id=>cancelled.push(id),requestBusinessInboxActivity:(job,s,target,current)=>new Promise(resolve=>requests.push({job,target,current,
      resolve:(data,endpoint=target?'v3_follow_user_method':'v3_get_inbox_social_relationships',status=200)=>resolve({...job,error:'',status,body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data}})})}))})});
  return {activity,requests,cancelled,feedback,session:()=>session,setSession:s=>session=s,setActive:v=>active=v,changes:()=>changes};
}
async function loaded(f,data=relations()) {const pending=f.activity.load();f.requests.at(-1).resolve(data);await pending;}
async function main() {
  const f=fixture();const initial=f.activity.load();await f.activity.load();assert.equal(f.requests.length,1,'single flight');
  f.requests[0].resolve([...relations(),...relations(),{relationship_type:99}]);await initial;
  assert.equal(f.activity.rows.length,1,'deduplicated follower relationships only');assert.equal(f.activity.rows[0].title,'Synthetic peer');assert.equal(f.activity.rows[0].activityFollowed,false);
  await f.activity.load();assert.equal(f.requests.length,1,'ready read cached');
  const follow=f.activity.follow('2');await f.activity.follow('2');assert.equal(f.requests.length,2);assert.equal(f.activity.rows[0].activityBusy,true);assert.equal(f.feedback.length,0);
  f.requests.at(-1).resolve({id:'2'});await follow;assert.equal(f.activity.rows[0].activityFollowed,true);assert.equal(f.feedback.length,1);await f.activity.follow('2');assert.equal(f.requests.length,2);
  const unknown=fixture();await loaded(unknown);const mismatch=unknown.activity.follow('2');unknown.requests.at(-1).resolve({id:'3'});await mismatch;
  assert.equal(unknown.activity.rows[0].activityUncertain,true);assert.equal(unknown.activity.rows[0].activityFollowed,false);await unknown.activity.follow('2');assert.equal(unknown.requests.length,2,'unknown write cannot replay');
  await unknown.activity.load();assert.equal(unknown.requests.length,2,'load without force retains cache');
  const reconcile=unknown.activity.load(true);unknown.requests.at(-1).resolve(relations(true));await reconcile;assert.equal(unknown.activity.rows[0].activityFollowed,true);assert.equal(unknown.activity.rows[0].activityUncertain,false);
  const checked=fixture();await loaded(checked);const lost=checked.activity.follow('2');checked.requests.at(-1).resolve({},'wrong');await lost;const checkRead=checked.activity.load(true);checked.requests.at(-1).resolve(relations(false));await checkRead;assert.equal(checked.activity.rows[0].activityUncertain,false,'authoritative read permits a new explicit follow, never an automatic replay');assert.equal(checked.requests.length,3);
  const cancelled=fixture();await loaded(cancelled);const write=cancelled.activity.follow('2');cancelled.activity.pause();assert(cancelled.cancelled.length);cancelled.requests.at(-1).resolve({id:'2'});await write;assert.equal(cancelled.feedback.length,0);assert.equal(cancelled.activity.rows[0].activityUncertain,true);
  const stale=fixture();const pending=stale.activity.load();stale.activity.reset();stale.requests[0].resolve(relations());await pending;assert.equal(stale.activity.rows.length,0);assert.equal(stale.activity.ready,false);
  const account=fixture();const old=account.activity.load();account.setSession({...account.session(),accountId:'9'});account.requests.at(-1).resolve(relations());await old;assert.equal(account.activity.rows.length,0,'old account data rejected');
  const failure=fixture();await loaded(failure);const bad=failure.activity.load(true);failure.requests.at(-1).resolve({},'wrong');await bad;assert(failure.activity.error);assert.equal(failure.activity.rows.length,1,'failure preserves rows');
  const retry=failure.activity.load(true);failure.requests.at(-1).resolve([]);await retry;assert.equal(failure.activity.rows.length,0);assert.equal(failure.activity.error,'');
  const invalid=fixture();await loaded(invalid,[{...relations()[0],followed_by_me:'false'}]);assert(invalid.activity.error);assert.equal(invalid.activity.ready,false);
  const net=new Network();let context;net.request=async(job,getContext)=>{context=getContext;return{error:getContext().authenticated?'':'rejected'}};
  const readJob=f.requests[0].job,writeJob=f.requests[1].job;
  for(const [job,target] of [[readJob,''],[writeJob,'2']])assert.equal((await net.requestBusinessInboxActivity(job,f.session,target,()=>true)).error,'');
  const alter=(job,fn)=>{const write=job.method==='POST';const encoded=write?job.body:job.url.split('?')[1];const parts=new URLSearchParams(encoded),body=JSON.parse(parts.get('data'));fn(body);parts.set('data',JSON.stringify(body));const query='source_url='+encodeURIComponent(parts.get('source_url'))+'&data='+encodeURIComponent(JSON.stringify(body));return write?{...job,body:query}:{...job,url:job.url.split('?')[0]+'?'+query};};
  for(const [job,target] of [[{...readJob,id:'bridge_1'},''],[{...readJob,method:'POST'},''],[{...readJob,headers:{...readJob.headers,'X-Pinterest-Pws-Handler':'www/index.js'}},''],[alter(readJob,e=>e.options.data.page_size=50),''],[alter(readJob,e=>e.options.url='/v3/users/2/follow/'),''],[alter(writeJob,e=>e.options.url='/v3/users/3/follow/'),'2'],[writeJob,'3'],[alter(writeJob,e=>e.context.extra=true),'2'],[{...writeJob,url:writeJob.url.replace('/update/','/delete/')},'2']])assert((await net.requestBusinessInboxActivity(job,f.session,target,()=>true)).error,'reject broadened contract');
  assert((await net.requestBusinessInboxActivity(readJob,f.session,'',()=>false)).error);
  let session=f.session();await net.requestBusinessInboxActivity(readJob,()=>session,'',()=>true);session={...session,generation:2};assert.equal(context().authenticated,false);
  const page=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets','utf8');
  assert(page.includes("if (this.section !== 'activity') {\n        Column()"),'activity has no messages/contacts segmented controls');
  assert(page.includes("this.section === 'activity' ? this.snapshot.activities || []"));assert(page.includes("if (this.section === 'activity') return;"));
  assert(page.includes("this.section === 'activity' ? 'pm_activity_title'"));assert(page.includes("this.section === 'activity' ? 0 : this.listHeaderHeight"));
  const root=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8');assert(root.indexOf("this.uiText('pm_activity_title')")<root.indexOf('this.snapshot.messagesLabel ||'));assert(!root.includes("pm_activity_view_all"));
  const activityBlock=root.slice(root.indexOf("this.listTitle(this.uiText('pm_activity_title')"),root.indexOf("if (this.snapshot.section === 'messages' && this.snapshot.items.length > 0)"));
  assert(!activityBlock.includes('LoadingProgress()'),'root activity refresh must not add a second spinner');
  assert.equal((page.match(/this.loading\(\) && this.section !== 'activity'/g)||[]).length,2,'activity list and search keep existing rows without refresh spinners');
  assert(page.includes("this.section === 'activity' && this.loading() && this.rows(false).length === 0"),'initial full-page load remains distinct');
  assert(root.includes('PinmonyInboxActivityRow'));assert(page.includes('PinmonyInboxActivityRow'));
  const activityRow=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxActivityRow.ets','utf8');assert(activityRow.includes("this.onAction('activity-chat:' + this.item.activityUserId)"));assert.equal((activityRow.match(/onClick\(\(\) => this.openChat\(\)\)/g)||[]).length,1,'name retains chat while avatar opens profile');assert(!activityRow.includes('stopPropagation')); assert(activityRow.includes('onClick(() => this.openProfile())'));assert(root.includes('onUser:(url: string) => this.onUser?.(url)'));assert(page.includes('onUser:this.onUser'));
  const methodStart=activityRow.indexOf('  private openProfile():');const methodEnd=activityRow.indexOf('  build()',methodStart);
  const handlers=require('node:vm').runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, 'class ActivityHandlers {'+activityRow.slice(methodStart,methodEnd)+'} ActivityHandlers;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
  const target=new handlers(),profiles=[],actions=[];Object.assign(target,{interactionReady:true,item:{enabled:true,profileUrl:'https://www.pinterest.com/synthetic_peer/',activityUserId:'2'},onUser:url=>profiles.push(url),onAction:id=>actions.push(id)});
  target.openProfile();assert.equal(profiles.length,1);assert.equal(actions.length,0,'avatar must not create a conversation');target.openChat();assert.equal(actions[0],'activity-chat:2');
  actions.length=0;target.performAction();assert.equal(actions.pop(),'activity-follow:2','follow back remains an explicit follow action');
  target.item.activityFollowed=true;target.performAction();assert.equal(actions.pop(),'activity-chat:2','say hello opens existing chat flow without another follow');
  target.item.activityUncertain=true;target.performAction();assert.equal(actions.pop(),'activity-retry','uncertain follow keeps its status check');
  target.item.activityUncertain=false;target.item.activityBusy=true;target.performAction();assert.equal(actions.length,0);
  target.item.activityBusy=false;target.interactionReady=false;target.performAction();assert.equal(actions.length,0);
  target.interactionReady=true;target.item.enabled=false;target.performAction();assert.equal(actions.length,0);target.item.enabled=true;
  assert(activityRow.includes("'pm_activity_say_hello'"));assert(!activityRow.includes('Span('),'username and follower description use separate lines');
  assert(activityRow.indexOf('Text(this.item.title)') < activityRow.indexOf('Text(this.followLabel())'));
  assert(activityRow.indexOf('Text(this.followLabel())') < activityRow.indexOf('Text(this.timeLabel())'),'action sits before far-right time');
  assert(!activityRow.includes('Column({space:8})'),'action and time are horizontal siblings, not stacked');
  assert(/Text\(this.timeLabel\(\)\)[^\n]*\.alignSelf\(ItemAlign.Center\)/.test(activityRow),'single-line activity time is vertically centered');
  assert(activityRow.includes('.padding({left:20,right:20,top:12,bottom:12}).alignItems(VerticalAlign.Center)'),
    'avatar, two-line text, action and time share the row center rather than mixing top and center alignment');
  target.interactionReady=false;target.openProfile();assert.equal(profiles.length,1);target.interactionReady=true;target.item.enabled=false;target.openProfile();assert.equal(profiles.length,1);target.item.enabled=true;target.item.profileUrl='';target.openProfile();assert.equal(profiles.length,1);
  const Controller=loader.loadFile('feature_inbox/src/main/ets/controllers/PinmonyInboxActionsController.ets').PinmonyInboxActionsController;
  let native=0,web=0;const controller=new Controller({}, {allowed:()=>true,enabled:()=>true,nativeOpen:async id=>{native++;return true},runScript:async()=>{web++;return ''}});
  await controller.open('activity-follow:2');await controller.open('activity-retry');await controller.open('activity-chat:2');assert.equal(native,3);assert.equal(web,0,'activity never falls through to Web');
  const Reader=loader.loadFile('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets').PinmonyInboxMessagesNativeReads;
  const store={inboxSession:0,inboxScrollOffset:0,inboxCache:{clear(){},get(){},put(){}}};const liveSession=f.session();let activityRequests=0;
  const respond=(job,endpoint,data)=>({...job,status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data}})});
  const reader=new Reader({store:()=>store,session:()=>liveSession,page:()=>liveSession.origin+'/inbox/',active:()=>true,settled(){},network:()=>({cancel(){},
    requestBusinessInboxActivity:async(job,s,target,current)=>{assert(current());activityRequests++;return respond(job,target?'v3_follow_user_method':'v3_get_inbox_social_relationships',target?{id:target}:relations());},
    requestBusinessInboxMessagesRead:async job=>respond(job,job.url.includes('/ConversationsResource/')?'v3_get_conversations':'v3_user_contacts_suggestion',[])})});
  await reader.demand();assert.equal(store.inbox.activities.length,1,'actual root snapshot includes activity independently of empty conversations');
  assert.equal(await reader.open('activity-follow:2'),true);assert.equal(store.inbox.activities[0].activityFollowed,true);assert.equal(activityRequests,2);
  reader.reset();assert.equal(store.inbox,undefined);assert.equal(reader.activity.rows.length,0);
  console.log('Inbox activity passed: exact read/follow gates, follower-only dedupe, shared list without segments, single-flight, verified follow, unknown/cancel protection, account/reset, empty/error and native dispatch.');
}
const watchdog=setTimeout(()=>{throw Error('Activity regression timed out')},15000);main().then(()=>clearTimeout(watchdog)).catch(error=>{clearTimeout(watchdog);console.error(error);process.exitCode=1});
