const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_profile/src/main/ets/components/PinmonyPublishPage.ets';
const source = fs.readFileSync(file, 'utf8');
const sf = ts.createSourceFile(file, source.replace('export struct PinmonyPublishPage', 'export class PinmonyPublishPage'), ts.ScriptTarget.Latest, true);
const view = sf.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'PinmonyPublishPage');
const names = ['syncWebsiteRoute', 'websiteTransition', 'destinationPhase', 'pageBack', 'act'];
const methods = names.map(name => view.members.find(n => ts.isMethodDeclaration(n) && n.name?.getText(sf) === name).getText(sf)).join('\n');
const scope = { exports: {}, NavigationOperation: { POP: 'pop' }, Curve: { EaseOut: 'easeOut' } };
vm.runInNewContext(ts.transpileModule('export class Host {' + methods + '}', { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText, scope);
const host = new scope.exports.Host();
const paths = ['publish'], actions = [], frames = [], animations = [];
let finished = 0;
Object.assign(host, { state: { phase: 'photo', kind: 'photo' }, draftRoot: true, mounted: true,
  websiteRouteOpen: false, websiteClosing: false,
  stack: { pushPath(info, animated) { assert.equal(animated, true); paths.push(info.name); }, pop(animated) { assert.equal(animated, true); paths.pop(); } },
  onAction(action, phase) { actions.push([action, phase]); },
  getUIContext() { return { postFrameCallback(frame) { frames.push(frame); }, animateTo(options, change) { animations.push(options); change(); options.onFinish(); } }; }
});
host.state = { phase: 'website', kind: 'website', fromDraftBox: true };
host.syncWebsiteRoute(); host.syncWebsiteRoute();
assert.deepEqual(paths, ['publish', 'draft-website'], 'website pushes once and retains drafts');
assert.equal(host.destinationPhase('publish'), 'photo');
assert.equal(host.destinationPhase('draft-website'), 'website');
const enter = host.websiteTransition({ name: 'publish' }, { name: 'draft-website' }, 'push');
enter.transition({ finishTransition() { finished++; } });
assert.equal(host.websiteMotionOffset, '100%');
frames.shift().onIdle(); assert.equal(host.websiteMotionOffset, '0%');
// Execute the actual system-back handler used by either retained destination.
const back = source.match(/\.onBackPressed\(\(\) => \{ (this\.pageBack\(this\.state\.phase\); return true;) \}\)/);
assert(back, 'system return must dispatch the current top phase');
const systemBack = new Function(back[1]);
assert.equal(systemBack.call(host), true);
assert.deepEqual(actions.pop(), ['back', 'website']);
host.pageBack('photo'); assert.equal(actions.length, 0, 'covered title cannot close publishing');
host.state = { phase: 'photo', kind: 'photo', fromDraftBox: false };
host.syncWebsiteRoute(); host.syncWebsiteRoute();
assert.deepEqual(paths, ['publish']);
systemBack.call(host); assert.equal(actions.length, 0, 'duplicate return during exit is consumed');
assert.equal(host.destinationPhase('draft-website'), 'website', 'exiting website keeps its own content');
const leave = host.websiteTransition({ name: 'draft-website' }, { name: 'publish' }, 'pop');
leave.transition({ finishTransition() { finished++; } }); frames.shift().onIdle();
assert.equal(host.websiteMotionOffset, '100%'); leave.onTransitionEnd(true);
assert.equal(host.websiteRouteOpen, false); assert.equal(host.websiteClosing, false);
assert.equal(finished, 2); assert.equal(animations[0].duration, 180);
assert.equal(animations[0].duration, animations[1].duration); assert.equal(animations[0].curve, animations[1].curve);
systemBack.call(host); assert.deepEqual(actions.pop(), ['close', '']);
host.state = { phase: 'empty', kind: 'website', fromDraftBox: true };
host.syncWebsiteRoute(); systemBack.call(host); assert.deepEqual(actions.pop(), ['back', 'empty']);
host.state.busy = true; systemBack.call(host); assert.equal(actions.length, 0);
assert(source.includes(".hitTestBehavior(!$$.websiteChild && this.websiteRouteOpen ? HitTestMode.None"));
assert(source.includes(".accessibilityLevel(!$$.websiteChild && this.websiteRouteOpen ? 'no-hide-descendants'"));
assert(source.includes('Scroll($$.websiteChild ? this.websiteScroller : this.scroller)'));
console.log('Publish website navigation: retained drafts, independent route, matched animations, system/title back, empty state and duplicate-back protection passed');
