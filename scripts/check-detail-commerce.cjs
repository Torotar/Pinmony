const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(file, deps = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
  } }).outputText, { exports, require: name => deps[name] || ({ PinmonyRuntimeLog: { info() {} }, PinmonyI18n: { message: k => k }, PinmonyTaskRegistry: class {} }) });
  return exports;
}
const root = 'feature_pin/src/main/ets/';
const { mapPrefetchedDetail, PinmonyDetailPrefetch } = load(root + 'services/PinmonyDetailPrefetch.ets');
const { PinmonyDetailCache } = load(root + 'services/PinmonyDetailCache.ets');
const { readProductPresentation } = load(root + 'services/PinmonyProductPresentation.ets');
const shuffleUrl = 'https://www.pinterest.com/pin/101/';
const shuffleBody = shuffle => JSON.stringify({ resource_response: { status: 'success', data: {
  id: '101', type: 'pin', images: { '736x': { url: 'https://i.pinimg.com/736x/fixture.jpg', width: 736, height: 1000 } }, shuffle
} } });
const shuffleDetail = mapPrefetchedDetail(shuffleBody({ id: '202', user: { id: 'private-fixture' } }), shuffleUrl, true);
assert.equal(shuffleDetail.shuffleId, '202', 'Pin metadata identifies collage independently of entry route');
assert.equal(mapPrefetchedDetail(shuffleBody(null), shuffleUrl, true).shuffleId, undefined, 'ordinary Pin keeps zoom');
assert.equal(mapPrefetchedDetail(shuffleBody({ id: 'invalid' }), shuffleUrl, true).shuffleId, undefined);
const shuffleCache = new PinmonyDetailCache();
shuffleCache.put('101', shuffleDetail, 0);
assert.equal(shuffleCache.get('101').detail.shuffleId, '202', 'retained detail preserves collage identity');
const galleryBody = images => JSON.stringify({ data: { v3GetPinQueryv2: { data: {
  entityId: '101', richMetadata: { products: [{ image_736x: images.map(canonicalImage => ({ canonicalImage })) }] }
} } } });
const goodImage = { url: 'https://i.pinimg.com/736x/synthetic-product.jpg', width: 736, height: 1400 };
const gallery = readProductPresentation(galleryBody([goodImage, goodImage,
  { ...goodImage, url: 'https://example.invalid/image.jpg' },
  { ...goodImage, width: 0 }, { ...goodImage, height: 50001 },
  { ...goodImage, url: 'https://i.pinimg.com/736x/second.jpg' }]), '101');
assert.equal(gallery.images.length, 2);
assert.equal(gallery.images[0].imageHeight, 1400);
assert.equal(gallery.images[1].imageUrl, 'https://i.pinimg.com/736x/second.jpg');
assert.equal(readProductPresentation(galleryBody(Array.from({ length: 30 }, (_, index) =>
  ({ ...goodImage, url: 'https://i.pinimg.com/736x/synthetic-' + index + '.jpg' }))), '101').images.length, 20);
const productBody = (id = '101') => JSON.stringify({ data: { v3GetPinQueryv2: { data: {
  entityId: id, link: 'https://example.invalid/product', linkDomain: { name: 'Example' },
  formattedCloseupDescription: { components: [
    { type: 'formatted_description_paragraph_component', stringContent: 'Long paragraph' },
    { type: 'formatted_description_points_component', pointsContent: ['First item', 'Second item'] },
    { type: 'unknown', stringContent: 'Ignore unknown component' }
  ] }
} } } });
assert.equal(readProductPresentation(productBody(), '101').description, 'Long paragraph\n\n• First item\n• Second item');
assert.equal(readProductPresentation(productBody(), '101').sourceLabel, 'Example');
assert.equal(readProductPresentation(productBody('102'), '101'), undefined);
assert.equal(readProductPresentation('{invalid', '101'), undefined);
assert.equal(readProductPresentation(JSON.stringify({ errors: [{}], data: JSON.parse(productBody()).data }), '101'), undefined);
const source = fs.readFileSync(root + 'services/PinmonyDetailScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
const snapshot = script.match(/function apiSnapshot\(pin\) \{([\s\S]*?)\n  function snapshot\(pin\)/)[1];
const url = 'https://www.pinterest.com/pin/101/';
const base = { id: '101', type: 'pin', images: { '736x': {
  url: 'https://i.pinimg.com/synthetic.jpg', width: 736, height: 900 } },
  description: 'Short description', pinner: { full_name: 'Saver', username: 'saver' } };
const body = fields => JSON.stringify({ resource_response: { status: 'success', data: { ...base, ...fields } } });
const context = { window: {}, location: { origin: 'https://www.pinterest.com', href: url }, URL,
  session: 1, schedule() {}, findHero: () => null, webFlowActive: false };
vm.runInNewContext('function apiSnapshot(pin) {' + snapshot, context);
function bridge(fields) {
  context.window.PinmonyDetailApi = { read: () => ({ detail: { ...base, ...fields },
    image: base.images['736x'], related: [] }) };
  return context.apiSnapshot(url);
}
const commerce = { price_value: '15.00', price_currency: 'USD', affiliate_disclosure: 'Paid link',
  rich_metadata: { description: 'Full product description\n• Contents', site_name: 'Example Store', url: 'https://example.invalid/item' },
  closeup_unified_attribution: { full_name: 'Store account', username: 'store', is_verified_merchant: true } };
for (const fields of [commerce, { ...commerce, rich_summary: { products: [{ offer_summary: { price: 'US$15.00' } }] } },
  {}, { price_value: 0, price_currency: 'USD' },
  { price_value: -1, price_currency: 'USD' }, { price_value: 'oops', price_currency: 'USD' },
  { price_value: 10, price_currency: '<script>' }, { affiliate_disclosure: { unexpected: true } }]) {
  const native = mapPrefetchedDetail(body(fields), url), web = bridge(fields);
  for (const key of ['priceText', 'richDescription', 'affiliateDisclosure', 'sourceName', 'creator', 'creatorVerified']) {
    assert.equal(native[key], web[key], key);
  }
}
const mapped = mapPrefetchedDetail(body(commerce), url);
assert.equal(mapPrefetchedDetail(body({ link: 'https://example.invalid/product', link_domain: { name: 'Example' } }), url).sourceLabel, 'example.invalid');
assert.equal(mapped.priceText, 'USD 15.00');
assert.equal(mapped.description, 'Short description');
assert.equal(mapped.richDescription, commerce.rich_metadata.description);
assert.equal(mapped.creator, 'Store account');
assert.equal(mapped.sourceUrl, commerce.rich_metadata.url);
assert.equal(bridge({ ...commerce, rich_summary: { products: [{ offer_summary: { price: 'US$15.00' } }] } }).priceText, 'US$15.00');
assert.equal(bridge(commerce).actions.find(a => a.kind === 'source').enabled, true);
for (const target of ['javascript:alert(1)', 'http://example.invalid/', 'https://user:pass@example.invalid/',
  'https://www.pinterest.com/pin/2/', 'https://i.pinimg.com/image.jpg', 'https://pin.it/abc']) {
  const fields = { rich_metadata: { url: target } };
  assert.equal(mapPrefetchedDetail(body(fields), url).sourceUrl, '');
  assert.equal(bridge(fields).sourceUrl, '');
  assert.equal(bridge(fields).actions.some(a => a.kind === 'source'), false);
}
assert.equal(bridge({ ...commerce, link: 'https://preferred.invalid/' }).sourceUrl, 'https://preferred.invalid/');
const cache = new PinmonyDetailCache(); cache.put('101', { ...mapped, actions: bridge(commerce).actions }, 32);
const retained = cache.get('101').detail;
assert.equal(retained.priceText, mapped.priceText);
assert.equal(retained.richDescription, mapped.richDescription);
assert.equal(retained.sourceUrl, mapped.sourceUrl);
assert.equal(retained.sourceName, mapped.sourceName);
assert.equal(retained.affiliateDisclosure, mapped.affiliateDisclosure);
assert.equal(retained.creatorVerified, true);
assert.equal(retained.actions[0].enabled, false, 'retained link never grants current operation authority');
assert.equal(mapPrefetchedDetail(body(commerce), url.replace('101', '102')), undefined);
const { PinmonyConfirmedSaves } = load(root + 'services/PinmonyConfirmedSaves.ets');
const confirmed = new PinmonyConfirmedSaves().apply('101', mapped);
for (const key of ['priceText','richDescription','affiliateDisclosure','sourceName','creatorVerified']) assert.equal(confirmed[key], mapped[key], 'confirmed save preserves ' + key);
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const heroEnd = index.indexOf("this.detailJourney.mark('main.image.stage=loaded')");
const heroStart = index.lastIndexOf('this.pinStore.detail = {',heroEnd);
const heroObject = index.slice(heroStart + 'this.pinStore.detail = '.length, index.indexOf('};',heroStart) + 1);
const copied = vm.runInNewContext('(' + heroObject + ')',{current:mapped});
for (const key of ['priceText','richDescription','affiliateDisclosure','sourceName','creatorVerified']) assert.equal(copied[key], mapped[key], 'image completion preserves ' + key);
const likeStart=index.indexOf('  private withDetailLike('), likeEnd=index.indexOf('\n  private ',likeStart+1);
const likeContext={};
vm.runInNewContext(ts.transpileModule('class LikeCopy {'+index.slice(likeStart,likeEnd)+'} globalThis.LikeCopy=LikeCopy;',{
  compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,likeContext);
const likeCopy=new likeContext.LikeCopy().withDetailLike(mapped,'none',true,'1');
for (const key of ['priceText','richDescription','affiliateDisclosure','sourceName','creatorVerified']) assert.equal(likeCopy[key], mapped[key], 'like completion preserves ' + key);
const page=fs.readFileSync(root+'components/PinmonyDetailPage.ets','utf8');
const intentStart=page.indexOf('  private acceptsActionIntent('), intentEnd=page.indexOf('\n  private ',intentStart+1);
const intentContext={};
vm.runInNewContext(ts.transpileModule('class Intent {'+page.slice(intentStart,intentEnd)+'} globalThis.Intent=Intent;',{
  compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,intentContext);
const intent=new intentContext.Intent(); Object.assign(intent,{readsReady:true});
assert.equal(intent.acceptsActionIntent({kind:'source',enabled:true}),true,'native ready enables source UI without Web actions');
assert.equal(!!intent.acceptsActionIntent({kind:'source',enabled:false}),false);
const { PinmonyRouteParser } = load('entry/src/main/ets/app/PinmonyRouteParser.ets');
const { PinmonyDetailNativeReads } = load('entry/src/main/ets/app/PinmonyDetailNativeReads.ets', {
  'common_network': { PIN_BUSINESS_PIN_READ_ENABLED:true }, './PinmonyRouteParser': { PinmonyRouteParser }
});
const nativeStore = {detail:confirmed,detailCache:new PinmonyDetailCache(),detailScrollOffset:0,detailPin:url,detailOpeningToken:1};
const session = {authenticated:true,generation:1};
const reads = new PinmonyDetailNativeReads({pinStore:()=>nativeStore,session:()=>session,foreground:()=>true,rootOnly:()=>false,backTarget:()=>''});
Object.assign(reads,{pin:url,opening:1,sessionGeneration:1,related:[]});
reads.apply();
assert.equal(nativeStore.detail.actions.find(a=>a.kind==='source').id,'native-source');
assert.equal(nativeStore.detail.priceText,mapped.priceText);
const { PinmonyDetailController } = load(root + 'controllers/PinmonyDetailController.ets');
const opened=[];
const controller = new PinmonyDetailController({store:nativeStore,isOffline:()=>false,isAuthenticated:()=>true,
  isForeground:()=>true,currentPinUrl:()=>url,traceAction(){},externalSourceUrl:PinmonyRouteParser.externalSourceUrl,
  openExternalLink:async target=>opened.push(target),showMessage(){}});
(async () => {
  await controller.performAction('native-source','source');
  assert.deepEqual(opened,[commerce.rich_metadata.url],'native source opens without Web detail action readiness');
  await controller.performAction('stale-source','source');
  assert.equal(opened.length,1);
  nativeStore.detail.pinUrl=url.replace('101','102');
  await controller.performAction('native-source','source');
  assert.equal(opened.length,1,'changed Pin rejects old source action');
  const prefetch = new PinmonyDetailPrefetch();
  const handoff = await prefetch.open(url, async () => body({ ...commerce, unrelated_secret: 'do not retain' }), () => true, () => {});
  const selected = JSON.parse(handoff).resource_response.data;
  assert.equal(selected.price_value, '15.00');
  assert.equal(selected.rich_metadata.description, commerce.rich_metadata.description);
  assert.equal(selected.unrelated_secret, undefined);
  console.log('detail commerce mapping, bridge, source validation and retained presentation passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
