const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const detailSource = readSourceFileSync(path.join(__dirname,
  '../entry/src/main/ets/services/PinmonyDetailScript.ets'), 'utf8');
const indexSource = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/pages/Index.ets'), 'utf8');
const template = detailSource.match(/= `([\s\S]*)`;/)[1];
const script = Function('return `' + template + '`')();
new Function(script);
const moreFunction = script.match(/window\.PinmonyDetailMore = function[\s\S]*?\n  };/)[0];
const target = { isConnected: true, enabled: true };
const calls = [];
const fixture = {
  window: { PinmonyNativeMoreOpenFromHome: (button, pin) => {
    calls.push({ button, pin });
    return true;
  } },
  controls: { more: target, save: target },
  actionKinds: { more: 'more', save: 'save' },
  session: 7,
  activePin: 'https://www.pinterest.com/pin/123/',
  pinUrl: () => fixture.activePin,
  enabled: button => button.enabled
};
vm.runInNewContext(moreFunction, fixture);
const open = fixture.window.PinmonyDetailMore;
assert.equal(open(6, fixture.activePin, 'more'), false, 'old session cannot open a menu');
assert.equal(open(7, 'https://www.pinterest.com/pin/456/', 'more'), false, 'another Pin cannot open this menu');
assert.equal(open(7, fixture.activePin, 'save'), false, 'a non-menu control is never clicked');
target.isConnected = false;
assert.equal(open(7, fixture.activePin, 'more'), false, 'unmounted control is rejected');
target.isConnected = true;
target.enabled = false;
assert.equal(open(7, fixture.activePin, 'more'), false, 'disabled control is rejected');
target.enabled = true;
fixture.pinUrl = () => 'https://www.pinterest.com/pin/456/';
assert.equal(open(7, fixture.activePin, 'more'), false, 'navigation invalidates the old Pin');
fixture.pinUrl = () => fixture.activePin;
assert.equal(calls.length, 0);
assert.equal(open(7, fixture.activePin, 'more'), true);
assert.equal(calls.length, 1);
assert.equal(calls[0].button, target, 'the real detail control is passed to the native menu bridge');
assert.equal(calls[0].pin, fixture.activePin);
fixture.window.PinmonyNativeMoreOpenFromHome = () => false;
assert.equal(open(7, fixture.activePin, 'more'), false, 'busy bridge is reported without a fake menu');
delete fixture.window.PinmonyNativeMoreOpenFromHome;
assert.equal(open(7, fixture.activePin, 'more'), false);

assert.match(indexSource, /reason\.includes\('menu-not-mounted'\)[\s\S]*?openHomeMoreViaDetail\(pin\.pinUrl, home\.pageKey\)/);
assert.match(indexSource, /!dispatched && this\.detailActionsReady[\s\S]*?this\.pinIdentity\(detail\.pinUrl\) === identity/);
assert.match(indexSource, /dispatched = result === 'true'/, 'an accepted request is not clicked repeatedly');
assert.match(indexSource, /token !== this\.homeDetailMoreToken\) return/);
assert.match(indexSource, /this\.pinIdentity\(targetPinUrl\) !== this\.pinIdentity\(this\.pendingHomeMorePin\)/);
assert.match(indexSource, /正在读取 Pin 选项/);
// Execute the native coordinator's actual method body with only ArkTS types removed.
const method = indexSource.match(/  private async openHomeMoreViaDetail\([\s\S]*?\n  private loadMoreHome/)[0]
  .replace(/\n  private loadMoreHome$/, '')
  .replace('private async', 'async')
  .replace(/: Promise<void>/g, '')
  .replace(/: PinmonyDetail(?:Snapshot|Action) \| undefined/g, '')
  .replace(/: PinmonyDetailAction/g, '')
  .replace(/: \(\) => void/g, '')
  .replace(/: (?:string|number|boolean|void)/g, '')
  .replace('new Promise<void>', 'new Promise');

async function checkCoordinator(mode) {
  let now = 0;
  let dispatches = 0;
  const notices = [];
  const coordinator = {
    homeDetailMoreToken: 0,
    pendingHomeMorePin: '',
    detailActionsReady: true,
    detail: { session: 7, pinUrl: fixture.activePin, actions: [
      { id: 'more', kind: 'more', enabled: true }
    ] },
    pinIdentity: value => (value.match(/\/pin\/(\d+)/) || [])[1] || '',
    currentPinUrl: () => mode === 'wrong-pin' ? 'https://www.pinterest.com/pin/456/' : fixture.activePin,
    cancelHomeDetailMore() { this.homeDetailMoreToken++; this.pendingHomeMorePin = ''; },
    controller: {
      loadUrl: value => assert.equal(value, fixture.activePin),
      runJavaScript: async value => {
        assert.match(value, /PinmonyDetailMore\(7,"https:\/\/www.pinterest.com\/pin\/123\/","more"\)/);
        dispatches++;
        return 'true';
      }
    },
    dismissMoreSheet: () => {},
    showMessage: message => notices.push(message)
  };
  const context = {
    Date: { now: () => now },
    setTimeout: (callback, delay) => {
      now += delay;
      if (mode === 'cancel' || mode === 'success' && now >= 750) coordinator.cancelHomeDetailMore();
      callback();
    }
  };
  const openViaDetail = vm.runInNewContext('({' + method + '}).openHomeMoreViaDetail', context);
  await openViaDetail.call(coordinator, fixture.activePin, 'https://www.pinterest.com/');
  assert.equal(coordinator.pendingHomeMorePin, '');
  assert.equal(coordinator.detailReturnUrl, 'https://www.pinterest.com/');
  if (mode === 'wrong-pin') {
    assert.equal(dispatches, 0, 'another detail Pin is never dispatched');
    assert.equal(notices.length, 1, 'timeout exits loading and reports the actual failure');
  } else {
    assert.equal(dispatches, 1, 'accepted menu request is dispatched only once while waiting');
    assert.equal(notices.length, 0, 'completion or cancellation produces no late timeout toast');
  }
}

Promise.resolve().then(async () => {
  await checkCoordinator('success');
  await checkCoordinator('cancel');
  await checkCoordinator('wrong-pin');
  console.log('detail menu syntax, exact Pin/session gating, single dispatch, cancellation and timeout OK');
}).catch(error => { console.error(error); process.exitCode = 1; });
