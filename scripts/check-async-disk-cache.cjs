const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const load = (file, require) => { const exports = {}; vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'), {
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}
}).outputText, {exports,require}); return exports; };
const {LruCache} = load('common_foundation/src/main/ets/cache/LruCache.ets', () => ({}));
const defer = () => { let resolve; const promise = new Promise(r => resolve=r); return {promise,resolve}; };
const turn = () => new Promise(setImmediate);
function fixture() {
  const records = new Map(), events = []; let writeGate, readGate, fail = false;
  class DiskCache {
    async getWithMetadataAsync(key, ttl, current) { const value=records.get(key); events.push('read'); if(readGate)await readGate;
      return {value:current() && value !== undefined ? value : null,status:current() && value !== undefined?'hit':'miss',ageMs:1}; }
    async putAsync(key,value,current) { events.push('write-start'); if(writeGate)await writeGate; if(!current())throw Error('invalidated');
      if(fail)throw Error('disk-full');records.set(key,value);events.push('write-end'); }
    async clearAsync() {const size=records.size;records.clear();events.push('clear');return size;}
    async removeAsync(key) {records.delete(key);}
  }
  const {ApiCache}=load('common_foundation/src/main/ets/cache/ApiCache.ets',name=>name==='./LruCache'?{LruCache}:name==='./DiskCache'?{DiskCache}:{PinmonyRuntimeLog:{info(){}}});
  return {cache:new ApiCache('/cache'),records,events,writeGate:value=>writeGate=value,readGate:value=>readGate=value,fail:value=>fail=value};
}
(async()=>{
  const a=fixture(), gate=defer(); a.writeGate(gate.promise); const write=a.cache.putAsync('a','value',10000);
  await turn(); assert.deepEqual(a.events,['write-start']); let cleared=false;
  const clear=a.cache.clearAsync().then(()=>cleared=true);assert.equal(cleared,false);gate.resolve();await assert.rejects(write);await clear;
  assert.equal(a.records.size,0,'clear cannot be followed by a stale write');
  const b=fixture(), old=defer();b.writeGate(old.promise);const first=b.cache.putAsync('same','old',10000);await turn();
  const second=b.cache.putAsync('same','new',10000);old.resolve();await assert.rejects(first);await second;assert.equal(b.records.get('same'),'new');
  const c=fixture(), read=defer();c.records.set('x','old');c.readGate(read.promise);const lookup=c.cache.getWithMetadataAsync('x',10000);await turn();
  const fresh=c.cache.putAsync('x','new',10000);read.resolve();assert.equal((await lookup).value,null);await fresh;
  assert.equal((await c.cache.getWithMetadataAsync('x',10000)).value,'new','old disk reads cannot overwrite confirmed memory');
  const d=fixture();d.records.set('hit','disk');const shared=await Promise.all([d.cache.getWithMetadataAsync('hit',10000),d.cache.getWithMetadataAsync('hit',10000)]);
  assert.equal(d.events.filter(x=>x==='read').length,1);assert(shared.every(x=>x.value==='disk'));
  d.fail(true);await assert.rejects(d.cache.putAsync('failure','confirmed',10000));
  assert.equal((await d.cache.getWithMetadataAsync('failure',10000)).value,'confirmed','disk failure retains confirmed memory');
  let valid=true;const e=fixture(), ownerGate=defer();e.writeGate(ownerGate.promise);const owned=e.cache.putAsync('account','old',10000,()=>valid);await turn();valid=false;ownerGate.resolve();await assert.rejects(owned);assert.equal(e.records.size,0);
  const diskSource=fs.readFileSync('common_foundation/src/main/ets/cache/DiskCache.ets','utf8');
  const asyncSource=diskSource.slice(diskSource.indexOf('  async getWithMetadataAsync'));
  assert(!/fs\.\w+Sync\(/.test(asyncSource),'asynchronous path does not call synchronous file APIs');
  assert.match(asyncSource,/await fs\.rename\(temporaryPath, path\)/,'atomic rename remains');
  const files=new Map(), handles=new Map();let nextFd=0,shortWrite=false,renameFails=false;
  const diskFs={OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},mkdir:async()=>{},
    open:async path=>{const file={fd:++nextFd};handles.set(file.fd,path);files.set(path,'');return file;},
    write:async(fd,bytes)=>{files.set(handles.get(fd),Buffer.from(bytes).toString('utf8'));return bytes.byteLength-(shortWrite?1:0);},
    close:async()=>{},rename:async(from,to)=>{if(renameFails)throw Error('rename-failed');files.set(to,files.get(from));files.delete(from);},
    unlink:async path=>{files.delete(path);},listFile:async()=>[...files.keys()].map(path=>path.split('/').at(-1)),
    stat:async path=>{if(!files.has(path))throw Error('missing');return {mtime:Date.now()/1000};},
    readText:async path=>{if(!files.has(path))throw Error('missing');return files.get(path);}};
  const codec=load('common_foundation/src/main/ets/cache/CacheCodec.ets',()=>({taskpool:{Priority:{LOW:0},Task:class{constructor(fn,...args){this.fn=fn;this.args=args;}},execute:async task=>task.fn(...task.args)},util:{TextEncoder:class{encodeInto(text){return new Uint8Array(Buffer.from(text,'utf8'));}}}}));
  const {DiskCache:RealDisk}=load('common_foundation/src/main/ets/cache/DiskCache.ets',name=>name==='./CacheCodec'?codec:name==='@ohos.file.fs'?{default:diskFs}:name==='@kit.ArkTS'?{util:{TextEncoder:class {encodeInto(text){return new Uint8Array(Buffer.from(text,'utf8'));}}}}:{hashCacheString:key=>key});
  const disk=new RealDisk('/cache');await disk.putAsync('unicode',{text:'中文'},()=>true);
  assert.equal((await disk.getWithMetadataAsync('unicode',10000,()=>true)).value.text,'中文');
  shortWrite=true;await assert.rejects(disk.putAsync('unicode',{text:'partial'},()=>true));shortWrite=false;
  assert.equal((await disk.getWithMetadataAsync('unicode',10000,()=>true)).value.text,'中文','short write preserves original');
  renameFails=true;await assert.rejects(disk.putAsync('unicode',{text:'rename'},()=>true));renameFails=false;
  assert.equal([...files.keys()].filter(path=>path.endsWith('.tmp')).length,0,'failure releases temporary files');
  assert.equal((await disk.getWithMetadataAsync('unicode',10000,()=>true)).value.text,'中文','failed rename preserves original');
  console.log('Async cache: nonblocking writes, serialized atomic commits, clear/replace/cancel/late-read isolation, shared lookup, and disk-failure memory retention passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
