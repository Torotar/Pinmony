const assert = require('node:assert/strict'), crypto = require('node:crypto');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const events = [], logs = [];
let hashFailure = false, diskFailure = '', asyncFailure = '', cookieFailure = '', cookieWrites = 0;
const sdkFailure = () => { throw Error('synthetic SDK error'); };
const fileIo = {
  OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4, APPEND: 8, READ_ONLY: 16 },
  open: async () => { if (asyncFailure === 'open') sdkFailure(); events.push('open'); return { fd: 7 }; },
  write: async (_fd, bytes) => { if (asyncFailure === 'write') sdkFailure(); return bytes.byteLength; },
  close: async () => { events.push('close'); if (asyncFailure === 'close') sdkFailure(); },
  copyFile: async () => sdkFailure(), stat: async () => ({ size: 5 }),
  accessSync: () => true,
  openSync: () => { events.push('disk-open'); return { fd: 8 }; },
  writeSync: () => { if (diskFailure === 'write') sdkFailure(); },
  closeSync: () => { events.push('disk-close'); },
  renameSync: () => { events.push('rename'); if (diskFailure === 'rename') sdkFailure(); },
  unlinkSync: () => events.push('unlink')
};
const cookieManager = {
  fetchCookie: () => { if (cookieFailure === 'sync') sdkFailure(); return Promise.reject(Error('synthetic SDK rejection')); },
  configCookie: () => { cookieWrites++; return Promise.reject(Error('synthetic SDK rejection')); }
};
const logger = { info() {}, warn: v => logs.push(v), error: v => logs.push(v) };
const loader = createArktsLoader(ts, {
  '@kit.RemoteCommunicationKit': { rcp: {} },
  '@kit.ArkTS': { util: { TextEncoder: class { encodeInto(v) { return new Uint8Array(Buffer.from(v)); } } } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd: () => {
    if (hashFailure) sdkFailure();
    const hash = crypto.createHash('md5');
    return { updateSync: v => hash.update(v.data), digestSync: () => ({ data: new Uint8Array(hash.digest()) }) };
  } } },
  '@ohos.file.fs': { default: fileIo }, '@kit.CoreFileKit': { fileIo },
  '@kit.ArkWeb': { webview: { WebCookieManager: cookieManager, WebDownloadDelegate: class {} } },
  '@kit.AbilityKit': {}, '@kit.BasicServicesKit': { pasteboard: { getSystemPasteboard: sdkFailure } },
  '@kit.ShareKit': {}, '@kit.ArkData': {},
  '@kit.MediaLibraryKit': { photoAccessHelper: { PhotoSelectOptions: class {}, PhotoViewMIMETypes: { IMAGE_TYPE: 1 },
    PhotoViewPicker: class { select() { sdkFailure(); } } } },
  '@kit.ImageKit': { image: { createImageSource: sdkFailure } },
  common_foundation: { PinmonyRuntimeLog: logger }
});
(async () => {
  const keys = loader.loadFile('common_foundation/src/main/ets/cache/CacheKey.ets');
  assert.equal(keys.hashCacheString('test'), crypto.createHash('md5').update('test').digest('hex'));
  hashFailure = true;
  assert.throws(() => keys.buildCacheKey('account', 'resource', {}), /cache-hash-unavailable/);
  hashFailure = false;
  const Disk = loader.loadFile('common_foundation/src/main/ets/cache/DiskCache.ets').DiskCache;
  const disk = new Disk('/fixture');
  diskFailure = 'write';
  assert.throws(() => disk.put('key', {}), /cache-write-failed/);
  assert.deepEqual(events.splice(0), ['disk-open', 'disk-close', 'unlink'], 'failed write must not commit and must clean up');
  diskFailure = 'rename';
  assert.throws(() => disk.put('key', {}), /cache-write-failed/);
  assert.deepEqual(events.splice(0), ['disk-open', 'disk-close', 'rename', 'unlink']);
  const Credentials = loader.loadFile('common_session/src/main/ets/services/PinmonySessionCredentials.ets').PinmonySessionCredentials;
  const credentials = new Credentials(), url = 'https://www.pinterest.com/';
  for (cookieFailure of ['sync', 'async']) await assert.rejects(credentials.read(url), /session-cookie-read-unavailable/);
  await assert.rejects(credentials.update(url, ['first', 'second'], () => true), /session-cookie-update-unavailable/);
  assert.equal(cookieWrites, 1, 'failed cookie update cannot continue to the next value');
  const Runtime = loader.loadFile('common_foundation/src/main/ets/services/PinmonyRuntimeLog.ets').PinmonyRuntimeLog;
  asyncFailure = 'write';
  await assert.rejects(Runtime.writeFile('/fixture', 'text', false), /diagnostics-write-failed/);
  assert.deepEqual(events.splice(0), ['open', 'close']);
  asyncFailure = 'close';
  await assert.rejects(Runtime.writeFile('/fixture', 'text', false), /diagnostics-close-failed/);
  events.length = 0;
  Runtime.sessionPath = '/fixture'; Runtime.previousPath = '/previous'; Runtime.sessionSize = 8 * 1024 * 1024;
  await assert.rejects(Runtime.writeSession('text'), /diagnostics-session-write-failed/);
  assert.equal(Runtime.sessionPersisted, false);
  assert.equal(Runtime.sessionIncomplete, true);
  assert.deepEqual(events.splice(0), ['open', 'close']);
  const Actions = loader.loadFile('entry/src/main/ets/app/PinmonySystemActions.ets').PinmonySystemActions;
  const actions = new Actions(() => ({ openLink: sdkFailure }), () => {});
  // Synchronous SDK exceptions must become Promise failures for existing callers.
  await assert.rejects(actions.copyText('text'), /无法复制/);
  await assert.rejects(actions.openLink(url), /无法打开/);
  await assert.rejects(actions.pickImage(), /无法选择/);
  asyncFailure = '';
  await assert.rejects(actions.readJpeg('file://media/fixture'), /无法读取/);
  assert.deepEqual(events.splice(0), ['open', 'close']);
  const photo = loader.loadFile('feature_profile/src/main/ets/services/PinmonyPublishPhoto.ets');
  await assert.rejects(photo.pickPublishPhotoUris(), /无法选择/);
  await assert.rejects(photo.readPublishPhoto('file://media/fixture'), /4 MB/, 'existing photo validation message survives');
  assert.deepEqual(events.splice(0), ['open', 'close']);
  assert(logs.every(v => !v.includes('synthetic SDK')), 'diagnostics must omit raw SDK messages');
  console.log('Platform exceptions: synchronous/rejected API failures, cache fail-closed behavior, cookie stop, log persistence and photo cleanup passed');
})().catch(e => { console.error(e); process.exitCode = 1; });
