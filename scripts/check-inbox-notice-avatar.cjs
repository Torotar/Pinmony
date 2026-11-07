const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const code=ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxNoticeAvatar.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText;
function fixture(){
  let active=true,bytes=16,dimensions={width:256,height:256},pixelBytes=65536,decodeFails=false,cancelled=0,releasedSource=0,releasedPixels=0,reads=0;
  const timers=new Map();let timerSequence=0;
  const pixels={release:async()=>releasedPixels++,getPixelBytesNumber:()=>pixelBytes};
  const source={getImageInfo:async()=>({size:dimensions}),createPixelMap:async options=>{assert.equal(options.desiredSize.width,128);assert.equal(options.desiredSize.height,128);if(decodeFails)throw Error('decode');return pixels;},release:async()=>releasedSource++};
  const exports={};
  vm.runInNewContext(code,{exports,Uint8Array,setTimeout:(callback,ms)=>{assert.equal(ms,3000);timers.set(++timerSequence,callback);return timerSequence;},clearTimeout:id=>timers.delete(id),
    require:name=>name==='@kit.ImageKit'?{image:{createImageSource:()=>source}}:{acceptsImageDownloadUrl:url=>/^https:\/\/i\.pinimg\.com\//.test(url),
      PinmonyImageDownload:class{cancel(){cancelled++;}async read(_url,current){reads++;assert(current());return{data:new ArrayBuffer(bytes)};}}}});
  const loader=new exports.PinmonyInboxNoticeAvatar();
  return{loader,pixels,current:()=>active,setActive:v=>active=v,setBytes:v=>bytes=v,setDimensions:v=>dimensions=v,setPixelBytes:v=>pixelBytes=v,setDecodeFails:v=>decodeFails=v,
    stats:()=>({cancelled,releasedSource,releasedPixels,reads,timers:timers.size})};
}
async function main(){
  const f=fixture();assert.equal(await f.loader.read('https://evil.invalid/avatar.jpg',f.current),undefined);assert.equal(f.stats().reads,0);
  assert.equal(await f.loader.read('https://i.pinimg.com/avatar.jpg',f.current),f.pixels);assert.equal(f.stats().releasedSource,1);assert.equal(f.stats().releasedPixels,0,'caller owns returned pixels');assert.equal(f.stats().timers,0);
  await f.pixels.release();f.setActive(false);assert.equal(await f.loader.read('https://i.pinimg.com/avatar.jpg',f.current),undefined);assert.equal(f.stats().reads,1);
  const huge=fixture();huge.setBytes(1024*1024+1);assert.equal(await huge.loader.read('https://i.pinimg.com/avatar.jpg',huge.current),undefined);
  const dimensions=fixture();dimensions.setDimensions({width:100000,height:100000});assert.equal(await dimensions.loader.read('https://i.pinimg.com/avatar.jpg',dimensions.current),undefined);assert.equal(dimensions.stats().releasedSource,1);
  const pixelLimit=fixture();pixelLimit.setPixelBytes(192*1024+1);assert.equal(await pixelLimit.loader.read('https://i.pinimg.com/avatar.jpg',pixelLimit.current),undefined);assert.equal(pixelLimit.stats().releasedPixels,1);assert.equal(pixelLimit.stats().releasedSource,1);
  const failed=fixture();failed.setDecodeFails(true);assert.equal(await failed.loader.read('https://i.pinimg.com/avatar.jpg',failed.current),undefined);assert.equal(failed.stats().releasedSource,1);assert.equal(failed.stats().timers,0);
  failed.loader.cancel();assert.equal(failed.stats().cancelled,1);
  console.log('Notice avatar: public CDN restriction, 128px decode, byte/pixel limits, inactive guard, bounded timer and source/pixel resource cleanup passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
