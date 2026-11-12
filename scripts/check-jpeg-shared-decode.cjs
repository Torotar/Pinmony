const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const pending=[],decodes=[],released=[];let transfers=0,peak=0,inflight=0;
class Download {
  cancel(){this.reject?.(Error('cancelled'));}
  async read(url,current){
    transfers++;inflight++;peak=Math.max(peak,inflight);
    try{return await new Promise((resolve,reject)=>{this.reject=reject;pending.push({url,current,
      done:(pixels=500000,bytes=2000000)=>resolve({data:{pixels,bytes,url},extension:'jpg'})});});}
    finally{inflight--;this.reject=undefined;}
  }
}
const kit={AllocatorType:{SHARE_MEMORY:2},DecodingDynamicRange:{SDR:1},
  createImageSource:data=>({getImageInfo:async()=>({size:{width:500,height:data.pixels/500}}),
    createPixelMapUsingAllocator:async(options,allocator)=>{decodes.push({url:data.url,options,allocator});
      return {getPixelBytesNumber:()=>data.bytes,release:async()=>released.push(data.url)};},release:async()=>{}})};
const output={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinmonyJpegDecode.ets','utf8'),{
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{
  exports:output,require:name=>name==='@kit.ImageKit'?{image:kit}:name==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:name==='./PinmonyNativeNetwork'?{Priority:{HIGH:0,NORMAL:1,LOW:2}}:{PinmonyImageDownload:Download,
    acceptsImageDownloadUrl:value=>/^https:\/\/i\.pinimg\.com\//.test(value)},Map,Promise,Error});
const api=output.PinmonyJpegDecode,url=key=>'https://i.pinimg.com/564x/'+key+'.jpg';
const flush=async()=>{for(let n=0;n<16;n++)await Promise.resolve();};
(async()=>{
  assert(output.acceptsSoftwareJpeg(url('a')));
  assert(!output.acceptsSoftwareJpeg('https://www.pinterest.com/a.jpg'));
  assert(!output.acceptsSoftwareJpeg('https://i.pinimg.com/a.gif'));
  assert.throws(()=>api.acquire('https://other.example/a.jpg'));
  const a=api.acquire(url('a')),same=api.acquire(url('a')),b=api.acquire(url('b')),c=api.acquire(url('c'));
  await flush();assert.equal(transfers,3);assert.equal(a.ready,same.ready,'one transfer/decode per URL');
  a.release();assert(pending[0].current(),'one owner may leave while another still needs the image');
  const cancelled=assert.rejects(same.ready,/unavailable/);same.release();await cancelled;await flush();
  assert.equal(transfers,3,'cancelled transfer is not replayed');assert(peak<=4);
  pending.find(p=>p.url===url('b')).done();const bitmap=await b.ready;
  assert.equal(decodes[0].allocator,2,'explicit SHARE_MEMORY is required');
  b.release();const cached=api.acquire(url('b')),motion=api.acquire(url('b')),heroLease=api.acquire(url('b'));
  assert.equal(cached.bitmap,bitmap,'home bitmap is synchronously available to the entry motion');
  assert.equal(motion.bitmap,bitmap);assert.equal(heroLease.bitmap,bitmap);
  assert.equal(await cached.ready,bitmap);assert.equal(transfers,3,'home, transition and hero share one transfer');
  cached.release();motion.release();heroLease.release();pending.find(p=>p.url===url('c')).done();await c.ready;c.release();
  const huge=api.acquire(url('huge')),hugeRejected=assert.rejects(huge.ready,/unavailable/);
  await flush();
  pending.find(p=>p.url===url('huge')).done(4000000);await hugeRejected;huge.release();
  assert(!decodes.some(d=>d.url===url('huge')),'oversized JPEG is rejected before PixelMap allocation');
  const held=api.acquire(url('held'));await flush();pending.find(p=>p.url===url('held')).done(500000,14000000);await held.ready;
  for(const key of ['d','e']){const item=api.acquire(url(key));await flush();pending.find(p=>p.url===url(key)).done(500000,14000000);await item.ready;item.release();}
  assert(!released.includes(url('held')),'cache eviction never releases a displayed bitmap');
  held.release();held.release();assert(peak<=4);
  const pinned=api.acquire(url('pinned'));await flush();pending.find(p=>p.url===url('pinned')).done();await pinned.ready;
  api.clearUnused();assert(!released.includes(url('pinned')));
  api.clear();assert(!released.includes(url('pinned')),'session reset defers displayed bitmap release');
  pinned.release();assert(released.includes(url('pinned')),'last old-session owner releases retired bitmap');
  const late=api.acquire(url('late')),lateRejected=assert.rejects(late.ready,/unavailable/);
  api.clear();await lateRejected;late.release();
  const smart=fs.readFileSync('common_ui/src/main/ets/components/SmartImage.ets','utf8');
  const methods=['releaseDecode','loadDecodedImage'].map(name=>smart.match(new RegExp('  private '+name+'\\([\\s\\S]*?\\r?\\n  \\}'))[0]);
  const leases=[];
  const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{
    compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Promise,
      acceptsSoftwareJpeg:output.acceptsSoftwareJpeg,PinmonyJpegDecode:{acquire:url=>{
        const entry={url,releases:0};entry.ready=new Promise((resolve,reject)=>Object.assign(entry,{resolve,reject}));
        entry.release=()=>entry.releases++;leases.push(entry);return entry;}}});
  const host=new Host();Object.assign(host,{imageVisible:true,imageRevision:1,softwareAttemptedRevision:-1,
    sourceUrl:url('view-a'),traceImage:()=>{}});host.loadDecodedImage();host.loadDecodedImage();assert.equal(leases.length,1);
  host.imageRevision=2;host.sourceUrl=url('view-b');host.loadDecodedImage();assert.equal(leases[0].releases,1);
  leases[0].resolve({old:true});await flush();assert.equal(host.decodedBitmap,undefined,'late source cannot replace current card');
  leases[1].reject(Error('offline'));await flush();assert.equal(host.softwarePending,false);
  host.loadDecodedImage();assert.equal(leases.length,2,'equivalent snapshots cannot repeat a failed transfer');
  host.imageRevision=3;host.loadDecodedImage();host.imageVisible=false;host.releaseDecode();
  leases[2].resolve({late:true});await flush();assert.equal(host.decodedBitmap,undefined,'disposed card ignores decode completion');
  const cdn=fs.readFileSync('common_ui/src/main/ets/components/PinmonyCdnImage.ets','utf8');
  const cdnMethods=['release','reload'].map(name=>cdn.match(new RegExp('  private '+name+'\\([\\s\\S]*?\\r?\\n  \\}'))[0]);
  const imageLeases=[];
  const ImageHost=vm.runInNewContext(ts.transpileModule('class ImageHost {'+cdnMethods.join('\n')+'} ImageHost;',{
    compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{Promise,acceptsSoftwareJpeg:output.acceptsSoftwareJpeg,
      PinmonyJpegDecode:{acquire:url=>{const lease={url,releases:0};lease.ready=new Promise((resolve,reject)=>Object.assign(lease,{resolve,reject}));
        lease.release=()=>lease.releases++;imageLeases.push(lease);return lease;}}});
  const hero=new ImageHost();Object.assign(hero,{visible:true,generation:0,url:url('hero-a'),
    uiCommits:{clear(){}},tracePhases:new Set()});hero.reload();
  hero.url=url('hero-b');hero.reload();assert.equal(imageLeases[0].releases,1);
  imageLeases[0].resolve({old:true});await flush();assert.equal(hero.bitmap,undefined);
  imageLeases[1].resolve({current:true});await flush();assert(hero.bitmap.current);assert.equal(hero.pending,false);
  hero.visible=false;hero.generation++;hero.release();assert.equal(imageLeases[1].releases,1);
  const home=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets','utf8');
  const motionSource=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailEntryMotion.ets','utf8');
  assert(home.includes('PinmonyCdnImage({ url: this.recoveredSources[pin.imageUrl] || pin.imageUrl'));
  assert(motionSource.includes('PinmonyCdnImage({ url: this.photo.imageUrl'));
  assert(!motionSource.includes('Image(this.photo.imageUrl)'));
  assert(cdn.includes('this.pending = !this.bitmap'),'cache hits must not hide the bitmap behind a pending phase');
  console.log('JPEG shared decode: allowlist, URL merging, leases, cancellation, queue, allocator, cache eviction and size guard passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
