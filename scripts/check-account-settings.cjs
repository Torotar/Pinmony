const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function moduleFrom(file, requireFn = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: requireFn, console });
  return exports;
}
const { PIN_ACCOUNT_SETTINGS_SCRIPT } = moduleFrom('feature_settings/src/main/ets/services/PinmonyAccountSettingsScript.ets');
const { acceptsNetworkJob } = moduleFrom('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const { useNativeTransport } = moduleFrom('common_network/src/main/ets/PinmonyNetworkScript.ets');
const page = 'https://' + (process.env.PINMONY_TEST_REGION === 'uk' ? 'uk' : 'www') + '.pinterest.com/synthetic/';
function harness() {
  const account = { id: '123', username: 'synthetic', email: 'synthetic@example.invalid', has_confirmed_email: true,
    birthdate: '2000-01-01', gender: 'male', custom_gender: '', country: 'US' };
  const writes = [], calls = [];
  let failWrite = false, wrongAck = false, delayed;
  const context = { URL, AbortController, setTimeout, clearTimeout, location: new URL(page),
    fetch: async (url, init) => {
      calls.push(url);
      const p = new URLSearchParams(init.body || new URL(url, page).search);
      const options = JSON.parse(p.get('data')).options;
      if (delayed) return delayed(url, init);
      let data;
      if (url.includes('CountriesResource')) data = [{ key: 'US', name: '美国' }, { key: 'CN', name: '中国' }];
      else if (init.method === 'POST') {
        writes.push(options);
        if (failWrite) throw Error('network');
        const field = Object.keys(options).find(k => !['surface_tag', 'user_id'].includes(k));
        account[field] = options[field]; data = { [field]: wrongAck ? 'mismatch' : options[field] };
      } else data = { ...account };
      return { ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, data } }) };
    } };
  context.window = context; context.top = context;
  vm.runInNewContext(PIN_ACCOUNT_SETTINGS_SCRIPT, context);
  return { context, account, writes, calls, api: context.PinmonyAccountSettings,
    failWrite() { failWrite = true; }, wrongAck() { wrongAck = true; }, delay(fn) { delayed = fn; } };
}
async function main() {
  const h = harness();
  await h.api.start(page, 1, 'read', '');
  assert.equal(h.api.read().birthdate, '2000-01-01');
  const timestamp = harness(); timestamp.account.birthdate = null;
  timestamp.account.birthday = Date.UTC(2000, 0, 2) / 1000;
  await timestamp.api.start(page, 1, 'read', '');
  assert.equal(timestamp.api.read().birthdate, '2000-01-02');
  timestamp.account.birthday = Date.UTC(2099, 0, 1) / 1000;
  await timestamp.api.start(page, 2, 'read', '');
  assert.equal(timestamp.api.read().birthdate, '', 'future birthday is hidden');
  assert(timestamp.calls.some(url => url.includes('ApiResource/get/')), 'missing valid birthday reads the settings API');
  for (const [input, expected] of [['2000/1/2', '2000-01-02'], ['2000-01-02T00:00:00Z', '2000-01-02'], ['2000-02-30', ''], [null, '']]) {
    h.account.birthdate = input;
    await h.api.start(page, 1, 'read', '');
    assert.equal(h.api.read().birthdate, expected);
  }
  h.account.birthdate = '2000-01-01';
  await h.api.start(page, 2, 'birthdate', '2001-02-03');
  assert.equal(h.api.read().saved, true); assert.equal(h.writes[0].birthdate, '2001-02-03');
  assert.equal(h.writes[0].user_id, undefined);
  await h.api.start(page, 3, 'birthdate', '2001-02-30'); assert.equal(h.writes.length, 1);
  await h.api.start(page, 4, 'gender', 'unspecified');
  await h.api.start(page, 5, 'customGender', 'synthetic custom');
  assert.equal(h.api.read().customGender, 'synthetic custom'); assert.equal(h.writes[2].user_id, '123');
  await h.api.start(page, 6, 'country', 'CN');
  assert.equal(h.api.read().country, 'CN'); assert.equal(h.api.read().countries.length, 2);
  await h.api.start(page, 7, 'country', 'XX'); assert.equal(h.writes.length, 4);
  h.failWrite(); await h.api.start(page, 8, 'gender', 'female');
  assert.equal(h.writes.length, 5); assert.equal(h.api.read().saved, false); assert.match(h.api.read().error, /未确认/);
  const mismatch = harness(); mismatch.wrongAck();
  await mismatch.api.start(page, 9, 'gender', 'female');
  assert.equal(mismatch.api.read().saved, false); assert.match(mismatch.api.read().error, /未确认/);
  const created = harness(); created.context.location = new URL(page + '_created/');
  await created.api.start(page + '_created/', 9, 'read', ''); assert.equal(created.api.read().ready, true);
  const identity = harness(); identity.account.username = 'another';
  await identity.api.start(page, 9, 'gender', 'female'); assert.equal(identity.writes.length, 0);
  const late = harness(); let resolve;
  late.delay(() => new Promise(r => { resolve = r; }));
  const pending = late.api.start(page, 10, 'gender', 'female');
  late.api.close(); resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', code: 0, data: late.account } }) });
  await pending; assert.equal(late.api.read(), null); assert.equal(late.writes.length, 0);
  const state = { authenticated: true, epoch: 1, page, userAgent: 'synthetic' };
  const origin = new URL(page).origin;
  const job = { id: 'test', epoch: 1, page, url: origin + '/resource/UserSettingsResource/update/', method: 'POST', headers: {}, body: '' };
  function accepts(options) { return acceptsNetworkJob({ ...job, body: 'data=' + encodeURIComponent(JSON.stringify({ options, context: {} })) }, state); }
  assert(accepts({ surface_tag: 'settings', user_id: '123', gender: 'male' }));
  assert(!accepts({ surface_tag: 'settings', user_id: '123', password: 'synthetic' }));
  assert(!accepts({ surface_tag: 'settings', user_id: '123', gender: 'male', country: 'US' }));
  assert(!accepts({ surface_tag: 'settings', user_id: '123', custom_gender: 'x'.repeat(501) }));
  assert(acceptsNetworkJob({ ...job, method: 'GET', url: origin + '/resource/CountriesResource/get/' }, state));
  assert.match(useNativeTransport(PIN_ACCOUNT_SETTINGS_SCRIPT), /window.PinmonyNetwork.fetch\(/);
  console.log('Account settings: mapping, validated writes, invalid dates, identity, countries, no replay, cancellation and native allowlist passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
