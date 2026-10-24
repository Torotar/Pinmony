const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const exportsBox = {}, jobs = [];
let now = 1000, destroyed = 0;
const reply = version => ({ responseCode: 200, result: JSON.stringify({ tag_name: version,
  html_url: 'https://github.com/Torotar/Pinmony/releases/tag/' + version, body: 'Notes', draft: false, prerelease: false }) });
const http = { RequestMethod: { GET: 'GET' }, HttpProtocol: { HTTP1_1: 1 }, HttpDataType: { STRING: 0 },
  createHttp: () => ({ request: () => new Promise((resolve, reject) => jobs.push({ resolve, reject })), destroy() { destroyed++; } }) };
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_settings/src/main/ets/services/PinmonyRelease.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, { exports: exportsBox, require: () => ({ http, PinmonyI18n: { message: value => value }, PinmonyRuntimeLog: { info() {}, warn() {} } }),
  Date: { now: () => now }, setTimeout: () => 1, clearTimeout() {} });
const Client = exportsBox.PinmonyReleaseClient;
(async () => {
  const home = new Client(), about = new Client();
  const first = home.latest('2.3.0'), second = about.latest('2.3.0');
  assert.equal(jobs.length, 1, 'homepage/About join the same in-flight check');
  home.cancel(); const cancelled = assert.rejects(first, /cancelled/);
  jobs[0].resolve(reply('v2.3.0')); await cancelled; await second;
  assert.equal(about.releases.length, 1, 'one caller cancelling cannot cancel another');
  const cached = await new Client().latest('2.3.0');
  assert.equal(jobs.length, 1); cached.body = 'changed';
  assert.equal((await new Client().latest('2.3.0')).body, 'Notes', 'callers cannot mutate shared data');
  const forced = about.latest('2.3.0', true); assert.equal(jobs.length, 2);
  jobs[1].resolve(reply('v2.3.0')); await forced;
  now += 300001;
  const expired = about.latest('2.3.0'); assert.equal(jobs.length, 3);
  jobs[2].resolve({ responseCode: 500 }); await assert.rejects(expired);
  const retry = about.latest('2.3.0'); assert.equal(jobs.length, 4, 'failed results are not cached');
  jobs[3].resolve(reply('v2.3.0')); await retry;
  const other = about.latest('2.4.0'); assert.equal(jobs.length, 5, 'installed version isolates history completeness');
  jobs[4].resolve(reply('v2.3.0')); await other;
  const sole = new Client(), lone = sole.latest('2.5.0');
  const rejected = assert.rejects(lone, /cancelled/), beforeCancel = destroyed;
  sole.cancel(); assert(destroyed > beforeCancel, 'last reader cancellation destroys the shared request');
  jobs[5].resolve(reply('v2.3.0')); await rejected;
  const fresh = sole.latest('2.5.0'); assert.equal(jobs.length, 7, 'fully cancelled results cannot populate cache');
  jobs[6].resolve(reply('v2.3.0')); await fresh;
  console.log('Release cache: request joining, cancellation isolation, immutable copies, manual refresh, expiry and failure retry passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
