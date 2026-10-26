const fs = require('node:fs');
const assert = require('node:assert/strict');

const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const detail = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');

const rootMethod = index.match(/  private detailRootIdentity\(\): string \{([\s\S]*?)\n  \}/);
assert(rootMethod, 'detailRootIdentity must exist');
assert(rootMethod[1].includes('this.pinIdentity('), 'root identity must use normalized Pin identity');
assert(!rootMethod[1].includes('detailOpeningToken'), 'root identity must not include opening token');
assert(!rootMethod[1].includes('detail.session'), 'root identity must not include snapshot session');
assert(index.includes('ForEach(this.detailPresentationIdentities()'),
  'detail root ForEach must use stable Pin identity');
assert(index.includes('? this.detailRenderIdentity() : _identity'),
  'volatile render identity must remain available to the detail component');
assert(detail.includes('ForEach(this.heroImageSources(this.detail.imageUrl, this.detail.pinUrl)') && detail.includes('=> source.key'),
  'hero image source identity controls structural node reuse');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const routeMethods = ['detailRootIdentity','detailPresentationIdentities','detailPresentation'].map(name =>
  index.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'))[0]).join('\n');
const Routes = vm.runInNewContext(ts.transpileModule('class Routes {'+routeMethods+'} Routes;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const routes = new Routes();
const parent = {pinUrl:'https://www.pinterest.com/pin/101/'}, child = {pinUrl:'https://www.pinterest.com/pin/102/'};
Object.assign(routes,{pinStore:{detail:parent},pinIdentity:v=>v.match(/\/pin\/(\d+)/)?.[1] || '',homeEntryCardId:'',homeEntryPhoto:undefined});
assert.equal(routes.detailPresentationIdentities().join(','),'101');
routes.relatedEntryParent=parent;routes.homeEntryPhoto={pinUrl:child.pinUrl};routes.homeEntryCardId='pinmony-related-photo-parent-child';routes.pinStore.detail=child;
assert.equal(routes.detailPresentationIdentities().join(','),'101,102','child insertion retains the mounted parent key in the same ForEach');
assert.equal(routes.detailPresentation('101'),parent);
routes.pinStore.detail=parent;routes.homeEntryPhoto=undefined;
assert.equal(routes.detailPresentationIdentities().join(','),'101','return removes only the child, preserving the original parent node');
const method = name => detail.match(new RegExp('  private ' + name + '\\([\\s\\S]*?\\r?\\n  \\}'))[0];
const context = {};
require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(`class Page {
  ${method('onPinChanged')}
  ${method('heroRenderKey')}
  ${method('heroImageSources')}
  ${method('retryHeroImage')}
} globalThis.Page = Page;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const page = new context.Page();
Object.assign(page, { detail: { pinUrl: 'https://www.pinterest.com/pin/101/', imageUrl: 'https://i.pinimg.com/1.jpg', kind: 'cached', session: 0 },
  heroIdentityKey: '', heroRenderRevision: 0, heroLoadedUrl: '', activePin: '', heroVisible: true,
  stopHeroDeadline() {}, syncHeroDeadline() {}, auditHeroImage() {},
  notifyImageLoaded() {}, restoreScrollPosition() {}, startSearchLabel() {}, updateDetailLayout() {}, auditRecommendationGate() {} });
page.onPinChanged();
const cachedKey = page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl);
page.detail = { ...page.detail, kind: 'state', session: 7 }; page.onPinChanged();
assert.equal(page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl), cachedKey, 'current confirmation preserves the same decoded image node');
assert.equal(page.heroRenderRevision, 0, 'snapshot updates never mutate the image node generation');
page.detail.imageUrl += '?version=2'; page.onPinChanged();
assert.notEqual(page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl), cachedKey, 'complete image URL changes require a new image identity');
const currentSource = page.heroImageSources(page.detail.imageUrl, page.detail.pinUrl)[0];
page.retryHeroImage(currentSource.key);
assert.notEqual(page.heroRenderKey(page.detail.imageUrl, page.detail.pinUrl), currentSource.key, 'retry replaces the complete hero component');
page.retryHeroImage(currentSource.key);
assert.equal(page.heroRenderRevision, 1, 'stale retry intent cannot replace the new node');
assert(detail.includes('private heroImage()'), 'hero builder reads state directly instead of freezing two value arguments');
console.log('Detail root reuse: stable Pin root, volatile snapshot guard, and independent hero key passed');
