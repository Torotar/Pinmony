const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const network = fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets', 'utf8');
const method = network.slice(network.indexOf('  async requestBusinessProductRead('), network.indexOf('  async requestBusinessPinRead('));
const context = { exports: {}, PIN_BUSINESS_PIN_READ_ENABLED: true };
vm.runInNewContext(ts.transpileModule('export class Guard { ' + method + ' }', { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
} }).outputText, context);
const guard = new context.exports.Guard();
guard.request = async (job, state) => state().authenticated;
const owner = { authenticated: true, accountId: 'fixture', generation: 1, origin: 'https://www.pinterest.com', userAgent: 'fixture' };
const pin = owner.origin + '/pin/101/';
const variables = { isAuth: true, isAuthDesktop: false, isDesktop: false, isUnauth: false, pinId: '101',
  shouldDefer: false, shouldFetchAIInsight: false, shouldFetchDesktopShoppingModule: false,
  shouldFetchMobileShoppingModule: true, shouldFetchUnauthAmazonModule: false, shouldShowSeoDrawerOption: false };
const queryHash = '43164757b22ade73c6219d2108b664c014b574d314f725af6b16036188662335';
const job = { id: 'native_product_1', epoch: 1, page: pin, url: owner.origin + '/_/graphql/', method: 'POST',
  headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ queryHash, variables }) };
(async () => {
  const read = (j = job, state = () => owner, current = () => true) => guard.requestBusinessProductRead(j, state, pin, current);
  assert.equal(await read(), true);
  for (const change of [{ epoch: 2 }, { page: owner.origin }, { method: 'GET' }, { id: 'unknown' },
    { url: 'https://example.invalid/_/graphql/' },
    { body: JSON.stringify({ queryHash, variables: { ...variables, pinId: '102' } }) },
    { body: JSON.stringify({ queryHash, variables: { ...variables, extra: true } }) },
    { body: JSON.stringify({ queryHash: '0'.repeat(64), variables }) }]) {
    assert.equal(await read({ ...job, ...change }), false);
  }
  assert.equal(await read(job, () => owner, () => false), false);
  let count = 0;
  assert.equal(await read(job, () => ++count === 1 ? owner : { ...owner, accountId: 'other' }), false);
  const commerce = fs.readFileSync('entry/src/main/ets/app/PinmonyDetailNativeReads.ets', 'utf8');
  assert.match(commerce, /revision !== this\.revision \|\| !this\.owned\(\) \|\| this\.store\.detail\?\.pinUrl !== pin/);
  console.log('Product read guard: exact query, Pin/session ownership, stale generation and malformed requests passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
