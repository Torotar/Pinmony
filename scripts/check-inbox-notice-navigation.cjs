const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
let now=1000000,active=true,polls=0;
class PollDate extends Date { static now(){return now;} }
const currentSession={authenticated:true,accountId:'self',generation:1,origin:'https://www.pinterest.com'};
const chatExports={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxNoticeChatSession.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:chatExports,Date:PollDate,require:name=>name==='feature_inbox'?{PinmonyInboxStore:class{}}:name.includes('UnreadNativeReads')?{PIN_INBOX_CHAT_POLL_MS:1000}:{PinmonyInboxMessagesNativeReads:class{poll(){polls++;}}}});
const timedChat=new chatExports.PinmonyInboxNoticeChatSession('cadence','100',{session:()=>({...currentSession}),active:()=>active});
timedChat.poll();assert.equal(polls,1);now+=999;timedChat.poll();assert.equal(polls,1,'notice chat waits until one second');now++;timedChat.poll();assert.equal(polls,2,'notice chat polls at one second');
now+=1000;active=false;timedChat.poll();assert.equal(polls,2,'covered chat cannot poll');active=true;currentSession.generation++;timedChat.poll();assert.equal(polls,2,'old session cannot poll');
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=index.indexOf('  private openNoticeChat('),end=index.indexOf('  private readonly inboxMessageNotice:',start);
assert(start>0&&end>start);
class Scene {
  constructor(key,conversation,ports){Object.assign(this,{key,conversation,ports,store:{inboxFlow:{screen:'chat',conversationId:conversation},chatScrollOffset:0},opens:0,pauses:0,resets:0,resumes:0});}
  open(){this.opens++;return Promise.resolve(true);}
  pause(){this.pauses++;}
  reset(){this.resets++;this.store.inboxFlow=undefined;}
  resume(){this.resumes++;}
  action(action){this.lastAction=action;if(action==='back')this.store.inboxFlow.screen='chat';return Promise.resolve(true);}
}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+index.slice(start,end)+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyInboxNoticeChatSession:Scene,Curve:{EaseOut:'ease'}});
function fixture(){const h=new Host(),timeouts=[];let focusClears=0;const session={authenticated:true,accountId:'self',generation:1,origin:'https://www.pinterest.com'};
  Object.assign(h,{noticeChats:[],noticeChatSequence:0,authStatus:'authenticated',businessSuspended:false,activeSheetKind:'',boardRecoveryVisible:false,
    activeTab:1,authenticatedProfileUrl:'https://www.pinterest.com/self/',inboxStore:{inboxFlow:{screen:'chat',conversationId:'9',draft:'source draft'},chatScrollOffset:341},
    homeStore:{offset:872,items:[{id:'source'}]},searchStore:{query:'原搜索',offset:415},pinStore:{detail:{pinId:'123',offset:230}},
    coordinatorTasks:{timeout:(fn,ms)=>{assert.equal(ms,180);timeouts.push(fn);}},
    getUIContext:()=>({animateTo:(_,fn)=>fn(),getFocusController:()=>({clearFocus:()=>focusClears++})}),
    nativeBusinessSessionContext:()=>session,showMessage(){}});
  return {h,timeouts,session,focusClears:()=>focusClears};}
const f=fixture(),h=f.h;const original={home:h.homeStore,search:h.searchStore,pin:h.pinStore.detail,inbox:h.inboxStore,flow:h.inboxStore.inboxFlow};
assert.equal(h.openNoticeChat('bad'),false);assert.equal(h.noticeChats.length,0);
h.activeSheetKind='comments';assert.equal(h.openNoticeChat('100'),false);h.activeSheetKind='';
h.inboxStore.inboxFlow.sending=true;assert.equal(h.openNoticeChat('100'),false);h.inboxStore.inboxFlow.sending=false;
assert.equal(h.openNoticeChat('100'),true);const first=h.noticeChats[0];assert.equal(first.opens,1);assert(first.ports.active());
assert.equal(h.openNoticeChat('100'),true);assert.equal(h.noticeChats.length,1,'duplicate notification keeps the existing scene');
first.store.chatScrollOffset=0;assert.equal(h.openNoticeChat('200'),true);const second=h.noticeChats[1];
assert.equal(first.pauses,1);assert.equal(first.ports.active(),false);assert.equal(second.ports.active(),true);
h.noticeChatAction(first,'back');assert.equal(h.noticeChats.length,2,'covered scenes cannot handle the top back');
second.store.inboxFlow.screen='settings';h.noticeChatAction(second,'back');assert.equal(h.noticeChats.length,2,'settings returns to the same chat');assert.equal(second.store.inboxFlow.screen,'chat');
h.noticeChatAction(second,'back');assert.equal(h.noticeChats.length,1);assert.equal(h.noticeChats[0],first);assert.equal(first.store.chatScrollOffset,0,'top position survives nested notifications');
assert.equal(second.store.inboxFlow.screen,'chat','outgoing frame remains available throughout the exit transition');f.timeouts.shift()();assert.equal(second.resets,1);
h.noticeChatAction(first,'back');assert.equal(h.noticeChats.length,0);f.timeouts.shift()();
assert.equal(h.activeTab,1);assert.equal(h.homeStore,original.home);assert.equal(h.searchStore,original.search);assert.equal(h.searchStore.offset,415);
assert.equal(h.pinStore.detail,original.pin);assert.equal(h.inboxStore,original.inbox);assert.equal(h.inboxStore.inboxFlow,original.flow);assert.equal(h.inboxStore.chatScrollOffset,341);assert.equal(original.flow.draft,'source draft');
assert(f.focusClears()>=3,'covered input focus is released without clearing source drafts');
h.openNoticeChat('300');h.pauseNoticeChats();assert.equal(h.noticeChats[0].pauses,1);h.resetNoticeChats();assert.equal(h.noticeChats.length,0);
const page=fs.readFileSync('entry/src/main/ets/components/PinmonyInboxNoticeChatPage.ets','utf8');
assert(page.includes('chatReturnConversation === this.store.inboxFlow.conversationId ? this.store.chatScrollOffset : -1'),'zero scroll offset must not become the latest-message sentinel');
assert(index.includes(".enabled(this.noticeChats.length === 0)"));assert(index.includes(".accessibilityLevel(this.noticeChats.length ? 'no-hide-descendants' : 'auto')"));
assert(index.includes('Stack() { this.buildMainScene() }'),'source UI stays mounted without replacing a source store or root tab');
assert(index.includes("if(this.noticeChats.length) { this.noticeChatAction(this.noticeChats[this.noticeChats.length - 1],'back'); return true; }"));
const ability=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');assert.equal((ability.match(/PinmonyInboxNoticeTap.receive\(want\)/g)||[]).length,2);
console.log('Notice navigation: independent existing-chat route, retained source page/stores/draft/scroll, nested chat/settings return, delayed exit cleanup, focus, lifecycle and both ability intents passed');
