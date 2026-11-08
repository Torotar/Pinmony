const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyNotificationsPage.ets', 'utf8');
const methods = source.slice(source.indexOf('  aboutToAppear('), source.indexOf('  @Builder'));
const lifecycle = source.slice(source.indexOf('  private readonly applicationState:'), source.indexOf('  private notificationPermissionEpoch:'));
const js = ts.transpileModule('class NotificationPermissionInteraction {' + lifecycle + methods + '}', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText;
const flush = async () => { for (let i = 0; i < 4; i++) await new Promise(resolve => setImmediate(resolve)); };
function fixture() {
  let allowed = true, checkError = false, settingsError = false, pending, pendingSettings;
  let queries = 0, opens = 0;
  const dialogs = [], writes = [];
  const notificationManager = {
    isNotificationEnabled: async () => {
      queries++;
      if (pending) return pending;
      if (checkError) throw Error('check');
      return allowed;
    },
    openNotificationSettings: async context => {
      assert.equal(context, host);
      opens++;
      if (pendingSettings) return pendingSettings;
      if (settingsError) throw Error('open');
    }
  };
  let listener;
  const application = {
    on: (event, callback) => { assert.equal(event, 'applicationStateChange'); listener = callback; },
    off: (event, callback) => { assert.equal(event, 'applicationStateChange'); assert.equal(listener, callback); listener = undefined; }
  };
  const host = { getApplicationContext: () => application };
  const Interaction = vm.runInNewContext(js + ';NotificationPermissionInteraction', {
    notificationManager, DialogAlignment: { Bottom: 1, Center: 2 }, $r: value => value,
    PinmonyI18n: { message: key => key },
    notificationGlobal: (type, section, option) => type === 'news' && option === 'NONE_IN_APP' || type === 'push' && option === 'NO_PUSH'
  });
  const x = new Interaction();
  x.pageVisible = true; x.confirmationOpen = false; x.checkingSystemNotification = false; x.notificationPermissionEpoch = 0;
  x.applicationForeground = true; x.systemNotificationEnabled = true; x.pendingNotificationToken = -1;
  x.pendingCompletionQueued = false; x.stack = { pushPath: () => {} };
  x.store = { screen: 'notifications', token: 1, busy: false, loading: false, writeUncertain: false, error: '', notifications: [{ categories: [{ channels: [channel()] }] }] };
  x.uiText = key => key;
  x.getUIContext = () => ({ showAlertDialog: dialog => dialogs.push(dialog), getHostContext: () => host });
  x.onRequest = (action, body) => writes.push({ action, choice: JSON.parse(body) });
  return { x, dialogs, writes, queries: () => queries, opens: () => opens,
    listener: () => listener,
    allowed: value => allowed = value, checkError: () => checkError = true, settingsError: () => settingsError = true,
    defer: () => { let resolve; pending = new Promise(done => resolve = done); return resolve; },
    deferSettings: () => { let reject; pendingSettings = new Promise((_, fail) => reject = fail); return reject; } };
}
const channel = (type = 'news', option = 'messages') => ({ channel: type, section: 'settings_news_categories', option, value: false, editable: true });
(async () => {
  const grantedEntry = fixture(); grantedEntry.x.aboutToAppear(); await flush();
  assert.equal(grantedEntry.queries(), 1); assert.equal(grantedEntry.dialogs.length, 0); assert.equal(grantedEntry.writes.length, 0);
  const life = fixture(); life.allowed(false); life.x.aboutToAppear(); await flush();
  assert.equal(life.queries(), 1, 'actual entry lifecycle checks permission');
  assert.equal(life.dialogs.length, 1, 'actual entry prompts when system notification permission is off');
  assert.equal(life.writes.length, 0, 'entry permission check never changes website settings');
  life.dialogs[0].primaryButton.action();
  life.listener().onApplicationBackground(); assert.equal(life.x.applicationForeground, false);
  life.allowed(true); life.listener().onApplicationForeground(); await flush();
  assert.equal(life.queries(), 2); assert.equal(life.x.systemNotificationEnabled, true);
  assert.equal(life.dialogs.length, 1, 'foreground query does not repeat entry prompt');
  life.x.aboutToDisappear(); assert.equal(life.listener(), undefined, 'actual leave lifecycle unregisters listener');
  for (const option of ['messages', 'published_comments', 'NONE_IN_APP']) {
    const f = fixture(); f.x.change(channel('news', option), true); await flush();
    assert.equal(f.queries(), 1); assert.equal(f.writes.length, 1);
    assert.equal(f.writes[0].choice.option, option); assert.equal(f.writes[0].choice.value, true);
    assert.equal(f.dialogs.length, 0);
  }
  const denied = fixture(); denied.allowed(false); denied.x.change(channel(), true); await flush();
  assert.equal(denied.writes.length, 0); assert.equal(denied.dialogs.length, 1);
  assert.equal(denied.x.confirmationOpen, true); assert.equal(denied.x.checkingSystemNotification, false);
  denied.dialogs[0].primaryButton.action(); assert.equal(denied.opens(), 0); assert.equal(denied.writes.length, 0);
  denied.x.change(channel(), true); await flush();
  const dialog = denied.dialogs.at(-1); dialog.secondaryButton.action(); dialog.secondaryButton.action(); await flush();
  assert.equal(denied.opens(), 1, 'explicit settings action opens once');
  assert.equal(denied.writes.length, 0, 'opening settings alone does not imply permission granted');
  denied.allowed(true); await denied.x.refreshSystemNotification();
  assert.equal(denied.writes.length, 1, 'foreground permission granted completes the explicitly requested enable');
  await denied.x.refreshSystemNotification(); assert.equal(denied.writes.length, 1, 'pending enable is consumed once');
  const entry = fixture(); entry.allowed(false); entry.x.store.loading = true;
  await entry.x.refreshSystemNotification(true);
  assert.equal(entry.queries(), 1); assert.equal(entry.dialogs.length, 1); assert.equal(entry.writes.length, 0);
  assert.equal(entry.x.channelEnabled({ ...channel(), value: true }), true, 'OS denial preserves enabled in-app switches');
  assert.equal(entry.x.channelEnabled(channel()), false, 'OS denial preserves disabled in-app switches');
  assert.equal(entry.x.channelEnabled({ ...channel('email'), value: true }), true, 'email is independent');
  const entryValues = JSON.stringify(entry.x.store.notifications);
  entry.dialogs[0].secondaryButton.action(); await flush();
  assert.equal(entry.opens(), 1, 'entry prompt opens app notification settings even while page data loads');
  assert.equal(entry.x.pendingNotification, undefined, 'entry prompt never invents a switch enable');
  entry.allowed(true); entry.x.store.loading = false; await entry.x.refreshSystemNotification();
  assert.equal(entry.writes.length, 0); assert.equal(JSON.stringify(entry.x.store.notifications), entryValues);
  const canceled = fixture(); canceled.allowed(false); canceled.x.aboutToAppear(); await flush();
  canceled.dialogs[0].cancel(); canceled.listener().onApplicationBackground(); canceled.listener().onApplicationForeground(); await flush();
  assert.equal(canceled.dialogs.length, 1, 'cancel plus foreground does not loop permission dialogs');
  canceled.x.aboutToDisappear(); canceled.x.aboutToAppear(); await flush();
  assert.equal(canceled.dialogs.length, 2, 'reentering checks and prompts again if still disabled');
  const staleEntry = fixture(); staleEntry.allowed(false); staleEntry.x.aboutToAppear(); await flush();
  staleEntry.x.store.token++; staleEntry.dialogs[0].secondaryButton.action(); await flush();
  assert.equal(staleEntry.opens(), 0, 'entry dialog cannot act after account/request ownership changes');
  const entryOpenFailed = fixture(); entryOpenFailed.allowed(false); entryOpenFailed.settingsError(); entryOpenFailed.x.aboutToAppear(); await flush();
  entryOpenFailed.dialogs[0].secondaryButton.action(); await flush();
  assert.equal(entryOpenFailed.x.store.error, 'pm_system_notifications_open_failed', 'entry settings failure is visible without a pending switch');
  const retryEntry = fixture(); retryEntry.allowed(false);
  retryEntry.x.onRetry = () => { retryEntry.x.store.token++; };
  retryEntry.x.retry(); await flush();
  assert.equal(retryEntry.dialogs.length, 1, 'retry rechecks OS permission after website request token changes');
  const prepare = async () => { const f = fixture(); f.allowed(false); f.x.change(channel(), true); await flush(); f.dialogs[0].secondaryButton.action(); await flush(); return f; };
  const stillDenied = await prepare(); await stillDenied.x.refreshSystemNotification();
  assert.equal(stillDenied.writes.length, 0); assert.equal(stillDenied.x.pendingNotification, undefined);
  for (const mutate of [x => x.pageVisible = false, x => x.store.token++, x => x.store.screen = 'root']) {
    const f = await prepare(); f.allowed(true); mutate(f.x); await f.x.refreshSystemNotification(); f.x.completePendingNotification();
    assert.equal(f.writes.length, 0, 'leaving or identity change discards pending enable');
  }
  const wait = await prepare(); wait.allowed(true); wait.x.store.loading = true; await wait.x.refreshSystemNotification();
  assert.equal(wait.writes.length, 0); wait.x.store.loading = false; wait.x.settingsChanged();
  assert.equal(wait.writes.length, 0, 'store watcher must allow native request finalization before dispatch');
  await flush(); assert.equal(wait.writes.length, 1);
  const lateOpen = fixture(); lateOpen.allowed(false); lateOpen.x.change(channel(), true); await flush();
  const rejectOldOpen = lateOpen.deferSettings(); lateOpen.dialogs[0].secondaryButton.action();
  const newerChoice = { type: 'news', section: 'settings_news_categories', option: 'published_comments', value: true };
  lateOpen.x.pendingNotification = newerChoice;
  rejectOldOpen(Error('late old settings failure')); await flush();
  assert.equal(lateOpen.x.pendingNotification, newerChoice, 'old settings error cannot erase a newer user choice');
  assert.equal(lateOpen.x.store.error, '', 'old settings error cannot overwrite current state');
  const lateRefresh = fixture(), settleRefresh = lateRefresh.defer();
  const refreshTask = lateRefresh.x.refreshSystemNotification(); lateRefresh.x.store.screen = 'root';
  settleRefresh(Promise.reject(Error('late permission failure'))); await refreshTask;
  assert.equal(lateRefresh.x.store.error, '', 'permission error cannot leak into the previous page');
  const already = await prepare(); already.allowed(true); already.x.store.notifications[0].categories[0].channels[0].value = true;
  await already.x.refreshSystemNotification(); assert.equal(already.writes.length, 0, 'already enabled does not write again');
  const noPermission = await prepare(); noPermission.allowed(true); noPermission.x.store.notifications[0].categories[0].channels[0].editable = false;
  await noPermission.x.refreshSystemNotification(); assert.equal(noPermission.writes.length, 0, 'lost website edit permission cancels pending enable');
  const uncertain = await prepare(); uncertain.allowed(true); uncertain.x.store.writeUncertain = true;
  await uncertain.x.refreshSystemNotification(); assert.equal(uncertain.writes.length, 0, 'uncertain write prevents pending dispatch');
  uncertain.x.aboutToDisappear(); uncertain.x.store.writeUncertain = false; uncertain.x.settingsChanged(); await flush();
  assert.equal(uncertain.writes.length, 0, 'leaving clears deferred enable');
  const duplicate = fixture(), resolve = duplicate.defer(); duplicate.x.change(channel(), true); duplicate.x.change(channel(), true);
  assert.equal(duplicate.queries(), 1); resolve(true); await flush(); assert.equal(duplicate.writes.length, 1);
  for (const mutate of [x => x.pageVisible = false, x => x.store.token++, x => x.store.screen = 'root',
    x => x.notificationPermissionEpoch++, x => x.store.loading = true, x => x.store.busy = true, x => x.store.writeUncertain = true]) {
    const f = fixture(), settle = f.defer(); f.x.change(channel(), true); mutate(f.x); settle(false); await flush();
    assert.equal(f.dialogs.length, 0); assert.equal(f.writes.length, 0, 'stale permission response has no effect');
  }
  const stale = fixture(); stale.allowed(false); stale.x.change(channel(), true); await flush(); stale.x.store.token++;
  stale.dialogs[0].secondaryButton.action(); await flush(); assert.equal(stale.opens(), 0);
  const failed = fixture(); failed.checkError(); failed.x.change(channel(), true); await flush();
  assert.equal(failed.writes.length, 0); assert.equal(failed.x.store.error, 'pm_system_notifications_check_failed');
  assert.equal(failed.x.checkingSystemNotification, false);
  const openFailed = fixture(); openFailed.allowed(false); openFailed.settingsError(); openFailed.x.change(channel(), true); await flush();
  openFailed.dialogs[0].secondaryButton.action(); await flush(); assert.equal(openFailed.x.store.error, 'pm_system_notifications_open_failed');
  for (const type of ['push', 'email']) {
    const f = fixture(); f.x.change(channel(type), true); assert.equal(f.writes.length, 1); assert.equal(f.queries(), 0);
  }
  const off = fixture(); off.x.change({ ...channel(), value: true }, false);
  assert.equal(off.writes.length, 1); assert.equal(off.queries(), 0, 'turning off does not check OS permission');
  const globalOff = fixture(); globalOff.x.change({ ...channel('news', 'NONE_IN_APP'), value: true }, false);
  assert.equal(globalOff.writes.length, 0); assert.equal(globalOff.dialogs.length, 1, 'existing global-disable confirmation stays');
  for (const state of ['busy', 'loading', 'writeUncertain']) {
    const f = fixture(); f.x.store[state] = true; f.x.change(channel(), true); assert.equal(f.queries(), 0);
  }
  const readonly = fixture(); readonly.x.change({ ...channel(), editable: false }, true); assert.equal(readonly.queries(), 0);
  assert(source.includes('this.notificationPermissionEpoch++; this.checkingSystemNotification = false;'), 'leaving cancels permission ownership');
  assert(source.includes("on('applicationStateChange', this.applicationState)"));
  assert(source.includes("off('applicationStateChange', this.applicationState)"), 'listener cleanup');
  assert(source.includes('this.refreshSystemNotification();'), 'entry and foreground query OS permission');
  assert(source.includes("JSON.stringify(group) + ':' + this.uiLanguage"), 'confirmed nested data changes refresh group nodes immediately');
  assert(source.includes("JSON.stringify(category) + ':' + this.uiLanguage"), 'confirmed channel changes refresh category nodes');
  const keys = ['pm_system_notifications_off', 'pm_system_notifications_enable_message', 'pm_system_notifications_open_settings', 'pm_system_notifications_check_failed', 'pm_system_notifications_open_failed'];
  for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
    const resources = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
    for (const key of keys) assert(resources.some(row => row.name === key && row.value.trim()), locale + ':' + key);
  }
  console.log('System notifications: entry/foreground checks, pending enable once, denial/cancel, loading/identity guards, live nested refresh, errors, unaffected channels and nine locales passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
