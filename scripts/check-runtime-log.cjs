const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = readSourceFileSync('entry/src/main/ets/services/PinmonyRuntimeLog.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
const files = new Map(); let destinations = []; let closes = 0;
const io = { OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4, APPEND: 8 },
  readTextSync: path => { if (!files.has(path)) throw Error('missing'); return files.get(path); },
  copyFileSync: (src,dst) => { if(!files.has(src)) throw Error('missing'); files.set(dst,files.get(src)); },
  openSync: (path,mode) => { if(mode & 4) files.set(path,''); return { fd: {path,mode} }; },
  writeSync: (fd, text) => files.set(fd.path, (fd.mode & 8 ? files.get(fd.path)||'' : '') + text), closeSync: () => closes++ };
const context = { fs: io, picker: { DocumentViewPicker: class { async save() { return destinations; } } }, console: { info() {}, warn() {} }, Date };
vm.runInNewContext(ts.transpileModule(source + '\nglobalThis.Log = PinmonyRuntimeLog;', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText, context);
(async () => {
  const log = context.Log;
  assert.match(log.savedStatus(), /尚未成功/);
  log.initialize('/internal');
  assert.match(log.savedStatus(), /已自动保存/);
  log.info('cookie=secret token=hidden https://example.test/?csrf=private account_id=1234567890123');
  const persisted = files.get('/internal/pinweb-runtime.log');
  assert(!/secret|hidden|private|1234567890123/.test(persisted));
  log.initialize('/internal');
  assert(files.get('/internal/pinweb-session-previous.log').includes('[credential]'),'previous startup session is retained');
  assert(files.get('/internal/pinweb-runtime.log').includes('[credential]'));
  for (let i = 0; i < 450; i++) log.info('event ' + i);
  assert.equal(files.get('/internal/pinweb-runtime.log').trim().split('\n').length, 453);
  assert(files.get('/internal/pinweb-session-current.log').includes('event 0'),'session file is not truncated to the bounded memory summary');
  assert.equal(await log.export({}), false);
  destinations = ['/export.txt'];
  assert.equal(await log.export({}), true);
  assert(files.get('/export.txt').includes('event 449'));
  assert(files.get('/export.txt').includes('Previous session'));
  for (let i = 0; i < 2300; i++) log.info('rotation ' + i + ' ' + 'x'.repeat(750));
  assert(files.get('/internal/pinweb-session-previous.log').length > 0,'previous completed session segment is retained when the session rotates');
  assert(files.get('/internal/pinweb-session-current.log').includes('rotation 2299'));
  assert(closes > 450);
  console.log('Runtime log: privacy, restart retention, bounded storage, cancel and export passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
