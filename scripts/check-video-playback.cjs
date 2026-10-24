const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2]);
const flush = () => new Promise(resolve => setImmediate(resolve));
const code = ts.transpileModule(readSourceFileSync('common_ui/src/main/ets/services/PinmonyVideoPlayback.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
function harness(delayed = false, config = {}) {
  const players = [], states = [], pending = [], traces = [];
  const timers = new Map(); let timerId = 0;
  const timerApi = config.fakeTime ? {
    setTimeout(fn, delay) { const id = ++timerId; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); }
  } : { setTimeout, clearTimeout };
  function player() {
    const events = {};
    const p = { state: 'idle', events, duration: 4600, releases: 0, pauses: 0, seeks: [],
      on: (name, fn) => events[name] = fn, release: async () => { p.releases++; p.state = 'released'; },
      prepare: async () => {
        if (config.prepareRejected) {
          p.state = 'error';
          if (config.stateErrorFirst) events.stateChange('error');
          throw { code: 5400102 };
        }
        if (config.preparePending) return new Promise(() => {});
        p.state = 'prepared'; events.stateChange('prepared');
      },
      play: async () => { p.state = 'playing'; events.stateChange('playing'); },
      pause: async () => { p.pauses++; p.state = 'paused'; events.stateChange('paused'); },
      seek: value => p.seeks.push(value), setVolume: volume => p.volume = volume };
    Object.defineProperty(p, 'url', { set: value => { p.source = value; p.state = 'initialized'; events.stateChange('initialized'); } });
    Object.defineProperty(p, 'fdSrc', { set: value => { p.fileSource = value; p.state = 'initialized'; events.stateChange('initialized'); } });
    players.push(p); return p;
  }
  const media = { createAVPlayer: () => delayed ? new Promise(resolve => pending.push(() => resolve(player()))) : Promise.resolve(player()),
    SeekMode: { SEEK_CLOSEST: 0 }, VideoScaleType: { VIDEO_SCALE_TYPE_FIT: 0 }, BufferingInfoType: { BUFFERING_START: 1, BUFFERING_END: 2 } };
  const audio = { InterruptHint: { INTERRUPT_HINT_PAUSE: 1, INTERRUPT_HINT_STOP: 2 } };
  const exports = {}; vm.runInNewContext(code, { exports, require: name => name === 'common_foundation' ? {PinmonyI18n: require('./local-message-test-fixture.cjs').rawLocalMessages} : ({ media, audio }), ...timerApi });
  const playback = new exports.PinmonyVideoPlayback(state => states.push(state), event => traces.push(event), config.fileReader);
  const video = { pinId: '123', duration: 4600, sources: [{ url: 'hls', kind: 'hls' }, { url: 'mp4', kind: 'mp4' }] };
  playback.setVideo(video); playback.setSurface('surface');
  return { playback, players, states, pending, video, traces, timers,
    fireTimers(delay) { for (const [id, timer] of Array.from(timers)) if (timer.delay === delay) { timers.delete(id); timer.fn(); } } };
}
async function main() {
  const reenter = harness(true);
  reenter.playback.start(); await flush();
  assert.equal(reenter.pending.length, 1);
  reenter.playback.release();
  assert.equal(reenter.states.at(-1).phase, 'idle', 'release must clear a loading state');
  assert.equal(reenter.states.at(-1).rendered, false);
  reenter.playback.setSurface(''); reenter.playback.start(); await flush();
  assert.equal(reenter.pending.length, 1, 'reentry waits for a new Surface');
  reenter.playback.setSurface('new-surface'); await flush();
  assert.equal(reenter.pending.length, 2, 'released loading player can restart with the same source');
  reenter.pending[0](); await flush();
  assert.equal(reenter.players[0].releases, 1, 'late old creation is released');
  reenter.pending[1](); await flush();
  assert.equal(reenter.players[1].state, 'playing');
  reenter.playback.release();
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
  assert(h.traces.some(event => event.includes('event=first-frame')));
  h.playback.mute(); assert.equal(h.players[0].volume, 0);
  h.playback.seek(99999); assert.equal(h.players[0].seeks.at(-1), 4600);
  h.playback.setActive(false); assert.equal(h.players[0].pauses, 1);
  h.playback.setActive(true); assert.equal(h.players[0].state, 'paused', 'foreground waits for explicit play');
  h.playback.toggle(); h.players[0].events.audioInterrupt({ hintType: 1 });
  assert.equal(h.players[0].state, 'paused', 'audio focus interruption pauses the video');
  h.playback.toggle(); h.players[0].events.error({ code: 5411003 }); await flush();
  assert.equal(h.players[0].releases, 1); assert.equal(h.players[1].source, 'mp4');
  const count = h.states.length; h.players[0].events.timeUpdate(1000); assert.equal(h.states.length, count, 'old HLS callbacks cannot alter MP4');
  h.players[1].events.error({ code: 5411010, message: 'SECRET_URL_COOKIE' }); assert.equal(h.states.at(-1).phase, 'error');
  assert.match(h.states.at(-1).error, /安全连接失败/);
  assert(h.traces.some(event => event.includes('code=5411010')));
  assert(h.traces.every(event => !event.includes('SECRET_URL_COOKIE')), 'diagnostics do not log arbitrary messages');
  const errors = h.states.length; h.players[1].events.stateChange('playing'); assert.equal(h.states.length, errors, 'released player cannot clear the error');
  h.playback.toggle(); await flush(); assert.equal(h.players[2].source, 'hls', 'explicit retry starts the candidate sequence again');
  h.playback.setVideo({ ...h.video, pinId: '999' }); const changed = h.states.length;
  h.players[2].events.timeUpdate(1234); assert.equal(h.states.length, changed); h.playback.release();
  const late = harness(true); late.playback.toggle(); await flush(); late.playback.release(); late.pending[0](); await flush();
  assert.equal(late.players[0].releases, 1, 'late player creation is immediately released');
  assert.equal(late.players[0].source, undefined);
  const cacheExports = {};
  const cacheCode = ts.transpileModule(readSourceFileSync('entry/src/main/ets/services/PinmonyDetailCache.ets', 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  vm.runInNewContext(cacheCode, { exports: cacheExports, require: () => ({ PinmonyI18n: require('./local-message-test-fixture.cjs').rawLocalMessages }) });
  const cache = new cacheExports.PinmonyDetailCache();
  cache.put('123', { pinUrl: '/pin/123/', isVideo: true, video: h.video, actions: [], related: [] }, 0);
  assert.equal(cache.get('123').detail.isVideo, true, 'return cache preserves media identity');
  assert.equal(cache.get('123').detail.video, undefined, 'cached media URLs wait for fresh session data');
  assert.equal(cache.get('123').detail.mediaLoading, false, 'retained video must not show a request that is not running');
  const race = harness(false, { fakeTime: true }); race.playback.start(); await flush();
  race.players[0].events.stateChange('error');
  assert.equal(race.players.length, 1, 'state-only error waits briefly for the real code');
  race.players[0].events.error({ code: 5411010, message: 'PRIVATE_MEDIA_URL' }); await flush();
  assert.equal(race.players.length, 2);
  assert(race.traces.some(event => /event=failed.*code=5411010/.test(event)));
  assert(!race.traces.some(event => /event=failed.*code=0/.test(event)), 'state callback must not consume the coded error');
  race.fireTimers(200); await flush(); assert.equal(race.players.length, 2, 'error deadline is cancelled after the coded event');
  race.playback.release();
  for (const stateErrorFirst of [true, false]) {
    const ssl = harness(false, { fakeTime: true, prepareRejected: true, stateErrorFirst });
    ssl.playback.start(); await flush();
    assert.equal(ssl.players.length, 1, 'generic prepare rejection must wait for the underlying player error');
    ssl.players[0].events.error({ code: 5411009 }); await flush();
    assert.equal(ssl.players.length, 2);
    ssl.players[1].events.error({ code: 5411009 }); await flush();
    assert.match(ssl.states.at(-1).error, /安全连接失败/);
    assert.match(ssl.states.at(-1).failureSummary, /HLS：安全连接失败（5411009）.*MP4：安全连接失败（5411009）/);
    assert.equal(ssl.traces.filter(event => /event=failed.*code=5411009/.test(event)).length, 2);
    assert(!ssl.traces.some(event => /event=failed.*code=5400102/.test(event)), 'generic rejection must not mask SSL failure');
    ssl.fireTimers(200); assert.equal(ssl.players.length, 2, 'coded failure cancels generic fallback');
    ssl.playback.release();
  }
  const rejected = harness(false, { fakeTime: true, prepareRejected: true });
  rejected.playback.start(); await flush(); rejected.fireTimers(200); await flush();
  rejected.fireTimers(200); await flush();
  assert.equal(rejected.states.at(-1).phase, 'error');
  assert.equal(rejected.traces.filter(event => /event=failed stage=prepare.*code=5400102/.test(event)).length, 2,
    'a lone operation rejection is retained as the bounded fallback code');
  rejected.playback.release();
  const departed = harness(false, { fakeTime: true, prepareRejected: true });
  departed.playback.start(); await flush(); departed.playback.release(); departed.fireTimers(200); await flush();
  assert.equal(departed.players.length, 1, 'departure cancels pending generic error arbitration');
  const departedStates = departed.states.length;
  departed.players[0].events.error({ code: 5411009 });
  assert.equal(departed.states.length, departedStates, 'late underlying error cannot change a departed page');
  const unknown = harness(false, { fakeTime: true }); unknown.playback.start(); await flush();
  unknown.players[0].events.stateChange('error'); unknown.fireTimers(200); await flush();
  assert.equal(unknown.players.length, 2, 'missing code never prevents bounded fallback');
  const beforeLateCode = unknown.states.length;
  unknown.players[0].events.error({ code: 5411010 });
  assert(unknown.traces.some(event => /event=late-error.*callbackGeneration=.*code=5411010/.test(event)));
  assert.equal(unknown.states.length, beforeLateCode, 'late error code is retained as evidence without changing the new player');
  unknown.players[1].events.stateChange('error'); unknown.playback.release();
  unknown.fireTimers(200); assert.equal(unknown.timers.size, 0, 'departure clears error arbitration');
  const prepare = harness(false, { fakeTime: true, preparePending: true }); prepare.playback.start(); await flush();
  prepare.fireTimers(15000); await flush(); prepare.fireTimers(15000); await flush();
  assert.match(prepare.states.at(-1).error, /准备超时/);
  assert(prepare.traces.some(event => /event=failed stage=prepare.*reason=timeout/.test(event)));
  prepare.playback.retry(); await flush();
  assert.equal(prepare.players[2].source, 'hls', 'same-source manual retry creates a new player');
  prepare.playback.retry(); await flush(); assert.equal(prepare.players.length, 3, 'repeated retry while loading does not create extra players');
  prepare.playback.setActive(false); assert.equal(prepare.states.at(-1).phase, 'idle', 'inactive pending prepare cannot remain stuck in loading');
  prepare.playback.setActive(true); prepare.playback.retry(); await flush(); assert.equal(prepare.players.length, 4);
  prepare.playback.release();
  const frame = harness(false, { fakeTime: true }); frame.playback.start(); await flush();
  frame.fireTimers(15000); await flush(); frame.fireTimers(15000); await flush();
  assert.match(frame.states.at(-1).error, /画面加载超时/);
  assert(frame.traces.some(event => /event=failed stage=first-frame.*reason=timeout/.test(event)));
  frame.playback.release();
  const create = harness(true, { fakeTime: true }); create.playback.start(); await flush();
  create.fireTimers(15000); await flush(); assert.equal(create.pending.length, 2, 'hung player creation is also bounded');
  create.pending[0](); await flush(); assert.equal(create.players[0].releases, 1, 'late timed-out creation is released');
  create.playback.release(); create.pending[1](); await flush(); assert.equal(create.players[1].releases, 1);
  const component = readSourceFileSync('feature_pin/src/main/ets/components/PinmonyVideoPlayer.ets', 'utf8');
  const io = harness(false, { fakeTime: true, preparePending: true }); io.playback.start(); await flush();
  io.players[0].events.error({ code: 5400103 }); await flush();
  io.fireTimers(15000); await flush();
  assert.match(io.states.at(-1).failureSummary, /HLS：媒体读取失败（5400103）.*MP4：准备超时/,
    'a final MP4 timeout must retain the original HLS I/O failure');
  assert(io.traces.some(event => /event=failed .*elapsedMs=\d+/.test(event)));
  assert(io.traces.some(event => /event=candidates-exhausted count=2/.test(event)));
  io.playback.retry(); await flush(); assert.equal(io.states.at(-1).failureSummary, '', 'explicit retry starts a new diagnostic attempt');
  io.playback.release();
  let downloads = 0, fileReleases = 0, fileCancels = 0;
  const local = harness(false, { fakeTime: true, fileReader: {
    load: async source => { downloads++; assert.equal(source, 'mp4'); return { fd: 77, size: 24, release() {
      assert.equal(local.players[1].releases, 1, 'AVPlayer releases before closing its file descriptor'); fileReleases++;
    } }; }, cancel() { fileCancels++; }
  } });
  local.playback.start(); await flush();
  assert.equal(downloads, 0, 'stream starts without waiting for a complete MP4 download');
  assert.equal(local.players[0].source, 'mp4', 'detail prioritizes MP4 streaming over HLS');
  local.players[0].events.error({ code: 5400103 }); await flush();
  assert.equal(downloads, 1); assert.equal(local.players.length, 2);
  assert.equal(local.players[1].fileSource.fd, 77); assert.equal(local.players[1].fileSource.offset, 0);
  assert.equal(local.players[1].fileSource.length, 24);
  assert.equal(local.states.at(-1).rendered, false, 'successful download is not proof of a first frame');
  local.players[1].events.startRenderFrame(); assert.equal(local.states.at(-1).rendered, true);
  assert(local.traces.some(event => event.includes('event=file-fallback')));
  local.playback.release(); await flush(); assert.equal(fileReleases, 1); assert(fileCancels > 0);
  const failedRead = harness(false, { fakeTime: true, fileReader: {
    load: async () => { throw { code: 1007900035 }; }, cancel() {} } });
  failedRead.playback.start(); await flush();
  failedRead.players[0].events.error({ code: 5400103 }); await flush();
  assert.equal(failedRead.players.length, 2); assert.equal(failedRead.players[1].source, 'hls', 'HLS is tried after MP4 stream and file recovery');
  failedRead.players[1].events.error({ code: 5400103 }); await flush();
  assert.equal(failedRead.states.at(-1).phase, 'error');
  assert(failedRead.traces.some(event => /event=failed stage=download.*code=1007900035/.test(event)));
  failedRead.fireTimers(200); failedRead.fireTimers(15000); await flush();
  assert.equal(failedRead.players.length, 2, 'exhausted candidates cannot loop back into remote or local reads');
  failedRead.playback.release();
  for (const code of [1007900060, 2300060]) {
    const certificate = harness(false, { fileReader: { load: async () => { throw { code }; }, cancel() {} } });
    certificate.playback.start(); await flush();
    certificate.players[0].events.error({ code: 5400103 }); await flush();
    assert.equal(certificate.players.length, 1, 'unverified file cannot reach decoding');
    assert.match(certificate.states.at(-1).error, /证书校验失败/);
    assert.match(certificate.states.at(-1).failureSummary, /证书校验失败/);
    certificate.playback.release();
  }
  let retryDownloads = 0;
  const directRetry = harness(false, { fileReader: {
    load: async () => { retryDownloads++; throw { code: 1007900028 }; }, cancel() {} } });
  directRetry.playback.start(); await flush();
  directRetry.players[0].events.error({ code: 5400103 }); await flush();
  directRetry.playback.retry(); await flush();
  assert.equal(directRetry.players[1].source, 'hls');
  assert.equal(directRetry.players[2].source, 'mp4', 'explicit retry resets MP4 priority');
  directRetry.players[2].events.error({ code: 5400103 }); await flush();
  assert.equal(retryDownloads, 2, 'each explicit retry makes exactly one file attempt');
  assert.equal(directRetry.players.length, 4, 'each retry tries each remote candidate at most once');
  directRetry.players[3].events.error({ code: 5400106 }); await flush();
  assert.match(directRetry.states.at(-1).error, /pinimg\.com.*DIRECT/);
  assert.match(directRetry.states.at(-1).error, /建议使用全局模式/);
  assert(!directRetry.states.at(-1).error.includes('格式'), 'known connection timeout must not become a format error after another candidate fails');
  assert.match(directRetry.states.at(-1).failureSummary, /视频连接超时.*1007900028/);
  directRetry.playback.retry(); await flush();
  directRetry.players[4].events.error({ code: 5400106 }); await flush();
  directRetry.players[5].events.error({ code: 5400106 }); await flush();
  assert(!directRetry.states.at(-1).error.includes('DIRECT'), 'explicit retry clears the previous timeout diagnosis');
  directRetry.playback.release();
  let hlsDownloads = 0;
  const hlsOnly = harness(false, { fileReader: { load: async () => { hlsDownloads++; throw new Error('unexpected'); }, cancel() {} } });
  hlsOnly.playback.setVideo({ ...hlsOnly.video, sources: [{ url: 'hls', kind: 'hls' }] });
  hlsOnly.playback.start(); await flush();
  assert.equal(hlsDownloads, 0); assert.equal(hlsOnly.players[0].source, 'hls', 'HLS-only sources retain native playback');
  hlsOnly.playback.release();
  let completeFileRead, staleFileReleases = 0;
  const lateFile = harness(false, { fakeTime: true, fileReader: {
    load: () => new Promise(resolve => completeFileRead = resolve), cancel() {} } });
  lateFile.playback.start(); await flush();
  lateFile.players[0].events.error({ code: 5400103 }); await flush();
  lateFile.playback.setActive(false);
  completeFileRead({ fd: 88, size: 24, release() { staleFileReleases++; } }); await flush();
  assert.equal(staleFileReleases, 1); assert.equal(lateFile.players.length, 1);
  assert.equal(lateFile.states.at(-1).phase, 'idle', 'background cancels the pending local candidate');
  lateFile.playback.release();
  const changeMethod = component.slice(component.indexOf('  private sourceChanged()'), component.indexOf('  private activeChanged()'));
  const componentContext = {};
  vm.runInNewContext(ts.transpileModule(`class Component { ${changeMethod} } globalThis.Component = Component;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, componentContext);
  let resets = 0; const view = new componentContext.Component();
  Object.assign(view, { autoplayChanged() {}, video: { ...h.video, readRevision: 0 }, sourceKey: '', active: true, visible: true,
    mediaOwner: '', mounted: true, sourceUpdateQueued: false, componentGeneration: 0, sessionReady: false,
    playback: { setVideo() { resets++; }, setActive() {}, start() {}, stop() {} } });
  view.sourceChanged(); await flush(); assert.equal(resets, 0, 'early base media does not start before the current session is confirmed');
  view.sourceChanged(); view.mediaOwner = '/pin/123/|7'; view.sessionReady = true; view.sourceChanged(); await flush();
  assert.equal(resets, 1, 'initial source and owner delivery coalesce into one player');
  view.sourceChanged(); await flush(); assert.equal(resets, 1, 'ordinary snapshots do not restart playback');
  view.video = { ...h.video, readRevision: 1 }; view.sourceChanged(); await flush();
  assert.equal(resets, 2, 'reread with unchanged URLs restarts playback');
  view.mediaOwner = '/pin/123/|8'; view.sourceChanged(); view.sourceChanged(); await flush();
  assert.equal(resets, 3, 'a new session invalidates the player once');
  view.video = { ...h.video, readRevision: 2 }; view.sourceChanged(); view.mounted = false; view.componentGeneration++;
  await flush(); assert.equal(resets, 3, 'queued initialization cannot run after departure');
  const retryMethods = component.slice(component.indexOf('  private activeChanged()'), component.indexOf('  private time('));
  const retryContext = {};
  vm.runInNewContext(ts.transpileModule(`class RetryView { ${retryMethods} } globalThis.RetryView = RetryView;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, retryContext);
  const retryView = new retryContext.RetryView(); let retries = 0;
  Object.assign(retryView, { active: true, visible: false, readingAddress: false, pendingRetry: false, sessionReady: true,
    playback: { setActive() {}, retry() { retries++; } } });
  retryView.retryRequested(); assert.equal(retries, 0, 'top retry waits until scrolling restores video visibility');
  retryView.visible = true; retryView.activeChanged(); retryView.activeChanged();
  assert.equal(retries, 1, 'restored visibility consumes the explicit retry once');
  retryView.visible = false; retryView.retryRequested(); retryView.active = false; retryView.activeChanged();
  retryView.active = true; retryView.visible = true; retryView.activeChanged();
  assert.equal(retries, 1, 'leaving the active detail cancels queued retry intent');
  retryView.readingAddress = true; retryView.retryRequested(); assert.equal(retries, 1, 'address read blocks playback retry');
  console.log('Video playback: manual start, surface binding, mute/seek/pause, fallback, retry and lifecycle guards passed');
}
main().catch(e => { console.error(e); process.exitCode = 1; });
