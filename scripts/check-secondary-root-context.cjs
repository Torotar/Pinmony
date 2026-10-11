const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const searchRuntime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
const names = ['rootActionContextReady', 'ensureRootActionContext', 'prepareProfileInteraction',
  'profileDocumentMatches',
  'performProfileAction', 'openProfileBoard', 'changeProfileTab', 'retryInboxContacts',
  'performSearchQuizAction', 'openProfilePublish', 'readProfilePublishWhenReady', 'requestAccountSettings'];
const context = { Date, setTimeout: (fn, ms) => ms <= 100 ? setTimeout(fn, ms) : 0,
  PinmonyRuntimeLog: { info() {}, warn() {} }, PIN_PROFILE_API_ENABLED: true, PIN_BOARD_API_ENABLED: true,
  PIN_ACCOUNT_SETTINGS_SCRIPT: '', useNativeTransport: () => '' };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Native {' + names.map(method).join('\n') +
  '} globalThis.Native = Native;', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, context);
const origin = 'https://www.pinterest.com/', roots = [origin, origin + 'search/', origin + 'inbox/', origin + 'sample/'];
const pin = origin + 'pin/123/', board = roots[3] + 'board/';
function harness(index) {
  let document = roots[0];
  const n = new context.Native(), requests = [];
  Object.assign(n, { authStatus: 'authenticated', activeTab: index, activeSheetKind: '', tabRequestToken: 1,
    pendingWebTab: -1, showNativeSheet: false, profileSettingsVisible: true, rootTabAddresses: new Map(),
    profileStore: { profileCache: { put() {}, clear() {} }, origins: [], profileActionsReady: false, profileSession: 1, publishRequestToken: 0, panelToken: 0,
      profile: { session: 1, profileUrl: roots[3], section: 'created',
        createdPins: [{ id: '123', targetUrl: pin }], boards: [{ id: 'b', targetUrl: board, title: 'board', pinCount: '1' }] } },
    searchStore: { searchActionsReady: false, search: { session: 1, pageKey: roots[1] } },
    inboxStore: { inboxActionsReady: false, inboxSectionReady: false, inboxSession: 1, inboxUrl: roots[2],
      inbox: { session: 1, pageUrl: roots[2], section: 'messages' } },
    pinStore: { rememberDetailOrigin() {} }, boardStore: { boardOpeningToken: 0 },
    settingsStore: { token: 0, busy: false, loading: false },
    pageHistory: { key: value => value || '' }, rootPresentationAddress: i => roots[i],
    currentHomePageKey: () => document, currentSearchPageKey: () => document,
    currentInboxUrl: () => document, currentProfileUrl: () => document === roots[3] ? roots[3] : '',
    profileUrlFromAddress: value => value === roots[3] || value.startsWith(roots[3] + '_created/') ? roots[3] : '',
    boardUrlFromAddress: value => value === board ? board : '', extractPinUrl: value => value === pin ? pin : '',
    pinIdentity: value => value === pin ? '123' : '', webJsonText: value => value,
    traceAction() {}, clearRootTabGuard() {}, showMessage: value => requests.push(['notice', value]),
    returnFromSearchQuiz: () => false,
    beginDetailOpening: (url, parent) => requests.push(['detail', url, parent]),
    requestRootPage(i) { n.tabRequestToken++; n.pendingWebTab = i; requests.push(['prepare', i]); },
    controller: { getUrl: () => document, loadUrl: url => requests.push(['load', url]), runJavaScript: async code => {
      requests.push(['js', code]);
      if (code.includes('PinmonyAccountSettings.read()')) return JSON.stringify({ token: n.settingsStore.token,
        page: document, loading: false, countries: [], email: '', birthdate: '', gender: '', customGender: '', error: '' });
      return 'true';
    } } });
  n.searchStore = Object.assign(new searchRuntime.Store(), n.searchStore);
  searchRuntime.bindIndex(n);
  n.inboxUrlFromAddress = value => value.startsWith(roots[2]) ? roots[2] : '';
  n.finishRootPull=()=>{}; n.pagePerformance={count(){}}; n.markRootPerformance=()=>{};
  require('./medium-priority-controller-harness.cjs').bind(n, ts, context);
  require('./inbox-read-controller-harness.cjs').bind(n, ts, context);
  require('./publish-controller-harness.cjs').bind(n, ts, context);
  require('./profile-actions-controller-harness.cjs').bind(n, ts, context);
  return { n, requests, ready() {
    document = roots[index];
    if (index === 3) { n.profileStore.profileActionsReady = true; n.profileStore.profileSession = n.profileStore.profile.session = 22; }
    if (index === 1) { n.searchStore.searchActionsReady = true; n.searchStore.search.session = 22; }
    if (index === 2) { n.inboxStore.inboxSectionReady = true; n.inboxStore.inboxSession = n.inboxStore.inbox.session = 22; }
  } };
}
(async () => {
  const sharedProfileDocument = harness(3);
  sharedProfileDocument.ready();
  sharedProfileDocument.n.rootPresentationAddress = () => roots[3] + '_created/';
  assert.equal(sharedProfileDocument.n.rootActionContextReady(3), true,
    'native created section reuses the authenticated saved profile document');
  sharedProfileDocument.n.rootPresentationAddress = () => origin + 'another/_created/';
  assert.equal(sharedProfileDocument.n.rootActionContextReady(3), false,
    'a different profile cannot reuse the bound session');
  const nav = harness(3);
  assert.equal(await nav.n.performProfileAction('123'), true);
  assert.deepEqual(nav.requests, [['detail', pin, roots[3] + '_created/'], ['load', pin]]);
  const b = harness(3); await b.n.openProfileBoard('b');
  assert.deepEqual(b.requests, [['load', board]]);
  assert.equal(b.n.boardStore.boardReturnUrl, roots[3] + '_created/', 'board returns to native source, not hidden Home');
  const retained = harness(3); retained.n.rootTabAddresses.set(3, roots[3] + '_created/?view=test');
  await retained.n.openProfileBoard('b');
  assert.equal(retained.n.boardStore.boardReturnUrl, roots[3] + '_created/?view=test', 'complete retained origin is preserved');
  const profile = harness(3), tab = profile.n.changeProfileTab('saved');
  assert.deepEqual(profile.requests, [['prepare', 3]]); profile.ready(); await tab;
  assert.match(profile.requests.at(-1)[1], /PinmonyProfileTab\(22,/);
  const contacts = harness(2), retry = contacts.n.retryInboxContacts();
  contacts.ready(); await retry;
  assert.match(contacts.requests.at(-1)[1], /PinmonyInboxContactsApiRefresh\(22\)/,
    'failed contacts can retry with confirmed section context');
  const quiz = harness(1), topic = quiz.n.performSearchQuizAction('topic', '0'); quiz.ready(); await topic;
  assert.match(quiz.requests.at(-1)[1], /PinmonySearchQuizAction\(22,/);
  const publish = harness(3); publish.n.openProfilePublish();
  assert.equal(publish.n.activeSheetKind, 'publish'); assert.equal(publish.n.profileStore.publishLoading, true);
  publish.ready(); await new Promise(resolve => setTimeout(resolve, 130));
  assert.match(publish.requests.at(-1)[1], /PinmonyProfilePublishDiscover\(22,/);
  const profileScript = fs.readFileSync('feature_profile/src/main/ets/services/PinmonyProfileScript.ets', 'utf8');
  assert.match(profileScript, /function containsPublishOptions\(node\)/,
    'publish discovery validates option contents inside a bounded menu');
  assert.match(profileScript, /found\.website && found\.photo && found\.board/,
    'publish discovery requires all three current-page options');
  const publishFinder = profileScript.slice(profileScript.indexOf('function findPublishMenu'),
    profileScript.indexOf('function readPublishOptions'));
  assert.doesNotMatch(publishFinder, /添加到个人资料\|Add to profile\|Add to your profile/,
    'publish discovery does not depend on a localized heading');
  const closed = harness(3); closed.n.openProfilePublish(); closed.n.activeSheetKind = '';
  closed.n.showNativeSheet = false; closed.n.profileStore.publishRequestToken++;
  closed.ready(); await new Promise(resolve => setTimeout(resolve, 130));
  assert.deepEqual(closed.requests, [['prepare', 3]], 'closing publish cancels pending intent');
  const settings = harness(3), read = settings.n.requestAccountSettings('personal', '');
  assert.equal(settings.n.settingsStore.loading, true); settings.ready(); await read;
  assert.equal(settings.n.settingsStore.loading, false);
  assert.equal(settings.requests.filter(x => x[0] === 'js' && x[1].includes('.start(')).length, 1);
  const canceled = harness(3), pending = canceled.n.requestAccountSettings('privateProfile', 'true');
  canceled.n.profileSettingsVisible = false; canceled.n.settingsStore.token++; canceled.ready(); await pending;
  assert.deepEqual(canceled.requests, [['prepare', 3]], 'closed settings never submits a waiting write');
  const filter = fs.readFileSync('feature_search/src/main/ets/controllers/PinmonySearchController.ets', 'utf8');
  const open = filter.slice(filter.indexOf('  async openSearchFilters()'), filter.indexOf('  refreshSearchFilters('));
  assert(open.indexOf('ensureContext(true)') < open.indexOf('searchActionsReady')); 
  assert.match(source, /keepPublish: boolean = this\.profileStore\.publishPreparing/);
  console.log('Secondary root context: Profile navigation/origins, fresh tabs, contact retry, quiz, publish readiness/close and settings read/write cancellation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
