const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts);
const { PinmonyDetailSources: Sources } = loader.loadPackage('common_ui');
const { PinmonyDetailSiblingNavigation: Navigation } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailSiblingNavigation.ets');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace(/\bstruct\b/g, 'class');
const ast = ts.createSourceFile('host.ts', source, 99, true), selected = [];
const names = ['detailRootIdentity', 'detailPresentationIdentities', 'detailPresentationKey', 'detailPresentation'];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) selected.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast); assert.equal(selected.length, names.length);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + selected.join('\n') + '} Host;', {
  compilerOptions: { target: 99 }
}).outputText);
const url = id => `https://www.pinterest.com/pin/${id}/`;
const cards = [1, 2, 3].map(id => ({ pinUrl: url(id), cardId: 'card-' + id, imageUrl: 'image-' + id }));
const nav = new Navigation();
Sources.stage({ identity: 'home:1', pageUrl: 'https://www.pinterest.com/', session: 1, cards: () => cards, locate() {} });
nav.enter(url(1), 'card-1', 7, false);
const h = new Host(); let generation = 7;
Object.assign(h, { pinStore: { detail: { pinUrl: url(1), imageUrl: 'image-1' } },
  detailSiblings: nav, nativeBusinessSessionContext: () => ({ generation }),
  pinIdentity: value => value.match(/\/pin\/(\d+)/)?.[1] || '',
  detailSearchParents: [], detailEntryCards: new Map() });
const capturedRoot = h.detailRootIdentity(), capturedKey = h.detailPresentationKey(capturedRoot);
for (const [id, step] of [[2, 1], [3, 1], [2, -1], [1, -1]]) {
  const previous = h.pinStore.detail.pinUrl;
  nav.advance(previous, 7, step);
  h.pinStore.detail = { pinUrl: url(id), imageUrl: 'image-' + id, kind: 'opening' };
  assert.equal(h.detailRootIdentity(), capturedRoot, 'sibling switch must retain destination identity');
  assert.equal(h.detailPresentationKey(capturedRoot), capturedKey, 'ForEach must not remount the whole detail');
  assert.equal(h.detailPresentation(capturedRoot).pinUrl, url(id), 'retained builder closure resolves current Pin');
  h.pinStore.detail = { ...h.pinStore.detail, kind: 'cached', session: 99 };
  assert.equal(h.detailRootIdentity(), capturedRoot, 'base publication does not rebuild destination');
}
nav.advance(url(1), 7, 1);
const parent = { pinUrl: url(2), imageUrl: 'image-2' };
h.pinStore.detail = { pinUrl: url(9) }; h.relatedEntryParent = parent;
h.homeEntryPhoto = {}; h.homeEntryCardId = 'pinmony-related-photo-9';
assert.deepEqual(Array.from(h.detailPresentationIdentities()), [capturedRoot, '9'], 'nested child retains actual sibling parent presentation');
assert.equal(h.detailPresentation(capturedRoot), parent);
h.pinStore.detail = parent; h.relatedEntryParent = undefined;
assert.equal(h.detailRootIdentity(), capturedRoot, 'return restores original destination');
h.shuffleParentDetail = parent; h.shuffleSelectedImage = 'cutout'; h.collageDetailPinUrl = url(4);
h.pinStore.detail = { pinUrl: url(4) };
assert.equal(h.detailRootIdentity(), capturedRoot, 'collage child retains its source destination');
h.shuffleParentDetail = undefined; h.pinStore.detail = parent;
Sources.stage({ identity: 'related:2', pageUrl: url(2), session: 2, cards: () => cards, locate() {} });
nav.enter(url(1), 'card-1', 7, false);
h.pinStore.detail = { pinUrl: url(1) }; h.relatedEntryParent = parent;
assert.notEqual(h.detailRootIdentity(), capturedRoot, 'nested Pin matching original entry gets independent destination');
assert.equal(h.detailPresentationIdentities().length, 2, 'nested same-Pin identity cannot collapse parent');
h.pinStore.detail = parent; h.relatedEntryParent = undefined;
generation = 8;
assert.equal(h.detailRootIdentity(), '2', 'new account cannot reuse old sibling identity');
generation = 7; nav.clear();
assert.equal(h.detailRootIdentity(), '2', 'source lifecycle clear releases retained identity');
console.log('Sibling presentation: A-B-C-B-A retains root and current data, nested child/parent, cached updates, account and lifecycle isolation passed');
