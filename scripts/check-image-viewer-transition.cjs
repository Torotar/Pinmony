const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const geometry=fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets','utf8').replace(/^import .*;\r?\n/gm,'').replace(/export /g,'');
const imageContainRect=vm.runInNewContext(ts.transpileModule(geometry+';imageContainRect;', {compilerOptions:{target:99}}).outputText);
const measureImageFlightOrigin=vm.runInNewContext(ts.transpileModule(geometry+';measureImageFlightOrigin;', {compilerOptions:{target:99}}).outputText);
const transformed=measureImageFlightOrigin({px2vp:n=>n/2,
  getComponentUtils:()=>({getRectangleById:()=>({size:{width:164,height:220},windowOffset:{x:100,y:200}})}),
  getFrameNodeById:id=>({getPositionToWindowWithTransform:()=>id==='source'?{x:50,y:280}:{x:0,y:48}})},'source','root');
assert.equal(transformed.y,232,'sheet visual translation must be included rather than using layout windowOffset');
assert.equal(transformed.width,82,'FrameNode positions are vp; component sizes are px');
const wide=imageContainRect(360,720,800,400);assert.equal(wide.width,360);assert.equal(wide.height,180);assert.equal(wide.y,270);
const tall=imageContainRect(720,360,400,800);assert.equal(tall.width,180);assert.equal(tall.x,270);
const source=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyImageViewer.ets','utf8');const sf=ts.createSourceFile('viewer.ts',source.replace(/\bstruct\b/g,'class'),99,true);
const names=['initializePhotos','aboutToAppear','aboutToDisappear','imageDecoded','beginTransition','containRect','sourceRect','sourceRadius','setFrame','transitionChanged'];const methods=[];
function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(sf)))methods.push(n.getText(sf));ts.forEachChild(n,visit);}visit(sf);
const timers=[],delays=[];const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;', {compilerOptions:{target:99}}).outputText,{imageContainRect,PinmonyRuntimeLog:{info(){}},curves:{springMotion:()=>0},setTimeout:(fn,delay)=>{timers.push(fn);delays.push(delay);return timers.length;},clearTimeout:()=>{}});
const x=new Host(),animations=[];let closed=0,ready=0;
Object.assign(x,{origin:{x:12,y:90,width:336,height:400},detail:{imageWidth:800,imageHeight:400},viewportWidth:360,viewportHeight:720,transitionVersion:0,previewReady:false,originalReady:false,viewportMeasured:true,naturalWidth:0,naturalHeight:0,closing:false,onClosed:()=>closed++,onReady:()=>ready++,stopInertia:()=>{},getUIContext:()=>({animateTo:(o,fn)=>{animations.push(o);fn();}})});
x.aboutToAppear();assert.equal(x.frameY,90);x.beginTransition();assert.equal(ready,0);x.imageDecoded(-1,false);assert.equal(ready,0);x.imageDecoded(0,false,800,400);assert.equal(ready,0,'data-ready must retain the detail photo');assert.equal(x.previewReady,true,'preview is exposed at source so it can render');assert.equal(timers.length,0);x.imageDecoded(1,false,800,400);assert.equal(ready,1,'only a rendered preview permits hiding the detail photo');assert.equal(delays.at(-1),32,'commit the rendered source before motion');timers.shift()();assert.equal(x.frameHeight,180);assert.equal(x.frameRadius,0);
x.imageDecoded(1,true,800,400);assert.equal(x.originalReady,false,'original waits for opening animation');animations.at(-1).onFinish();assert.equal(x.originalReady,true);
const page=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');assert(!page.includes('opacity(this.viewerMounted ? 0 : 1)'), 'source image stays visible until decoded handoff');
x.scaleValue=3;x.dx=100;x.closing=true;x.transitionChanged();const old=animations.at(-1);assert.equal(x.scaleValue,1);assert.equal(x.dx,0);assert.equal(x.frameY,206);assert.equal(x.frameHeight,168);assert.equal(x.frameRadius,0,'letterboxed image remains square during return');
const originalOrigin=x.origin;x.origin={x:0,y:0,width:336,height:168};x.originRadius=18;assert.equal(x.sourceRadius(),18,'filled rounded source retains its corners');x.originRadius=10;assert.equal(x.sourceRadius(),10,'comment source retains its actual corner radius');x.originRadius=18;x.origin=originalOrigin;
assert.equal(x.frameY + x.frameHeight / 2, x.origin.y + x.origin.height / 2, 'close targets actual contained photo bounds rather than letterboxed frame');
const carousel=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets','utf8');
assert.match(carousel,/\.id\(this.sourceId\)\.opacity\(this.imageHidden \? 0 : 1\)/);
assert.match(page,/sourceId: 'pinmony-photo-source-' \+ this.traceId.toString\(\)/);
assert(!page.includes(".id('pinmony-photo-source-' + this.traceId.toString()).opacity(this.viewerMounted && this.viewerImageReady ? 0 : 1)\n          } else if"), 'carousel indicator must not be part of measured or hidden photo frame');
x.closing=false;x.transitionChanged();old.onFinish();assert.equal(closed,0,'interrupted close cannot remove reopened viewer');
x.closing=true;x.transitionChanged();animations.at(-1).onFinish();assert.equal(closed,1);
x.transitionChanged();const late=animations.at(-1);x.aboutToDisappear();late.onFinish();assert.equal(closed,1,'disposed transition cannot close newer page');
console.log('Image transition: contain geometry, decode handoff, reverse/zoom reset, rapid reopen and stale disposal passed');

function awaitingOriginal() {
 const host=new Host();
 Object.assign(host,{origin:{x:12,y:90,width:336,height:400},detail:{imageWidth:800,imageHeight:400},viewportWidth:360,viewportHeight:720,
   transitionVersion:0,previewReady:true,previewRendered:true,originalReady:false,originalDecoded:false,originalDataReady:false,
   viewportMeasured:true,naturalWidth:800,naturalHeight:400,closing:false,transitionStarted:true,transitioning:false,
   stopInertia(){},getUIContext:()=>({animateTo:(opts,fn)=>{animations.push(opts);fn();}}),onReady(){throw Error('upgrade must not restart entry');}});
 host.aboutToAppear();return host;
}
const upgrade=awaitingOriginal();upgrade.imageDecoded(0,true,800,400);
assert.equal(upgrade.originalDataReady,true,'data-ready exposes the full image above the retained preview');
assert.equal(upgrade.originalReady,false,'data-ready must not hide the rendered preview');assert.equal(upgrade.originalDecoded,false);
upgrade.imageDecoded(1,true,800,400);assert.equal(upgrade.originalReady,true,'full image takes over only after render completion');
const during=awaitingOriginal();during.transitioning=true;during.imageDecoded(0,true,800,400);
assert.equal(during.originalReady,false);assert.equal(during.originalDecoded,false);
during.getUIContext=()=>({animateTo:(opts,fn)=>{animations.push(opts);fn();}});during.transitionChanged();animations.at(-1).onFinish();
assert.equal(during.originalReady,false,'animation completion cannot turn data readiness into render readiness');
during.imageDecoded(1,true,800,400);assert.equal(during.originalReady,true);
const originalOnly=awaitingOriginal();originalOnly.transitionStarted=false;originalOnly.previewReady=false;originalOnly.previewRendered=false;let originalHandoffs=0;originalOnly.onReady=()=>originalHandoffs++;
originalOnly.imageDecoded(0,true,800,400);assert.equal(originalHandoffs,0);assert.equal(originalOnly.originalDataReady,true);
originalOnly.imageDecoded(1,true,800,400);assert.equal(originalHandoffs,1,'original-only path also waits for render');timers.shift()();
const disposedUpgrade=awaitingOriginal();disposedUpgrade.aboutToDisappear();disposedUpgrade.imageDecoded(1,true,800,400);assert.equal(disposedUpgrade.originalReady,false);
console.log('Viewer handoff: rendered preview before source hide, rendered original before preview hide, mid-animation data-only upgrade, original-only and disposed callbacks passed');

// Narrow side fill uses the same rounded-photo policy as the detail source.
// Exercise production transitionChanged so the radius shares the photo animation.
const roundedReturn=awaitingOriginal(); roundedReturn.originRadius=18;
roundedReturn.naturalWidth=300; roundedReturn.naturalHeight=400;
roundedReturn.origin={x:12,y:90,width:324,height:400};
assert.equal(roundedReturn.sourceRadius(),18,'12vp side fill must retain the rounded detail photo');
roundedReturn.frameRadius=18;
roundedReturn.transitionChanged();
assert.equal(roundedReturn.frameRadius,0,'opening ends at square full-screen artwork');
animations.at(-1).onFinish();
let returnRadiusBefore=-1,returnRadiusAfter=-1;
roundedReturn.getUIContext=()=>({animateTo:(options,change)=>{
  returnRadiusBefore=roundedReturn.frameRadius;
  change(); returnRadiusAfter=roundedReturn.frameRadius; animations.push(options);
}});
roundedReturn.closing=true; roundedReturn.transitionChanged();
assert.equal(returnRadiusBefore,0,'return starts square');
assert.equal(returnRadiusAfter,18,'return animates to rounded corners inside the geometry transaction');
assert.equal(animations.at(-1).duration,400,'existing reverse motion timing is retained');
roundedReturn.origin.width=336;
assert.equal(roundedReturn.sourceRadius(),0,'18vp side fill remains square at the detail threshold');
roundedReturn.origin.width=335.8;
assert.equal(roundedReturn.sourceRadius(),18,'side fill just below 18vp is rounded');
roundedReturn.origin.width=324;roundedReturn.originRadius=0;
assert.equal(roundedReturn.sourceRadius(),0,'an explicitly square source remains square');
roundedReturn.origin={x:0,y:0,width:0,height:0};roundedReturn.originRadius=18;
assert.equal(roundedReturn.sourceRadius(),0,'missing geometry cannot invent rounded source corners');
assert.match(source,/\.borderRadius\(this\.frameRadius\)\.clip\(this\.transitioning\)/,'animated radius clips the moving photo');
console.log('Narrow blur viewer: square-to-rounded return in geometry animation, opening, threshold, square source and missing geometry passed');

const detailFile=ts.createSourceFile('detail.ts',page.replace(/\bstruct\b/g,'class'),99,true);let prepare='';
function findPrepare(n){if(ts.isMethodDeclaration(n)&&n.name.getText(detailFile)==='prepareViewerReturn')prepare=n.getText(detailFile);ts.forEachChild(n,findPrepare);}findPrepare(detailFile);
const ReturnHost=vm.runInNewContext(ts.transpileModule('class ReturnHost {'+prepare+'} ReturnHost;',{compilerOptions:{target:99}}).outputText);
for(const [top,height,offset,reset] of [[-40,700,120,true],[-900,700,920,false],[80,700,0,false],[800,300,200,false]]){
 const host=new ReturnHost();let scroll=offset,reported=-1;
 Object.assign(host,{viewportHeight:720,displayedDetail:()=>({pinUrl:'pin'}),measureViewerOrigin:()=>({x:18,y:top,width:324,height}),detailScroller:{offset:()=>({yOffset:scroll}),scrollTo:o=>{assert.equal(o.animation,false);scroll=o.yOffset;}},onScrollPosition:(_pin,y)=>reported=y});
 const target=host.prepareViewerReturn();assert.equal(scroll,reset?0:offset);assert.equal(target.y,reset?top+offset:top);assert.equal(reported,reset?0:-1);
}
console.log('Viewer return: visible photo resets to top with matching destination; offscreen and unscrolled positions retained passed');
