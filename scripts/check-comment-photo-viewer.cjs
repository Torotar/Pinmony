const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { fixture: sharedFixture } = require('./check-shared-image-viewer.cjs');
const geometry = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets', 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const imageContainRect = vm.runInNewContext(ts.transpileModule(geometry + ';imageContainRect;', { compilerOptions: { target: 99 } }).outputText);
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets', 'utf8');
const ast = ts.createSourceFile('comments.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['photoSourceId', 'commentPhotoFrame', 'recordPhotoSize', 'currentPhoto', 'releasePhoto', 'clearPhoto', 'openPhoto', 'resultChanged', 'aboutToDisappear'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
  ts.forEachChild(node, visit);
}
visit(ast); assert.equal(methods.length, names.length);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { imageContainRect });
function fixture() {
  const f = sharedFixture();
  const photo = { id: '21', imageUrl: 'synthetic-photo', replies: [] };
  const h = Object.assign(new Host(), { result: { pin: '/pin/1/', items: [photo] }, draftPin: '/pin/1/',
    mutationVersion: 0, draft: 'keep draft', photoId: '', hiddenPhotoId: '', photoPin: '', photoUrl: '', photoSizes: [],
    onViewerOpen: request => f.session.open(request), onViewerCancel: owner => f.session.cancel(owner) });
  return { ...f, h, photo };
}
const f = fixture(), { h, photo, session, ui } = f;
h.recordPhotoSize(photo, 1080, 2340);
const frame = h.commentPhotoFrame(photo); assert.equal(frame.height, 110);
assert(Math.abs(frame.width / frame.height - 1080 / 2340) < 0.0001, 'rounded source excludes letterboxing');
h.recordPhotoSize({ id: 'stale', imageUrl: 'old' }, 100, 100); assert.equal(h.photoSizes.length, 1);
h.openPhoto({ id: '22' }); assert(!session.visible);
h.openPhoto(photo); assert(session.visible); assert.equal(h.hiddenPhotoId, '', 'source remains until shared renderer is ready');
assert.equal(h.draft, 'keep draft'); assert.equal(session.request.detail.actions.length, 0); assert.equal(session.request.detail.carousel, undefined);
assert.equal(session.request.sourceRadius, 10); assert.equal(session.request.sourceId(), h.photoSourceId(photo));
h.openPhoto({ id: '23', imageUrl: 'other' }); assert.equal(h.photoId, '21');
const revision = session.revision;
session.measure(ui, revision); session.rendered(revision); assert.equal(h.hiddenPhotoId, '21');
h.resultChanged(); assert(session.visible);
h.result = { ...h.result, items: [{ ...photo, translatedText: 'translated' }] }; h.resultChanged(); assert(session.visible);
session.close(); assert(session.closing && session.visible); assert.equal(h.hiddenPhotoId, '21');
session.finish(revision); assert(!session.visible); assert.equal(h.hiddenPhotoId, ''); assert.equal(h.draft, 'keep draft');
h.openPhoto(photo); h.result = { ...h.result, items: [{ ...photo, imageUrl: 'replacement' }] }; h.resultChanged(); assert(!session.visible);
const nested = fixture(); nested.photo.replies.push({ id: '31', imageUrl: 'reply-photo' });
nested.h.openPhoto(nested.photo.replies[0]); assert(nested.session.visible); nested.h.resultChanged(); assert(nested.session.visible);
nested.h.result.pin = '/pin/2/'; nested.h.resultChanged(); assert(!nested.session.visible); assert.equal(nested.h.photoSizes.length, 0);
const disposed = fixture(); disposed.h.openPhoto(disposed.photo); disposed.h.aboutToDisappear(); assert(!disposed.session.visible);
assert(!source.includes('private photoViewer(')); assert(!source.includes('photoClosing'));
assert(!source.includes('.bindContentCover(')); assert(!source.includes('PinmonyImageViewer({'));
assert(source.includes('this.hiddenPhotoId === item.id ? 0 : 1'));
console.log('Comment entry -> shared viewer: original/round source geometry, decode handoff, reverse close, draft/snapshot retention, reply, Pin change, replacement and disposal passed');