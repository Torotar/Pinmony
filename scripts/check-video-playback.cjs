const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const flush = () => new Promise(resolve => setImmediate(resolve));
const code = ts.transpileModule(readSourceFileSync('common_ui/src/main/ets/services/PinWebVideoPlayback.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
function harness(delayed = false) {
  const players = [], states = [], pending = [];
  function player() {
    const events = {};
    const p = { state: 'idle', events, duration: 4600, releases: 0, pauses: 0, seeks: [],
      on: (name, fn) => events[name] = fn, release: async () => { p.releases++; p.state = 'released'; },
      prepare: async () => { p.state = 'prepared'; events.stateChange('prepared'); },
      play: async () => { p.state = 'playing'; events.stateChange('playing'); },
      pause: async () => { p.pauses++; p.state = 'paused'; events.stateChange('paused'); },
      seek: value => p.seeks.push(value), setVolume: volume => p.volume = volume };
    Object.defineProperty(p, 'url', { set: value => { p.source = value; p.state = 'initialized'; events.stateChange('initialized'); } });
    players.push(p); return p;
  }
  const media = { createAVPlayer: () => delayed ? new Promise(resolve => pending.push(() => resolve(player()))) : Promise.resolve(player()),
    SeekMode: { SEEK_CLOSEST: 0 }, VideoScaleType: { VIDEO_SCALE_TYPE_FIT: 0 }, BufferingInfoType: { BUFFERING_START: 1, BUFFERING_END: 2 } };
  const audio = { InterruptHint: { INTERRUPT_HINT_PAUSE: 1, INTERRUPT_HINT_STOP: 2 } };
  const exports = {}; vm.runInNewContext(code, { exports, require: name => ({ media, audio }), setTimeout, clearTimeout });
  const playback = new exports.PinWebVideoPlayback(state => states.push(state));
  const video = { pinId: '123', duration: 4600, sources: [{ url: 'hls', kind: 'hls' }, { url: 'mp4', kind: 'mp4' }] };
  playback.setVideo(video); playback.setSurface('surface');
  return { playback, players, states, pending, video };
}
async function main() {
  const automatic = harness();
  automatic.playback.setVideo(automatic.video);
  automatic.playback.setSurface('');
  automatic.playback.mute();
  automatic.playback.start();
  assert.equal(automatic.players.length, 0, 'autoplay waits for the Surface');
  automatic.playback.setSurface('card-surface'); await flush();
  assert.equal(automatic.players[0].state, 'playing');
  assert.equal(automatic.players[0].volume, 0, 'card autoplay is muted');
  automatic.playback.start(); assert.equal(automatic.players[0].state, 'playing', 'start does not toggle to pause');
  automatic.playback.stop();
  assert.equal(automatic.states.at(-1).rendered, false);
  automatic.playback.start(); await flush();
  assert.equal(automatic.players[1].state, 'playing', 'released offscreen card can restart');
  automatic.playback.release();
  const h = harness(); assert.equal(h.players.length, 0, 'poster does not autoplay');
  h.playback.toggle(); await flush(); assert.equal(h.players[0].source, 'hls');
  assert.equal(h.players[0].surfaceId, 'surface'); assert.equal(h.states.at(-1).rendered, false);
  h.players[0].events.startRenderFrame(); assert.equal(h.states.at(-1).rendered, true);
  h.playback.mute(); assert.equal(h.players[0].volume, 0);
  h.playback.seek(99999); assert.equal(h.players[0].seeks.at(-1), 4600);
  h.playback.setActive(false); assert.equal(h.players[0].pauses, 1);
  h.playback.setActive(true); assert.equal(h.players[0].state, 'paused', 'foreground waits for explicit play');
  h.playback.toggle(); h.players[0].events.audioInterrupt({ hintType: 1 });
  assert.equal(h.players[0].state, 'paused', 'audio focus interruption pauses the video');
  h.playback.toggle(); h.players[0].events.error(new Error()); await flush();
  assert.equal(h.players[0].releases, 1); assert.equal(h.players[1].source, 'mp4');
  const count = h.states.length; h.players[0].events.timeUpdate(1000); assert.equal(h.states.length, count, 'old HLS callbacks cannot alter MP4');
  h.players[1].events.error(new Error()); assert.equal(h.states.at(-1).phase, 'error');
  const errors = h.states.length; h.players[1].events.stateChange('playing'); assert.equal(h.states.length, errors, 'released player cannot clear the error');
  h.playback.toggle(); await flush(); assert.equal(h.players[2].source, 'hls', 'explicit retry starts the candidate sequence again');
  h.playback.setVideo({ ...h.video, pinId: '999' }); const changed = h.states.length;
  h.players[2].events.timeUpdate(1234); assert.equal(h.states.length, changed); h.playback.release();
  const late = harness(true); late.playback.toggle(); await flush(); late.playback.release(); late.pending[0](); await flush();
  assert.equal(late.players[0].releases, 1, 'late player creation is immediately released');
  assert.equal(late.players[0].source, undefined);
  const cacheExports = {};
  const cacheCode = ts.transpileModule(readSourceFileSync('entry/src/main/ets/services/PinWebDetailCache.ets', 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  vm.runInNewContext(cacheCode, { exports: cacheExports });
  const cache = new cacheExports.PinWebDetailCache();
  cache.put('123', { pinUrl: '/pin/123/', isVideo: true, video: h.video, actions: [], related: [] }, 0);
  assert.equal(cache.get('123').detail.isVideo, true, 'return cache preserves media identity');
  assert.equal(cache.get('123').detail.video, undefined, 'cached media URLs wait for fresh session data');
  console.log('Video playback: manual start, surface binding, mute/seek/pause, fallback, retry and lifecycle guards passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
