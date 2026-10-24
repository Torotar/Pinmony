const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/controllers/PinmonyDetailOperationsController.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: exportsObject, require: name => name === 'common_foundation' ? { PinmonyTaskRegistry: class { invalidate() {} } } :
  name.includes('VisualSearchApiScript') ? { PIN_VISUAL_SEARCH_API_ENABLED: true } :
  name.includes('models/PinmonyVisualSearch') ? { emptyVisualResult: () => ({ items: [] }) } : {} });
const pin = 'https://www.pinterest.com/pin/1/';
function fixture() {
  let resolve, calls = 0, foreground = true, epoch = 1;
  const store = { detail: { pinUrl: pin }, detailPin: pin, detailPresentationOnly: true,
    detailPreparing: false, detailActionsReady: false, visualToken: 0, imageLayer: '', visualResult: {} };
  const controller = new exportsObject.PinmonyDetailOperationsController(store, {
    authEpoch: () => epoch, authStatus: () => 'authenticated', businessSuspended: () => !foreground,
    pinIdentity: value => value === pin ? '1' : '', ensureDetailActionContext: () => {
      calls++; store.visualToken++; store.detailPreparing = true;
      return new Promise(done => { resolve = ready => { store.detailPreparing = false; store.detailActionsReady = ready; done(ready); }; });
    }
  });
  return { store, controller, resolve: ready => resolve(ready), calls: () => calls,
    background: () => { foreground = false; }, changeAccount: () => { epoch++; } };
}
async function main() {
  const good = fixture(); const opening = good.controller.openImageLayer('search');
  assert.equal(good.calls(), 1); assert.equal(good.store.imageLayer, '', 'cached data cannot open a live search before preparation');
  await good.controller.openImageLayer('search'); assert.equal(good.calls(), 1, 'duplicate tap does not prepare twice');
  good.resolve(true); await opening; assert.equal(good.store.imageLayer, 'search');
  for (const invalidate of [f => f.controller.cancelVisual(), f => f.controller.pause(), f => f.background(),
    f => f.changeAccount(), f => { f.store.detailPin = 'other'; }]) {
    const f = fixture(); const pending = f.controller.openImageLayer('search'); invalidate(f); f.resolve(true); await pending;
    assert.equal(f.store.imageLayer, '', 'closed, departed, suspended or old-account preparation cannot reopen search');
  }
  const failed = fixture(); const pending = failed.controller.openImageLayer('search'); failed.resolve(false); await pending;
  assert.equal(failed.store.imageLayer, '');
  const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
  assert.match(page, /\.enabled\(this.acceptsActionIntent\(item\)\)/);
  assert.match(page, /Button\(this\.uiText\("pm_load_recommendations_08df83f8"\)\)\.enabled\(this.deferredActions \|\| this.readsReady \|\| this.actionsReady\)/);
  assert.ok(!page.includes('推荐内容需要重新读取'));
  assert.match(page, /this.detail.kind === 'cached' && !this.detail.relatedLoading && this.detail.relatedError/);
  console.log('Detail image return: deferred search, duplicate taps, preparation failure, departure, close, background and account guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
