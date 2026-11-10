const assert = require('node:assert/strict'), fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const logs = [], unhandled = [];
const lifecycle = require('./snackbar-lifecycle-harness.cjs').loadSnackBarLifecycle(ts, {warn:s=>logs.push(s)});
const onUnhandled = reason => unhandled.push(reason);
process.on('unhandledRejection', onUnhandled);
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  let rejectClose, backs = 0;
  const native = {
    show(icon, message, operation, style) {
      this.back = style.pressBackCallback;
      return new Promise((resolve, reject) => { rejectClose = reject; });
    },
    dismiss() { return Promise.reject(Error('private native close payload')); }
  };
  lifecycle.show(native, {}, {}, {}, {duration:4000,pressBackCallback:()=>backs++});
  native.back();
  rejectClose(Error('private native back payload'));
  await flush();
  assert.equal(backs,1); assert.equal(unhandled.length,0);
  assert(logs.includes('SnackBarNative: operation=show outcome=rejected'));
  lifecycle.show(native, {}, {}, {}, {duration:4000});
  lifecycle.dismiss(native); await flush();
  assert(logs.includes('SnackBarNative: operation=dismiss outcome=rejected'));
  lifecycle.show({show(){throw Error('private show')}},{},{},{},{});
  const throwingDismiss={show(){},dismiss(){throw Error('private dismiss')}};
  lifecycle.show(throwingDismiss,{},{},{},{});lifecycle.dismiss(throwingDismiss);
  lifecycle.show({show(){}},{},{},{},{}); lifecycle.dismiss({dismiss(){}});
  await flush(); assert.equal(unhandled.length,0);
  assert(logs.includes('SnackBarNative: operation=show outcome=threw'));
  assert(logs.includes('SnackBarNative: operation=dismiss outcome=threw'));
  assert(!logs.join('\n').includes('private'));
  const order=[];
  const old={show(icon,message,operation,style){this.style=style;this.operation=operation;order.push('old-show')},dismiss(){order.push('old-dismiss')}};
  const current={show(){order.push('new-show')},dismiss(){order.push('new-dismiss')}};
  let staleActions=0;
  lifecycle.show(old,{},{},{onContentClick:()=>staleActions++,onCloseButtonClick:()=>staleActions++},{pressBackCallback:()=>staleActions++});
  lifecycle.show(current,{},{},{},{});
  assert.deepEqual(order,['old-show','old-dismiss','new-show'],'handoff closes old owner before displaying new owner');
  lifecycle.dismiss(old);old.style.pressBackCallback();old.operation.onCloseButtonClick();old.operation.onContentClick();
  assert.equal(staleActions,0,'superseded notices cannot undo, retry or navigate');
  assert.deepEqual(order,['old-show','old-dismiss','new-show'],'late old page cleanup and native callbacks cannot close current notice');
  lifecycle.dismiss(current);lifecycle.dismiss(current);
  assert.deepEqual(order,['old-show','old-dismiss','new-show','new-dismiss'],'global native owner closes once');
  let persistentDismissals=0;
  const persistent={show(){},dismiss(){persistentDismissals++;}};
  lifecycle.show(persistent,{},{},{},{duration:0});
  assert(lifecycle.isCurrent(persistent),'persistent owner remains current');
  lifecycle.dismiss(persistent);lifecycle.dismiss(persistent);
  assert.equal(lifecycle.isCurrent(persistent),false);
  assert.equal(persistentDismissals,1,'persistent notice remains dismissible and closes once');
  const pending = [], callbacks = [];
  let currentBacks = 0;
  const reused = { show(icon, message, operation, style) {
    callbacks.push(style.pressBackCallback);
    return new Promise((resolve, reject) => pending.push(reject));
  }, dismiss() {} };
  lifecycle.show(reused, {}, {}, {}, {duration:0, pressBackCallback:()=>currentBacks++});
  lifecycle.show(reused, {}, {}, {}, {duration:0, pressBackCallback:()=>currentBacks++});
  pending[0](Error('private superseded show'));
  await flush();
  assert(lifecycle.isCurrent(reused), 'old rejection cannot release reused instance current presentation');
  callbacks[0]();
  assert.equal(currentBacks, 0, 'old native back cannot invoke superseded action');
  assert(lifecycle.isCurrent(reused));
  callbacks[1]();
  assert.equal(currentBacks, 1);
  assert.equal(lifecycle.isCurrent(reused), false);
  assert.equal(unhandled.length, 0);
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  assert.equal((index.match(/PinmonySnackBarLifecycle\.show\(snack,/g)||[]).length,9);
  assert(!/\bsnack\.(show|dismiss)\(/.test(index),'every Index HDS call uses the boundary');
  console.log('Snackbar native boundary: delayed back/show and dismiss rejection, persistent owner, synchronous errors, void returns, nine entry points and private diagnostics passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>process.removeListener('unhandledRejection',onUnhandled));
