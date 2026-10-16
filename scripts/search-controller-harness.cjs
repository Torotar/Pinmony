const fs = require('node:fs');
const vm = require('node:vm');
const { createArktsLoader } = require('./arkts-module-loader.cjs');

function createSearchRuntime(ts, globals = {}) {
  const mocks = { common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {}, error() {} } } };
  const loader = createArktsLoader(ts, mocks, globals);
  mocks.common_foundation.PinmonyTaskRegistry = loader.loadFile(
    'common_foundation/src/main/ets/services/PinmonyTaskRegistry.ets').PinmonyTaskRegistry;
  const Controller = loader.loadFile('feature_search/src/main/ets/controllers/PinmonySearchController.ets').PinmonySearchController;
  const Store = loader.loadFile('feature_search/src/main/ets/stores/PinmonySearchStore.ets').PinmonySearchStore;

  function bindIndex(native) {
    native.searchNativeReads ||= { eligible: () => false, apply() {}, demand:async()=>{}, pause(){}, reset(){} };
    const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
    const begin = source.indexOf('  private readonly searchController:');
    const end = source.indexOf('\n  private ', begin + 1);
    if (begin < 0 || end < 0) throw Error('Missing actual product search bindings');
    const initializer = source.slice(begin, end);
    const body = 'this.searchController ' + initializer.slice(initializer.indexOf('='));
    const binding = ts.transpileModule('function bind() {' + body + '} bind;', {
      compilerOptions: { target: ts.ScriptTarget.ES2021 }
    }).outputText;
    vm.runInNewContext(binding, { PinmonySearchController: Controller }).call(native);
    return native.searchController;
  }

  function harness(overrides = {}) {
    const store = new Store(), events = [];
    let pageKey = 'https://www.pinterest.com/search/pins/?q=art', active = true, sheet = '';
    const ports = {
      currentPageKey: () => pageKey, isActive: () => active, preservingPinSearch: () => false,
      runScript: async script => { events.push(['js', script]); return 'true'; },
      ensureContext: async () => active, markInteracted() {}, clearTabGuard() {}, finishPull() {},
      recordPageKey: key => events.push(['ready', key]), setDetailReturn: key => events.push(['return', key]),
      navigateSearch: (target, source) => events.push(['search', target, source]),
      navigateResult: (target, source) => events.push(['result', target, source]),
      cancelNavigation() {}, clearOpeningDetail() {}, sheetKind: () => sheet,
      setFilterVisible: visible => { sheet = visible ? 'searchFilter' : ''; },
      prepareRead: () => false, requestRead: () => events.push(['read']),
      pinIdentity: url => url.match(/\/pin\/(\d+)/)?.[1] || '',
      traceAction() {}, showMessage: message => events.push(['notice', message]), ...overrides
    };
    const controller = new Controller(store, ports);
    return { controller, store, ports, events, setPage: value => { pageKey = value; },
      setActive: value => { active = value; }, setSheet: value => { sheet = value; } };
  }
  return { Controller, Store, bindIndex, harness };
}
module.exports = { createSearchRuntime };
