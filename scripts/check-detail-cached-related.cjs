const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const begin = source.indexOf('  private ' + name);
  assert(begin >= 0, name);
  return source.slice(begin, source.indexOf('\n  private ', begin + 1));
}
const context = { PIN_DETAIL_API_ENABLED: true, PIN_NATIVE_NETWORK_ENABLED: true,
  PINTEREST_URL: 'https://www.pinterest.com/', setTimeout() {},
  PinmonyRuntimeLog: { info() {}, warn() {} } };
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Native {
  ${method('async openImageRelated')}
  ${method('beginDetailOpening')}
  ${method('supersedeRootPreparationForDetail')}
} globalThis.Native = Native;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
async function main() {
  const n = new context.Native(), loads = [], reads = [], origins = [], marks = [];
  const parent = 'https://www.pinterest.com/pin/101/';
  const target = 'https://www.pinterest.com/pin/102/';
  const card = { id: 'cached-card', pinUrl: target, imageUrl: 'https://i.pinimg.com/474x/target.jpg',
    imageWidth: 474, imageHeight: 900, title: 'Target title' };
  function restoreParent() {
    Object.assign(n.pinStore, { detailPresentationOnly: true, detailPreparing: false,
      detailOpeningPin: '', detailPin: parent, detailActionsReady: false,
      detail: { kind: 'cached', dataSource:'api', pinUrl: parent, actions:[], related: [card] } });
  }
  Object.assign(n, { authStatus: 'authenticated', businessSuspended: false,
    detailOpeningCoordinator: { pauseShufflePreviews() {} },
    pinStore: { videoForeground: true, detailOpeningToken: 3,
      detailPrefetch: { cancelExcept() {} }, rememberDetailOrigin: (id, url) => origins.push([id, url]),
      detailOrigin: () => parent }, homeStore: {}, detailPrefetchTimer: -1,
    pinIdentity: value => String(value || '').match(/\/pin\/(\d+)\//)?.[1] || '',
    rejectOfflineAction: () => false, closeImageLayer() {}, clearRootTabGuard() {},
    capturePinEntryPhoto(pinUrl,imageUrl) { this.homeEntryPhoto = {pinUrl,imageUrl,x:0,y:100,width:150,height:200}; },
    pagePerformance: { beginSecondary() {} },
    pageHistory: { visit() {} }, detailJourney: { begin() {}, mark: name => marks.push(name) },
    clearDetail() { this.pinStore.detail = undefined; this.pinStore.detailPresentationOnly = false; this.pinStore.detailActionsReady = false; },
    restoreCachedDetail() {}, startOpeningDetailRead: url => reads.push(url), probeDetailDocument() {},
    ensureDetailActionContext() { throw Error('cached navigation must not confirm parent'); },
    controller: { loadUrl(url) {
      assert.equal(n.pinStore.detail.pinUrl, target, 'target presentation exists before hidden navigation');
      assert.equal(n.pinStore.detail.imageUrl, card.imageUrl);
      assert.equal(n.pinStore.detail.imageHeight, card.imageHeight);
      assert.equal(n.pinStore.detailActionsReady, false, 'route does not authorize target writes');
      loads.push(url);
    } } });
  const {createArktsLoader}=require('./arkts-module-loader.cjs');
  const {PinmonyDetailReadCache}=createArktsLoader(ts).loadFile('feature_pin/src/main/ets/services/PinmonyDetailReadCache.ets');
  const {PinmonyDetailCache}=createArktsLoader(ts).loadFile('feature_pin/src/main/ets/services/PinmonyDetailCache.ets');
  n.pinStore.detailCache = new PinmonyDetailCache();
  n.detailReadCache=new PinmonyDetailReadCache({ detailPin:()=>n.pinStore.detailPin, currentPin:()=>parent,
    pinIdentity:n.pinIdentity,isAuthenticated:()=>n.authStatus==='authenticated',hasNativeBackTarget:()=>false,markJourney(){} });
  require('./medium-priority-controller-harness.cjs').bindWork(n, ts, context);
  restoreParent(); await n.openImageRelated(card.id);
  assert.deepEqual(loads, [target]); assert.deepEqual(reads, [target]);
  assert.deepEqual(origins, [['102', parent]], 'back retains the native parent route');
  assert(marks.includes('related.cached.route.opened'));
  assert.equal(n.relatedEntryParent.pinUrl,parent,'child flight retains its actual parent presentation');
  assert.equal(n.relatedEntryParent.kind,'cached','animation underlay never authorizes live controls');
  for (const blocked of ['unknown', 'invalid-url', 'wrong-parent', 'logged-out', 'background', 'preparing', 'offline']) {
    restoreParent(); n.authStatus = 'authenticated'; n.businessSuspended = false;
    n.rejectOfflineAction = () => false; card.pinUrl = target;
    if (blocked === 'invalid-url') card.pinUrl = 'https://example.com/pin/102/';
    if (blocked === 'wrong-parent') n.pinStore.detailPin = target;
    if (blocked === 'logged-out') n.authStatus = 'unauthenticated';
    if (blocked === 'background') n.businessSuspended = true;
    if (blocked === 'preparing') n.pinStore.detailPreparing = true;
    if (blocked === 'offline') n.rejectOfflineAction = () => true;
    await n.openImageRelated(blocked === 'unknown' ? 'unknown' : card.id);
    assert.equal(loads.length, 1, blocked + ' cannot start hidden navigation');
    assert.equal(reads.length, 1, blocked + ' cannot start a demand read');
  }
  restoreParent(); n.authStatus = 'authenticated'; n.businessSuspended = false;
  n.rejectOfflineAction = () => false; card.pinUrl = target;
  card.id = 'api:102'; n.pinStore.detailNativeReadsReady = true;
  n.detailNativeReads = { owned: () => true };
  await n.openImageRelated(target);
  assert.equal(reads.length, 2, 'retained image route resolves the current ID after cache replacement');
  assert.equal(reads[1], target);
  assert(fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8').includes('this.onRelated(pin.pinUrl)'),
    'retained card callbacks pass stable routes instead of cached IDs');
  const Back = vm.runInNewContext(ts.transpileModule('class Back {' + method('async backFromDetail') + '} Back;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){}},Date,
      display:{getDefaultDisplaySync:()=>({width:360,height:800})}});
  const back = new Back();
  Object.assign(back,{activeSheetKind:'',showNativeSheet:false,pageHistory:{isPending:()=>false},
    pinStore:{shareBackHandledUntil:0,detail:{pinUrl:target},detailOrigin:()=>parent},
    pinIdentity:n.pinIdentity,homeEntryPhoto:{pinUrl:target,imageUrl:card.imageUrl},homeEntryBackCommitted:false,
    homeEntryClosing:false,homeEntryCardId:'pinmony-related-photo-'+parent+'-'+target,relatedEntryParent:{pinUrl:parent},
    getUIContext:()=>({getComponentUtils:()=>({getRectangleById:()=>{throw Error('parent layout pending');}})})});
  await back.backFromDetail();
  assert.equal(back.homeEntryClosing,true,'related back starts its exit even while parent geometry is pending');
  assert.equal(back.homeEntryPhoto.pinUrl,target,'return does not discard the flight and instantly replace the page');
  for (const [y, pageOnly] of [[-40,false],[700,false],[-300,true],[900,true]]) {
    back.homeEntryClosing=false; back.relatedEntryParent=undefined; back.homeEntryCardId='pinmony-home-photo-card';
    back.getUIContext=()=>({px2vp:n=>n,getComponentUtils:()=>({getRectangleById:()=>({windowOffset:{x:20,y},size:{width:150,height:200}})})});
    await back.backFromDetail();
    assert.equal(back.homeEntryClosing,true,'partial and offscreen cards both animate on return');
    assert.equal(back.homeEntryPhoto.returnPageOnly,pageOnly,'only completely offscreen cards use page exit');
    assert.equal(back.homeEntryPhoto.y,y,'preserve full card geometry without squeezing the image');
  }
  back.homeEntryClosing=false;
  back.getUIContext=()=>{throw Error('source recycled');};
  await back.backFromDetail();
  assert.equal(back.homeEntryClosing,true);
  assert.equal(back.homeEntryPhoto.returnPageOnly,true,'recycled sources use a page exit');
  console.log('Cached related navigation: immediate target card, stable route after cache replacement, target-only read/navigation, native parent history and session/background/offline guards passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
