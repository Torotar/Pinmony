const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {
  common_foundation: { PinmonyRuntimeLog: { info() {}, warn() {} } },
  common_network: { PIN_BUSINESS_PIN_READ_ENABLED: true }, common_ui: {}, feature_home: {}
});
const { PinmonyHomeNativeReads } = loader.loadFile('entry/src/main/ets/app/PinmonyHomeNativeReads.ets');
const native = new PinmonyHomeNativeReads({ store: () => ({}), saved: () => false });
native.origin = 'https://www.pinterest.com';
const pins = [
  { id: '1', is_video: true },
  { id: '2', videos: { video_list: {} } },
  { id: '3' },
  { id: '4', videos: { video_list: { V_720P: { url: 'https://i.pinimg.com/videos/clip.mp4', duration: 0 } } } },
  { id: '5', videos: { video_list: { V_720P: { url: 'https://other.example/clip.mp4' } } } }
].map(pin => ({ type: 'pin', images: { '474x': { url: 'https://i.pinimg.com/a.jpg', width: 474, height: 700 } }, ...pin }));
const mapped = native.mapPins(pins);
assert.deepEqual(Array.from(mapped, pin => pin.isVideo), [true, true, false, true, true]);
assert.equal(mapped[0].video, undefined, 'metadata alone cannot authorize playback');
assert.equal(mapped[3].video.duration, 0);
assert.equal(mapped[4].video, undefined, 'invalid playback host is still rejected');
const api = fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets', 'utf8');
const script = Function('return `' + api.match(/= `([\s\S]*?)`;/)[1] + '`')();
const context = { URL, location: { origin: native.origin } };
vm.runInNewContext(script.slice(script.indexOf('  function mapPins('), script.indexOf('  function boardImage(')) + '\nglobalThis.mapPins = mapPins;', context);
assert.deepEqual(Array.from(context.mapPins(pins), pin => pin.isVideo), [true, true, false, true, true]);
const { normalizeHomeCacheRecord } = loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeCache.ets');
const pageKey = 'https://www.pinterest.com/';
const record = { snapshot: { kind: 'state', dataSource: 'api', pageKey, selectedTab: 'all',
  tabs: [{ id: 'all', label: 'all', selected: true, enabled: true }], pins: mapped } };
const cached = normalizeHomeCacheRecord(record, pageKey).snapshot;
assert.deepEqual(Array.from(cached.pins, pin => pin.isVideo), [true, true, false, true, true]);
assert(cached.pins.every(pin => !pin.video), 'disk cache keeps the label without restoring playable URLs');
const restored = normalizeHomeCacheRecord({ snapshot: cached }, pageKey).snapshot;
assert.deepEqual(Array.from(restored.pins, pin => pin.isVideo), [true, true, false, true, true]);
const feed = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'utf8');
const card = fs.readFileSync('common_ui/src/main/ets/components/PinmonyVideoCard.ets', 'utf8');
assert(feed.includes('if (pin.isVideo === true)'));
assert(feed.includes("@Watch('syncFeedRows') private uiLanguage"));
assert(card.includes("this.video.duration > 0 ? this.durationText() : this.uiText('pm_videos_c20f7618')"));
console.log('Home video labels: native/bridge metadata, invalid sources, zero duration, disk restore and live language passed');
