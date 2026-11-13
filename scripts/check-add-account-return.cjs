const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const { PinmonyHomeStore } = require('./arkts-module-loader.cjs').createArktsLoader(ts).loadFile('feature_home/src/main/ets/stores/PinmonyHomeStore.ets');
const exportsHome = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyHomeNativeReads.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: exportsHome, require: withLocalMessages(name => name === 'common_network' ? { PIN_BUSINESS_PIN_READ_ENABLED: true } : name === 'common_foundation' ? { PinmonyRuntimeLog: { info() {} } } : {}) });
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replaceAll('\r\n', '\n');
function method(name, end) {
  const start = source.indexOf('  private ' + name + '('); assert(start >= 0);
  return source.slice(start, source.indexOf(end, start + 1));
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  method('openProfileSettings', '\n  private showInboxBlockSnack') +
  method('closeProfileSettings', '\n  private rootExitBackAt') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { Curve: { EaseOut: 'out', EaseIn: 'in' }, Date });
function port(name, next) {
  const start = source.indexOf('  private readonly ' + name + ':');
  const block = source.slice(start, source.indexOf('\n  private readonly ', start + 20));
  const marker = 'active: (): boolean => ';
  const activeStart = block.indexOf(marker) + marker.length;
  const expression = block.slice(activeStart, block.indexOf(',\n    ' + next + ':', activeStart));
  assert(expression, name);
  return vm.runInNewContext(ts.transpileModule('(function(){ return ' + expression + '; })', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
}
const homeActive = port('homeNativeReads', 'saved');
const profileActive = port('profileNativeReads', 'network');
const flush = () => new Promise(resolve => setImmediate(resolve));
const response = id => JSON.stringify({ resource_response: { status: 'success', data: [{ id, type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/fixture.jpg', width: 474, height: 700 } } }], bookmark: '' } });
async function main() {
  for (const origin of ['https://www.pinterest.com', 'https://uk.pinterest.com']) {
    const h = new Host(), jobs = [], canceled = [], commits = []; let profileReads = 0, notified = 0;
    const store = new PinmonyHomeStore();
    Object.assign(h, { authStatus: 'authenticated', businessSuspended: false, activeTab: 0,
      nativeBusinessRoutesEnabled: true, profileSettingsVisible: false, settingsProfileDepth: -1,
      activeSheetKind: '', pinStore: {}, profileStore: { origins: [] }, boardStore: {}, inboxStore: {},
      settingsStore: { screen: 'root', back: () => false, reset() {} }, nativeChildBackUntil: 0,
      rootContextCoordinator: { notify() { notified++; } }, cancelAccountSettings() {},
      getUIContext: () => ({ animateTo(options, callback) { callback(); } }) });
    h.profileNativeReads = { async demand() {
      if (profileActive.call(h)) { profileReads++; h.profileStore.profile = { profileUrl: origin + '/fixture/', displayName: 'Synthetic fixture', avatarUrl: 'https://i.pinimg.com/fixture-avatar.jpg' }; }
    } };
    const session = { authenticated: true, generation: 3, accountId: 'synthetic-account', origin, userAgent: 'synthetic' };
    h.homeNativeReads = new exportsHome.PinmonyHomeNativeReads({ store: () => store, session: () => session,
      username: () => 'fixture', active: () => homeActive.call(h), saved: () => false,
      network: () => ({ cancel: id => canceled.push(id), requestBusinessHomeRead(job, currentSession, user, board, current) {
        return new Promise(resolve => jobs.push({ job, current, resolve: body => resolve({ status: 200, error: '', body }) }));
      } }), committed: snapshot => commits.push(snapshot) });
    const first = h.homeNativeReads.demand(); assert.equal(jobs.length, 2);
    h.openProfileSettings(); assert.equal(h.profileSettingsVisible, true); assert.equal(profileReads, 1);
    assert.equal(h.profileStore.profile.displayName, 'Synthetic fixture', 'settings can hydrate the header while root tab is home');
    assert.equal(canceled.length, 2, 'settings pauses covered home requests');
    assert.equal(store.homeLoading, false);
    jobs[0].resolve(response('101')); jobs[1].resolve(JSON.stringify({ resource_response: { status: 'success', data: [] } }));
    await first; await flush(); assert.equal(commits.length, 0, 'covered canceled response cannot repopulate home');
    h.closeProfileSettings(); assert.equal(h.profileSettingsVisible, false); assert.equal(notified, 1);
    assert.equal(jobs.length, 4, 'closing settings restarts missing feed without tab switching');
    jobs[2].resolve(response('202')); jobs[3].resolve(JSON.stringify({ resource_response: { status: 'success', data: [] } }));
    await flush(); assert.equal(store.home.pins[0].id, '202'); assert.equal(store.homeLoading, false);
    const snapshot = store.home, count = jobs.length;
    h.nativeChildBackUntil = 0; h.openProfileSettings(); h.closeProfileSettings(); await flush();
    assert.equal(jobs.length, count, 'ordinary settings return reuses populated feed');
    assert.equal(store.home.pins, snapshot.pins, 'cached photo rows retain their identity');
    assert.equal(h.activeTab, 0, 'do not switch tabs to repair content');
    h.authStatus = 'error'; assert.equal(profileActive.call(h), false); assert.equal(homeActive.call(h), false);
    h.openProfileSettings(); assert.equal(h.profileSettingsVisible, false, 'unverified sessions cannot open settings');
    h.authStatus = 'authenticated'; h.profileSettingsVisible = true; h.businessSuspended = true;
    assert.equal(profileActive.call(h), false); assert.equal(homeActive.call(h), false);
    h.businessSuspended = false; h.settingsProfileDepth = 0; assert.equal(profileActive.call(h), false, 'do not replace nested settings identity');
    h.settingsProfileDepth = -1; h.pinStore.detail = {}; assert.equal(profileActive.call(h), false);
  }
  console.log('Add-account return: own settings header eligibility, home pause/resume, canceled response isolation, cached feed identity, www/uk and session/background guards passed');
}
main().catch(error => { console.error(error); process.exit(1); });
