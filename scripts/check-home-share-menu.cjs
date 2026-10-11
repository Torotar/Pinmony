const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../feature_pin/src/main/ets/services/PinmonySharePanelScript.ets'), 'utf8');
const template = source.match(/const SHARE_PANEL_BRIDGE_SCRIPT: string = `([\s\S]*?)`;/)[1];
let script = Function('return `' + template + '`')();
new Function(script);
script = script.replace('  function findPanel() {',
  '  window.testSharePanel = findPanel;\n' +
  '  window.testShareSnapshot = function(p) { panel = p; return snapshot(); };\n' +
  '  window.testCloseShare = closeWebPanel;\n  function findPanel() {');
const messages = [];
let clicks = 0, closeClicks = 0;
function node(text, top, width = 400, attrs = {}) {
  return { isConnected: true, innerText: text, textContent: text, disabled: false,
    getAttribute: key => attrs[key] || '', setAttribute: () => {}, removeAttribute: () => {},
    querySelector: () => null, contains: other => other === this,
    getBoundingClientRect: () => ({ width, height: 40, left: 0, right: width, top, bottom: top + 40 }),
    click: () => { clicks++; } };
}
const title = node('分享', 30), options = node('选项', 180);
const close = node('', 20, 40, { 'aria-label': '关闭背景模式' });
close.click = () => { closeClicks++; };
const platform = node('Messenger', 100, 56, { 'aria-label': '通过 Facebook Messenger 分享' });
platform.href = 'fb-messenger://share/?link=https%3A%2F%2Fpin.it%2Fexample';
const copy = node('', 100, 56, { 'aria-label': '复制链接' });
const actionNames = ['保存', '在应用中打开', '下载图片', '查看更多', '查看更少', '举报'];
const actions = actionNames.map((name, index) => node(name, 220 + index * 50));
const controls = [close, platform, copy, ...actions];
const panel = node('', 0, 400, { 'data-test-id': 'mobile-signup-mask' });
panel.getBoundingClientRect = () => ({ width: 400, height: 790, top: 0, bottom: 790 });
panel.querySelectorAll = selector => selector.startsWith('h1,') ? [title, options] : controls;
panel.querySelector = selector => {
  if (selector.includes('mobile-modal-heading')) return title;
  if (selector.includes('mobile-modal-cancel-button')) return close;
  if (selector.includes('share-icon')) return copy;
  return null;
};
panel.contains = item => controls.includes(item);
const document = { readyState: 'loading', addEventListener: () => {}, getElementById: () => ({}),
  querySelectorAll: selector => selector.includes('mobile-signup-mask') ? [panel] : [],
  activeElement: null };
const pin = 'https://www.pinterest.com/pin/123/';
const location = { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com', pathname: '/', href: 'https://www.pinterest.com/' };
const window = { innerWidth: 400, innerHeight: 800, PinmonyHomeMenuPin: pin,
  getComputedStyle: () => ({ display: 'block', visibility: 'visible', position: 'fixed' }),
  addEventListener: () => {}, PinmonyShareBridge: { sheetState: value => messages.push(JSON.parse(value)) },
  PinmonyPostApi: { shareSnapshot: () => { throw new Error('homepage options must remain DOM sourced'); },
    shareAction: () => { throw new Error('homepage actions must use the actual menu controls'); } } };
window.top = window;
vm.runInNewContext(script, { window, document, location, setTimeout: () => 1, clearTimeout: () => {},
  requestAnimationFrame: () => 1, cancelAnimationFrame: () => {}, console,
  Promise: { resolve: () => ({ then: () => {} }) } });
assert.equal(window.testSharePanel(), panel, 'full-height mobile share mask is recognized');
const trigger = node('…', 200, 32);
trigger.scrollIntoView = () => {};
assert.equal(window.PinmonyNativeShareOpenFromHome(trigger, pin.replace('123', '999')), false);
assert.equal(window.PinmonyNativeShareOpenFromHome(trigger, pin), true);
assert.equal(messages[0].pinUrl, pin);
assert.equal(messages[0].pinDetail, false);
assert.equal(clicks, 0, 'website click waits until the native loading sheet is opened');
assert.equal(window.PinmonyNativeShareOpen(messages[0].session), true);
assert.equal(clicks, 1);
const snapshot = window.testShareSnapshot(panel);
assert.equal(snapshot.title, '分享');
assert.equal(snapshot.sectionLabel, '选项');
assert.deepEqual(Array.from(snapshot.options, item => item.label), ['Messenger', '复制链接']);
assert.deepEqual(Array.from(snapshot.actions, item => item.label), actionNames);
assert.equal(snapshot.contacts.length, 0, 'options are not misclassified as people');
assert.equal(snapshot.searchActive, false, 'no invented contact search is added to the homepage menu');
assert.equal(window.PinmonyNativeShareAction(snapshot.session, snapshot.actions[2].id), true);
assert.equal(clicks, 2);
window.testCloseShare(panel);
assert.equal(closeClicks, 1, 'the supplied mobile close control is used');
location.pathname = '/pin/999/';
assert.equal(window.PinmonyNativeShareAction(snapshot.session, snapshot.actions[2].id), false);
console.log('homepage mobile share mask, real options, exact Pin, delayed click, close and route gating OK');
