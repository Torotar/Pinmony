const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchView.ets', 'utf8');
const sf = ts.createSourceFile('search.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['beginTransition', 'closeTransition', 'scheduleReturnPhoto', 'resultSheetDisappeared', 'finishReturn', 'runTransition', 'publishPhotoFrame', 'aboutToAppear', 'aboutToDisappear', 'photoWidth', 'photoHeight', 'photoX', 'photoY'];
const methods = [];
function visit(n) { if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(sf))) methods.push(n.getText(sf)); ts.forEachChild(n, visit); }
visit(sf);
const timers = [], timerDelays = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {
  compilerOptions: { target: 99 }
}).outputText, { PinmonyRuntimeLog: {info(){}}, Curve: { EaseOut: 0 }, setTimeout: (fn,delay) => { timers.push(fn);timerDelays.push(delay); return timers.length; }, clearTimeout: () => {} });
const animations = []; let ready = 0, closed = 0;
const x = new Host();
Object.assign(x, { animatePhoto: true, alive: true, measured: true, decoded: false, started: false,
  widthValue: 360, heightValue: 720, imageWidth: 600, imageHeight: 800, originX: 18, originY: 200,
  originWidth: 324, originHeight: 432, originRadius: 18, closing: false, transitionVersion: 0, sheetVisible: false,
  onTransitionReady: () => ready++, onTransitionClosed: () => closed++, getUIContext: () => ({
    px2vp: n => n, getComponentUtils: () => ({ getRectangleById: () => ({ windowOffset: { x: 0, y: 100 } }) }),
    animateTo: (opts, fn) => { animations.push(opts); fn(); }
  }) });
x.beginTransition(); assert.equal(ready, 0, 'wait for decoded handoff');
x.decoded = true; x.beginTransition(); assert.equal(ready, 1); assert.equal(x.frameY, 100);
timers.shift()(); assert.equal(x.frameWidth, 324); assert.equal(x.frameY, 0); assert.equal(x.backdrop, 1);
assert.equal(x.sheetVisible, true, 'result sheet opens concurrently with photo flight');
assert.equal(animations.at(-1).duration, 240);
x.closing = true; x.closeTransition(); timers.shift()(); const oldClose = animations.at(-1);
assert.equal(x.frameY, 100); assert.equal(x.frameRadius, 18); assert.equal(x.backdrop, 0);
assert.equal(animations.at(-1).duration, 200);
x.closing = false; x.closeTransition(); oldClose.onFinish(); assert.equal(closed, 0, 'reopen cancels stale close');
animations.at(-1).onFinish(); assert.equal(x.sheetVisible, true); assert.equal(x.chrome, 1);
x.closing = true; x.closeTransition(); timers.shift()(); animations.at(-1).onFinish(); assert.equal(closed, 1);
x.runTransition(false); const late = animations.at(-1); x.aboutToDisappear(); late.onFinish();
assert.equal(closed, 1); assert.equal(x.alive, false);
const early = new Host(); Object.assign(early, { animatePhoto: true, alive: true, closing: true, started: false,
  onTransitionClosed: () => closed++ }); early.closeTransition(); assert.equal(closed, 2, 'back before decode cannot trap page');
console.log('Image search transition: decode handoff, window coordinates, sheet sequencing, reverse, rapid reopen, early back and stale callbacks passed');

const completed = source.match(/\.onComplete\(\(event\) => \{([\s\S]*?)\n        \}\)/);
assert(completed,'flight image completion handler');
for(const status of [0,1]) {
 const host={decoded:false,starts:0,beginTransition(){this.starts++;}};
 const callback=new Function('event','PinmonyRuntimeLog',ts.transpile(completed[1]));
 callback.call(host,{loadingStatus:status},{info(){}});
 assert(host.decoded);assert.equal(host.starts,1,'data-ready and render-ready both unblock transition');
}
console.log('Image search readiness: data-ready unblocks hidden flight without waiting for render passed');

const detailPage=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
assert.match(detailPage,/PinmonyVisualSearchView\(\{ pin: this\.displayedDetail\(\)\.pinUrl, imageUrl: this\.displayedDetail\(\)\.imageUrl \|\| this\.displayedDetail\(\)\.originalImageUrl/,'search entry must reuse the displayed image before requesting original size');
console.log('Visual search entry reuses displayed detail image passed');

// HDS changes its content origin when the search title returns to the detail
// title. The moving photo must remain in the stable outer window plane.
let searchRootPx = 200;
const frames = [], flights = [];
const moving = new Host();
Object.assign(moving, { animatePhoto: true, alive: true, measured: true, decoded: true, started: false,
  widthValue: 360, heightValue: 720, imageWidth: 600, imageHeight: 800, originX: 18, originY: 200,
  originWidth: 324, originHeight: 432, originRadius: 18, closing: false, transitionVersion: 0,
  onPhotoFrame: (...frame) => frames.push(frame), onPhotoFlight: active => flights.push(active),
  getUIContext: () => ({ px2vp: n => n / 2,
    getComponentUtils: () => ({ getRectangleById: () => ({ windowOffset: { x: 0, y: searchRootPx } }) }),
    animateTo: (opts, fn) => { animations.push(opts); fn(); } }) });
moving.beginTransition(); assert.equal(frames.at(-1)[1], 200, 'opening starts at original window Y');
timers.shift()(); assert.equal(frames.at(-1)[1], 100, 'search target adds current HDS origin');
animations.at(-1).onFinish(); assert.equal(flights.at(-1), false, 'stationary crop image returns to the search component');
searchRootPx = 0; moving.closing = true; moving.closeTransition();
assert.equal(frames.at(-1)[1], 100, 'handoff first commits the last visible search photo frame');
timers.shift()();
assert.equal(frames.at(-1)[1], 200, 'close endpoint remains at original window Y after HDS moves up 100vp');
assert.equal(flights.at(-1), true); assert.equal(moving.photoFlightActive, true);
const sfDetail = ts.createSourceFile('detail.ts', detailPage.replace(/\bstruct\b/g, 'class'), 99, true);
let update;
function findUpdate(n) { if (ts.isMethodDeclaration(n) && n.name.getText(sfDetail) === 'updateSearchFlightFrame') update = n.getText(sfDetail); ts.forEachChild(n, findUpdate); }
findUpdate(sfDetail); assert(update);
const Detail = vm.runInNewContext(ts.transpileModule('class Detail {' + update + '} Detail;', {compilerOptions:{target:99}}).outputText, { Curve: { EaseOut: 0 } });
const detail = new Detail(); detail.traceId = 1; const hostAnimations=[]; detail.getUIContext = () => ({ animateTo: (opts,fn) => { hostAnimations.push(opts); fn(); }, px2vp: n => n / 2,
  getComponentUtils: () => ({ getRectangleById: () => ({ windowOffset: { x: 8, y: 60 } }) }) });
detail.updateSearchFlightFrame(...frames.at(-1));
assert.equal(detail.searchFlightFrame.y, 170); assert.equal(detail.searchFlightFrame.y + 30, 200);
assert.equal(detail.searchFlightFrame.x + 4, 18); assert.equal(detail.searchFlightFrame.height, 432);
assert.match(detailPage, /if \(this.searchMounted\) \{\s*\/\/[^\n]*\n\s*\/\/[^\n]*\n\s*Stack\(\{ alignContent: Alignment.TopStart \}\) \{\s*Stack\(\{ alignContent: Alignment.TopStart \}\) \{\s*Image\(this.displayedDetail/,
  'flight Image remains mounted in the outer page plane for reverse handoff');
console.log('Visual search return: moving HDS origin, stable window endpoint, density conversion and stationary crop handoff passed');

assert.equal(hostAnimations.at(-1).duration, 200, 'outer photo bounds animate in their owning UI context');
let synchronizedClosed=0;
const waiting = new Host(); Object.assign(waiting, moving, { alive:true, started:true, closing:true, resultSheetMounted:true, sheetVisible:true, transitionVersion:0, backdrop:1,
  onTransitionClosed:()=>synchronizedClosed++ });
const beforeWait=animations.length; waiting.closeTransition();
assert.equal(waiting.sheetVisible,true,'native Sheet stays until source frame is committed');
assert.equal(animations.length,beforeWait);
timers.shift()();
assert.equal(waiting.sheetVisible,false,'Sheet starts dismissal in the same callback as photo motion');
assert.equal(animations.length,beforeWait+1,'photo starts before native Sheet disappearance');
assert.equal(animations.at(-1).duration,200,'mounted Sheet must not stretch the original photo return timing');
assert.equal(frames.at(-1)[6],0,'selection fades to transparent in the photo transaction');
const togetherFinish=animations.at(-1).onFinish; togetherFinish();
assert.equal(synchronizedClosed,0,'retain the completed photo until native Sheet actually disappears');
waiting.resultSheetDisappeared(); assert.equal(synchronizedClosed,1);
waiting.resultSheetDisappeared(); assert.equal(synchronizedClosed,1,'completion is idempotent');
const sheetFirst=new Host(); Object.assign(sheetFirst,moving,{alive:true,started:true,closing:true,resultSheetMounted:true,sheetVisible:true,transitionVersion:0,onTransitionClosed:()=>synchronizedClosed++});
sheetFirst.closeTransition(); timers.shift()(); const photoLast=animations.at(-1).onFinish;
sheetFirst.resultSheetDisappeared(); assert.equal(synchronizedClosed,1,'early Sheet disappearance must not remove moving photo');
photoLast();assert.equal(synchronizedClosed,2);
const reopening=new Host(); Object.assign(reopening,moving,{alive:true,started:true,closing:true,resultSheetMounted:true,sheetVisible:true,transitionVersion:0});
reopening.closeTransition(); reopening.closing=false; const beforeReopen=animations.length; reopening.closeTransition();
timers.shift()(); assert.equal(animations.length,beforeReopen,'reopen invalidates pending close-frame callback');
reopening.resultSheetDisappeared(); assert.equal(reopening.sheetVisible,true); assert.equal(animations.at(-1).duration,240);
assert(!source.includes('visibility(this.closing'),'selection must not disappear directly on close');
assert.match(source,/onPhotoSelection\?\.\(this.crop\)/,'flight uses current user selection');
assert.match(detailPage,/searchFlightChrome = chrome/,'host opacity changes in the same transaction as photo bounds');
assert.match(detailPage,/PinmonyImageSearchSelection\(\{ photoWidth: this.searchFlightBaseWidth, photoHeight: this.searchFlightBaseHeight/,'selection and image keep fixed local geometry during flight');
assert.match(source,/PinmonyImageSearchSelection\(\{ photoWidth: this.photoWidth\(\)/,'stationary and flying selection share artwork');
console.log('Visual search close: concurrent Sheet/photo/selection fade, completion ordering, stale reopen and shared crop artwork passed');

// The photo and all four mask pieces must share one render transform. Updating
// their layout dimensions separately lets child props snap to the destination
// while the Image is still interpolating (visible as top/bottom protrusions).
detail.updateSearchFlightFrame(18,200,324,432,18,0,0);
assert.equal(detail.searchFlightBaseWidth,324);assert.equal(detail.searchFlightBaseHeight,432);
detail.updateSearchFlightFrame(36,120,288,384,0,240,1);
assert.equal(detail.searchFlightBaseWidth,324);assert.equal(detail.searchFlightBaseHeight,432,'animation must not relayout selection artwork');
assert.match(detailPage,/\.scale\(\{ x: this.searchFlightFrame.width \/ this.searchFlightBaseWidth,\s*y: this.searchFlightFrame.height \/ this.searchFlightBaseHeight, centerX: 0, centerY: 0 \}\)/);
assert.match(detailPage,/\.translate\(\{ x: this.searchFlightFrame.x, y: this.searchFlightFrame.y \}\)/);
assert.match(detailPage,/\.scale\(\{ x: this.searchFlightFrame.width \/ this.searchFlightBaseWidth,[\s\S]*?centerY: 0 \}\)\s*\}.width\(this.searchFlightFrame.width\).height\(this.searchFlightFrame.height\)\s*\.borderRadius\(this.searchFlightRadius\).clip\(true\)/,
 'a separate display-sized clip animates radius while fixed image/selection artwork shares one inner transform');
for(const p of [0,.1,.25,.5,.75,.9,1]) {
 const w=324+(288-324)*p,h=432+(384-432)*p,sx=w/detail.searchFlightBaseWidth,sy=h/detail.searchFlightBaseHeight;
 const crop={x:.1,y:.1,w:.8,h:.8};
 assert(Math.abs(detail.searchFlightBaseWidth*sx-w)<1e-9);
 assert(Math.abs((crop.y+crop.h)*detail.searchFlightBaseHeight*sy+((1-crop.y-crop.h)*detail.searchFlightBaseHeight*sy)-h)<1e-9,'bottom mask ends at the photo edge at every sampled frame');
}
assert.equal((detailPage.match(/enableComponentSafeArea: false/g)||[]).length,2,'search and detail must retain the same HDS content origin');
assert.match(detailPage,/\}\)\s*\}.width\('100%'\).height\('100%'\).padding\(\{ top: this.titleContentInset\(\) \}\)/,'only the search child owns its title inset');
console.log('Visual search geometry: fixed artwork, shared scale/translation, sampled mask edges and stable detail safe area passed');
assert.match(source,/Stack\(\{ alignContent: Alignment.TopStart \}\) \{\s*Image\(this.imageUrl\)\.width\(this.photoWidth\(\)\)/,
  'local flight keeps photo artwork at its fixed destination size');
assert.match(source,/\.scale\(\{ x: this.animatePhoto \? this.frameWidth \/ this.photoWidth\(\) : 1,/,
  'local photo and crop selection share the flight transform');
assert(source.includes('this.sourceSelectionBorder ? 2 * (1 - this.chrome) : 0'),
  'history selection border fades with crop chrome in both directions');

const selectionSource=fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchSelection.ets','utf8');
const selectionAst=ts.createSourceFile('selection.ts',selectionSource.replace(/\bstruct\b/g,'class'),99,true);
const selectionMethods=[];
function findSelectionMethods(n){if(ts.isMethodDeclaration(n)&&['selectionRadius','cornerSize','cornerX','cornerY','maskCommands'].includes(n.name.getText(selectionAst)))selectionMethods.push(n.getText(selectionAst));ts.forEachChild(n,findSelectionMethods);}
findSelectionMethods(selectionAst);
const Selection=vm.runInNewContext(ts.transpileModule('class Selection {'+selectionMethods.join('\n')+'} Selection;',{compilerOptions:{target:99}}).outputText);
const artwork=new Selection();Object.assign(artwork,{photoWidth:300,photoHeight:450,crop:{x:.1,y:.1,w:.8,h:.8}});
let selectionDensity=1;
artwork.getUIContext=()=>({vp2px:n=>n*selectionDensity});
assert.equal(artwork.selectionRadius(),12);
assert.equal(artwork.maskCommands(),'M 0 0 H 300 V 450 H 0 Z M 42 45 A 12 12 0 0 0 30 57 V 393 A 12 12 0 0 0 42 405 H 258 A 12 12 0 0 0 270 393 V 57 A 12 12 0 0 0 258 45 Z','four counter-clockwise arcs cut the rounded aperture from the clockwise outer mask');
for(const density of [1.5,2,3,3.5]) {
 selectionDensity=density;
 const numbers=artwork.maskCommands().match(/\d+(?:\.\d+)?/g).map(Number);
 assert.equal(numbers[2],300*density,'mask covers the full physical photo width');
 assert.equal(numbers[3],450*density,'mask covers the full physical photo height');
 const arcs=[...artwork.maskCommands().matchAll(/A ([\d.]+) ([\d.]+) 0 0 0 ([\d.]+) ([\d.]+)/g)];
 assert.equal(arcs.length,4);
 for(const arc of arcs) assert.equal(Number(arc[1]),12*density,'rounded aperture uses the same physical radius as the vp border');
 assert.equal(numbers[5],42*density,'aperture x follows the full-size selection');
 assert.equal(numbers[6],45*density,'aperture y follows the full-size selection');
}
selectionDensity=1;
artwork.crop={x:0,y:0,w:.08,h:1};artwork.photoWidth=100;
assert.equal(artwork.selectionRadius(),4*12/28,'small selections scale their aperture with the handles');
for(const [width,height,crop] of [
 [300,450,{x:.1,y:.1,w:.8,h:.8}],
 [24,800,{x:.1,y:.1,w:.8,h:.8}],
 [800,24,{x:.1,y:.1,w:.8,h:.8}],
 [100,100,{x:0,y:0,w:.08,h:.08}],
 [100,100,{x:.92,y:.92,w:.08,h:.08}]
]) {
 Object.assign(artwork,{photoWidth:width,photoHeight:height,crop});
 const size=artwork.cornerSize();
 assert(size<=28 && size<=crop.w*width/2 && size<=crop.h*height/2,'opposing handles never overlap');
 for(let index=0;index<4;index++) {
  const right=index===1||index===3,bottom=index>1;
  assert(Math.abs(artwork.cornerX(index)+size*(right?25:3)/28-(crop.x+(right?crop.w:0))*width)<1e-9,'rotated SVG vertical stroke stays on selection edge');
  assert(Math.abs(artwork.cornerY(index)+size*(bottom?25:3)/28-(crop.y+(bottom?crop.h:0))*height)<1e-9,'rotated SVG horizontal stroke stays on selection edge');
 }
}
const hitBody=source.match(/const cornerX: number = ([\s\S]*?)\n      \}\)/)[0].replace(/\n      \}\)$/,'');
const hit= new Function('x','y','left','top','right','bottom',ts.transpile(hitBody));
for(const [x,y,expected] of [[0,0,0],[8,0,1],[0,8,2],[8,8,3],[4,4,0]]) {
 const target={dragCorner:-2};hit.call(target,x,y,0,0,8,8);
 assert.equal(target.dragCorner,expected,'overlapping 44vp hit targets choose the nearest corner');
}
const interior={dragCorner:-2};hit.call(interior,50,50,0,0,100,100);assert.equal(interior.dragCorner,-1);
const outside={dragCorner:-2};hit.call(outside,150,150,0,0,100,100);assert.equal(outside.dragCorner,-2);
assert.match(selectionSource,/Path\(\).commands\(this.maskCommands\(\)\)/);
assert.match(selectionSource,/borderRadius\(this.selectionRadius\(\)\)/,'mask and border share one radius');
assert(!selectionSource.includes('Rect().fill'),'rectangular mask pieces must not leave square transparent corners');
console.log('Visual search selection: rounded aperture, opposite winding and minimum crop radius passed');
for(const uploadedPhoto of [false,true]) {
 let starts=0;const initialHost=new Host();
 Object.assign(initialHost,{uploadedPhoto,animatePhoto:true,closing:false,crop:{x:.1,y:.1,w:.8,h:.8},onSearch(){starts++;}});
 const timerIndex=timers.length;initialHost.aboutToAppear();
 assert.equal(starts,0,'dispatch stays outside the component creation stack');
 assert.equal(timerDelays.at(-1),0,'initial request has no fixed 100ms delay');
 timers[timerIndex]();assert.equal(starts,uploadedPhoto?0:1,'uploaded photo keeps its existing upload flow');
 const lateHost=new Host();Object.assign(lateHost,{uploadedPhoto,animatePhoto:true,onSearch(){throw Error('late request');}});
 const lateIndex=timers.length;lateHost.aboutToAppear();lateHost.aboutToDisappear();timers[lateIndex]();
}
console.log('Image search startup: zero-delay dispatch, upload ownership and early-close cancellation passed');

assert(detailPage.includes('originRadius: this.detailPhotoRadius()'), 'search uses the actual adaptive detail corner radius');
for (const radius of [0,18,26]) {
 const radiusFrames=[];
 const rounded=new Host();
 Object.assign(rounded,{...moving,alive:true,started:false,closing:false,originRadius:radius,
   onPhotoFrame:(...frame)=>{radiusFrames.push(frame);detail.updateSearchFlightFrame(...frame);}});
 const queued=timers.length;rounded.beginTransition();
 assert.equal(rounded.frameRadius,radius,'source frame starts at actual detail radius');
 assert.equal(radiusFrames[0][4],radius);assert.equal(detail.searchFlightRadius,radius);
 timers.splice(queued,1)[0]();
 assert.equal(rounded.frameRadius,0);assert.equal(detail.searchFlightRadius,0);
 assert.equal(hostAnimations.at(-1).duration,240,'opening radius shares the frame animation duration');
 rounded.runTransition(true);
 assert.equal(rounded.frameRadius,radius);assert.equal(detail.searchFlightRadius,radius);
 assert.equal(radiusFrames.at(-1)[4],radius,'return restores square or rounded source without a hardcoded endpoint');
 assert.equal(hostAnimations.at(-1).duration,200,'return radius shares the frame animation duration');
 rounded.alive=false;
}
console.log('Visual search corners: adaptive square/rounded endpoints, display-space clip and shared 240ms/200ms frame transactions passed');
