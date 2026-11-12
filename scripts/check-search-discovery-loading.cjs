const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const start = source.indexOf('  private discoveryInitialLoading(');
const tail = source.slice(start);
const end = tail.indexOf('\n  @Builder');
const method = tail.slice(0, end);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '\n} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const h = new Host();h.discoverySnapshot=()=>h.snapshot;
const reset = () => Object.assign(h, { loading: false, error: '',
  snapshot: { kind: 'state', session: 1, heroes: [], ideaSections: [], discoveryApi: true, discoveryActive: false } });
reset(); assert.equal(h.discoveryInitialLoading(), true, 'waiting for the initial discovery response is loading');
h.snapshot.discoveryBusy = true; assert.equal(h.discoveryInitialLoading(), true);
reset(); h.snapshot = { kind: 'loading', session: 0, heroes: [], ideaSections: [] };
assert.equal(h.discoveryInitialLoading(), true, 'placeholder never shows empty feedback');
reset(); h.snapshot.discoveryActive = true;
assert.equal(h.discoveryInitialLoading(), false, 'confirmed empty response can show empty feedback');
reset(); h.snapshot.discoveryError = 'failed';
assert.equal(h.discoveryInitialLoading(), false, 'failure remains retryable');
reset(); h.loading = true; h.snapshot.heroes = [{}];
assert.equal(h.discoveryInitialLoading(), false, 'refresh keeps existing carousel visible');
assert(source.includes('if (this.discoveryInitialLoading())'));
const loadingBuilder = source.slice(source.indexOf('  private searchLoadingState()'), source.indexOf('  private discoveryContent()'));
assert.match(loadingBuilder, /if \(!this\.suppressSearchContentLoading\(\)\)\s*\{\s*LoadingProgress\(\)/,
  'the shared central spinner is omitted during pull refresh for discovery and search results');
assert.match(loadingBuilder, /if \(!this\.suppressSearchContentLoading\(\)\)[\s\S]*Text\(this\.uiText/,
  'central loading copy is suppressed with the spinner');
const pullBuilder = source.slice(source.indexOf('  private searchRefreshIndicator()'), source.indexOf('  @State private searchRefreshState'));
assert.match(pullBuilder, /LoadingProgress\(\)[\s\S]*\.visibility\(this\.searchPullIndicatorVisible\(\)/,
  'the pull refresh spinner remains visible while refreshing');
const pullMethodStart = source.indexOf('  private searchPullIndicatorVisible(');
const pullMethod = source.slice(pullMethodStart, source.indexOf('\n  @Builder', pullMethodStart));
const RefreshStatus = { Inactive: 0, Drag: 1, OverDrag: 2, Refresh: 3, Done: 4 };
const PullHost = vm.runInNewContext(ts.transpileModule('class PullHost {' + pullMethod + '\n} PullHost;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, { RefreshStatus });
const pull = new PullHost();
for (const refreshing of [false, true]) {
  for (const state of Object.values(RefreshStatus)) {
    Object.assign(pull, { refreshing, searchRefreshState: state });
    const visible = pull.searchPullIndicatorVisible();
    assert.equal(visible, refreshing || [RefreshStatus.OverDrag, RefreshStatus.Refresh].includes(state));
  }
}
console.log('Search discovery loading: placeholder, pending read, confirmed empty, failure and retained content passed');
