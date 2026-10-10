const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('feature_search/src/main/ets/services/PinmonySearchScript.ets', 'utf8');
const script = Function('return ' + source.match(/string = (\x60[\s\S]*\x60);/)[1])();
assert.doesNotMatch(script, /querySelector|MutationObserver|dispatchEvent|\.click\(|getElementById|document\./);
const scheduled = [], messages = [], navigations = [];
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/search/', search: '', assign: v => navigations.push(v) };
const window = { top: null, addEventListener() {}, setInterval() {}, PinmonyShareBridge: { searchState: v => messages.push(JSON.parse(v)) },
  PinmonySearchDiscoveryApi: { read: () => ({ sections: [], heroes: [], active: true, busy: false, error: '', ended: true }), refresh: () => true, loadMore: () => false, reset() {}, pause() {} },
  PinmonySearchUiApi: { readHint: () => '搜索', readSuggestions: () => ({ items: [{ id: 's1', label: '海报', enabled: true }], error: '' }), reset() {}, readFilters: () => ({ options: [], loading: false, error: '' }) }
}; window.top = window;
vm.runInNewContext(script, { window, location, URL, URLSearchParams, setTimeout: fn => { scheduled.push(fn); return scheduled.length; } });
function flush() { while (scheduled.length) scheduled.shift()(); }
flush(); const first = messages.at(-1);
assert.equal(first.api, true); assert.equal(first.placeholder, '搜索'); assert.equal(first.suggestions.length, 1);
assert.equal(window.PinmonySearchQuery(first.session, first.pageKey, '海报'), true); flush();
assert.equal(messages.at(-1).query, '海报');
assert.equal(window.PinmonySearchSubmit(first.session - 1, first.pageKey, '海报'), false);
assert.equal(window.PinmonySearchSubmit(first.session, first.pageKey, '海报'), true);
assert.equal(navigations.at(-1), 'https://www.pinterest.com/search/pins/?q=' + encodeURIComponent('海报'));
assert.equal(window.PinmonySearchAction(first.session, first.pageKey, 's1', 'suggestion'), true);
assert.equal(window.PinmonySearchSelectFilter(first.session, first.pageKey, 'unknown'), false);
assert.equal(window.PinmonySearchRefresh(first.session, first.pageKey), true);
location.pathname = '/search/pins/'; location.search = '?q=art'; flush();
assert.equal(window.PinmonySearchQuery(first.session, first.pageKey, 'late'), false);
console.log('Search API bridge, native input/submit, suggestions and stale-page guards passed');
