const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const Priority = { HIGH: 0, NORMAL: 1, LOW: 2 };
const loader = createArktsLoader(ts, {
  common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true, Priority },
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } }, feature_pin: {}
});
const { PinmonyDetailNativeReads: Reads } = loader.loadFile('entry/src/main/ets/app/PinmonyDetailNativeReads.ets');
async function main() {
  const requests = [], pin = 'https://www.pinterest.com/pin/1/';
  const session = { authenticated: true, origin: 'https://www.pinterest.com', accountId: 'synthetic', generation: 1 };
  const reads = new Reads({ pinStore: () => ({}), session: () => session,
    network: () => ({ requestBusinessPinRead(job, _session, currentPin, current) {
      assert.equal(currentPin, pin); assert(current()); requests.push(job);
      return Promise.resolve({ status: 200, error: '', body: '' });
    } }) });
  reads.pin = pin; reads.owned = () => true;
  for (const [resource, options, prefix, expected] of [
    ['RelatedModulesResource', { pin_id: '1' }, 'native_related_', Priority.HIGH],
    ['RelatedModulesResource', { pin_id: '1', bookmarks: ['next'] }, 'native_related_', undefined],
    ['UnifiedCommentsPreviewResource', { aggregated_pin_id: '2' }, 'native_preview_', undefined],
    ['UserSettingsResource', {}, 'native_autoplay_', undefined]
  ]) {
    await reads.request(resource, options, prefix);
    assert.equal(requests.at(-1).priority, expected, resource + ' priority');
  }
  assert.equal(reads.requests.size, 0, 'priority does not change request cleanup');
  // Exercise the actual opening coordinator with a captured demand callback.
  const source = fs.readFileSync('entry/src/main/ets/app/PinmonyDetailOpeningCoordinator.ets', 'utf8');
  const start = source.indexOf('startOpeningDetailRead(');
  const end = source.indexOf('\nprefetchHomePinDetails(', start);
  assert(start >= 0 && end > start);
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} Host;',
    { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
    { Priority, PinmonyI18n: { message: key => key } });
  const h = new Host(); let demand, demandJob, warmed, cancelled;
  const owners = new Map();
  const timeouts = [];
  h.pinStore = { videoForeground: true, detailOpeningToken: 1, detailOpeningPin: pin,
    detailPrefetch: { open(_pin, reader) { demand = reader; return new Promise(() => {}); } } };
  h.ports = { setOpeningRelated() {}, setOpeningRelatedToken() {}, detailJourney: () => ({ mark() {}, current: () => 1 }),
    nativeBusinessSessionContext: () => session, authStatus: () => 'authenticated', nativeBackTarget: () => '',
    warmRelated: (pin, token) => { warmed = [pin, token]; },
    cancelEarlyRelated: (pin, token) => { cancelled = [pin, token]; },
    coordinatorTasks: () => ({ timeout(callback) { timeouts.push(callback); } }), detailRequestOwners: () => owners,
    detailReadNetwork: () => ({ requestBusinessPinRead: async job => {
      demandJob = job; return { status: 200, error: '', body: 'validated' };
    } }) };
  h.startOpeningDetailRead(pin, 1);
  assert.deepEqual(warmed, [pin, 1], 'opening immediately schedules the protected early read');
  assert.equal(await demand(pin, 'detail_prefetch_synthetic', () => true), 'validated');
  assert.equal(demandJob.priority, Priority.HIGH, 'foreground demand overrides the shared prefetch ID classification');
  assert.equal(owners.size, 0);
  h.ports.detailReadNetwork = () => ({ requestBusinessPinRead: async () => { throw Error('synthetic rejection'); } });
  await assert.rejects(demand(pin, 'detail_prefetch_failed', () => true), /synthetic rejection/);
  assert.equal(owners.size, 0, 'transport rejection releases the request owner');
  timeouts[0](); assert.deepEqual(cancelled, [pin, 1], 'base timeout cancels its early read');
  console.log('Detail request priority: visible base and recommendation first page are high, other reads unchanged, ownership and cleanup retained');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
