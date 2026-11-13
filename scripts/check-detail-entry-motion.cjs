const fs=require('node:fs'), vm=require('node:vm'), assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailEntryMotion.ets','utf8');
const sf=ts.createSourceFile('motion.ts',source.replace(/\bstruct\b/g,'class'),99,true), methods=[];
const names=['aboutToAppear','aboutToDisappear','openWithoutPhoto','target','heroVisible','begin','imageComplete','closeChanged','move'];
function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(sf)))methods.push(n.getText(sf));ts.forEachChild(n,visit);} visit(sf);
const geometry=fs.readFileSync('feature_pin/src/main/ets/services/PinmonyImageTransition.ets','utf8').replace(/^import .*;\r?\n/gm,'').replace(/export /g,'');
const imageContainRect=vm.runInNewContext(ts.transpileModule(geometry+';imageContainRect;',{compilerOptions:{target:99}}).outputText);
const timers=[],animations=[],preparationTimers=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:99}}).outputText,
 {imageContainRect,PinmonyRuntimeLog:{info:()=>{}},Curve:{EaseOut:0},setTimeout:(fn,delay)=>{if(delay===500){preparationTimers.push(fn);return -1000-preparationTimers.length;}timers.push(fn);return timers.length;},clearTimeout:()=>{}});
let opened=0,closed=0,revealed=0;
function fixture(HostType=Host){const x=new HostType(); Object.assign(x,{photo:{x:20,y:130,width:160,height:200},targetId:'target',rootId:'root',imageWidth:400,imageHeight:500,targetRadius:18,bottomInset:28,restoredOffset:0,
  decoded:false,rendered:true,measured:true,started:false,version:0,closing:false,showing:false,layoutAttempts:0,preparationExpired:false,
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
for(const prefix of ['pinmony-board-photo-','pinmony-search-photo-','pinmony-profile-photo-']){
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
const media=page.slice(page.indexOf('private detailMedia()'),page.indexOf('private detailInformation()'));
assert.match(media,/PinmonyCdnImage\(\{ url: this\.backdropImageUrl\(\), useSharedDecode: false \}\)[\s\S]{0,180}\.blur\(28 \* this\.entryBackdropProgress \* \(1 - this\.viewerBackdropProgress\)\)[\s\S]{0,220}HitTestMode\.None/,'photo backdrop retains viewer animation outside the entry-hidden clear photo');
assert(media.includes('(this.coverBackdropVisible() ? 1 : 0)'), 'rendered carousel handoff controls cover visibility without replacing its source');
assert(media.indexOf('.blur(')<media.indexOf('    Column() {'),'backdrop is a sibling of the clear media group');
assert.match(media, /opacity\(this.entryPhotoHidden &&\s*\(!this.displayedDetail\(\).carousel \|\| this.displayedDetail\(\).carousel\?\.freeScroll\) \? 0 : 1\)/, 'ordinary carousel keeps its slot blur mounted during entry; other media retain the original hidden group');
const carouselMedia=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyCarouselView.ets','utf8');
assert(carouselMedia.includes('.opacity(this.entryPhotoHidden || this.imageHidden ? 0 : 1)'), 'entry flight hides carousel clear media separately from its blur');
const pageAst=ts.createSourceFile('page.ts',page.replace(/\bstruct\b/g,'class'),99,true);let reveal;
function findReveal(n){if(ts.isPropertyAssignment(n)&&n.name.getText(pageAst)==='onReveal')reveal=n.initializer.getText(pageAst);ts.forEachChild(n,findReveal);}findReveal(pageAst);
assert(reveal);const revealHost={entryOpacity:0,entryScale:1,entryPhotoHidden:false};let transition;
revealHost.getUIContext=()=>({animateTo:(options,commit)=>{transition=options;commit();}});
const runReveal=vm.runInNewContext(ts.transpileModule('function invoke(){return ('+reveal+');} invoke;', {compilerOptions:{target:99}}).outputText,{Curve:{EaseOut:0}}).call(revealHost);
runReveal(false,false);assert.equal(revealHost.entryOpacity,1);assert.equal(revealHost.entryPhotoHidden,true);assert.equal(transition.duration,240,'backdrop fades during entry while clear photo is flying');
runReveal(true,false);assert.equal(revealHost.entryOpacity,0);assert.equal(transition.duration,200,'backdrop fades during return');
runReveal(false,true);assert.equal(revealHost.entryPhotoHidden,false,'page-only entry retains media');
assert(page.includes('@Prop disableImageZoom: boolean = false;'),'detail exposes source-specific zoom suppression');
assert.match(page,/onImageTap: \(url: string\) => \{ if \(!this\.disableImageZoom && !this\.displayedDetail\(\)\.shuffleId\)/,'collage detail suppresses carousel zoom without changing normal Pin behavior');
assert.match(page,/onTap: \(\) => \{ if \(!this\.disableImageZoom && !this\.displayedDetail\(\)\.shuffleId\)/,'collage detail suppresses hero zoom without changing normal Pin behavior');
const profilePage=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
assert(profilePage.includes(".id('pinmony-profile-photo-' + pin.id)"),'profile collage pins expose stable entry-photo geometry');
const profileOpen=indexSource.slice(indexSource.indexOf('private async performProfileAction'),indexSource.indexOf('private async ',indexSource.indexOf('private async performProfileAction')+1));
assert(profileOpen.includes("profile.hubMode === 'collages'") && profileOpen.includes("'pinmony-profile-photo-' + target.id"),'published collage Pin opens through the existing photo detail transition');
assert(indexSource.includes("false, profile.hubMode === 'collages' && target?.collageDraft !== true"),'published collage detail carries a scoped no-zoom interaction mode');
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

let preserveSearch='';
function findPreserveSearch(n){if(ts.isMethodDeclaration(n)&&n.name.getText(indexFile)==='preservingSearchForPin')preserveSearch=n.getText(indexFile);ts.forEachChild(n,findPreserveSearch);}findPreserveSearch(indexFile);
const RetainedSearch=vm.runInNewContext(ts.transpileModule('class RetainedSearch {'+preserveSearch+'} RetainedSearch;',{compilerOptions:{target:99}}).outputText);
const retained=new RetainedSearch();
Object.assign(retained,{searchStore:{search:{pageKey:'search'},searchReturnPageKey:'search'},pinStore:{detailOpeningPin:'pin',detailPresentationOnly:true},currentPinUrl:()=>''});
assert.equal(retained.preservingSearchForPin(),true,'opening detail retains search before native business URL ownership');
retained.pinStore.detail={pinUrl:'pin'};retained.pinStore.detailOpeningPin='';
assert.equal(retained.preservingSearchForPin(),true,'presentation-only snapshot retains the source during decode and flight');
retained.searchStore.searchReturnPageKey='other';
assert.equal(retained.preservingSearchForPin(),false,'unrelated search cannot become the detail underlay');
retained.searchStore.searchReturnPageKey='search';retained.pinStore.detail=undefined;
assert.equal(retained.preservingSearchForPin(),false,'completed return releases detail-only retention');
console.log('Search entry underlay: opening identity, preview snapshot, origin isolation and release passed');

let activeChanged='';
function findActiveChanged(n){if(ts.isMethodDeclaration(n)&&n.name.getText(searchFile)==='activeChanged')activeChanged=n.getText(searchFile);ts.forEachChild(n,findActiveChanged);}findActiveChanged(searchFile);
const pendingVisibility=[];
const SearchLifecycle=vm.runInNewContext(ts.transpileModule('class SearchLifecycle {'+activeChanged+'} SearchLifecycle;',{compilerOptions:{target:99}}).outputText,{Promise:{resolve:()=>({then:fn=>pendingVisibility.push(fn)})}});
const lifecycle=new SearchLifecycle();let clears=0,prefetchSyncs=0;
const uiCommits = require('./ui-commit-harness.cjs').createUiCommitHarness(ts);
lifecycle.uiCommits = new uiCommits.Queue();
Object.assign(lifecycle,{pagePresent:true,active:false,detailReturnPreview:false,syncImagePrefetchActivity:()=>prefetchSyncs++,closePhotoSearch:()=>{},restoreHeroPosition:()=>{},ensureSearchDestination:()=>{},tracePresentation:()=>{},searchPathStack:{clear:()=>clears++}});
lifecycle.activeChanged();assert.equal(clears,0,'active prop must not clear search before retained prop arrives');
lifecycle.detailReturnPreview=true;lifecycle.activeChanged();pendingVisibility.shift()();
assert.equal(clears,0,'same-frame preview handoff retains the original WaterFlow destination');
lifecycle.detailReturnPreview=false;lifecycle.activeChanged();pendingVisibility.shift()();
assert.equal(clears,1,'ordinary inactive search still releases its destination');
lifecycle.activeChanged();lifecycle.pagePresent=false;pendingVisibility.shift()();
assert.equal(clears,1,'disposed page ignores late visibility work');
assert.equal(prefetchSyncs,4,'all active-state changes synchronize existing prefetch admission');
console.log('Search watched-prop handoff: no intermediate pop, inactive cleanup and disposal passed');

const scrolled=fixture();scrolled.decoded=true;scrolled.closing=true;
const baseUI=scrolled.getUIContext();
scrolled.getUIContext=()=>({...baseUI,getComponentUtils:()=>({getRectangleById:id=>id==='root'?{windowOffset:{x:0,y:30},size:{width:360,height:800}}:{windowOffset:{x:18,y:-600},size:{width:324,height:433}}})});
assert.equal(scrolled.heroVisible(),false,'offscreen hero uses page exit');
let pageExit=false;scrolled.onReveal=(closing,page)=>{pageExit=closing&&page;};
scrolled.begin();assert.equal(scrolled.showing,false,'closing remount cannot flash offscreen photo');
timers.shift()();assert.equal(pageExit,true);assert.equal(scrolled.showing,false);
const beforeClose=closed;animations.at(-1).onFinish();assert.equal(closed,beforeClose+1,'page exit commits back once');
console.log('Scrolled detail: offscreen hero hidden and page exit completes navigation passed');
for (const top of [-300, 760]) {
 const partial=fixture();partial.closing=true;partial.decoded=true;
 const ui=partial.getUIContext();
 partial.getUIContext=()=>({...ui,getComponentUtils:()=>({getRectangleById:id=>id==='root'?{windowOffset:{x:0,y:30},size:{width:360,height:800}}:{windowOffset:{x:18,y:top+30},size:{width:324,height:433}}})});
 let mode;partial.onReveal=(_closing,page)=>{mode=page;};
 assert.equal(partial.heroVisible(),true,'partially visible detail hero keeps its photo flight');
 partial.begin();timers.shift()();assert.equal(mode,false);animations.at(-1).onFinish();
}
const recycledHero=fixture();recycledHero.started=true;recycledHero.decoded=true;recycledHero.target=()=>undefined;
let recycledPage=false;recycledHero.onReveal=(closing,page)=>{recycledPage=closing&&page;};
recycledHero.closing=true;recycledHero.closeChanged();assert.equal(recycledPage,true,'missing detail hero still animates page exit');
animations.at(-1).onFinish();
const missingSource=fixture();missingSource.photo.returnPageOnly=true;missingSource.closing=true;missingSource.decoded=true;
let fallbackExit=false;missingSource.onReveal=(closing,page)=>{fallbackExit=closing&&page;};
missingSource.begin();assert.equal(missingSource.showing,false,'offscreen source cannot flash a stale photo');
timers.shift()();assert.equal(fallbackExit,true,'offscreen source animates the page even with visible hero');
animations.at(-1).onFinish();
const reopened=fixture();reopened.restoredOffset=900;reopened.decoded=true;let pageOpen=false;reopened.onReveal=(closing,page)=>{pageOpen=!closing&&page;};
reopened.getUIContext=scrolled.getUIContext;
reopened.begin();assert.equal(reopened.showing,false,'restored entry never paints flying hero');timers.shift()();assert.equal(pageOpen,true);assert.equal(reopened.showing,false);animations.at(-1).onFinish();
console.log('Restored detail entry: page fade without flying to offscreen hero passed');
for(const offset of [1,28,160]){
 const visibleRestored=fixture();visibleRestored.restoredOffset=offset;visibleRestored.decoded=true;
 let pageMode;visibleRestored.onReveal=(_closing,page)=>{pageMode=page;};
 visibleRestored.begin();assert.equal(visibleRestored.showing,true,'restored offset alone cannot suppress visible photo');
 timers.shift()();assert.equal(pageMode,false,'visible restored carousel keeps photo flight');animations.at(-1).onFinish();
}
console.log('Visible restored detail: nonzero scroll offsets retain photo entry while offscreen restoration stays page-only passed');

const pageFile=ts.createSourceFile('page.ts',page.replace(/\bstruct\b/g,'class'),99,true);let anchorMethod='';
function findAnchor(n){if(ts.isMethodDeclaration(n)&&n.name.getText(pageFile)==='preserveRelatedAnchor')anchorMethod=n.getText(pageFile);ts.forEachChild(n,findAnchor);}findAnchor(pageFile);
const Anchor=vm.runInNewContext(ts.transpileModule('class Anchor {'+anchorMethod+'} Anchor;', {compilerOptions:{target:99}}).outputText,{PinmonyRuntimeLog:{info:()=>{},warn:()=>{}}});
const anchor=new Anchor();let scroll=900;Object.assign(anchor,{measuredHeaderHeight:600,restoringScroll:false,detail:{pinUrl:'pin'},detailScroller:{offset:()=>({yOffset:scroll}),scrollTo:o=>scroll=o.yOffset},onScrollPosition:()=>{}});anchor.preserveRelatedAnchor(680);assert.equal(scroll,980,'header growth preserves related card screen position');anchor.preserveRelatedAnchor(580);assert.equal(scroll,880,'header shrink preserves related card screen position');scroll=100;anchor.preserveRelatedAnchor(630);assert.equal(scroll,100,'hero viewport must not be moved');
assert(page.includes('pin.pinUrl || pin.id'),'recommendation nodes survive image metadata refresh');assert(indexSource.includes('pinmony-related-photo-'),'related route captures exact card');
assert(page.includes("'pinmony-related-photo-' + this.displayedDetail().pinUrl + '-' + pin.pinUrl"), 'source geometry uses parent and target routes independent of cached IDs and opening tokens');
assert(indexSource.includes("'pinmony-related-photo-' + parent + '-' + target"), 'geometry lookup matches the retained image node');
console.log('Related entry capture, stable card identity and header anchor compensation passed');

assert.match(source,/onDataReady: \(\) => this.imageComplete\(0\)/);
assert.match(source,/onDecoded: \(\) => this.imageComplete\(1\)/);
const hidden=fixture();hidden.rendered=false;
const beforeReady=animations.length;
hidden.imageComplete(0);
assert.equal(hidden.started,false,'data-ready cannot start movement before a drawable frame');
assert.equal(hidden.showing,true,'source photo becomes visible so a hidden Image can render');
assert.equal(hidden.frame.y,100,'render preparation stays at the card source');
assert.equal(timers.length,0,'no timed guess may hide the underlying page before the render callback');
assert.equal(animations.length,beforeReady);
hidden.imageComplete(0);assert.equal(timers.length,0,'duplicate data-ready keeps waiting');
hidden.imageComplete(1);assert.equal(hidden.started,true);
assert.equal(timers.length,1,'render-ready still commits the source before movement');
timers.shift()();hidden.imageComplete(1);
assert.equal(timers.length,0,'duplicate render callback cannot restart entry');
assert.equal(animations.length,beforeReady+1);
const direct=fixture();direct.rendered=false;direct.imageComplete(1);
assert.equal(direct.started,true,'render-ready without a separate data callback also starts');timers.shift()();
const pageOnly=fixture();pageOnly.rendered=false;pageOnly.restoredOffset=300;pageOnly.getUIContext=scrolled.getUIContext;pageOnly.imageComplete(0);
assert.equal(pageOnly.started,true,'page-only return never waits for an invisible photo to render');timers.shift()();
const disposed=fixture();disposed.rendered=false;disposed.aboutToDisappear();disposed.imageComplete(0);disposed.imageComplete(1);
assert.equal(disposed.started,false,'late data callback cannot open disposed detail');
assert.equal(disposed.rendered,false,'disposed image callback cannot mutate readiness');
const preparing=fixture();preparing.rendered=false;preparing.imageComplete(0);preparing.closing=true;
const beforeEarlyClose=closed;preparing.closeChanged();assert.equal(closed,beforeEarlyClose+1,'back during render preparation cannot trap navigation');
console.log('Detail flight readiness: visible source preparation, render-gated movement, duplicate callbacks, page-only path, disposal and early back passed');

assert(!indexSource.includes("this.profileSettingsVisible || this.homeEntryPhoto && this.homeEntryCardId.startsWith('pinmony-home-photo-')"),'detail entry must not add a second status inset to retained home tabs');
const rootTabs = indexSource.slice(indexSource.indexOf('private buildRootTabs()'), indexSource.indexOf('private buildRootTabs()') + 5000);
assert(!/\.padding\(\{ top:.*homeEntryPhoto/.test(rootTabs),'retained tabs must not shift when the return flight appears');
console.log('Retained home geometry: detail entry and return do not change root tabs inset passed');
const pageOnlyPhoto=fixture();pageOnlyPhoto.photo.returnPageOnly=true;pageOnlyPhoto.rendered=false;pageOnlyPhoto.decoded=true;
const pageOnlyModes=[];pageOnlyPhoto.onReveal=(_closing,page)=>pageOnlyModes.push(page);
const pageOnlyTimer=timers.length;pageOnlyPhoto.begin();assert.equal(pageOnlyPhoto.showing,false,'Sheet source uses page motion without hidden photo render wait');timers[pageOnlyTimer]();
assert.equal(pageOnlyModes.at(-1),true);assert.equal(animations.at(-1).duration,240);animations.at(-1).onFinish();
pageOnlyPhoto.closing=true;pageOnlyPhoto.closeChanged();assert.equal(pageOnlyModes.at(-1),true);assert.equal(animations.at(-1).duration,200);animations.at(-1).onFinish();
console.log('Photo result motion: existing page entry/exit, hidden Sheet source and no invisible-image render wait passed');

// Drive the real motion methods with a cancellable virtual clock. The old
// 80ms deadline fails the warm-image case before its drawable frame arrives.
let clockMs=0, nextTimer=0;const scheduled=new Map();
function advance(ms){const end=clockMs+ms;for(;;){const due=[...scheduled].filter(([,job])=>job.at<=end).sort((a,b)=>a[1].at-b[1].at)[0];if(!due)break;scheduled.delete(due[0]);clockMs=due[1].at;due[1].fn();}clockMs=end;}
const TimedHost=vm.runInNewContext(ts.transpileModule('class TimedHost {'+methods.join('\n')+'} TimedHost;',{compilerOptions:{target:99}}).outputText,
 {imageContainRect,PinmonyRuntimeLog:{info:()=>{}},Curve:{EaseOut:0},setTimeout:(fn,delay)=>{const id=++nextTimer;scheduled.set(id,{at:clockMs+delay,fn});return id;},clearTimeout:id=>scheduled.delete(id)});
assert.match(source,/fit: ImageFit\.Cover, useSharedDecode: false/,'flight reuses the native image cache used by home cards and detail hero');
assert.match(fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets','utf8'),/useSharedDecode: false/,'home cards use native images');
assert.match(fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailHero.ets','utf8'),/useSharedDecode: false/,'detail hero uses native images');
const warm=fixture(TimedHost);warm.rendered=false;let warmMode;
warm.onReveal=(_closing,page)=>{warmMode=page;};advance(100);
assert.equal(warm.preparationExpired,false,'80ms must not downgrade a warm card');
warm.imageComplete(0);advance(100);warm.imageComplete(1);advance(32);
assert.equal(warmMode,false,'drawable image after 80ms still gets a photo flight');
advance(500);assert.equal(warm.preparationExpired,false,'started flight cancels preparation timeout');
const cold=fixture(TimedHost);cold.rendered=false;let coldMode;
cold.onReveal=(_closing,page)=>{coldMode=page;};advance(500);advance(32);
assert.equal(coldMode,true,'missing image has a bounded page fallback');
const coldAnimationCount=animations.length;cold.imageComplete(1);advance(100);
assert.equal(animations.length,coldAnimationCount,'late image must not restart fallback');
const leaving=fixture(TimedHost);leaving.rendered=false;const beforeLeaving=closed;
advance(100);leaving.closing=true;leaving.closeChanged();advance(600);
assert.equal(closed,beforeLeaving+1,'back during preview preparation closes once');
const dead=fixture(TimedHost);dead.rendered=false;dead.aboutToDisappear();advance(600);dead.imageComplete(1);
assert.equal(dead.started,false,'disposed preparation cannot start an animation');
let resetEntry='';
function findResetEntry(n){if(ts.isMethodDeclaration(n)&&n.name.getText(pageAst)==='resetEntryMotion')resetEntry=n.getText(pageAst);ts.forEachChild(n,findResetEntry);}findResetEntry(pageAst);
assert(resetEntry);const EntryReset=vm.runInNewContext(ts.transpileModule('class EntryReset {'+resetEntry+'} EntryReset;',{compilerOptions:{target:99}}).outputText);
const resetEntryHost=new EntryReset();Object.assign(resetEntryHost,{entryPhoto:{pinUrl:'new'},entryResumed:false,entryMotionComplete:true,entryOpacity:1,entryPhotoHidden:true,entryScale:0.97});
resetEntryHost.resetEntryMotion();assert.equal(resetEntryHost.entryMotionComplete,false);assert.equal(resetEntryHost.entryOpacity,0);assert.equal(resetEntryHost.entryPhotoHidden,false);assert.equal(resetEntryHost.entryScale,1);
resetEntryHost.entryResumed=true;resetEntryHost.resetEntryMotion();assert.equal(resetEntryHost.entryMotionComplete,true);assert.equal(resetEntryHost.entryOpacity,1,'retained parent return skips a new entrance');
resetEntryHost.entryResumed=false;resetEntryHost.entryPhoto=undefined;resetEntryHost.resetEntryMotion();assert.equal(resetEntryHost.entryOpacity,1,'entries without photo geometry remain visible');
assert.match(page,/this\.activePin = this\.displayedDetail\(\)\.pinUrl;[\s\S]{0,250}this\.resetEntryMotion\(\)/,'Pin replacement resets completed flight state');
console.log('Detail longtake: native cache parity, warm render after 80ms, bounded cold fallback, cancellation, late callbacks and reused page reset passed');

// Image readiness is conditional on admission to a drawable source frame.
// Do not inject completion into an invisible 1px Image: that hid the real
// preparation deadlock in the previous warm-image tests.
const admitted=fixture(TimedHost);admitted.rendered=false;let admittedMode;
admitted.onReveal=(_closing,page)=>{admittedMode=page;};
admitted.begin();
assert.equal(admitted.showing,true,'source must be visible before any image completion callback');
assert.equal(admitted.frame.width,admitted.photo.width,'first drawable frame uses card width, not 1px');
assert.equal(admitted.frame.height,admitted.photo.height,'first drawable frame uses card height');
assert.equal(admitted.frame.y,100,'prepare the card in root-local window coordinates');
assert.equal(admitted.started,false,'source preparation does not start a flight before readiness');
assert.equal(admittedMode,undefined,'keep the detail hidden while preparing the visible source');
advance(16);
if(admitted.showing && admitted.frame.width>1 && admitted.frame.height>1)admitted.imageComplete(0);
advance(16);admitted.imageComplete(1);advance(32);
assert.equal(admittedMode,false,'admitted card expands into the detail instead of fading the page');
assert.equal(admitted.frame.width,324,'photo flight reaches the contained destination');
animations.at(-1).onFinish();advance(500);
assert.equal(admitted.preparationExpired,false,'successful drawable-source flight cancels its deadline');
console.log('Detail source admission: real card frame precedes readiness, then photo expansion and final handoff passed');

const coldReturn=fixture(TimedHost);coldReturn.closing=true;coldReturn.rendered=false;
const returnModes=[];let returned=0;
coldReturn.onReveal=(closing,pageOnly)=>returnModes.push([closing,pageOnly]);coldReturn.onClosed=()=>returned++;
coldReturn.begin();advance(499);assert.equal(coldReturn.started,false);
advance(33);assert.equal(coldReturn.started,true);assert.deepEqual(returnModes,[[true,true]],'cold return cannot wait indefinitely for another download');
const returnAnimation=animations.at(-1);assert.equal(returnAnimation.duration,200);
coldReturn.imageComplete(1);assert.equal(returnModes.length,1,'late image cannot restart a fallback return');
returnAnimation.onFinish();assert.equal(returned,1);
const warmReturn=fixture(TimedHost);warmReturn.closing=true;warmReturn.rendered=false;
let warmReturnPage;warmReturn.onReveal=(_closing,pageOnly)=>warmReturnPage=pageOnly;
warmReturn.begin();warmReturn.imageComplete(0);warmReturn.imageComplete(1);advance(32);
assert.equal(warmReturnPage,false,'cached return retains photo flight');
advance(500);assert.equal(warmReturn.preparationExpired,false,'ready return cancels fallback deadline');
console.log('Detail return preparation: bounded cold return, late callback isolation and cached photo return passed');

const synced=fixture(TimedHost);synced.decoded=true;let inCommit=false;
const uiSynced=synced.getUIContext();const progress=[];
synced.getUIContext=()=>({...uiSynced,animateTo:(options,commit)=>{animations.push(options);inCommit=true;commit();inCommit=false;}});
synced.onTransition=expanded=>{assert(inCommit,'blur shares the photo geometry transaction');progress.push(expanded);};
synced.begin();assert.equal(synced.frameRadius,18);advance(32);assert.equal(synced.frameRadius,18);assert.deepEqual(progress,[1]);
synced.closing=true;synced.closeChanged();assert.equal(synced.frameRadius,18);assert.deepEqual(progress,[1,0]);
assert(source.includes('.borderRadius(this.frameRadius)'),'flight draws interpolated radius');
assert(page.includes('onTransition: (expanded: number) => { this.entryBackdropProgress = expanded; }'));
assert(!media.includes('if (!this.displayedDetail().carousel &&'),'carousel metadata cannot unmount the backdrop');
assert(page.includes('sourceRadius: this.detailPhotoRadius()'),'viewer returns to actual adaptive photo radius');
assert.match(fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailHero.ets','utf8'),/height\(this.heightVp\)\.borderRadius\(this.radiusVp\)\.clip\(true\)/,'final detail photo keeps rounded corners');
console.log('Detail visual motion: rounded flight endpoints match final photo, blur uses geometry transaction and carousel backdrop retained passed');
const squareTarget=fixture(TimedHost);squareTarget.decoded=true;squareTarget.targetRadius=0;
squareTarget.begin();assert.equal(squareTarget.frameRadius,18);advance(32);assert.equal(squareTarget.frameRadius,0);
squareTarget.closing=true;squareTarget.closeChanged();assert.equal(squareTarget.frameRadius,18,'adjusted photo reverses from square to rounded card');
