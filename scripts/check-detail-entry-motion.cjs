const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailEntryMotion.ets','utf8');
const sf=ts.createSourceFile('motion.ts',source.replace(/\bstruct\b/g,'class'),99,true), methods=[];
const names=['aboutToAppear','aboutToDisappear','target','heroVisible','begin','closeChanged','move'];
function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(sf)))methods.push(n.getText(sf));ts.forEachChild(n,visit);} visit(sf);
const geometry=fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets','utf8').replace(/export /g,'');
const imageContainRect=vm.runInNewContext(ts.transpileModule(geometry+';imageContainRect;',{compilerOptions:{target:99}}).outputText);
const timers=[],animations=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:99}}).outputText,
 {imageContainRect,PinmonyRuntimeLog:{info:()=>{}},Curve:{EaseOut:0},setTimeout:fn=>{timers.push(fn);return timers.length;},clearTimeout:()=>{}});
let opened=0,closed=0,revealed=0;
function fixture(){const x=new Host(); Object.assign(x,{photo:{x:20,y:130,width:160,height:200},targetId:'target',rootId:'root',imageWidth:400,imageHeight:500,bottomInset:28,restoredOffset:0,
  decoded:false,measured:true,started:false,version:0,closing:false,showing:false,layoutAttempts:0,
  onOpened:()=>opened++,onClosed:()=>closed++,onReveal:()=>revealed++,getUIContext:()=>({px2vp:n=>n,getComponentUtils:()=>({
    getRectangleById:id=>id==='root'?{windowOffset:{x:0,y:30},size:{width:360,height:800}} :{windowOffset:{x:18,y:110},size:{width:324,height:433}}
  }),animateTo:(opts,fn)=>{animations.push(opts);fn();}})});x.aboutToAppear();return x;}
const x=fixture();x.begin();assert.equal(x.started,false,'wait for cached cover decode');x.decoded=true;x.begin();assert.equal(x.frame.y,100);
timers.shift()();assert.equal(x.frame.y,80);assert.equal(x.frame.height,405,'exclude indicator row');assert.equal(animations.at(-1).duration,240);
animations.at(-1).onFinish();assert.equal(opened,1);assert.equal(x.showing,false);
x.closing=true;x.closeChanged();assert.equal(x.frame.y,100);assert.equal(animations.at(-1).duration,200);
animations.at(-1).onFinish();assert.equal(closed,1);
const early=fixture();early.closing=true;early.closeChanged();assert.equal(closed,2,'early back cannot trap navigation');
const stale=fixture();stale.decoded=true;stale.begin();timers.shift()();const pending=animations.at(-1);stale.aboutToDisappear();pending.onFinish();assert.equal(opened,1,'disposed flight cannot reveal another Pin');
assert.equal(revealed,3);
const deferred=fixture();deferred.decoded=true;const validTarget=deferred.target.bind(deferred);let layouts=0;
deferred.target=()=>++layouts===1?undefined:validTarget();deferred.begin();assert.equal(deferred.started,false,'first layout miss must not skip animation');
timers.shift()();assert.equal(deferred.started,true);timers.shift()();assert.equal(deferred.showing,true);
console.log('Detail entry motion: decoded handoff, window coordinates, indicator exclusion, 240ms entry/200ms exit, early back and stale disposal passed');
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const indexFile=ts.createSourceFile('index.ts',indexSource.replace(/\bstruct\b/g,'class'),99,true);let capture='';
function findCapture(n){if(ts.isMethodDeclaration(n)&&n.name.getText(indexFile)==='capturePinEntryPhoto')capture=n.getText(indexFile);ts.forEachChild(n,findCapture);}findCapture(indexFile);
let coverWidth=0;
const Capture=vm.runInNewContext(ts.transpileModule('class Capture {'+capture+'} Capture;',{compilerOptions:{target:99}}).outputText,
 {pickCoverImageUrl:(images,width)=>{coverWidth=width;return images['564x']?.url||'';}});
const owner=new Capture();let measuredId='';Object.assign(owner,{authStatus:'authenticated',businessSuspended:false,getUIContext:()=>({px2vp:n=>n/2,getComponentUtils:()=>({getRectangleById:id=>{measuredId=id;return {windowOffset:{x:40,y:180},size:{width:320,height:400}};}})})});
for(const prefix of ['pinmony-board-photo-','pinmony-search-photo-']){
 owner.capturePinEntryPhoto('pin','image',prefix+'1',800,1000);
 assert.equal(measuredId,prefix+'1');assert.equal(owner.homeEntryCardId,measuredId);assert.equal(owner.homeEntryPhoto.y,90);assert.equal(owner.homeEntryPhoto.imageHeight,1000);
}
owner.capturePinEntryPhoto('pin','fallback','pinmony-related-photo-parent-target',800,1000,{'564x':{url:'visible-cover'}});
assert.equal(coverWidth,160,'select the cover using measured vp width');
assert.equal(owner.homeEntryPhoto.imageUrl,'visible-cover','reuse the displayed tier instead of loading a different source');
owner.capturePinEntryPhoto('pin','fallback','pinmony-related-photo-parent-target',800,1000,{});
assert.equal(owner.homeEntryPhoto.imageUrl,'fallback','missing tiers retain the original source');
owner.businessSuspended=true;owner.capturePinEntryPhoto('pin','image','old',800,1000);assert.equal(owner.homeEntryPhoto,undefined,'suspended session cannot retain stale origin');
console.log('Board/search entry capture: exact source ownership, dimensions, window conversion and suspended guard passed');
const page=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
assert(page.includes('this.entryPhoto && (!this.entryMotionComplete || this.entryClosing)'), 'finished entry overlay must leave the hit-test tree');
const remount=fixture();remount.closing=true;remount.decoded=true;remount.begin();assert.equal(remount.frame.y,80,'closing remount starts at current detail photo');
timers.shift()();assert.equal(remount.frame.y,100,'closing remount returns to original card');
const searchSource=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
const searchFile=ts.createSourceFile('search.ts',searchSource.replace(/\bstruct\b/g,'class'),99,true);let ensure='';
function findEnsure(n){if(ts.isMethodDeclaration(n)&&n.name.getText(searchFile)==='ensureSearchDestination')ensure=n.getText(searchFile);ts.forEachChild(n,findEnsure);}findEnsure(searchFile);
const Preview=vm.runInNewContext(ts.transpileModule('class Preview {'+ensure+'} Preview;',{compilerOptions:{target:99}}).outputText);
const preview=new Preview();const paths=[];Object.assign(preview,{pagePresent:true,active:false,detailReturnPreview:false,searchPathStack:{size:()=>paths.length,pushPath:p=>paths.push(p)}});
preview.ensureSearchDestination();assert.equal(paths.length,0,'inactive search stays unmounted outside a return');
preview.detailReturnPreview=true;preview.ensureSearchDestination();assert.equal(paths.length,1,'return preview must create real card content despite inactive business state');
preview.active=true;preview.detailReturnPreview=false;preview.ensureSearchDestination();assert.equal(paths.length,1,'handoff retains the same destination');
console.log('Search return preview: inactive isolation, actual destination creation and no duplicate destination passed');

const scrolled=fixture();scrolled.decoded=true;scrolled.closing=true;
const baseUI=scrolled.getUIContext();
scrolled.getUIContext=()=>({...baseUI,getComponentUtils:()=>({getRectangleById:id=>id==='root'?{windowOffset:{x:0,y:30},size:{width:360,height:800}}:{windowOffset:{x:18,y:-600},size:{width:324,height:433}}})});
assert.equal(scrolled.heroVisible(),false,'offscreen hero uses page exit');
let pageExit=false;scrolled.onReveal=(closing,page)=>{pageExit=closing&&page;};
scrolled.begin();assert.equal(scrolled.showing,false,'closing remount cannot flash offscreen photo');
timers.shift()();assert.equal(pageExit,true);assert.equal(scrolled.showing,false);
const beforeClose=closed;animations.at(-1).onFinish();assert.equal(closed,beforeClose+1,'page exit commits back once');
console.log('Scrolled detail: offscreen hero hidden and page exit completes navigation passed');
const reopened=fixture();reopened.restoredOffset=900;reopened.decoded=true;let pageOpen=false;reopened.onReveal=(closing,page)=>{pageOpen=!closing&&page;};
reopened.begin();assert.equal(reopened.showing,false,'restored entry never paints flying hero');timers.shift()();assert.equal(pageOpen,true);assert.equal(reopened.showing,false);animations.at(-1).onFinish();
console.log('Restored detail entry: page fade without flying to offscreen hero passed');

const pageFile=ts.createSourceFile('page.ts',page.replace(/\bstruct\b/g,'class'),99,true);let anchorMethod='';
function findAnchor(n){if(ts.isMethodDeclaration(n)&&n.name.getText(pageFile)==='preserveRelatedAnchor')anchorMethod=n.getText(pageFile);ts.forEachChild(n,findAnchor);}findAnchor(pageFile);
const Anchor=vm.runInNewContext(ts.transpileModule('class Anchor {'+anchorMethod+'} Anchor;', {compilerOptions:{target:99}}).outputText,{PinmonyRuntimeLog:{info:()=>{},warn:()=>{}}});
const anchor=new Anchor();let scroll=900;Object.assign(anchor,{measuredHeaderHeight:600,restoringScroll:false,detail:{pinUrl:'pin'},detailScroller:{offset:()=>({yOffset:scroll}),scrollTo:o=>scroll=o.yOffset},onScrollPosition:()=>{}});anchor.preserveRelatedAnchor(680);assert.equal(scroll,980,'header growth preserves related card screen position');anchor.preserveRelatedAnchor(580);assert.equal(scroll,880,'header shrink preserves related card screen position');scroll=100;anchor.preserveRelatedAnchor(630);assert.equal(scroll,100,'hero viewport must not be moved');
assert(page.includes('pin.pinUrl || pin.id'),'recommendation nodes survive image metadata refresh');assert(indexSource.includes('pinmony-related-photo-'),'related route captures exact card');
assert(page.includes("'pinmony-related-photo-' + this.detail.pinUrl + '-' + pin.pinUrl"), 'source geometry uses parent and target routes independent of cached IDs and opening tokens');
assert(indexSource.includes("'pinmony-related-photo-' + parent + '-' + target"), 'geometry lookup matches the retained image node');
console.log('Related entry capture, stable card identity and header anchor compensation passed');
