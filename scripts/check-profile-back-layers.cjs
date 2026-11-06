const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const profile = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
function method(source, name) {
  const declaration = new RegExp('^\\s*(?:private\\s+)?(?:async\\s+)?' + name + '\\(', 'm').exec(source);
  assert(declaration, name);
  const start = declaration.index;
  const body = source.indexOf('{', start);
  let depth = 1, end = body + 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(start, end);
}
const source = 'class Harness {' + method(index, 'inboxFlowAction') + method(index, 'onBackPress') +
  method(profile, 'requestProfileBack') + '} Harness;';
const Harness = vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { PinmonyRuntimeLog: { info() {} } });
function destinationBack(source, state) {
  const marker = '.onBackPressed(() => {';
  const start = source.lastIndexOf(marker) + marker.length - 1;
  assert(start >= marker.length - 1);
  let depth = 1, end = start + 1;
  for (; depth; end++) {
    assert(end < source.length);
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  const Back = vm.runInNewContext(ts.transpileModule('class Back { fire() ' + source.slice(start, end) + '} Back;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText);
  return Object.assign(new Back(), state);
}
async function main() {
  const h = new Harness(); let nativeBacks = 0, parentBacks = 0;
  Object.assign(h, {
    profileChatActive: true, nativeChildBackUntil: 0, profileStore: { origins: [{}] }, pinStore: {}, inboxStore: { inboxFlow: { screen: 'settings' } },
    inboxMessagesNativeReads: { async action(action) {
      assert.equal(action, 'back'); nativeBacks++;
      h.inboxStore.inboxFlow = h.inboxStore.inboxFlow.screen === 'settings' ? { screen: 'chat' } : undefined;
    } },
    navigationCoordinator: { onBackPress() { parentBacks++; return true; } },
    authStatus: 'authenticated', boardOrderVisible: false, boardRecoveryVisible: false
  });
  await h.inboxFlowAction('back');
  assert.equal(h.inboxStore.inboxFlow.screen, 'chat'); assert(h.profileChatActive);
  h.onBackPress(); assert.equal(nativeBacks, 1, 'duplicate back during settings exit cannot also close chat');
  h.nativeChildBackUntil = 0; h.onBackPress(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.inboxStore.inboxFlow, undefined); assert.equal(h.profileChatActive, false);
  h.onBackPress(); assert.equal(parentBacks, 0, 'chat dismissal cannot also pop the retained profile');
  h.backActive = false; h.onBack = () => parentBacks++; h.backRequested = false;
  h.requestProfileBack(); assert.equal(parentBacks, 0); assert.equal(h.backRequested, false, 'covered profile cannot latch its back state');
  h.backActive = true; h.requestProfileBack(); h.requestProfileBack(); assert.equal(parentBacks, 1);
  const binding = fs.readFileSync('entry/src/main/ets/components/PinmonyProfileRootContent.ets', 'utf8');
  assert(binding.includes('backActive: !view.profileChatActive && !view.profileStore.panel && !view.profileStore.searchVisible'));
  assert(index.includes('pageActive: _identity === this.detailRootIdentity() && !this.profileChatActive &&'));
  for (const file of ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets',
    'feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets',
    'feature_pin/src/main/ets/components/PinmonyDetailPage.ets',
    'feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets']) {
    const content = fs.readFileSync(file, 'utf8');
    let forwarded = 0, defaultPops = 0;
    const page = destinationBack(content, { active: false, backActive: false, pageActive: false,
      onCoveredBack() { forwarded++; return true; } });
    if (!page.fire()) defaultPops++;
    assert.equal(forwarded, 1, file + ': covered destination forwards immediately to host');
    assert.equal(defaultPops, 0, file + ': HDS must not pop retained root into an empty navigation');
  }
  const inbox = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
  h.profileChatActive = true; h.nativeChildBackUntil = 0; h.inboxStore.inboxFlow = { screen: 'chat' };
  const covered = destinationBack(profile, { backActive: false, onCoveredBack: () => h.onBackPress() });
  assert.equal(covered.fire(), true); await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.inboxStore.inboxFlow, undefined, 'first back delivered to covered profile closes only top chat');
  assert.equal(h.profileStore.origins.length, 1, 'contact return preserves profile origin');
  assert.equal(parentBacks, 1, 'contact return does not reopen lower Pin');
  h.nativeChildBackUntil = 0;h.profileChatActive = true;h.inboxStore.inboxFlow = { screen: 'chat' };
  const chat = destinationBack(inbox, { active: true, act: () => h.inboxFlowAction('back') });
  assert.equal(chat.fire(), true);await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.inboxStore.inboxFlow, undefined, 'active chat handles first system back');
  assert.equal(parentBacks, 1);
  console.log('Profile back layers: real destination callbacks, first contact return, no HDS default pop/empty roots, settings/chat, duplicate suppression and retained profile passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
