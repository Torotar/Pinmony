const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const read = p => fs.readFileSync(p, 'utf8');
const paths = {
  home: 'feature_home/src/main/ets/components/PinmonyHomePage.ets',
  detail: 'feature_pin/src/main/ets/components/PinmonyDetailPage.ets',
  search: 'feature_search/src/main/ets/components/PinmonySearchPage.ets',
  button: 'common_ui/src/main/ets/components/PinmonyBackToTopButton.ets',
  inboxRoot: 'entry/src/main/ets/components/PinmonyInboxRootContent.ets',
  searchRoot: 'entry/src/main/ets/components/PinmonySearchRootContent.ets',
  profileRoot: 'entry/src/main/ets/components/PinmonyProfileRootContent.ets'
};
function compile(code, context = {}) {
  return vm.runInNewContext(ts.transpileModule(code, { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  }}).outputText, context);
}
function method(source, name) {
  const start = source.search(new RegExp('  private (?:static )?' + name + '\\('));
  assert(start >= 0, name);
  const end = source.indexOf('\n  }', start);
  assert(end > start, name + ' end');
  return source.slice(start, end + 4);
}
function host(kind, names, context) {
  return new (compile('class Host {' + names.map(n => method(read(paths[kind]), n)).join('\n') + '} Host;', context))();
}
// A scroll callback must not write an observed top-level Store field.
const storeSource = read('feature_inbox/src/main/ets/stores/PinmonyInboxStore.ets');
const Store = compile(storeSource.replace(/^import .*;\r?\n/gm, '').replace(/@Observed\s*/g, '')
  .replace(/export /g, '') + '\nPinmonyInboxStore;', { PinmonyInboxCache: class {} });
const store = new Store(); let writes = 0;
const watched = new Proxy(store, { set(target, key, value) { writes++; target[key] = value; return true; } });
for (let i = 0; i < 120; i++) watched.rememberScrollOffset(i * 4);
assert.equal(writes, 0); assert.equal(watched.inboxScrollOffset, 476);
watched.inboxScrollOffset = 0; assert.equal(watched.inboxScrollOffset, 0);
assert(read(paths.inboxRoot).includes('view.inboxStore.rememberScrollOffset(offset)'));

// Equivalent copied snapshots retain pane inputs; changes and resets still commit.
const home = host('home', ['categoryId', 'retainSnapshot', 'syncCategories']);
home.home = { kind: 'state', pageKey: 'home', session: 1, tabs: [
  { id: 'all', label: 'All', enabled: true, selected: true }
], pins: [{ id: '1', imageUrl: 'image', title: 'a' }] };
home.categoryMaterials = new Map(); home.snapshots = []; home.categories = []; home.selectedId = 'all';
home.retainSnapshot(); home.syncCategories();
const retained = home.snapshots, tabs = home.categories;
home.home = JSON.parse(JSON.stringify(home.home)); home.retainSnapshot(); home.syncCategories();
assert.equal(home.snapshots, retained); assert.equal(home.categories, tabs);
home.home.pins[0].title = 'b'; home.retainSnapshot(); assert.notEqual(home.snapshots, retained);
home.home.tabs[0].label = 'Changed'; home.syncCategories(); assert.notEqual(home.categories, tabs);
home.snapshots = []; home.retainedContentSignature = ''; home.retainSnapshot(); assert.equal(home.snapshots.length, 1);
home.home.session = 2; home.retainSnapshot(); assert.equal(home.snapshots[0].session, 2);

let parses = 0;
const detail = host('detail', ['descriptionParts'], { splitDescriptionTags: text => { parses++; return [{ text, query: '' }]; } });
detail.parsedDescriptionSource = ''; detail.parsedDescriptionParts = [];
assert.equal(detail.descriptionParts('').length, 0);
const parts = detail.descriptionParts('#a');
assert.equal(detail.descriptionParts('#a'), parts); assert.equal(parses, 1);
detail.descriptionParts('#b'); assert.equal(parses, 2);
detail.descriptionParts(''); assert.equal(parses, 3);

// Pagination updates only the results section; structural changes replace sections.
const search = host('search', ['syncQuizPresentation']);
let columns = 2; const calls = [];
Object.assign(search, { snapshot: { quiz: { mode: 'entry' }, results: [1, 2] }, flowShape: '', flowStructure: '',
  syncResultRows() {}, contentColumns: () => columns,
  flowSections: { count: 0, length() { return this.count; }, splice(_a, _b, sections) {
    calls.push(['splice', sections.length]); this.count = sections.length;
  }, update(index, section) { calls.push(['update', index, section.itemsCount]); } }
});
search.syncQuizPresentation(); assert.deepEqual(calls.pop(), ['splice', 2]);
search.syncQuizPresentation(); assert.equal(calls.length, 0);
search.snapshot.results.push(3); search.syncQuizPresentation(); assert.deepEqual(calls.pop(), ['update', 1, 3]);
columns = 3; search.syncQuizPresentation(); assert.deepEqual(calls.pop(), ['splice', 2]);
search.snapshot.quiz = undefined; search.syncQuizPresentation(); assert.deepEqual(calls.pop(), ['splice', 1]);

// Actual root creation expressions keep page instances when detail covers them.
function mounts(kind, view) {
  const source = read(paths[kind]); const begin = source.indexOf('          if (') + '          if '.length;
  let depth = 0, end = begin;
  do { const ch = source[end++]; if (ch === '(') depth++; if (ch === ')') depth--; } while (depth > 0);
  return Function('view', 'return ' + source.slice(begin, end))(view);
}
const view = { pinStore: {}, inboxStore: { inbox: {} }, profileStore: { profile: {} }, searchStore: {},
  shouldKeepSearchRootMounted: () => true };
for (const kind of ['inboxRoot', 'profileRoot', 'searchRoot']) {
  assert(mounts(kind, view), kind); view.pinStore.detail = {};
  assert(mounts(kind, view), kind + ' retained under detail'); view.pinStore.detail = undefined;
  view.loadFailed = true; assert(!mounts(kind, view), kind + ' failure gate'); view.loadFailed = false;
}
function prop(kind, name, input) {
  const match = read(paths[kind]).match(new RegExp('\\n\\s+' + name + ': ([\\s\\S]*?),\\r?\\n'));
  assert(match, kind + '.' + name);
  return Function('view', 'return (' + match[1] + ')')(input);
}
Object.assign(view, { activeTab: 2, authStatus: 'authenticated', nativeRootOnly: false });
assert.equal(prop('inboxRoot', 'interactionReady', view), true);
view.pinStore.detail = {}; assert.equal(prop('inboxRoot', 'interactionReady', view), false);
view.pinStore.detail = undefined; view.pinStore.detailOpeningPin = 'opening';
assert.equal(prop('inboxRoot', 'interactionReady', view), false);
view.activeTab = 1;
assert.equal(prop('searchRoot', 'interactionReady', view), false);
assert.equal(prop('searchRoot', 'automaticLoadingEnabled', view), false);
view.pinStore.detailOpeningPin = ''; assert.equal(prop('searchRoot', 'interactionReady', view), true);
assert.equal(prop('searchRoot', 'automaticLoadingEnabled', view), true);
const index = read('entry/src/main/ets/pages/Index.ets');
const root = compile('class Host {' + method(index, 'shouldKeepSearchRootMounted') + '} Host;');
const rootHost = new root(); Object.assign(rootHost, { searchStore: { search: { pageKey: 'search' } },
  pinStore: { detail: {} }, nativeSearchPageVisible: () => false, shouldKeepSearchPageMounted: () => false });
assert(rootHost.shouldKeepSearchRootMounted()); rootHost.pinStore.detailWebFlow = true;
assert(!rootHost.shouldKeepSearchRootMounted());
const searchSource = read(paths.search);
const backStart = searchSource.indexOf('.onBackPressed(() => {') + '.onBackPressed('.length;
const backEnd = searchSource.indexOf('\n      })', backStart) + '\n      }'.length;
// Arrow functions use lexical this; execute the real callback inside a host method.
const BackHost = compile('class Host { run() { return (' + searchSource.slice(backStart, backEnd) + ')(); } } Host;');
const bh = new BackHost(); let delegated = 0, activeBack = 0;
Object.assign(bh, { active: false, onRootBack: () => delegated++, handleSearchBack: () => activeBack++ });
assert.equal(bh.run(), true); assert.equal(delegated, 1); assert.equal(activeBack, 0);
bh.active = true; assert.equal(bh.run(), true); assert.equal(activeBack, 1);
bh.active = false; bh.retainPhotoSearch = true; bh.onBack = () => delegated++;
assert.equal(bh.run(), true); assert.equal(delegated, 2);
assert(!method(searchSource, 'activeChanged').includes('searchPathStack.clear'));

// Successful resources cache per language; failed/uninitialized lookups can recover.
const i18nSource = read('common_foundation/src/main/ets/services/PinmonyI18n.ets');
const I18n = compile(i18nSource.replace(/^import .*;\r?\n/gm, '').replace('export class', 'class') + '\nPinmonyI18n;',
  { AppStorage: { get: () => 'zh' }, PINMONY_LOCAL_COPY_KEYS: {}, console,
    resourceManager: { ColorMode: { DARK: 0, LIGHT: 1 } } });
let reads = 0; I18n.chinese = { updateOverrideConfiguration() {}, getStringByNameSync: key => { reads++; return '中文:' + key; } };
I18n.english = { updateOverrideConfiguration() {}, getStringByNameSync: key => { reads++; return 'English:' + key; } };
assert.equal(I18n.text('pm_test', 'zh'), '中文:pm_test'); I18n.text('pm_test', 'zh'); assert.equal(reads, 1);
assert.equal(I18n.text('pm_test', 'en'), 'English:pm_test'); assert.equal(reads, 2);
assert.equal(I18n.text('site text', 'zh'), 'site text');
I18n.syncResourceColorMode({ resourceManager: { getConfigurationSync: () => ({ colorMode: 0 }) } });
I18n.text('pm_test', 'zh'); assert.equal(reads, 3);
assert.equal(I18n.text('pm_test', 'zh'), '中文:pm_test'); assert.equal(reads, 3);
assert.equal(I18n.text('pm_test', 'ja'), 'pm_test');
I18n.japanese = { getStringByNameSync: key => 'Japanese:' + key };
assert.equal(I18n.text('pm_test', 'ja'), 'Japanese:pm_test', 'uninitialized resource must recover without a poisoned cache');
for (let i = 0; i < 4100; i++) I18n.text('pm_bound_' + i, 'zh');
assert(I18n.textCache.size <= 4096, 'resource cache is bounded');
const button = host('button', ['updateHostArea']); let dimensions = 0;
Object.defineProperty(button, 'hostWidth', { get: () => 100, set: () => dimensions++ });
Object.defineProperty(button, 'hostHeight', { get: () => 200, set: () => dimensions++ });
button.updateHostArea(100, 200); assert.equal(dimensions, 0);
button.updateHostArea(101, 200); assert.equal(dimensions, 1);
button.updateHostArea(NaN, 200); assert.equal(dimensions, 1);
console.log('Scroll performance: observed-write isolation, retained roots/back delegation, snapshot identity, description cache, section updates, language cache and dimension guards passed');
