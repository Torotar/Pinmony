const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/app/PinmonyInboxMessageNotice.ets', 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
let now = Date.parse('2026-11-07T08:00:00Z');
class TestDate extends Date { static now() { return now; } }
function fixture(recovery, earlyWant) {
  let active = true, background = false, visible = '', viewed = '', enabled = true, language = 'zh', permissionCalls = 0, failPublish = false, failCancel = false;
  let session = { authenticated: true, accountId: 'self', generation: 1, origin: 'https://www.pinterest.com' };
  let permissionGate, wantGate, publishGate;
  let avatarResult, avatarGate, canOpen = true, visibleBoard = ''; const openedInvitations = [];
  const opened = [], avatarReads = [];
  const tapExports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxNoticeTap.ets','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText, {exports:tapExports,require:()=>({})});
  const published = [], cancelled = [], exports = {};
  const manager = {
    SlotType: { SOCIAL_COMMUNICATION: 1 }, ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 0 },
    cancel: async id => { cancelled.push(id); if(failCancel)throw Error('synthetic cancellation'); }, isNotificationEnabled: async () => enabled,
    requestEnableNotification: async () => { permissionCalls++; if (permissionGate) await permissionGate; },
    publish: async request => { if (failPublish) throw Error('synthetic'); published.push({...request}); if (publishGate) await publishGate; }
  };
  vm.runInNewContext(compiled, { exports, Date: TestDate, require: name => name === './PinmonyInboxNoticeAvatar' ? { PinmonyInboxNoticeAvatar: class { cancel() {} async read(url) { if(!url)return;avatarReads.push(url); if(avatarGate)await avatarGate;return avatarResult; } } } : name === './PinmonyInboxNoticeRecovery' ? { PinmonyInboxNoticeRecovery: recovery || { save: async()=>{}, read: async()=>undefined, consume(){}, clear(){} } } : name === './PinmonyInboxNoticeTap' ? tapExports : name === '@kit.NotificationKit' ? { notificationManager: manager } : name === '@kit.AbilityKit' ? {
    wantAgent: { getWantAgent: async info => { if (wantGate) await wantGate; return info; }, OperationType: { START_ABILITY: 0 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 0 } }
  } : name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {}, warn() {} }, PinmonyI18n: { format: (key,args) => { assert.equal(key,'pm_board_invitation_notice_body'); assert.equal(args.length,1); return language === 'zh' ? '邀请你在'+args[0]+'上进行合作' : 'Invited you to collaborate on '+args[0]; }, message: () => language === 'zh' ? '新消息' : 'New message' } } : {} });
  if(earlyWant)tapExports.PinmonyInboxNoticeTap.receive(earlyWant);
  const notice = new exports.PinmonyInboxMessageNotice({ session: () => session, active: () => active, deliveryActive: () => background, username: () => 'self', visibleConversation: () => visible, viewedConversation:()=>viewed, context: () => ({ applicationInfo: { name: 'com.synthetic.pinmony' } }),visibleInvitationBoard:()=>visibleBoard,openInvitation:item=>{if(!canOpen)return false;openedInvitations.push(item);return true;},openChat:id=>{if(!canOpen)return false;opened.push(id);return true;} });
  return { notice, published, cancelled, setActive: v => active = v, setVisible: v => visible = v, setEnabled: v => enabled = v,
    setSession: v => session = v, setLanguage: v => language = v, setBackground: v => background = v, permissionCalls: () => permissionCalls,
    setPermissionGate: v => permissionGate = v, setWantGate: v => wantGate = v, setPublishGate: v => publishGate = v, failPublish: v => failPublish = v,
    setViewed:v=>viewed=v,failCancel:v=>failCancel=v,
    openedInvitations,setVisibleBoard:v=>visibleBoard=v,opened,avatarReads,receive:want=>tapExports.PinmonyInboxNoticeTap.receive(want),setCanOpen:v=>canOpen=v,setAvatar:(pixels,gate)=>{avatarResult=pixels;avatarGate=gate;} };
}
const row = (id, message, extra = {}) => ({ id, unread: 1, users: [{ id: '2', full_name: '发送者原文' }], last_message: {
  id: message, created_at: new Date(now).toISOString(), sender: { id: '2', username: 'peer' }, text: '消息原文', ...extra
} });
const settle = f => f.notice.queue;
const turn = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const invitation = (id='81') => ({boardId:id,boardUrl:'https://www.pinterest.com/peer/art/',boardName:'原图板',inviter:'原用户',inviterAvatar:'https://i.pinimg.com/avatar.jpg',invitedUser:'41',createdAt:'',status:'new'});
  const inv=fixture();inv.notice.observeInvitations([invitation()]);await settle(inv);
  assert.equal(inv.published.length,1);assert.equal(inv.published[0].id,7201);assert.equal(inv.published[0].notificationSlotType,1);
  assert.equal(inv.published[0].content.normal.title,'原用户');assert.equal(inv.published[0].content.normal.text,'邀请你在原图板上进行合作');
  inv.notice.observeInvitations([invitation()]);await settle(inv);assert.equal(inv.published.length,1);
  inv.setCanOpen(false);inv.receive({parameters:inv.published[0].wantAgent.wants[0].parameters});inv.notice.dismissForeground();await settle(inv);inv.setCanOpen(true);inv.notice.consumeTap();assert.equal(inv.openedInvitations[0].boardId,'81');assert.equal(inv.opened.length,0);
  const removed=fixture();let releaseInvite;removed.setWantGate(new Promise(r=>releaseInvite=r));removed.notice.observeInvitations([invitation()]);await turn();removed.notice.observeInvitations([]);releaseInvite();await settle(removed);assert.equal(removed.published.length,0,'removed invitation cannot publish late');
  const mixed=fixture();mixed.notice.observe([]);mixed.notice.observeInvitations([invitation()]);await settle(mixed);now+=10000;mixed.notice.observe([row('100','900')]);mixed.notice.observeInvitations([]);await settle(mixed);assert.equal(mixed.notice.publishedConversation,'100','removal cannot cancel newer chat');
  const visibleInvite=fixture();visibleInvite.setVisibleBoard(invitation().boardUrl);visibleInvite.notice.observeInvitations([invitation()]);await settle(visibleInvite);assert.equal(visibleInvite.published.length,0);
  const localeInvite=fixture();localeInvite.notice.observeInvitations([invitation()]);localeInvite.setLanguage('en');await settle(localeInvite);assert.equal(localeInvite.published[0].content.normal.text,'Invited you to collaborate on 原图板');
  const avatarInvite=fixture();let avatarReleased=0;const pixelsInvite={release:async()=>avatarReleased++};avatarInvite.setAvatar(pixelsInvite);avatarInvite.notice.observeInvitations([invitation()]);await turn();await settle(avatarInvite);assert.equal(avatarInvite.published.length,2);assert.equal(avatarInvite.published[1].largeIcon,pixelsInvite);assert.equal(avatarInvite.published[1].isAlertOnce,true);assert.equal(avatarReleased,1);
  const hiddenInvite=fixture();hiddenInvite.setActive(false);hiddenInvite.setBackground(true);hiddenInvite.notice.observeInvitations([invitation()]);await settle(hiddenInvite);assert.equal(hiddenInvite.published.length,0);
  const f = fixture(); f.notice.observe([row('100', '1')]); await settle(f); assert.equal(f.published.length, 0, 'old unread messages establish a silent baseline');
  now += 10000; f.notice.observe([row('100', '2')]); await settle(f); assert.equal(f.published.length, 1);
  const request = f.published[0]; assert.equal(request.content.normal.title, '发送者原文'); assert.equal(request.content.normal.text, '消息原文');
  assert.equal(request.deliveryTime, now); assert.equal(request.notificationSlotType, 1); assert.equal(request.wantAgent.wants[0].abilityName, 'EntryAbility');
  f.notice.observe([row('100', '2')]); await settle(f); assert.equal(f.published.length, 1, 'same latest ID and same unread count never repeats');
  now += 10000; f.notice.observe([row('100', '3')]); await settle(f); assert.equal(f.published.length, 2, 'new message with unchanged unread count is detected');
  f.notice.observe([row('100', '2', { created_at: new Date(now).toISOString() })]); await settle(f); assert.equal(f.published.length, 2, 'overlapping readers cannot replay an already seen ID even with equal timestamps');
  f.setVisible('100'); now += 10000; f.notice.observe([row('100', '4')]); await settle(f); assert.equal(f.published.length, 2, 'current chat is quiet');
  f.setVisible(''); f.notice.observe([row('100', '4')]); await settle(f); assert.equal(f.published.length, 2, 'leaving chat does not replay suppressed messages');
  now += 10000; f.notice.observe([row('100', '5', { sender: { id: '1', username: 'self' } })]); await settle(f); assert.equal(f.published.length, 2, 'outgoing messages are quiet');
  now += 10000; f.notice.observe([row('100', '6', { deleted_by: {} })]); await settle(f); assert.equal(f.published.length, 2, 'deleted messages are quiet');
  now += 10000; f.notice.observe([row('100', '7', { text: '' })]); f.setLanguage('en'); await settle(f); assert.equal(f.published.at(-1).content.normal.text, 'New message', 'fallback resolves language at delivery');
  f.notice.observe([row('100', '1', { created_at: new Date(now - 90000).toISOString() })]); await settle(f); assert.equal(f.published.length, 3, 'older response cannot roll back the latest message');
  now += 10000; f.notice.observe([row('200', '8')]); await settle(f); assert.equal(f.published.length, 4, 'a new conversation also notifies');
  f.notice.observe([row('300', '9', { created_at: new Date(now - 90000).toISOString() })]); await settle(f); assert.equal(f.published.length, 4, 'old conversations appearing later do not notify');
  f.setActive(false); now += 10000; f.notice.observe([row('100', '10')]); await settle(f); assert.equal(f.published.length, 4);
  f.setActive(true); f.notice.observe([row('100', '10')]); f.notice.pause(); await settle(f); assert.equal(f.published.length, 4, 'suspension cancels queued delivery');
  f.notice.reset(); f.setSession({ authenticated: true, accountId: 'other', generation: 2, origin: 'https://www.pinterest.com' });
  f.notice.observe([row('100', '11')]); await settle(f); assert.equal(f.published.length, 4, 'account change rebaselines and clears old notifications');
  const denied = fixture(); denied.setEnabled(false); denied.notice.observe([]); now += 10000;
  denied.notice.observe([row('100', '1')]); await settle(denied); denied.notice.observe([row('100', '2')]); await settle(denied);
  assert.equal(denied.permissionCalls(), 1); assert.equal(denied.published.length, 0, 'permission denial does not loop or claim success');
  denied.setEnabled(true); denied.notice.observe([row('100', '3')]); await settle(denied); assert.equal(denied.published.length, 1, 'manual system authorization is respected');
  const race = fixture(); race.notice.observe([]); await settle(race); let release; race.setWantGate(new Promise(resolve => release = resolve));
  now += 10000; race.notice.observe([row('100', '1')]); await turn(); race.setActive(false); race.notice.pause(); release(); await settle(race);
  assert.equal(race.published.length, 0, 'late platform callbacks cannot publish in background');
  const failed = fixture(); failed.notice.observe([]); await settle(failed); failed.failPublish(true); now += 10000; failed.notice.observe([row('100', '1')]); await settle(failed);
  failed.failPublish(false); failed.notice.observe([row('100', '2')]); await settle(failed); assert.equal(failed.published.length, 1, 'publish failure does not break future messages or replay old writes');
  for (const bad of [null, {}, { id: 3 }, row('100', '3', { sender: { id: '2', full_name: {} }, text: {} }), row('100', '4', { created_at: 'bad' })]) failed.notice.observe([bad]);
  await settle(failed);
  const tap = fixture(); tap.notice.observe([]); now += 10000; tap.notice.observe([row('100','20')]); await settle(tap);
  const parameters = tap.published[0].wantAgent.wants[0].parameters;
  assert.deepEqual(Object.keys(parameters),['pinmonyMessageNotice'],'intent carries only an opaque capability');
  tap.receive({parameters:{pinmonyMessageNotice:'forged'}}); tap.notice.consumeTap(); assert.equal(tap.opened.length,0);
  tap.setActive(false); tap.receive({parameters}); tap.notice.consumeTap(); assert.equal(tap.opened.length,0);
  tap.setActive(true); tap.setCanOpen(false); tap.notice.consumeTap(); assert.equal(tap.opened.length,0,'modal and in-flight writes defer the intent');
  tap.setCanOpen(true); tap.notice.consumeTap(); assert.equal(tap.opened[0],'100'); tap.receive({parameters}); tap.notice.consumeTap(); assert.equal(tap.opened.length,1,'a consumed notification cannot be replayed');
  now += 10000; tap.notice.observe([row('100','21')]); await settle(tap); const stale = tap.published.at(-1).wantAgent.wants[0].parameters;
  tap.notice.reset();tap.receive({parameters:stale});tap.notice.consumeTap();assert.equal(tap.opened.length,1,'logout revokes old capabilities');
  const deferred=fixture();deferred.notice.observe([]);now+=10000;deferred.notice.observe([row('100','22')]);await settle(deferred);
  deferred.setCanOpen(false);deferred.receive({parameters:deferred.published[0].wantAgent.wants[0].parameters});
  now+=10000;deferred.notice.observe([row('200','23')]);await settle(deferred);deferred.setCanOpen(true);deferred.notice.consumeTap();
  assert.equal(deferred.opened[0],'100','a newer notification cannot overwrite the conversation the user already clicked');
  const avatar = fixture(); let releases=0; const pixels={release:async()=>releases++}; avatar.setAvatar(pixels);
  avatar.notice.observe([]); now+=10000; avatar.notice.observe([row('100','30',{sender:{id:'2',full_name:'头像用户',image_small_url:'https://i.pinimg.com/avatar.jpg'}})]);
  await turn(); await settle(avatar); assert.equal(avatar.published.length,2);assert.equal(avatar.published[1].largeIcon,pixels);assert.equal(avatar.published[1].isAlertOnce,true,'avatar update never sounds a second alert');assert.equal(releases,1);
  const clicked = fixture(); let finishAvatar, lateReleases=0; clicked.setAvatar({release:async()=>lateReleases++},new Promise(resolve=>finishAvatar=resolve));
  clicked.notice.observe([]);now+=10000;clicked.notice.observe([row('100','31',{sender:{id:'2',full_name:'头像用户',image_small_url:'https://i.pinimg.com/avatar.jpg'}})]);await turn();
  clicked.receive({parameters:clicked.published[0].wantAgent.wants[0].parameters});clicked.notice.consumeTap();finishAvatar();await turn();await settle(clicked);
  assert.equal(clicked.published.length,1,'a late avatar cannot resurrect a clicked notification');assert.equal(lateReleases,1);
  const hidden=fixture();assert.equal(hidden.notice.readyForBackground(),false);hidden.notice.observe([]);assert.equal(hidden.notice.readyForBackground(),true);
  hidden.setActive(false);hidden.setBackground(true);hidden.setVisible('100');now+=10000;hidden.notice.observe([row('100','40')]);await settle(hidden);
  assert.equal(hidden.published.length,1,'a chat left underneath the background is no longer visible and must notify');
  hidden.receive({parameters:hidden.published[0].wantAgent.wants[0].parameters});assert.equal(hidden.opened.length,0,'a live background reader cannot navigate while hidden');
  hidden.setActive(true);hidden.setBackground(false);hidden.notice.consumeTap();assert.equal(hidden.opened[0],'100','foreground resumes the exact tapped chat');
  const hiddenDenied=fixture();hiddenDenied.notice.observe([]);hiddenDenied.setActive(false);hiddenDenied.setBackground(true);hiddenDenied.setEnabled(false);now+=10000;hiddenDenied.notice.observe([row('100','41')]);await settle(hiddenDenied);
  assert.equal(hiddenDenied.permissionCalls(),0,'background cannot open a permission dialog');assert.equal(hiddenDenied.published.length,0);
  let finishHidden;const expiry=fixture();expiry.notice.observe([]);expiry.setActive(false);expiry.setBackground(true);expiry.setWantGate(new Promise(resolve=>finishHidden=resolve));now+=10000;expiry.notice.observe([row('100','42')]);await turn();expiry.setBackground(false);expiry.notice.pause();finishHidden();await settle(expiry);assert.equal(expiry.published.length,0,'stopped background work cannot publish late');
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const foreground=fixture();foreground.notice.observe([]);await settle(foreground);now+=10000;foreground.notice.observe([row('100','70')]);await settle(foreground);const beforeForeground=foreground.cancelled.length;
  foreground.notice.dismissForeground();await settle(foreground);assert.equal(foreground.cancelled.length,beforeForeground+1,'opening the app clears its notice without entering a chat');assert.equal(foreground.notice.publishedConversation,'');
  const foregroundRace=fixture();foregroundRace.notice.observe([]);await settle(foregroundRace);let finishForeground;foregroundRace.setPublishGate(new Promise(resolve=>finishForeground=resolve));now+=10000;foregroundRace.notice.observe([row('100','71')]);await turn();foregroundRace.notice.dismissForeground();finishForeground();await settle(foregroundRace);assert.equal(foregroundRace.notice.publishedConversation,'','foreground invalidates a background SDK publication already in flight');
  const foregroundTap=fixture();foregroundTap.notice.observe([]);await settle(foregroundTap);now+=10000;foregroundTap.notice.observe([row('100','72')]);await settle(foregroundTap);foregroundTap.setActive(false);foregroundTap.receive({parameters:foregroundTap.published[0].wantAgent.wants[0].parameters});foregroundTap.notice.dismissForeground();await settle(foregroundTap);foregroundTap.setActive(true);foregroundTap.notice.consumeTap();assert.equal(foregroundTap.opened[0],'100','clearing on app entry preserves the already clicked chat target');
  const coldBackground=fixture();coldBackground.setActive(false);coldBackground.setBackground(true);coldBackground.notice.observe([row('100','73')]);await settle(coldBackground);assert.equal(coldBackground.published.length,0,'first background read establishes a silent baseline');now+=10000;coldBackground.notice.observe([row('100','74')]);await settle(coldBackground);assert.equal(coldBackground.published.length,1,'later background arrivals notify without any foreground list read');
  assert.match(index,/onPageShow\(\): void \{\s*this.inboxBackgroundSync.stop\(\);\s*this.inboxMessageNotice.dismissForeground\(\)/);
  const viewed=fixture();viewed.notice.observe([]);await settle(viewed);now+=10000;viewed.notice.observe([row('100','50')]);await settle(viewed);
  const initialCancels=viewed.cancelled.length;
  viewed.setVisible('100');viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.cancelled.length,initialCancels,'visible but unloaded chat does not clear');
  viewed.setViewed('200');viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.cancelled.length,initialCancels,'viewing another chat preserves current notice');
  viewed.setViewed('100');viewed.setActive(false);viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.cancelled.length,initialCancels,'background retained chat is not viewed');
  viewed.setActive(true);viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.cancelled.length,initialCancels+1);assert.equal(viewed.notice.publishedConversation,'');
  viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.cancelled.length,initialCancels+1,'dismissal is idempotent');
  viewed.setVisible('');viewed.setViewed('');now+=10000;viewed.notice.observe([row('100','51')]);await settle(viewed);assert.equal(viewed.published.length,2,'later messages can notify after leaving');
  viewed.failCancel(true);viewed.setViewed('100');viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.notice.publishedConversation,'100','failure retains retry ownership');
  viewed.failCancel(false);viewed.notice.dismissViewed();await settle(viewed);assert.equal(viewed.notice.publishedConversation,'','later host tick retries failed cancellation');
  const queued=fixture();queued.notice.observe([]);await settle(queued);now+=10000;queued.notice.observe([row('100','52')]);queued.setViewed('100');queued.notice.dismissViewed();queued.setViewed('');await settle(queued);assert.equal(queued.published.length,0,'viewing then leaving invalidates queued delivery');
  const flight=fixture();flight.notice.observe([]);await settle(flight);let finishPublish;flight.setPublishGate(new Promise(resolve=>finishPublish=resolve));now+=10000;flight.notice.observe([row('100','53')]);await turn();flight.setViewed('100');flight.notice.dismissViewed();flight.setViewed('');finishPublish();await settle(flight);assert.equal(flight.notice.publishedConversation,'','viewing during SDK publication clears late notification');
  const replacement=fixture();replacement.notice.observe([]);await settle(replacement);now+=10000;replacement.notice.observe([row('100','54')]);await settle(replacement);let finishReplacement;replacement.setPublishGate(new Promise(resolve=>finishReplacement=resolve));now+=10000;replacement.notice.observe([row('200','55')]);await turn();const cancelBefore=replacement.cancelled.length;replacement.setViewed('100');replacement.notice.dismissViewed();finishReplacement();await settle(replacement);assert.equal(replacement.notice.publishedConversation,'200');assert.equal(replacement.cancelled.length,cancelBefore,'queued old dismissal cannot clear newer conversation');
  const late=fixture();let finishLate,releasedLate=0;late.setAvatar({release:async()=>releasedLate++},new Promise(resolve=>finishLate=resolve));late.notice.observe([]);await settle(late);now+=10000;late.notice.observe([row('100','56',{sender:{id:'2',image_small_url:'https://i.pinimg.com/avatar.jpg'}})]);await turn();late.setViewed('100');late.notice.dismissViewed();await settle(late);late.setViewed('');finishLate();await turn();await settle(late);assert.equal(late.published.length,1,'late avatar cannot resurrect viewed notification');assert.equal(releasedLate,1);
  const helper=index.slice(index.indexOf('  private visibleInboxNoticeConversation('),index.indexOf('  private readonly inboxMessageNotice:'));
  assert(helper.includes('viewed && (flow.loading || !!flow.error || !flow.messages.length)'));
  const helperExports={};let helperBackground=false;
  vm.runInNewContext(ts.transpileModule('export class Host { '+helper+' }',{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:helperExports,PinmonyInboxBackgroundLifecycle:{isBackground:()=>helperBackground}});
  const host=new helperExports.Host();Object.assign(host,{authStatus:'authenticated',businessSuspended:false,noticeChats:[],inboxMessagesNativeReads:{ownsFlow:()=>true},pinStore:{},nativeBoardVisible:()=>false,activeSheetKind:'',profileSettingsVisible:false,boardRecoveryVisible:false,chatProfileTransition:false,profileChatActive:false,activeTab:2,profileStore:{origins:[]},currentInboxUrl:()=>'/chat',inboxStore:{inboxFlow:{screen:'chat',pageUrl:'/chat',conversationId:'100',messages:[{}],loading:false,error:''}}});
  assert.equal(host.visibleInboxNoticeConversation(true),'100');
  for(const patch of [{loading:true},{error:'failed'},{messages:[]},{screen:'settings'}]){const saved={...host.inboxStore.inboxFlow};Object.assign(host.inboxStore.inboxFlow,patch);assert.equal(host.visibleInboxNoticeConversation(true),'');host.inboxStore.inboxFlow=saved;}
  host.activeTab=0;assert.equal(host.visibleInboxNoticeConversation(true),'');host.profileChatActive=true;assert.equal(host.visibleInboxNoticeConversation(true),'100');host.profileChatActive=false;host.activeTab=2;
  for(const key of ['businessSuspended','profileSettingsVisible','boardRecoveryVisible','chatProfileTransition','activeSheetKind']){host[key]=true;assert.equal(host.visibleInboxNoticeConversation(true),'');host[key]=false;}
  host.noticeChats=[{store:{inboxFlow:{screen:'chat',conversationId:'200',messages:[{}]}}}];assert.equal(host.visibleInboxNoticeConversation(true),'200','only top notification chat is viewed');host.noticeChats[0].store.inboxFlow.screen='settings';assert.equal(host.visibleInboxNoticeConversation(true),'');helperBackground=true;assert.equal(host.visibleInboxNoticeConversation(true),'');
  assert(index.includes('this.inboxMessageNotice.consumeTap();\n    this.inboxMessageNotice.dismissViewed();')||index.includes('this.inboxMessageNotice.consumeTap();\r\n    this.inboxMessageNotice.dismissViewed();'));
  assert.equal((index.match(/messagesObserved: \(rows: PinmonyInboxNoticeConversation\[\]\): void => this.inboxMessageNotice.observe\(rows\)/g) || []).length, 2);
  assert.equal((index.match(/this.inboxMessageNotice.pause\(\)/g) || []).length, 3, 'both lifecycle adapters and background shutdown invalidate pending work');
  assert.equal((index.match(/if\(!this.inboxBackgroundSync.active\(\)\)this.inboxMessageNotice.pause\(\)/g)||[]).length,2,'only the active background owner can retain notification delivery during page suspension');
  assert(index.includes('this.inboxMessageNotice.reset();')); assert(index.includes('this.inboxUnreadNativeReads.pollMessages();'));
  console.log('Inbox message notice: sender/body/time, silent baseline, new ID deduplication, chat/outgoing suppression, locale, account/background races and platform failures passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
