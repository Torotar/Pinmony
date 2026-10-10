const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailHero.ets', 'utf8');
const parent = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const method = name => source.match(new RegExp('  (?:private )?' + name + '\\([\\s\\S]*?\\r?\\n  \\}'))[0];
let serial = 0;
const timers = new Map(), decoded = [], logs = [];
const context = { Date, PinmonyRuntimeLog: { info: line => logs.push(line) },
  setTimeout(fn, delay) { const id = ++serial; timers.set(id, { fn, delay }); return id; },
  clearTimeout(id) { timers.delete(id); } };
vm.runInNewContext(ts.transpileModule(`class Hero {
  ${['aboutToAppear', 'aboutToDisappear', 'isCurrent', 'stopDeadline', 'onStageChanged',
    'onRenderChanged', 'completeImage', 'failImage', 'retryImage', 'audit'].map(method).join('\n')}
} globalThis.Hero = Hero;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
function hero(revision = 0) {
  const node = new context.Hero();
  Object.assign(node, { source: { pinUrl: 'https://www.pinterest.com/pin/101/', url: 'https://i.pinimg.com/hero.jpg',
    key: 'synthetic-source-' + revision, revision }, imageState: 'loading', decoded: false, deadline: -1,
    stageReady: false, confirmedLoaded: false, phase: 'opening', openId: 3, onLoaded: (...args) => decoded.push(args) });
  node.aboutToAppear(); return node;
}
const opening = hero(), deadline = timers.get(opening.deadline);
assert.equal(deadline.delay, 8000); deadline.fn();
assert.equal(opening.imageState, 'timeout'); assert.equal(decoded.length, 0);
opening.completeImage(0); assert.equal(decoded.length, 0, 'download success is not decode success');
opening.completeImage(1); assert.equal(opening.imageState, 'loaded'); assert.equal(decoded.length, 1);
opening.completeImage(1); assert.equal(decoded.length, 1, 'duplicate decode callbacks do not duplicate notifications');
opening.renderIdentity = 'current-confirmation'; opening.onRenderChanged();
assert.equal(decoded.length, 2, 'an unchanged decoded node reports readiness for a new detail confirmation');
const stage = hero(); stage.stageReady = true; stage.onStageChanged();
assert.equal(stage.imageState, 'timeout', 'bridge timeout stops waiting but does not unmount the Image');
assert.equal(stage.decoded, false);
stage.completeImage(1); assert.equal(stage.imageState, 'loaded', 'real late decode replaces timeout');
let retries = 0; const retry = hero(1); retry.onRetry = () => retries++;
retry.stageReady = true; retry.onStageChanged();
assert.equal(retry.imageState, 'loading', 'old bridge timeout does not finish a fresh retry generation');
retry.failImage(); assert.equal(retry.imageState, 'failed'); retry.retryImage(); assert.equal(retries, 1);
const stale = hero(2), staleDeadline = timers.get(stale.deadline);
stale.aboutToDisappear(); const notifications = decoded.length;
staleDeadline.fn(); stale.completeImage(1); stale.retryImage();
assert.equal(decoded.length, notifications, 'departed node cannot confirm an image');
assert.equal(stale.imageState, 'loading', 'departed timer cannot change visual state');
const changed = hero(3); changed.source.key = 'unexpected-other-source'; changed.completeImage(1);
assert.equal(decoded.length, notifications, 'callbacks must match immutable mounted source');
const cached = hero(); cached.confirmedLoaded = true; cached.stageReady = true; cached.onStageChanged();
assert.equal(cached.decoded, false, 'a previous snapshot does not fake decode of a newly mounted node');
cached.completeImage(1); assert.equal(decoded.length, notifications + 1);
assert(source.includes('Image(this.source.url)'));
assert(!source.slice(source.indexOf('build()')).includes("if (this.imageState === 'loaded')"), 'loading feedback never removes the actual Image');
assert(parent.includes('private heroImage()'));
assert(!logs.join('\n').includes('https://'), 'node diagnostics exclude Pin and image URLs');
assert(logs.some(line => line.includes('event=node-created')) && logs.some(line => line.includes('event=node-disposed')));
console.log('Isolated detail hero: node lifecycle, bounded timeout, actual retry generation, decode-only success, confirmation reuse, stale guards and payload-free diagnostics passed');
