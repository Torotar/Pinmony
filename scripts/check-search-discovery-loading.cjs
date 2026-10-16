const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const start = source.indexOf('  private discoveryInitialLoading(');
const tail = source.slice(start);
const end = tail.indexOf('\n  @Builder');
const method = tail.slice(0, end);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '\n} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
const h = new Host();
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
console.log('Search discovery loading: placeholder, pending read, confirmed empty, failure and retained content passed');
