const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps,globals={}){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:deps,setTimeout,clearTimeout,...globals});return exports;}
let reply,requests=[],closed=0,cancelled=0;
class Request{constructor(url,method,headers){this.url=url;this.method=method;this.headers=headers;}}
const rcp={Request,createSession:()=>({fetch:r=>new Promise((resolve,reject)=>{requests.push(r);reply=(bytes,status=200)=>{try{r.configuration.tracing.httpEventsHandler.onStatusCodeReceive(status);r.destination(new Uint8Array(bytes).buffer);resolve({statusCode:status});}catch(e){reject(e);}};}),cancel:()=>cancelled++,close:()=>closed++})};
const {PinmonyImageDownload:Download,acceptsImageDownloadUrl}=load('common_network/src/main/ets/PinmonyImageDownload.ets',n=>n==='@kit.RemoteCommunicationKit'?{rcp}:{NetworkManager:{enqueue:(_p,fn)=>fn()},Priority:{NORMAL:1}});
const png=[137,80,78,71,13,10,26,10,0],url='https://i.pinimg.com/originals/photo.png';
async function main(){
 assert(acceptsImageDownloadUrl(url));for(const value of ['http://i.pinimg.com/a.png','https://evil.test/a.png','https://i.pinimg.com@evil.test/a','https://i.pinimg.com/a#secret','https://i.pinimg.com/../../a\\b'])assert(!acceptsImageDownloadUrl(value));
 const d=new Download();let p=d.read(url,()=>true);assert.equal(requests[0].method,'GET');assert(!Object.keys(requests[0].headers).some(k=>/cookie|csrf|authorization/i.test(k)));assert.equal(requests[0].configuration.transfer.autoRedirect,false);reply(png);const image=await p;assert.equal(image.extension,'png');assert.equal(image.data.byteLength,png.length);
 p=d.read(url,()=>true);reply(png,302);await assert.rejects(p);
 p=d.read(url,()=>true);reply([60,104,116,109,108,62]);await assert.rejects(p);
 p=d.read(url,()=>true);reply(new Uint8Array(32*1024*1024+1));await assert.rejects(p);
 p=d.read(url,()=>true);d.cancel();await assert.rejects(p);assert(cancelled);
 let active=true;p=d.read(url,()=>active);active=false;reply(png);await assert.rejects(p);assert(closed>=6);
 // Execute the real save handler: cancellation sends no download, partial writes finish and files close.
 const text=fs.readFileSync('entry/src/main/ets/app/PinmonySystemActions.ets','utf8'),start=text.indexOf('  async downloadImage('),end=text.indexOf('\n  private ',start);assert(start>=0);
 const exports={},events=[];let selected=[],reads=0,fail=false;
 const picker={DocumentSaveOptions:class{},DocumentPickerMode:{DOWNLOAD:1},DocumentViewPicker:class{async save(){return selected;}}};
 const fileIo={OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},open:async(path)=>{events.push(['open',path]);return{fd:4};},write:async(_fd,data)=>{if(fail)throw Error('disk');events.push(['write',data.byteLength]);return Math.min(3,data.byteLength);},close:async fd=>events.push(['close',fd]),unlink:async path=>events.push(['unlink',path])};
 vm.runInNewContext(ts.transpileModule('export class Host{'+text.slice(start,end)+'}',{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,picker,fileUri:{FileUri:class{constructor(){this.path='/selected';}}},fileIo,acceptsImageDownloadUrl,Date});
 const h=new exports.Host();Object.assign(h,{active:true,generation:1,imageDownloadBusy:false,imageDownloadSequence:0,showMessage:m=>events.push(['message',m]),imageDownload:{read:async()=>{reads++;return{data:new Uint8Array(png).buffer,extension:'png'};}}});
 await h.downloadImage(url);assert.equal(reads,0);selected=['uri'];await h.downloadImage(url);assert.equal(reads,1);assert.equal(events.filter(e=>e[0]==='write').length,3);assert.equal(events.at(-1)[1],'下载完成，请在所选目录查看');assert(!h.imageDownloadBusy);
 fail=true;await h.downloadImage(url);assert(events.some(e=>e[0]==='unlink'));assert.equal(events.at(-1)[1],'下载失败，请重试');
 console.log('Native image download: CDN/format/size/status restrictions, no credentials/redirect, cancellation, system directory picker, complete/partial file writes and cleanup passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
