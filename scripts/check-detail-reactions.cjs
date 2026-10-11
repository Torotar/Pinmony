const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyDetailApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
const flush = () => new Promise(resolve => setImmediate(resolve));
async function main() {
  const requests = [], window = { PinmonyDetailApiEnabled: true }; window.top = window;
  window.fetch = (url, args) => new Promise((resolve, reject) => {
    requests.push({ url, args, resolve });
    if (args?.signal) args.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
  });
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname: '/pin/123/' };
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, console,
    fetch: (...args) => window.fetch(...args) });
  const api = window.PinmonyDetailApi;
  let key = location.origin + location.pathname, updates = 0;
  const read = () => api.read(key, () => updates++, () => location.origin + location.pathname === key);
  read();
  const query = () => window.fetch('/_/graphql/', { method: 'POST', body: JSON.stringify({ variables: { pinId: '123' } }) });
  const resolveGraph = async (index, entityId, reactionCount) => {
    const payload = { data: { v3GetPinQueryv2: { data: { entityId, reactionCountsData: [{ reactionType: 1, reactionCount }] } } } };
    requests[index].resolve({ ok: true, clone: () => ({ json: async () => payload }) }); await flush();
  };
  query(); await resolveGraph(1, '123', 0);
  assert.equal(read().reactionCount, '0'); assert.equal(updates, 1, 'zero reactions are valid API data');
  query(); await resolveGraph(2, '999', 27);
  assert.equal(read().reactionCount, '0', 'another Pin cannot overwrite counts');
  query(); await resolveGraph(3, '123', -1);
  assert.equal(read().reactionCount, '0', 'invalid counts are rejected');
  query();
  location.pathname = '/pin/456/'; key = location.origin + location.pathname; read();
  await resolveGraph(4, '123', 99);
  assert.equal(read().reactionCount, null, 'late previous-Pin counts are discarded');
  api.reset(); await flush();
  assert.equal(requests[0].args.signal.aborted, true);
  console.log('Detail GraphQL reaction checks passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
