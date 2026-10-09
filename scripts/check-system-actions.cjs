const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const callbacks = {}, events = [], notices = [];
let selection = [], imageFailure = '';
class Delegate {
  onBeforeDownload(fn) { callbacks.before = fn; }
  onDownloadFinish(fn) { callbacks.finish = fn; }
  onDownloadFailed(fn) { callbacks.failed = fn; }
}
const context = { openLink: async url => events.push(['link', url]) };
const mocks = {
  '@kit.ArkWeb': { webview: { WebDownloadDelegate: Delegate } },
  '@kit.CoreFileKit': {
    picker: { DocumentSaveOptions: class {}, DocumentPickerMode: { DOWNLOAD: 1 },
      DocumentViewPicker: class { save() { return Promise.resolve(selection); } } },
    fileUri: { FileUri: class { constructor(uri) { this.path = uri === 'valid-directory' ? '/downloads' : ''; } } },
    fileIo: { OpenMode: { READ_ONLY: 1 }, open: async uri => { events.push(['open', uri]); return { fd: 7 }; },
      close: async () => events.push('file-close') }
  },
  '@kit.MediaLibraryKit': { photoAccessHelper: { PhotoSelectOptions: class {}, PhotoViewMIMETypes: { IMAGE_TYPE: 1 },
    PhotoViewPicker: class { async select() { return { photoUris: ['file://media/photo'] }; } } } },
  '@kit.BasicServicesKit': { pasteboard: { MIMETYPE_TEXT_PLAIN: 'text/plain', createData: (_, text) => text,
    getSystemPasteboard: () => ({ setData: async text => events.push(['copy', text]) }) } },
  '@kit.ImageKit': { image: {
    createImageSource: () => ({ release: async () => events.push('source-release') }),
    createImagePacker: () => {
      if (imageFailure === 'create') throw Error('packer creation');
      return { packToData: async () => { if (imageFailure === 'pack') throw Error('packing'); return new ArrayBuffer(3); },
        release: async () => events.push('packer-release') };
    }
  } },
  common_foundation: { PinWebRuntimeLog: { info() {}, warn() {}, error() {}, export: async () => true } }
};
const Actions = createArktsLoader(ts, mocks).loadFile('entry/src/main/ets/app/PinWebSystemActions.ets').PinWebSystemActions;
const actions = new Actions(() => context, message => notices.push(message));
function item(guid) {
  return { getGuid: () => guid, getSuggestedFileName: () => 'photo:*?.jpg', getLastErrorCode: () => 1,
    cancel: () => events.push(['cancel', guid]), start: path => events.push(['start', guid, path]) };
}
async function main() {
  await actions.copyText('https://pin.it/example');
  await actions.openLink('https://www.pinterest.com/');
  assert.equal(await actions.exportRuntimeLog(), true);
  assert.equal(await actions.pickImage(), 'file://media/photo');
  assert.equal((await actions.readJpeg('file://media/photo')).byteLength, 3);
  assert.deepEqual(events.slice(-3), ['packer-release', 'source-release', 'file-close']);
  imageFailure = 'create';
  await assert.rejects(actions.readJpeg('file://media/photo'));
  assert.deepEqual(events.slice(-2), ['source-release', 'file-close']);
  imageFailure = 'pack';
  await assert.rejects(actions.readJpeg('file://media/photo'));
  assert.deepEqual(events.slice(-3), ['packer-release', 'source-release', 'file-close']);

  const controller = { setDownloadDelegate: delegate => { assert(delegate instanceof Delegate); } };
  actions.installDownloadDelegate(controller);
  let resolveSelection;
  selection = new Promise(resolve => { resolveSelection = resolve; });
  callbacks.before(item('late'));
  actions.dispose();
  assert(events.some(e => Array.isArray(e) && e[0] === 'cancel' && e[1] === 'late'));
  resolveSelection(['valid-directory']);
  await new Promise(setImmediate);
  assert.equal(events.some(e => Array.isArray(e) && e[0] === 'start'), false, 'disposed picker cannot start a download');
  callbacks.finish(item('late')); callbacks.failed(item('late'));
  assert.equal(notices.length, 0, 'disposed callbacks cannot show UI feedback');
  actions.activate(); selection = ['valid-directory'];
  callbacks.before(item('current'));
  await new Promise(setImmediate);
  const started = events.find(e => Array.isArray(e) && e[0] === 'start');
  assert.equal(started[1], 'current');
  assert.match(started[2], /^\/downloads\/pin-\d+-photo___\.jpg$/);
  selection = []; callbacks.before(item('cancelled'));
  await new Promise(setImmediate); const beforeFailure = notices.length;
  callbacks.failed(item('cancelled'));
  assert.equal(notices.length, beforeFailure, 'user cancellation does not become a download failure');
  actions.dispose();
  console.log('System actions: injected native adapters, picker cancellation, stale download suppression and JPEG resource release passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
