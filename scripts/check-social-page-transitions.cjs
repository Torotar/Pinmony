const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const settings = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySettingsPage.ets', 'utf8');
const social = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySocialPermissionsPage.ets', 'utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function methods(source, names) {
  const ast = ts.createSourceFile('host.ts', source.replace(/\bstruct\b/g, 'class '), 99, true);
  const found = new Map();
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) found.set(node.name.getText(ast), node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  for (const name of names) assert(found.has(name), name);
  return names.map(name => found.get(name)).join('\n');
}
function host(source, names, context = {}) {
  return vm.runInNewContext(ts.transpileModule('class Host {' + methods(source, names) + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, context);
}
const Routes = host(settings, ['settingsPageScreens']);
const routes = new Routes();
routes.store = { screen: 'root' };
const expected = {
  root: [], social: ['social'], socialComments: ['social', 'socialComments'],
  socialBlocked: ['social', 'socialBlocked'], socialMentions: ['social', 'socialMentions'],
  socialMessages: ['social', 'socialMessages'], personal: ['account', 'personal'], display: ['display']
};
for (const leaf of ['socialFriends', 'socialFollowers', 'socialFollowing', 'socialOthers']) {
  expected[leaf] = ['social', 'socialMessages', leaf];
}
for (const [screen, stack] of Object.entries(expected)) {
  routes.store.screen = screen;
  assert.deepEqual(Array.from(routes.settingsPageScreens()), stack, screen);
}
let previous = [];
for (const screen of ['social', 'socialMessages', 'socialFriends', 'socialMessages', 'social', 'root']) {
  routes.store.screen = screen;
  const next = Array.from(routes.settingsPageScreens());
  const retained = previous.filter(key => next.includes(key));
  assert.deepEqual(next.slice(0, retained.length), retained, 'parent route keys stay mounted and keep their position');
  assert(Math.abs(next.length - previous.length) === 1, 'push/pop only adds/removes the top layer');
  previous = next;
}
assert(settings.includes('routeScreen: screen, active: screen === this.store.screen'));
assert(settings.includes('.hitTestBehavior(_screen !== this.store.screen ? HitTestMode.None : HitTestMode.Default)'));
assert(settings.includes(".accessibilityLevel(_screen !== this.store.screen ? 'no-hide-descendants' : 'auto')"));
assert(settings.includes('.transition(TransitionEffect.asymmetric('));
assert(settings.includes('animation({duration:180,curve:Curve.EaseOut})'));
assert(settings.includes('animation({duration:150,curve:Curve.EaseIn})'));
assert(!social.includes('ForEach([this.store.screen]'), 'do not replace the inner content during navigation');
assert(!social.includes('.transition('), 'one route host owns the page transition');
assert(!methods(social, ['open']).includes('scrollTo'), 'opening a child preserves the parent scroll');

const animations = [];
const Page = host(social, ['pageScreen', 'title', 'groupId', 'open', 'available', 'selectMessageTab'], {
  Curve: { EaseOut: 'out' }
});
const page = new Page();
page.visible = true; page.active = true; page.confirming = false;
page.routeScreen = 'social';
page.store = { screen: 'social', token: 3, error: 'old', busy: false, loading: false, social: { business: false } };
page.uiText = key => key;
page.getUIContext = () => ({ animateTo(options, action) { animations.push(options); action(); } });
const requests = [];
page.onRequest = (...args) => requests.push(args);
page.open('socialMessages');
assert.equal(page.store.screen, 'socialMessages');
assert.equal(page.store.token, 4);
assert.equal(animations[0].duration, 180);
assert.equal(animations[0].curve, 'out');
assert.deepEqual(requests, [['socialRead', '']]);
assert.equal(page.pageScreen(), 'social', 'covered parent retains its own content');
assert.equal(page.title(), 'pm_social_title', 'covered parent retains its own title');
page.active = false;
assert.equal(page.available(), false);
page.open('socialBlocked');
assert.equal(requests.length, 1, 'inactive parent cannot navigate or send a request');
page.routeScreen = 'socialFriends'; page.store.screen = 'socialFollowers';
assert.equal(page.groupId(), 0, 'retained message choice page does not inherit the next route');

const Back = host(index, ['closeProfileSettings'], { Date, Curve: { EaseIn: 'in', EaseOut: 'out' } });
for (const screen of ['socialFriends', 'socialMessages', 'social']) {
  const back = new Back();
  let cancels = 0;
  let notifications = 0;
  let backCalls = 0;
  back.pinStore = {};
  back.nativeChildBackUntil = 0;
  back.settingsStore = { screen, busy: false, back() { backCalls++; return true; } };
  back.cancelAccountSettings = () => cancels++;
  back.rootContextCoordinator = { notify() { notifications++; } };
  back.getUIContext = () => ({ animateTo(options, action) {
    assert.equal(options.duration, 150); assert.equal(options.curve, 'in'); action();
  } });
  back.closeProfileSettings();
  assert.equal(backCalls, 1); assert.equal(cancels, 1); assert.equal(notifications, 1);
  back.closeProfileSettings();
  assert.equal(backCalls, 1, 'existing return throttle prevents repeated pops');
}
assert(social.includes('.onBackPressed(() => { if (this.active === false) return false;'));
assert(social.includes('if (this.active !== false && this.onBack) this.onBack();'));
console.log('Social page transitions: all route chains, stable parents and titles, scroll retention, inactive guards, 180ms enter/150ms exit and shared back throttle passed');
