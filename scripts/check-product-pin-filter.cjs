const fs = require('node:fs'), assert = require('node:assert/strict');
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
assert.equal(related.pins.length, 1); assert.equal(related.bookmark, 'next'); assert.equal(related.ended, false);
const filtered = readRelatedPresentation(JSON.stringify({ resource_response: { status: 'success',
  data: [{ ...pin, is_product_pin: true }], bookmark: 'next' } }), 'https://www.pinterest.com/pin/100/');
assert.equal(filtered.pins.length, 0); assert.equal(filtered.bookmark, 'next');
assert.equal(filtered.ended, false, 'all-filtered page is not a service failure or end of pagination');
for (const file of ['PinmonyHomeNativeReads.ets', 'PinmonySearchNativeReads.ets', 'PinmonyBoardNativeReads.ets'])
  assert(fs.readFileSync('entry/src/main/ets/app/' + file, 'utf8').includes('isProductPin('));
assert(!fs.readFileSync('entry/src/main/ets/app/PinmonyProfileNativeReads.ets', 'utf8').includes('isProductPin('), 'saved/created profile content remains available');
console.log('Product filtering: explicit signals, ordinary links retained, related paging and saved/created exception passed');
