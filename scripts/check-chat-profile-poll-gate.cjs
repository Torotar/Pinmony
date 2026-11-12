const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm');
const ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:withLocalMessages(name=>name==='feature_inbox'?load('feature_inbox/src/main/ets/services/PinmonyInboxHiddenConversations.ets'):deps(name)),setTimeout,clearTimeout,console});return exports;}
const {PinmonyInboxCache:Cache}=load('feature_inbox/src/main/ets/services/PinmonyInboxCache.ets');
const {PinmonyInboxMessagesNativeReads:Reader}=load('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets',name=>name==='./PinmonyInboxActivityNativeReads'?load('entry/src/main/ets/app/PinmonyInboxActivityNativeReads.ets'):name==='./PinmonyInboxNativeWrites'?load('entry/src/main/ets/app/PinmonyInboxNativeWrites.ets',n=>n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{}):name==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:name==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',name=>name==='common_session'?{PinmonySessionCredentials:class{}}:{});
const Store=require('./arkts-module-loader.cjs').createArktsLoader(ts).loadFile('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets').PinmonyInboxStore;
const me={id:'1',username:'self',full_name:'Self'},peer={id:'2',username:'peer',full_name:'Peer',image_medium_url:'https://i.pinimg.com/avatar.jpg',type:'user_share_suggestion'};
const conversation=(id='100')=>({id,name:'Self、Peer',users:[me,peer],unread:1,last_message:{text:'hello',created_at:'2026-10-13T00:01:00Z',sender:peer}});
const message=(id,minute=1)=>({id:String(id),text:'hello',created_at:'2026-10-13T00:'+String(minute).padStart(2,'0')+':00Z',sender:peer,reactions:[{'2':'👍'}],board:{id:'50',url:'/peer/ideas/',name:'Ideas',pin_count:5,pin_thumbnail_urls:['https://i.pinimg.com/pin.jpg']}});
const body=(endpoint,data,bookmark='-end-')=>JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data,bookmark}});
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){let session={authenticated:true,accountId:'1',generation:1,origin:'https://www.pinterest.com',userAgent:'synthetic'},page=session.origin+'/inbox/',active=true;const store=Object.assign(new Store(),{inboxSession:0,inboxCache:new Cache(),inboxScrollOffset:62,inboxActionsReady:false}),requests=[],cancelled=[];const network={cancel:id=>cancelled.push(id),requestBusinessInboxActivity:async job=>({...job,status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_get_inbox_social_relationships',data:[]}})}),requestBusinessInboxMessagesRead:(job,s,current)=>{assert(current());return new Promise(resolve=>requests.push({job,current,resolve:(body,status=200,error='')=>resolve({...job,body,status,error})}));}};const reader=new Reader({store:()=>store,session:()=>session,page:()=>page,active:()=>active,network:()=>network,settled(){}});return{reader,store,requests,cancelled,session:()=>session,setSession:s=>session=s,page:()=>page,setPage:p=>page=p,setActive:v=>active=v};}
async function start(f){const pending=f.reader.demand();assert.equal(f.requests.length,2);f.requests[0].resolve(body('v3_get_conversations',[conversation(),conversation()]));f.requests[1].resolve(body('v3_user_contacts_suggestion',[peer,peer]));await pending;}
async function chat(f,cursor='older'){const pending=f.reader.open('conversation:100');assert.equal(f.store.inboxMessagesUnreadCount,0,'chat entry clears before network resolves');assert.equal(f.store.inbox.items[0].unreadCount,0,'row clears before back');assert(f.requests.at(-1).job.url.includes('/ApiResource/get/'));f.requests.at(-1).resolve(body('v3_get_conversation',conversation()));await flush();f.requests.at(-1).resolve(body('v3_get_conversation_messages',[message(300,2),message(300,2)],cursor));await pending;}
async function main(){
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const readerHostBlock=indexSource.slice(indexSource.indexOf('private readonly inboxMessagesNativeReads:'),indexSource.indexOf('} as PinmonyInboxMessagesNativeReadsPorts)'));
const activeExpression=readerHostBlock.match(/active: \(\): boolean => ([^\r\n]+),/)[1];
const coveredHost={authStatus:'authenticated',businessSuspended:false,noticeChats:[],chatProfileTransition:false,profileChatActive:false,profileStore:{origins:[]},activeTab:2,pinStore:{},boardStore:{},activeSheetKind:''};
const hostActive=Function('return '+activeExpression).bind(coveredHost);
const covered=fixture();await start(covered);await chat(covered);
covered.reader.ports.active=hostActive;
const retained=covered.store.inboxFlow;const retainedMessages=retained.messages;const retainedOffset=covered.store.inboxScrollOffset;
let pendingCovered=covered.reader.poll();const coveredRequest=covered.requests.at(-1);const requestCount=covered.requests.length;
coveredHost.chatProfileTransition=true;coveredHost.profileStore.origins.push({});
assert.equal(covered.reader.owned(),false,'actual host port loses ownership while profile covers chat');
await covered.reader.poll();assert.equal(covered.requests.length,requestCount,'covered chat dispatch is paused');
coveredRequest.resolve(body('v3_get_conversation_messages',[message(999,4)]));await pendingCovered;
assert.equal(covered.store.inboxFlow,retained);assert.equal(retained.messages,retainedMessages,'late response cannot mutate retained messages');
assert.equal(covered.store.inboxScrollOffset,retainedOffset);assert.equal(covered.reader.flowBusy,false,'late response releases read slot');
coveredHost.chatProfileTransition=false;
assert.equal(hostActive(),false,'nested profile keeps root chat inactive');
coveredHost.profileChatActive=true;assert.equal(hostActive(),true,'profile contact chat remains eligible');
coveredHost.profileChatActive=false;coveredHost.profileStore.origins=[];
pendingCovered=covered.reader.poll();assert.equal(covered.requests.length,requestCount+1,'return resumes retained chat reader');
covered.requests.at(-1).resolve(body('v3_get_conversation_messages',[message(300,2),message(301,3)]));await pendingCovered;
assert.equal(covered.store.inboxFlow.messages.length,2,'returned chat receives new messages');
const foregroundStart=indexSource.indexOf('  private pollVisibleInbox('),foregroundEnd=indexSource.indexOf('\n  private startupBuildLogged',foregroundStart);const RouteHost=vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, 'class RouteHost {'+indexSource.slice(foregroundStart,foregroundEnd)+'} RouteHost;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_INBOX_CHAT_POLL_MS:1000,PIN_INBOX_MESSAGES_POLL_MS:2000});const route=new RouteHost();Object.assign(route,{authStatus:'authenticated',noticeChats:[],boardInvitationNotice:{poll(){}},inboxMessageNotice:{consumeTap(){},dismissViewed(){}}});
let coveredUnread=0,coveredBody=0;Object.assign(route,{businessSuspended:false,activeTab:2,profileChatActive:false,chatProfileTransition:true,profileStore:{origins:[{}]},inboxPagePollMode:'chat',inboxUnreadNativeReads:{pollMessages(){coveredUnread++},poll(){coveredUnread++}},inboxMessagesNativeReads:{owned(){return true},eligible(){return true},poll(){coveredBody++}},inboxUpdatesNativeReads:{eligible(){return false}},inboxStore:{inboxFlow:{screen:'chat'}},inboxPagePollDue(){return true}});
route.pollVisibleInbox();assert.equal(coveredBody,0);assert.equal(coveredUnread,1);assert.equal(route.inboxPagePollMode,'','cover resets page cadence');
route.chatProfileTransition=false;route.pollVisibleInbox();assert.equal(coveredBody,0,'nested profile remains covered');
route.profileChatActive=true;route.pollVisibleInbox();assert.equal(coveredBody,1,'profile contact chat can poll');
route.profileChatActive=false;route.profileStore.origins=[];route.pollVisibleInbox();assert.equal(coveredBody,2,'return resumes visible root chat');
route.chatProfileTransition=true;route.inboxMessagesNativeReads.eligible=()=>false;route.runSessionScript=()=>{throw Error('covered legacy dispatch')};route.pollVisibleInbox();assert.equal(coveredBody,2,'legacy dispatch is covered too');
console.log('Chat profile gate: actual host ownership, covered polling, late response, retained state, nested profiles and return resume passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
