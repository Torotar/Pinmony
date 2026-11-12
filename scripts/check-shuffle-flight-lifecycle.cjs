const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const tree = ts.createSourceFile('page.ts', page.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['shufflePhotoUrl', 'shuffleOverlayVisible', 'shuffleViewerVisible', 'shuffleRect', 'shuffleItemOrigin',
  'onShuffleViewerPresentedChanged', 'queueShuffleFlight', 'shuffleFlightImageComplete',
  'shuffleViewerContentVisible', 'shufflePageOpacity', 'startShuffleFlight', 'closeShuffleViewer'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(tree))) methods.push(node.getText(tree));
  ts.forEachChild(node, visit);
}
visit(tree);
assert.equal(methods.length, names.length);
const geometry = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace(/export /g, '');
const contain = vm.runInNewContext(ts.transpileModule(geometry + '; imageContainRect;', {compilerOptions:{target:99}}).outputText);
let timerId = 0;
const timers = new Map();
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
  {compilerOptions:{target:99}}).outputText, {imageContainRect:contain, Curve:{EaseOut:1,EaseInOut:2},
    setTimeout:fn=>{timers.set(++timerId,fn);return timerId;}, clearTimeout:id=>timers.delete(id)});
function tick() {
  const [id, callback] = timers.entries().next().value;
  timers.delete(id); callback();
}
const item = {id:'selected',imageUrl:'photo',cutoutUrl:'cutout',imageWidth:1000,imageHeight:1000,
  hitWidth:100,hitHeight:200,scale:1,offsetX:0,offsetY:0,rotation:25};
function fixture() {
  timers.clear();
  const x = new Host(), animations = [];
  Object.assign(x, {shuffleSelectedImage:'cutout',shuffleItems:[item],shuffleIndex:0,shuffleFullDetail:false,
    shuffleViewerPresented:true,shuffleFlightPreparing:true,shuffleFlightActive:false,shuffleFlightStarted:false,shuffleBackdropOpacity:0,
    shuffleFlightQueued:false,shuffleFlightRevision:1,shuffleLayoutAttempts:0,shuffleFlightItem:item.id,shuffleSourceOnCanvas:true,
    shuffleFlightSource:{x:120,y:430,width:40,height:80},shuffleFlightSourceRotation:25,
    shuffleRect:()=>({x:20,y:30,width:300,height:600}),videoActive:true,
    getUIContext:()=>({animateTo:(options, change)=>{animations.push(options);change();}})});
  return {x,animations};
}
const {x,animations} = fixture();
const captured = x.shuffleFlightSource;
x.onShuffleViewerPresentedChanged();
assert.equal(x.shuffleOverlayVisible(),false,'ready viewer stays hidden until source frame is installed');
assert.equal(animations.length,0);
tick();
assert.equal(x.shuffleFlightFrame,captured,'opening starts at the exact captured source');
assert.equal(x.shuffleFlightSource,captured,'ready callback must never remeasure and overwrite the source');
assert.equal(x.shuffleFlightTarget.height,600,'cutout aspect ratio takes precedence over the original photo');
assert.equal(x.shuffleFlightTarget.y,30);
assert.equal(x.shuffleOverlayVisible(),true);
assert.equal(x.shuffleBackdropOpacity,0,'opening source frame starts with transparent background');
assert.equal(x.shufflePageOpacity('neighbor'),0,'adjacent pages start transparent');
x.queueShuffleFlight(); x.queueShuffleFlight();
assert.equal(timers.size,1,'decode callbacks schedule only one source-frame commit');
assert.equal(animations.length,0,'animateTo cannot run in the decode callback frame');
tick(); assert.equal(animations.length,1);
assert.equal(x.shuffleBackdropOpacity,1,'background fades in within the photo entry animation');
assert.equal(x.shufflePageOpacity('neighbor'),1,'adjacent pages fade in in the same animation');
assert.equal(x.shufflePageOpacity(item.id),0,'selected page remains hidden behind the moving cutout');
assert.equal(animations[0].duration,320);
assert.equal(animations[0].curve,2,'photo and backdrop accelerate gradually from their committed source');
animations[0].onFinish();
assert.equal(x.shuffleFlightActive,false);
let backs=0; x.onBack=()=>backs++;
x.closeShuffleViewer(item.id);
assert.equal(x.shuffleFlightTarget,captured,'reverse flight uses the original unshifted rectangle');
assert.equal(x.shuffleFlightFrame.height,600,'closing also uses the cutout aspect ratio');
assert.equal(x.shuffleViewerContentVisible(),true,'closing keeps the existing photo and card while the new flight Image loads');
x.shuffleFlightImageComplete(0);
assert.equal(timers.size,0,'data-ready is insufficient to hide the rendered viewer');
assert.equal(x.shuffleViewerContentVisible(),true);
x.shuffleFlightImageComplete(1);
assert.equal(timers.size,1);
assert.equal(x.shuffleViewerContentVisible(),true,'viewer also covers the source-frame commit interval');
assert.equal(x.shuffleBackdropOpacity,1,'closing decode wait retains the existing background');
tick(); assert.equal(backs,0);
assert.equal(x.shuffleBackdropOpacity,0,'reverse photo flight fades background out in the same animation');
assert.equal(x.shufflePageOpacity('neighbor'),0,'adjacent pages fade out during reverse flight');
assert.equal(animations[1].duration,280);
assert.equal(x.shuffleViewerContentVisible(),false,'only animation start hands the viewer to the rendered flight');
animations[1].onFinish(); assert.equal(backs,1); assert.equal(x.shuffleViewerPresented,false);
x.closeShuffleViewer(item.id); assert.equal(backs,1,'late image click cannot pop the collage');
const strip=fixture();strip.x.shuffleSourceOnCanvas=false;
assert.equal(strip.x.shufflePhotoUrl(item),'cutout','thumbnail navigation always uses cutout artwork');
strip.x.onShuffleViewerPresentedChanged();tick();
assert.equal(strip.x.shuffleFlightRadius,12,'thumbnail opening commits the original rounded corners');
assert.equal(strip.x.shuffleFlightImage,'cutout');
assert.equal(strip.x.shuffleFlightTarget.width,300);
assert.equal(strip.x.shuffleFlightTarget.height,600,'thumbnail flight uses cutout aspect throughout');
strip.x.queueShuffleFlight();tick();
assert.equal(strip.x.shuffleFlightRadius,0,'opening animates corners to the square viewer within the photo animation');
strip.animations[0].onFinish();
assert.equal(strip.x.shuffleFlightImage,'cutout','opening completion retains the same cutout artwork');
strip.x.shuffleFlightImage='';
strip.x.closeShuffleViewer(item.id);
assert.equal(strip.x.shuffleFlightImage,'cutout','closing explicitly reinstalls the same cutout before mounting its Image');
assert.equal(strip.x.shuffleFlightTarget,strip.x.shuffleFlightSource,'return ends at the original thumbnail rectangle');
assert.equal(strip.x.shuffleFlightFrame.height,600,'return begins with the same cutout geometry as the viewer');
assert.equal(strip.x.shuffleFlightRadius,0,'return commits a square source before it moves');
strip.x.shuffleFlightImageComplete(1);tick();
assert.equal(strip.x.shuffleFlightRadius,12,'return animates back to the thumbnail radius');
assert(page.includes('.borderRadius(this.shuffleFlightRadius).clip(true)'),'animated radius clips the flight artwork');
assert(!page.includes('Image(this.shuffleFlightImage || this.shuffleSelectedImage)'),'flight can never silently replace original artwork with selected cutout');
assert(page.includes('Image(this.shufflePhotoUrl(item))'),'stationary viewer uses the same source as the thumbnail flight');
const stale=fixture().x; stale.onShuffleViewerPresentedChanged(); tick(); stale.queueShuffleFlight();
stale.shuffleFlightRevision++; tick(); assert.equal(stale.shuffleFlightStarted,false,'disposed generation cannot start motion');
const retry=fixture().x; let probes=0; retry.shuffleRect=()=>++probes===1?undefined:{x:0,y:0,width:300,height:600};
retry.onShuffleViewerPresentedChanged();tick();assert.equal(retry.shuffleOverlayVisible(),false);
tick();assert.equal(retry.shuffleFlightActive,true,'transient layout miss retries while viewer remains hidden');
const unavailable=fixture().x;unavailable.shuffleRect=()=>undefined;unavailable.onShuffleViewerPresentedChanged();
for(let i=0;i<12;i++)tick();
assert.equal(unavailable.shuffleFlightPreparing,false,'missing layout has a bounded fallback');
assert.equal(unavailable.shuffleFlightSource,undefined,'fallback cannot fly back to a stale rectangle');
const coordinates = new Host();let rootId='';
coordinates.traceId=7;
coordinates.getUIContext=()=>({px2vp:n=>n/3,getComponentUtils:()=>({getRectangleById:id=>{
  if(id==='source')return {size:{width:120,height:240},windowOffset:{x:90,y:600}};
  rootId=id;return {windowOffset:{x:30,y:60}};
}})});
const rect=coordinates.shuffleRect('source');assert.equal(rootId,'pinmony-photo-root-7');
assert.equal(rect.x,20);assert.equal(rect.y,180);assert.equal(rect.height,80);
coordinates.shuffleRect=()=>rect;
assert.equal(coordinates.shuffleItemOrigin(item,false).y,180,'thumbnail uses measured geometry without title inset');
coordinates.shuffleRect=()=>({x:10,y:20,width:100,height:100});
const cutoutOrigin=coordinates.shuffleItemOrigin(item,false);
assert.equal(cutoutOrigin.x,35,'narrow cutout starts inside the thumbnail letterbox');
assert.equal(cutoutOrigin.width,50);assert.equal(cutoutOrigin.height,100);
const bounded={...item,cutoutBounds:{x:.2,y:.1,width:.5,height:.8}};
const subject=coordinates.shuffleItemOrigin(bounded,false);
assert.equal(subject.x,30);assert.equal(subject.y,30);
assert.equal(subject.width,50);assert.equal(subject.height,80,'subject starts at its actual original-image bounds, not fitted to the whole thumbnail');
coordinates.shuffleRect=()=>({x:10,y:20,width:100,height:100});
const coverSubject=coordinates.shuffleItemOrigin({...bounded,imageWidth:2000,imageHeight:1000},false);
assert.equal(coverSubject.x,0,'bounds inherit original Cover horizontal cropping');
assert.equal(coverSubject.width,100);assert.equal(coverSubject.height,80);
coordinates.shuffleRect=()=>({x:10,y:20,width:200,height:200});
const scaledSubject=coordinates.shuffleItemOrigin(bounded,false);
assert.equal(scaledSubject.width,subject.width*2);assert.equal(scaledSubject.height,subject.height*2,'bounds scale with the measured thumbnail');
assert.match(page,/Image\(item.imageUrl\).width\(this.shuffleThumbnailWidth\(item\)\)[\s\S]*?objectFit\(ImageFit.Cover\)/,'thumbnail preserves the original artwork and layout independently of the cutout flight');
const destination=page.slice(page.indexOf('private detailDestination()'),page.indexOf('\n  build()'));
assert(page.includes('.hideTitleBar(false)'),'viewer must not relayout the HDS title bar');
assert(page.indexOf('this.shuffleOverlay()')>page.indexOf('\n  build()'),'viewer lives outside HDS content');
assert(!page.includes('shuffleTitleInset'),'no guessed title height in coordinate transforms');
assert(page.includes('@State private shuffleFlightStarted: boolean'),'handoff visibility updates reactively at animation start');
assert(page.includes('.opacity(this.shufflePageOpacity(item.id))'),'each adjacent page owns its animated opacity');
assert(page.includes('.opacity(this.shuffleViewerVisible() && !this.shuffleFlightPreparing ? 1 : 0)'),'viewer container stays available for adjacent-page fades during the flight');
assert(!page.includes('.opacity(this.shuffleOverlayVisible() ? 1 : 0)'),'outer overlay must not abruptly gate the animated backdrop');
const overlay=page.slice(page.indexOf('private shuffleOverlay()'),page.indexOf('private detailContent()'));
const underlying=page.slice(page.indexOf('private detailContent()'),page.indexOf('private videoRetryNotice()'));
assert(overlay.includes("this.shuffleImageReady('backdrop', backdropUrl)"),'actual displayed background owns source-checked readiness');
assert(!underlying.includes("this.shuffleImageReady('backdrop'"),'underlying image cannot prematurely unlock the overlay fade');
assert.match(page,/Scroll\(\) \{ this.shuffleSelectedCard\(item\) \}.width\('100%'\).height\(188\)\s*\.opacity\(this.shuffleBackdropOpacity\)/,'information cards fade continuously rather than disappearing at flight start');
assert.match(overlay,/\.blur\(80 \* this.shuffleBackdropOpacity\)\s*\.opacity\(0\.5 \* this.shuffleBackdropOpacity \* this.shuffleBackdropImageOpacity\)/,'filter and alpha follow flight progress, including the late background reveal');
assert(!underlying.includes('.blur(80)'), 'retained collage cannot introduce a second full-strength background');
assert(page.includes('.backgroundEffect({radius:28 * this.shuffleBackdropOpacity,'), 'card material blur also follows the flight instead of mounting at full strength');
assert(!page.includes('.opacity(this.shuffleOverlayVisible() ? 0 : this.entryOpacity)'), 'underlying page stays drawn beneath transparent backdrop');
console.log('Shuffle flight: hidden preparation, stable source, pixel conversion, cutout aspect, deferred decode, reverse handoff and stale/layout guards passed');
