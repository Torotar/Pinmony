const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/app/PinmonyInboxMessageNotice.ets', 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
let now = Date.parse('2026-11-07T08:00:00Z');
class TestDate extends Date { static now() { return now; } }
function fixture() {
  let active = true, visible = '', enabled = true, language = 'zh', permissionCalls = 0, failPublish = false;
  let session = { authenticated: true, accountId: 'self', generation: 1, origin: 'https://www.pinterest.com' };
  let permissionGate, wantGate, publishGate;
  let avatarResult, avatarGate, canOpen = true;
  const opened = [], avatarReads = [];
  const tapExports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxNoticeTap.ets','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText, {exports:tapExports,require:()=>({})});
  const published = [], cancelled = [], exports = {};
  const manager = {
    SlotType: { SOCIAL_COMMUNICATION: 1 }, ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 0 },
    cancel: async id => { cancelled.push(id); }, isNotificationEnabled: async () => enabled,
    requestEnableNotification: async () => { permissionCalls++; if (permissionGate) await permissionGate; },
    publish: async request => { if (failPublish) throw Error('synthetic'); published.push({...request}); if (publishGate) await publishGate; }
  };
  vm.runInNewContext(compiled, { exports, Date: TestDate, require: name => name === './PinmonyInboxNoticeAvatar' ? { PinmonyInboxNoticeAvatar: class { cancel() {} async read(url) { if(!url)return;avatarReads.push(url); if(avatarGate)await avatarGate;return avatarResult; } } } : name === './PinmonyInboxNoticeTap' ? tapExports : name === '@kit.NotificationKit' ? { notificationManager: manager } : name === '@kit.AbilityKit' ? {
    wantAgent: { getWantAgent: async info => { if (wantGate) await wantGate; return info; }, OperationType: { START_ABILITY: 0 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 0 } }
  } : name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {}, warn() {} }, PinmonyI18n: { message: () => language === 'zh' ? '新消息' : 'New message' } } : {} });
  const notice = new exports.PinmonyInboxMessageNotice({ session: () => session, active: () => active, username: () => 'self', visibleConversation: () => visible, context: () => ({ applicationInfo: { name: 'com.synthetic.pinmony' } }),openChat:id=>{if(!canOpen)return false;opened.push(id);return true;} });
  return { notice, published, cancelled, setActive: v => active = v, setVisible: v => visible = v, setEnabled: v => enabled = v,
    setSession: v => session = v, setLanguage: v => language = v, permissionCalls: () => permissionCalls,
    setPermissionGate: v => permissionGate = v, setWantGate: v => wantGate = v, setPublishGate: v => publishGate = v, failPublish: v => failPublish = v,
    opened,avatarReads,receive:want=>tapExports.PinmonyInboxNoticeTap.receive(want),setCanOpen:v=>canOpen=v,setAvatar:(pixels,gate)=>{avatarResult=pixels;avatarGate=gate;} };
}
const row = (id, message, extra = {}) => ({ id, unread: 1, users: [{ id: '2', full_name: '发送者原文' }], last_message: {
  id: message, created_at: new Date(now).toISOString(), sender: { id: '2', username: 'peer' }, text: '消息原文', ...extra
} });
const settle = f => f.notice.queue;
const turn = () => new Promise(resolve => setImmediate(resolve));
async function main() {
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
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.equal((index.match(/messagesObserved: \(rows: PinmonyInboxNoticeConversation\[\]\): void => this.inboxMessageNotice.observe\(rows\)/g) || []).length, 2);
  assert.equal((index.match(/this.inboxMessageNotice.pause\(\)/g) || []).length, 2, 'both lifecycle adapters invalidate pending work');
  assert(index.includes('this.inboxMessageNotice.reset();')); assert(index.includes('this.inboxUnreadNativeReads.pollMessages();'));
  console.log('Inbox message notice: sender/body/time, silent baseline, new ID deduplication, chat/outgoing suppression, locale, account/background races and platform failures passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
