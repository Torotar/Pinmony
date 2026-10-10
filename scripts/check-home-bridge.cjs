const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const path = require('node:path');
const vm = require('node:vm');

const source = readSourceFileSync(path.join(__dirname, '../feature_home/src/main/ets/services/PinmonyHomeScript.ets'), 'utf8');
const pageSource = readSourceFileSync(path.join(__dirname, '../feature_home/src/main/ets/components/PinmonyHomePage.ets'), 'utf8');
const apiSource = readSourceFileSync(path.join(__dirname, '../feature_home/src/main/ets/services/PinmonyHomeApiScript.ets'), 'utf8');
const indexSource = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/pages/Index.ets'), 'utf8');
const template = source.match(/`([\s\S]*?)`;/)[1];
const script = Function('return `' + template + '`')();
new Function(script);
assert.match(apiSource, /BoardsFeedResource\/get/);
assert.match(apiSource, /setUsername/);
assert.doesNotMatch(apiSource, /__PWS_INITIAL_PROPS__|getElementById|document\./);
assert.doesNotMatch(source, /querySelector|querySelectorAll|MutationObserver|\.click\(|PinmonyHomePin|PinmonyHomeMore/);
assert.match(source, /dataSource: 'api'/);
assert.match(pageSource, /Button\(\{ type: ButtonType\.Circle \}\)/);
assert.match(indexSource, /window\.PinmonyHomeSetUsername/);
assert.match(indexSource, /this\.controller\.loadUrl\(pinUrl\)/);
assert.doesNotMatch(indexSource, /window\.PinmonyHomeMore/);

const messages = [];
const api = { initialTabs: () => [{ name: '动漫', boardId: '42' }], savedTabsReady: () => true,
  identityReady: () => true, savedTabsFailed: () => false,
  read: (_key, _eligible, _changed, current, boardId) => {
    assert.equal(current(), true);
    return { active: true, pins: [{ id: '123', pinUrl: 'https://www.pinterest.com/pin/123/', imageUrl: 'https://i.pinimg.com/474x/a.jpg', imageWidth: 474, imageHeight: 600, title: '接口标题', hasMore: false }], board: boardId ? { id: boardId, name: '动漫', pinCount: 1, thumbnailUrl: '' } : null, refreshing: false, busy: false, ended: false, error: '' };
  }, reset: () => {}, loadMore: () => true, refresh: () => true, setUsername: () => {} };
const callbacks = [];
const context = { window: { top: null, PinmonyHomeApiEnabled: true, PinmonyHomeApi: api,
  PinmonyShareBridge: { homeState: value => messages.push(JSON.parse(value)) }, addEventListener: () => {},
  history: { pushState: () => {}, replaceState: () => {} } },
  location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/', href: 'https://www.pinterest.com/' },
  setTimeout: callback => { callbacks.push(callback); return callbacks.length; }, clearTimeout: () => {}, setInterval: () => 0 };
context.window.top = context.window;
vm.runInNewContext(script, context);
callbacks.shift()();
assert.equal(messages.at(-1).dataSource, 'api');
assert.deepEqual(messages.at(-1).tabs.map(tab => tab.label), ['所有', '动漫']);
assert.equal(messages.at(-1).pins[0].title, '接口标题');
const session = messages.at(-1).session; const page = messages.at(-1).pageKey;
assert.equal(context.window.PinmonyHomeTab(session, page, 'tab:42'), true);
callbacks.shift()();
assert.equal(messages.at(-1).selectedTab, '动漫');
context.location.pathname = '/search/';
context.window.PinmonyHomeDemand('https://www.pinterest.com/search/');
callbacks.shift()();
assert.equal(messages.at(-1).kind, 'closed');
console.log('home API-only bridge: no DOM card/category reads or web-control clicks; native selection and API cards passed');
