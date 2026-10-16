const fs = require('node:fs');
const vm = require('node:vm');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
function createHomeRuntime(ts, globals = {}) {
  const log = globals.PinmonyRuntimeLog || { info() {}, warn() {}, error() {} };
  const mocks = { common_foundation: { PinmonyRuntimeLog: log,
    CACHE_TTL: { homeFeed: 300000 },
    buildCacheKey: (account, resource, params) => account + '_' + resource + '_' + JSON.stringify(params) } };
  const loader = createArktsLoader(ts, mocks, globals);
  mocks.common_foundation.PinmonyTaskRegistry = loader.loadFile('common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry;
  const Controller = loader.loadFile('feature_home/src/main/ets/controllers/PinmonyHomeController.ets').PinmonyHomeController;
  const Store = loader.loadFile('feature_home/src/main/ets/stores/PinmonyHomeStore.ets').PinmonyHomeStore;
  const cache = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeCache.ets');
  function bindIndex(native, nativeMode = false) {
    native.homeStore ||= new Store();
    for (const [key, value] of Object.entries(new Store())) if (!(key in native.homeStore)) native.homeStore[key] = value;
    const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
    const start = source.indexOf('  private readonly homeController:');
    const end = source.indexOf('  private readonly searchController:', start);
    if (start < 0 || end < 0) throw Error('Missing actual product home bindings');
    const initializer = source.slice(start, end);
    const body = 'this.homeController ' + initializer.slice(initializer.indexOf('='));
    const binding = ts.transpileModule('function bind() {' + body + '} bind;', {
      compilerOptions: { target: ts.ScriptTarget.ES2021 }
    }).outputText;
    vm.runInNewContext(binding, { PinmonyHomeController: Controller, PinmonyRuntimeLog: log, ...globals, PIN_NATIVE_HOME_READS_ENABLED: nativeMode }).call(native);
    return native.homeController;
  }
  function harness(overrides = {}) {
    const store = new Store(), events = [];
    let page = 'https://www.pinterest.com/', active = true, accepted = true;
    const ports = {
      canAcceptMessages: () => accepted, currentPageKey: () => page, presentationPageKey: () => page,
      retainedPageKey: () => page, pageKeyFromAddress: value => value === page ? page : '',
      isOtherRoot: value => /\/(search|inbox|sample)\//.test(value), isActive: () => active, isAuthenticated: () => true,
      runScript: async script => { events.push(['js', script]); return 'true'; },
      ensureContext: async (_required, isCurrent) => active && isCurrent(), rejectOffline: () => false,
      recoverOffline: () => false, prepareRead: () => false, requestRead: () => events.push(['read']),
      reloadPage: (target, refresh) => events.push(['reload', target, refresh]),
      pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '', knownPinTitle: () => '', isSaved: () => false,
      hasMeaningfulTitle: title => !!title && title !== 'Pin 图', recordPageKey: key => events.push(['ready', key]),
      persistSnapshot: snapshot => events.push(['persist', snapshot]), cardsCommitted() {}, contentReady() {},
      markFeedConfirmed() {}, finishRecovery: () => events.push(['recovered']),
      openPin: (target, source) => events.push(['pin', target, source]), traceAction() {},
      showMessage: message => events.push(['notice', message]), ...overrides
    };
    const controller = new Controller(store, ports);
    return { controller, store, ports, events, setPage: value => { page = value; },
      setActive: value => { active = value; }, setAccepted: value => { accepted = value; } };
  }
  return { Controller, Store, cache, bindIndex, harness, loader };
}
module.exports = { createHomeRuntime };
