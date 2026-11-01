const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function binding(name) {
  const start = index.indexOf('  private readonly ' + name + ':');
  assert(start >= 0, name);
  const end = index.indexOf('\n  } as ', start), stop = index.indexOf(';', end);
  assert(end > start && stop > end, name + ' initializer');
  return index.slice(start, stop + 1).replace(/private readonly (\w+): \w+ = /, 'this.$1 = ');
}
function method(name) {
  const start = index.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const end = index.indexOf('\n  private ', start + 1);
  assert(end > start, name + ' boundary');
  return index.slice(start, end);
}
class Tasks { invalidate() {} async wait() { return true; } cancelTimeout() {} }
const forbidden = new Proxy({}, { get(_, key) { throw Error('unexpected dependency: ' + String(key)); } });
async function disabled(master, local) {
  const flags = Object.fromEntries([...new Set(index.match(/PIN_NATIVE_\w+_ENABLED/g))].map(key => [key, master && local]));
  const loader = createArktsLoader(ts, { common_network: { PIN_BUSINESS_PIN_READ_ENABLED: master },
    common_foundation: { PinmonyTaskRegistry: Tasks, PinmonyRuntimeLog: { info() {}, warn() {} } },
    '@kit.ArkTS': {}, '@kit.ImageKit': {} }, flags);
  const types = {};
  for (const [name, path] of [
    ['PinmonySharePanelsController', 'feature_pin/src/main/ets/controllers/'],
    ['PinmonyPublishController', 'feature_profile/src/main/ets/controllers/'],
    ['PinmonySettingsController', 'feature_settings/src/main/ets/controllers/'],
    ['PinmonyProfileActionsController', 'feature_profile/src/main/ets/controllers/'],
    ['PinmonyDetailController', 'feature_pin/src/main/ets/controllers/']
  ]) types[name] = loader.loadFile(path + name + '.ets')[name];
  const fields = ['sharePanelsController', 'publishController', 'settingsController', 'profileActionsController', 'detailController'];
  const Host = vm.runInNewContext(ts.transpileModule('class Host { bind() {' + fields.map(binding).join('\n') +
    '}\n' + ['openProfilePanelBoard', 'openProfileBoard', 'openInboxBoard', 'beginDetailOpening', 'performSearchAction', 'usesNativeProfileReads'].map(method).join('\n') + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { ...flags, ...types, PIN_POST_API_ENABLED: true });
  const host = new Host(), pin = 'https://www.pinterest.com/pin/12/', profile = 'https://www.pinterest.com/test/';
  Object.assign(host, { nativeBusinessRoutesEnabled: true, nativeLoginEnabled: true, loginHostMounted: true,
    authStatus: 'authenticated', businessSuspended: false, activeSheetKind: 'share', showNativeSheet: true,
    pinStore: { shareSession: 7, sharePin: pin, shareContacts: [{ id: 'retained' }], moreOptions: [], detail: { pinUrl: pin } },
    profileStore: { profile: { profileUrl: profile, section: 'saved' }, publishOptions: [{ id: 'retained' }] },
    settingsStore: { screen: 'account' }, boardStore: {}, rejectOfflineAction: () => false,
    sessionDocumentUrl: () => pin, boardUrlFromAddress: url => url,
    runSessionScript() { throw Error('unexpected Web script from actual Index binding'); },
    loadSessionDocument() { throw Error('unexpected Web navigation'); },
    closeProfilePanel() { throw Error('disabled board must retain its source panel'); },
    showMessage() { throw Error('disabled operation must not fabricate feedback'); } });
  for (const name of ['PinmonyShareNativeFlow', 'PinmonyPinMenuNative', 'PinmonyPublishNativeFlow',
    'PinmonySettingsNativeFlow', 'PinmonyProfileNativeActions']) {
    const Type = loader.loadFile('entry/src/main/ets/app/' + name + '.ets')[name];
    const service = Object.create(Type.prototype); service.store = forbidden; service.ports = forbidden;
    const key = { PinmonyShareNativeFlow: 'shareNativeFlow', PinmonyPinMenuNative: 'pinMenuNative',
      PinmonyPublishNativeFlow: 'publishNativeFlow', PinmonySettingsNativeFlow: 'settingsNativeFlow',
      PinmonyProfileNativeActions: 'profileNativeActions' }[name];
    host[key] = service;
  }
  host.bind();
  const before = JSON.stringify([host.pinStore, host.profileStore, host.settingsStore, host.boardStore]);
  assert.equal(host.sharePanelsController.ports.nativeShare(), true);
  assert.equal(host.sharePanelsController.ports.nativeMenu(), true);
  await host.sharePanelsController.searchShareContacts('test');
  await host.sharePanelsController.refreshShareSheet();
  await host.sharePanelsController.performShareAction('native-send');
  await host.sharePanelsController.openApiDetailMore();
  await host.sharePanelsController.performMoreAction('detail-see-less');
  await host.sharePanelsController.refreshMoreSheet();
  host.sharePanelsController.updateShareSheet(JSON.stringify({ kind: 'state', session: 7, pinUrl: pin, contacts: [] }));
  assert.equal(host.publishController.ports.nativeFlow(), true);
  host.publishController.openMenu(); await host.publishController.select('retained');
  assert.equal(host.settingsController.ports.nativeEnabled(), true);
  await host.settingsController.request('read', '');
  assert.equal(host.profileActionsController.ports.nativeEnabled(), true);
  host.openProfilePanelBoard('https://www.pinterest.com/test/board/');
  await host.openProfileBoard('board'); host.openInboxBoard('message');
  host.beginDetailOpening(pin); await host.performSearchAction('board', 'hero');
  assert.equal(host.usesNativeProfileReads(), true, 'disabled profile cannot accept legacy bridge snapshots');
  for (const kind of ['more', 'comment', 'share', 'save', 'like', 'edit']) {
    assert.equal(await host.detailController.ports.nativePostAction(kind), true, 'disabled native action is consumed');
  }
  assert.equal(await host.detailController.ports.nativePostAction('source'), false, 'external-source actions retain their existing system path');
  host.detailController.ports.loadDetailUrl(pin);
  assert.equal(JSON.stringify([host.pinStore, host.profileStore, host.settingsStore, host.boardStore]), before,
    'actual Index/controller/native-service chain retains presentation and emits no Web work');
  // Every direct detail navigation fallback must depend on implementation mode.
  assert.doesNotMatch(index, /if\s*\(\s*!PIN_NATIVE_DETAIL_READS_ENABLED\s*\)\s*(?:\{\s*(?:try\s*\{\s*)?)?this\.loadSessionDocument/);
}
(async () => {
  await disabled(true, false); await disabled(false, true); await disabled(false, false);
  console.log('Native entry isolation: actual Index bindings, feature controllers and native services reject disabled local/master work without Web fallback, state changes or feedback');
})().catch(error => { console.error(error); process.exitCode = 1; });
