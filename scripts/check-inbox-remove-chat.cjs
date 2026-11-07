const assert=require('node:assert/strict'),fs=require('node:fs');
const ts=require(process.argv[2]||'typescript');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const loader=createArktsLoader(ts,{common_foundation:{PinmonyRuntimeLog:{info(){},warn(){}}},common_network:{PIN_BUSINESS_PIN_READ_ENABLED:true}});
const Hidden=loader.loadFile('feature_inbox/src/main/ets/services/PinmonyInboxHiddenConversations.ets').PinmonyInboxHiddenConversations;
const Reader=loader.loadFile('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets').PinmonyInboxMessagesNativeReads;
const Store=loader.loadFile('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets').PinmonyInboxStore;
const origin='https://www.pinterest.com',me={id:'1',username:'self'},peer={id:'2',username:'peer',full_name:'Peer',type:'user_share_suggestion'};
const conversation={id:'100',users:[me,peer],unread:2,last_message:{id:'300',text:'Hello',sender:peer,created_at:'2026-11-07T00:00:00Z'}};
let persisted='[]',saveFails=false;
const save=value=>{if(saveFails)return false;persisted=value;return true;};
function fixture(account='1') {
  const store=new Store(),calls=[],feedback=[];
  let session={authenticated:true,accountId:account,generation:1,origin,userAgent:'synthetic'};
  const reply=(job,endpoint,data)=>({...job,status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data,bookmark:'-end-'},client_context:{user:me}})});
  const reader=new Reader({store:()=>store,session:()=>session,page:()=>origin+'/inbox/',active:()=>true,settled(){},feedback:message=>feedback.push(message),
    network:()=>({cancel(){},requestBusinessInboxActivity:async job=>reply(job,'v3_get_inbox_social_relationships',[]),
      requestBusinessInboxMessagesRead:async(job,s,current)=>{
        assert(current());calls.push(job);assert.equal(job.method,'GET','local delete never makes a write request');
        if(job.url.includes('/ConversationsResource/'))return reply(job,'v3_get_conversations',[conversation]);
        if(job.url.includes('/ShareSuggestionsResource/'))return reply(job,'v3_user_contacts_suggestion',[peer]);
        return job.url.includes('/ConversationMessagesResource/')?reply(job,'v3_get_conversation_messages',[{id:'300',sender:peer,text:'Hello',created_at:'2026-11-07T00:00:00Z'}]):reply(job,'v3_get_conversation',conversation);
      }})});
  return{reader,store,calls,feedback,setSession:s=>session=s};
}
async function main(){
  Hidden.initialize('[]',save);
  const f=fixture();await f.reader.demand();assert.equal(f.store.inbox.items.length,1);assert.equal(f.store.inboxMessagesUnreadCount,2);
  const count=f.calls.length;await f.reader.open('conversation-remove:999');assert.equal(f.store.inbox.items.length,1,'unknown row cannot be removed');
  await f.reader.open('conversation-remove:100');assert.equal(f.calls.length,count,'removal is entirely local');
  assert.equal(f.store.inbox.items.length,0);assert.equal(f.store.inboxMessagesUnreadCount,0);assert.equal(f.store.inbox.contacts.length,1);
  assert(Hidden.hidden(origin,'1','100'));assert(!Hidden.hidden(origin,'9','100'));assert(!Hidden.hidden('https://uk.pinterest.com','1','100'));
  const isolated=fixture('9');await isolated.reader.demand();assert.equal(isolated.store.inbox.items.length,1,'another account retains its own conversation window');
  const Unread=loader.loadFile('entry/src/main/ets/app/PinmonyInboxUnreadNativeReads.ets').PinmonyInboxUnreadNativeReads;
  const unreadStore=new Store();unreadStore.inboxMessagesUnreadCount=2;
  const unread=new Unread({store:()=>unreadStore,active:()=>true,session:()=>({authenticated:true,accountId:'1',generation:1,origin}),network:()=>({cancel(){},
    requestBusinessInboxMessagesRead:async job=>({...job,status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_get_conversations',data:[conversation]}})})})});
  await unread.pollMessages();assert.equal(unreadStore.inboxMessagesUnreadCount,0,'off-page polling cannot restore hidden conversation badges');
  await f.reader.refresh();assert.equal(f.store.inbox.items.length,0,'refresh must not resurrect a deleted window');
  f.reader.reset();Hidden.initialize(persisted,save);
  const restarted=fixture();await restarted.reader.demand();assert.equal(restarted.store.inbox.items.length,0,'restart restores local removal');
  await restarted.reader.open('contact:2');assert.equal(restarted.store.inboxFlow.screen,'chat');
  assert.equal(restarted.store.inboxFlow.messages[0].text,'Hello','chat history is preserved');
  assert(!Hidden.hidden(origin,'1','100'),'opening contact restores the conversation');
  await restarted.reader.action('back');await new Promise(setImmediate);
  assert.equal(restarted.store.inbox.items.length,1,'return from reopened chat restores its list window');
  const lateRefresh=restarted.reader.refresh();await restarted.reader.open('conversation-remove:100');await lateRefresh;
  assert.equal(restarted.store.inbox.items.length,0,'already in-flight refresh respects the current local removal');
  Hidden.setHidden(origin,'1','100',false);restarted.reader.apply();
  saveFails=true;await restarted.reader.open('conversation-remove:100');assert.equal(restarted.store.inbox.items.length,1,'storage failure must not pretend deletion succeeded');assert.equal(restarted.feedback.length,1);saveFails=false;
  Hidden.initialize('broken',save);assert(!Hidden.hidden(origin,'1','100'));
  assert(!Hidden.setHidden(origin,'1','bad',true));
  const swipe=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxConversationSwipe.ets','utf8');
  assert(!swipe.includes('PanGesture('));assert(!swipe.includes('.translate('));assert(!swipe.includes("height('100%')"),'action must not stretch the row to viewport height');
  assert(swipe.includes('sys.symbol.trash'));assert(swipe.includes('pm_remove_chat_window'));
  const Controller=loader.loadFile('feature_inbox/src/main/ets/controllers/PinmonyInboxActionsController.ets').PinmonyInboxActionsController;
  let legacyCalls=0;const controller=new Controller({}, {allowed:()=>true,enabled:()=>true,nativeOpen:async()=>false,prepare:async()=>{legacyCalls++;return true;},runScript:async()=>{legacyCalls++;return 'true';}});
  await controller.open('conversation-remove:100');assert.equal(legacyCalls,0,'local removal must never fall back to a website click or write');
  for(const name of ['PinmonyInboxPage','PinmonyInboxListPage']) {
    const source=fs.readFileSync('feature_inbox/src/main/ets/components/'+name+'.ets','utf8');
    assert(source.includes('List({ scroller: this.scroller'));assert(source.includes('ListItem() {'));
    assert(source.includes('.swipeAction({ end:'));assert(source.includes('builder: () => { this.removeConversationAction(item); }'));
    assert(source.includes('closeAllSwipeActions()'));assert(source.includes('TouchType.Cancel'));
    assert(!source.includes('Scroll(this.scroller)'));assert(!source.includes('onSwiping:'));assert(source.includes('if(this.conversationSwipeActive)return;'),'row swipe cannot also switch message/contact segments');
  }
  const listSource=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets','utf8');
  assert(listSource.includes('List({ scroller: this.searchScroller, space: 8 })'));
  const rootSource=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8');
  assert(rootSource.includes('.onDidScroll((offset: number, state: ScrollState)'));
  assert(!rootSource.includes('.contentStartOffset('), 'restoring offset zero must retain the physical title inset');
  assert(rootSource.includes('.padding({ top: this.inboxTopInset() })'));
  assert(rootSource.includes('.padding({ bottom: 120 })'));
  assert(!listSource.includes('.contentStartOffset('), 'full list and search use physical header spacers');
  console.log('Local chat removal: no server writes, preview/list/search reuse, contacts restore existing history, refresh/restart, account/origin isolation, failure and unread counts passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
