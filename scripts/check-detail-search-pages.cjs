const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const shared = fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchView.ets', 'utf8');
const aux = fs.readFileSync('entry/src/main/ets/app/PinmonyDetailNativeAuxiliary.ets', 'utf8');
function methods(source, names) {
  const ast = ts.createSourceFile('test.ts', source.replace(/\bstruct\b/g, 'class'), 99, true), result = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) result.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast); assert.equal(result.length, names.length); return result.join('\n');
}
function host(source, names) {
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods(source, names) + '} Host;',
    { compilerOptions: { target: 99 } }).outputText, { PinmonyRuntimeLog: { info() {} }, SheetSize: { LARGE: 'large' }, clearTimeout() {} });
}
const Host = host(index, ['openDetailSearchResult', 'restoreDetailSearchPresentation', 'detailPresentationIdentities', 'detailPresentation', 'detailPresentationKey']);
const root = 'https://www.pinterest.com', url = id => root + '/pin/' + id + '/';
const card = id => ({ id: 'api:' + id, pinUrl: url(id), imageUrl: 'image-' + id, imageWidth: 400, imageHeight: 800 });
const n = new Host(), cache = new Map(); let current = '1', continuation;
Object.assign(n, { detailSearchParents: [], detailEntryCards: new Map(),
  pinIdentity: pin => pin.match(/\/pin\/(\d+)/)?.[1] || '', detailRootIdentity: () => current,
  detailRenderIdentity: () => 'render-' + current, relatedEntryParent: undefined,
  detailNativeAuxiliary: { visualContinuation: () => ({ pin: url(current), owner: 'session', bookmark: 'cursor-' + current, crop: 'crop-' + current }),
    restoreVisualContinuation: state => continuation = state },
  pinStore: { detail: { pinUrl: url(1) }, detailScrollOffset: 240, detailOpeningToken: 1, imageLayer: 'search',
    visualResult: { pin: url(1), loading: false, items: [card(2)], ended: false },
    detailCache: { put: (id, detail, offset) => cache.set(id, { detail, offset }) } },
  beginDetailOpening(pin) {
    current = this.pinIdentity(pin); this.detailEntryCards.set(pin, this.homeEntryCardId);
    this.pinStore.detail = { pinUrl: pin }; this.pinStore.detailOpeningToken++;
    this.pinStore.imageLayer = ''; this.pinStore.visualResult = { pin, items: [], loading: false };
  }
});
const firstResult = n.pinStore.visualResult, firstKey = n.detailPresentationKey('1');
assert.equal(n.openDetailSearchResult(card(2)), true);
assert.deepEqual(Array.from(n.detailPresentationIdentities()), ['1', '2']);
assert.equal(n.detailPresentationKey('1'), firstKey, 'the original component keeps its key beneath the child');
assert.equal(n.detailSearchParents[0].result, firstResult, 'child results cannot overwrite the original search');
assert.equal(n.homeEntryPhoto.returnPageOnly, true); assert.equal(n.homeEntryPhoto.imageHeight, 800);
n.pinStore.imageLayer = 'search'; n.pinStore.visualResult = { pin: url(2), loading: false, items: [card(3)] };
n.pinStore.detailScrollOffset = 480; assert.equal(n.openDetailSearchResult(card(3)), true);
assert.deepEqual(Array.from(n.detailPresentationIdentities()), ['1', '2', '3']);
for (const [id, offset] of [['2', 480], ['1', 240]]) {
  current = id; n.pinStore.detail = cache.get(id).detail;
  n.restoreDetailSearchPresentation(url(id), true);
  assert.equal(n.pinStore.imageLayer, 'search'); assert.equal(n.pinStore.visualResult.pin, url(id));
  assert.equal(n.pinStore.detailScrollOffset, offset); assert.equal(continuation.bookmark, 'cursor-' + id);
}
assert.equal(n.detailSearchParents.length, 0); assert.equal(n.detailPresentationKey('1'), firstKey);
assert.equal(n.openDetailSearchResult(card(1)), false, 'the source Pin never replaces its own search');
assert.equal(n.openDetailSearchResult({ ...card(2), pinUrl: 'https://example.com/pin/2/' }), false);
assert.equal(n.openDetailSearchResult(card(2)), true, 'a returned result can be opened again');
assert.match(index, /if \(!preserveRead\) this\.detailSearchParents = \[\]/);
assert.match(index, /detailEntryCards\.clear\(\); this\.detailSearchParents = \[\]/);
assert.match(page, /presentationActive: this\.pageActive/);
assert.match(page, /if \(this\.onVisualResult\) return this\.onVisualResult\(id\)/);
assert(!page.slice(page.indexOf('onRelated: (id: string) => {'), page.indexOf('onRelated: (id: string) => {') + 220).includes("this.onImageLayer('')"));

const Sheet = host(shared, ['openRelated', 'resultSheetAppeared', 'presentationChanged', 'resultSheetDisappeared']);
const sheet = new Sheet(), crop = { x: .2, y: .1, w: .5, h: .6 }; let restoredOffset = -1, opens = 0;
Object.assign(sheet, { alive: true, presentationActive: true, relatedOpening: false, result: { loading: false }, pin: url(1),
  closing: false, sheetVisible: true, sheetHeight: 'large', resultSheetMounted: true, crop,
  resultScroller: { offset: () => ({ yOffset: 730 }), scrollTo: options => restoredOffset = options.yOffset },
  onRelated: () => { opens++; sheet.presentationActive = false; sheet.presentationChanged(); return true; }
});
sheet.openRelated(card(2)); assert.equal(opens, 1); assert.equal(sheet.sheetVisible, false);
sheet.openRelated(card(3)); assert.equal(opens, 1, 'hidden search cannot open another Pin');
sheet.presentationActive = true; sheet.presentationChanged();
assert.equal(sheet.resumeRelatedSheet, true, 'rapid return waits for the previous Sheet disappearance');
sheet.resultSheetDisappeared(); sheet.resultSheetAppeared();
assert.equal(sheet.sheetVisible, true); assert.equal(sheet.relatedOpening, false);
assert.equal(restoredOffset, 730); assert.equal(sheet.crop, crop); assert.equal(sheet.sheetHeight, 'large');
sheet.onRelated = () => false; sheet.openRelated(card(3));
assert.equal(sheet.sheetVisible, true); assert.equal(sheet.relatedOpening, false, 'rejected navigation unlocks the existing panel');
const Continuation = host(aux, ['visualContinuation', 'restoreVisualContinuation']);
const cursor = new Continuation(); Object.assign(cursor, { pin: url(1), account: 'owner', bookmark: 'next', crop: JSON.stringify(crop),
  store: { detailPin: url(1) }, key: () => 'owner' });
const saved = cursor.visualContinuation(); cursor.bookmark = 'child'; cursor.restoreVisualContinuation(saved);
assert.equal(cursor.bookmark, 'next'); assert.equal(cursor.crop, saved.crop);
cursor.store.detailPin = url(2); cursor.restoreVisualContinuation(saved); assert.equal(cursor.bookmark, '');
cursor.store.detailPin = url(1); cursor.key = () => 'other-account'; cursor.restoreVisualContinuation(saved); assert.equal(cursor.crop, '');
console.log('Independent search Pin pages: nested retention, stable parent, return/reopen, crop, Sheet detent/scroll, pagination continuation and owner isolation passed');
