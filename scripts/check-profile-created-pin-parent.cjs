const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const content = fs.readFileSync('entry/src/main/ets/components/PinmonyProfileRootContent.ets', 'utf8');
const ast = ts.createSourceFile('host.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
let method;
function visit(node) {
  if (ts.isMethodDeclaration(node) && node.name.getText(ast) === 'retainProfilePinParent') method = node.getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast); assert(method);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const profile = 'https://www.pinterest.com/example/', pin = 'https://www.pinterest.com/pin/123/';
function fixture() {
  return Object.assign(new Host(), { profileStore: { profile: { profileUrl: profile } },
    pinStore: { detail: undefined, detailOpeningPin: pin, detailReturnUrl: profile + '_created/', detailOrigin: () => '' },
    nativeBackTarget: pin, navigationAddress: pin, pinIdentity: value => value,
    profileUrlFromAddress: value => [profile, profile + '_created/'].includes(value) ? profile : '' });
}
const h = fixture(); assert(h.retainProfilePinParent(), 'preload retains profile without a captured image');
h.pinStore.detail = { pinUrl: pin }; h.pinStore.detailOpeningPin = '';
assert(h.retainProfilePinParent(), 'loaded detail retains same parent');
h.nativeBackTarget = profile; assert.equal(h.retainProfilePinParent(), false, 'return restores active profile');
for (const invalidate of [
  h => { h.profileStore.profile = undefined; },
  h => { h.profileStore.profile.profileUrl = 'different'; },
  h => { h.pinStore.detailOpeningPin = ''; },
  h => { h.pinStore.detailReturnUrl = 'board'; },
  h => { h.pinStore.detailOrigin = () => 'different'; },
  h => { h.nativeBackTarget = ''; h.navigationAddress = profile; }
]) { const f = fixture(); invalidate(f); assert.equal(f.retainProfilePinParent(), false, 'unrelated/closed/return context cannot retain parent'); }
const stored = fixture(); stored.pinStore.detailReturnUrl = 'board'; stored.pinStore.detailOrigin = () => profile;
assert(stored.retainProfilePinParent(), 'per-Pin origin takes priority over shared fallback');
assert(source.includes('retainPinSource: this.retainProfilePinParent() ||'), 'retention independent of photo transition');
assert(source.includes('this.currentProfileUrl() || this.retainProfileBoardParent() || this.retainProfilePinParent()'), 'visitor overlay remains mounted');
assert(source.includes('coveredByPin: this.retainProfilePinParent()'));
for (const prop of ['backActive', 'interactionReady', 'automaticLoadingEnabled']) {
  assert(content.includes(prop + ': !view.coveredByBoard && !view.coveredByPin &&'), prop);
}
assert(content.includes('if (view.coveredByBoard || view.coveredByPin ||'), 'covered page cannot rewrite scroll');
assert(source.includes('.zIndex(!this.retainProfileBoardParent() && !this.retainProfilePinParent() &&'), 'child Pin remains above parent');
console.log('Created Pin parent: preload/loaded retention without photo, matching source, return/cleanup and covered gates passed');
