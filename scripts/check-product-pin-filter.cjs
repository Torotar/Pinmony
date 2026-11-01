const fs = require('node:fs'), assert = require('node:assert/strict'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { isProductPin } = createArktsLoader(ts).loadFile('common_foundation/src/main/ets/PinmonyProductPin.ets');
for (const value of [{ is_product_pin: true }, { rich_summary: { products: [{}] } },
  { rich_metadata: { products: [{}] } }, { price_value: '15.00', price_currency: 'USD' }]) assert.equal(isProductPin(value), true);
for (const value of [{}, { rich_summary: { products: [] } }, { rich_metadata: { products: [null] } },
  { price_value: 0, price_currency: 'USD' }, { price_value: 10, price_currency: 'invalid' },
  { link: 'https://store.invalid/', affiliate_disclosure: 'Paid link', title: 'Product example' }]) assert.equal(isProductPin(value), false);
const loader = createArktsLoader(ts, { common_foundation: { isProductPin } });
const { readRelatedPresentation } = loader.loadFile('feature_pin/src/main/ets/services/PinmonyRelatedPresentation.ets');
const pin = { id: '101', type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/synthetic.jpg', width: 474, height: 700 } } };
const mixed = JSON.stringify({ resource_response: { status: 'success', data: [pin, { ...pin, id: '102', is_product_pin: true }], bookmark: 'next' } });
const related = readRelatedPresentation(mixed, 'https://www.pinterest.com/pin/100/');
assert.equal(related.pins.length, 2); assert.equal(related.bookmark, 'next'); assert.equal(related.ended, false);
const productsOnly = readRelatedPresentation(JSON.stringify({ resource_response: { status: 'success',
  data: [{ ...pin, is_product_pin: true }], bookmark: 'next' } }), 'https://www.pinterest.com/pin/100/');
assert.equal(productsOnly.pins.length, 1); assert.equal(productsOnly.bookmark, 'next');
assert.equal(productsOnly.ended, false, 'a product-only page keeps its cards and pagination');
function readerPrototype(file, name) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  }}).outputText, { exports, require: () => ({ PIN_BUSINESS_PIN_READ_ENABLED: true }) });
  return Object.create(exports[name].prototype);
}
const home = readerPrototype('entry/src/main/ets/app/PinmonyHomeNativeReads.ets', 'PinmonyHomeNativeReads');
home.origin = 'https://www.pinterest.com'; home.ports = { saved: () => false };
const search = readerPrototype('entry/src/main/ets/app/PinmonySearchNativeReads.ets', 'PinmonySearchNativeReads');
search.origin = home.origin;
for (const signals of [{ is_product_pin: true }, { rich_metadata: { products: [{}] } },
  { rich_summary: { site_name: 'Example shop', products: [{ offer_summary: { price: '$15', standard_price: '$20' } }] } },
  { price_value: '15.00', price_currency: 'USD' }]) {
  const product = { ...pin, ...signals };
  assert.equal(home.mapPins([product, product]).length, 1, 'home keeps and deduplicates product Pins');
  assert.equal(search.map(product).targetUrl, home.origin + '/pin/101/');
  const page = readRelatedPresentation(JSON.stringify({ resource_response: { status: 'success', data: [product, product] } }), home.origin + '/pin/100/');
  assert.equal(page.pins.length, 1, 'related content keeps and deduplicates each product signal');
  assert.equal(search.map({ ...product, is_promoted: true }), undefined, 'existing promoted-result filtering remains');
}
const priced = search.map({ ...pin, rich_summary: { site_name: 'Example shop', products: [{ offer_summary: { price: '$15', standard_price: '$20' } }] } });
assert.equal(priced.merchant, 'Example shop'); assert.equal(priced.price, '$15'); assert.equal(priced.standardPrice, '$20');
assert.equal(home.mapPins([{ ...pin, images: {} }]).length, 0);
assert.equal(search.map({ ...pin, images: {} }), undefined);
assert.equal(readRelatedPresentation(JSON.stringify({ resource_response: { status: 'success', data: [{ ...pin, images: {} }] } }), home.origin + '/pin/100/'), undefined);
for (const file of ['PinmonyHomeNativeReads.ets', 'PinmonySearchNativeReads.ets', 'PinmonyBoardNativeReads.ets'])
  assert(!fs.readFileSync('entry/src/main/ets/app/' + file, 'utf8').includes('isProductPin('), 'product filtering removed from ' + file);
assert(!fs.readFileSync('entry/src/main/ets/app/PinmonyProfileNativeReads.ets', 'utf8').includes('isProductPin('), 'saved/created profile content remains available');
console.log('Product Pin restoration: home/search/related cards, product-only pagination, prices, deduplication, invalid data and existing ad filtering passed');
