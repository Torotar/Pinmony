const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript'), out = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyBottomBarCoordinator.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, { exports: out, require: () => ({ HdsAnimationMode: { CLICK_ANIMATION: 1, SCROLL_ANIMATION: 0 } }) });
let mounted = false, hidden = true, scroll = [true, true, true, true], child = true, root = 3, token = 1, visible = true;
const calls = [];
const coordinator = new out.PinmonyBottomBarCoordinator({ floatingTabsMounted: () => mounted,
  floatingTabsHidden: () => hidden, setFloatingTabsHidden: value => hidden = value,
  rootTabsScrollHidden: () => scroll, setRootTabsScrollHidden: value => scroll = value,
  childBottomBarRestoreHidden: () => child, setChildBottomBarRestoreHidden: value => child = value,
  childBottomBarRootTab: () => root, setChildBottomBarRootTab: value => root = value,
  floatingTabsMotionToken: () => token, setFloatingTabsMotionToken: value => token = value,
  authStatus: () => 'authenticated', nativeRootTabsVisible: () => visible,
  tabsController: () => ({ applyShowAnimation: () => calls.push('show'), applyHideAnimation: () => calls.push('hide') }) });
coordinator.resetForSession(); assert.equal(calls.length, 0, 'no platform animation before mounting');
assert.equal(scroll.every(x => x === false), true); assert.equal(child, null); assert.equal(root, -1);
mounted = true; hidden = false; coordinator.resetForSession();
assert.deepEqual(calls, ['show'], 'a reused controller gets an explicit show even when the local flag was false');
assert.equal(hidden, false);
visible = false; coordinator.resetForSession(); assert.equal(calls.length, 1, 'session reset cannot expose the bar over a child');
console.log('Bottom bar session: reset scroll/depth state, mounting, explicit platform show and child gate passed');
let active = 3, opening = false;
const tasks = [];
coordinator.ports.activeTab = () => active;
coordinator.ports.pinStore = () => ({ detailOpeningPin: opening });
coordinator.ports.coordinatorTasks = () => ({ timeout: task => tasks.push(task) });
visible = true; hidden = false; scroll[3] = true;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(scroll[3], false); assert.equal(calls.at(-1), 'show', 'foreground resends show even when local flag says visible');
visible = false; hidden = false;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(hidden, true); assert.equal(calls.at(-1), 'hide', 'foreground never exposes tabs over a board');
visible = true; opening = true;
coordinator.resumeAfterForeground(); tasks.shift()();
assert.equal(hidden, true, 'opening detail remains hidden');
opening = false; visible = true; hidden = true;
coordinator.resumeAfterForeground(); visible = false; tasks.shift()();
assert.equal(hidden, true, 'navigation between scheduling and reconciliation uses latest depth');
mounted = false; const count = calls.length;
coordinator.resumeAfterForeground(); tasks.shift()(); assert.equal(calls.length, count);
console.log('Bottom bar foreground: explicit reconciliation, scroll expansion, child/opening gates and unmounted controller passed');

// Explicit back-to-top expands only an eligible current root and cancels queued collapse.
const pending=new Map(); let nextTask=0, foreground=true, authenticated=true, resultsVisible=false;
active=0; visible=true; mounted=true; opening=false; hidden=false; scroll=[false,false,false,false];
Object.assign(coordinator.ports, {
  authStatus:()=>authenticated?'authenticated':'anonymous', foreground:()=>foreground,
  searchResultsVisible:()=>resultsVisible, bottomBarScrollCollapseEnabled:()=>true,
  coordinatorTasks:()=>({timeout:fn=>{pending.set(++nextTask,fn);return nextTask;},cancelTimeout:id=>pending.delete(id)})
});
coordinator.lastAnimationAt=Date.now(); coordinator.setBottomBarHidden(true);
assert.equal(pending.size,1,'a pending collapse exists before return-to-top');
const beforeExplicitShow=calls.length;
scroll[0]=true; coordinator.expandAfterBackToTop();
assert.equal(pending.size,0,'return-to-top cancels pending collapse even when visually expanded');
assert.equal(scroll[0],false); assert.equal(hidden,false);
assert.equal(calls.length,beforeExplicitShow,'back-to-top must not replay show when already expanded');
coordinator.expandAfterBackToTop();
assert.equal(calls.length,beforeExplicitShow,'repeated back-to-top remains a no-op for expanded tabs');
hidden=true; scroll[0]=true; coordinator.expandAfterBackToTop();
assert.equal(calls.at(-1),'show'); assert.equal(scroll[0],false);
active=1; hidden=true; scroll[1]=true; coordinator.expandAfterBackToTop(); assert.equal(hidden,false); assert.equal(scroll[1],false);
for(const block of ['child','results','opening','background','signed-out','unmounted','inbox','profile']) {
  visible=block!=='child'; resultsVisible=block==='results'; opening=block==='opening';
  foreground=block!=='background'; authenticated=block!=='signed-out'; mounted=block!=='unmounted';
  active=block==='inbox'?2:block==='profile'?3:0; hidden=true; scroll[active]=true;
  const before=calls.length; coordinator.expandAfterBackToTop(); assert.equal(calls.length,before,block); assert.equal(hidden,true,block); assert.equal(scroll[active],true,block);
}
// Only collapsed bars animate, using the scroll route without throttle delay.
mounted=true; authenticated=true; foreground=true; visible=true; opening=false; resultsVisible=false; active=0; hidden=false;
const platformModes=[];
coordinator.ports.tabsController=()=>({applyShowAnimation:mode=>platformModes.push(mode),applyHideAnimation:()=>{}});
coordinator.lastAnimationAt=Date.now(); coordinator.expandAfterBackToTop();
assert.deepEqual(platformModes,[],'expanded bar does not replay an animation');
assert.equal(pending.size,0,'explicit expansion leaves no delayed collapse');
active=1; hidden=true; coordinator.expandAfterBackToTop();
assert.deepEqual(platformModes,[0],'collapsed discovery expands immediately despite scroll throttling');
coordinator.expandAfterBackToTop();
assert.deepEqual(platformModes,[0],'discovery also skips repeated expansion');
active=0; hidden=true; coordinator.expandAfterBackToTop();
assert.deepEqual(platformModes,[0,0],'collapsed home uses the same immediate expansion path');
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
assert(indexSource.includes('.barHeight(56)'));
assert(indexSource.includes('barBottomMargin: 28'),'preserve existing bottom clearance');

function pageMethod(file,name){const src=fs.readFileSync(file,'utf8'), start=src.indexOf('  private '+name+'('); assert(start>=0);return src.slice(start,src.indexOf('\n  }',start)+4);}
function pageHost(file){return new (vm.runInNewContext(ts.transpileModule('class Page {'+pageMethod(file,'backToTop')+'} Page;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText))();}
const homePage=pageHost('feature_home/src/main/ets/components/PinmonyHomePage.ets'); let scrolled=0,expanded=0;
Object.assign(homePage,{presentationActive:true,interactionReady:true,pagerMoving:false,selectedId:'all',paneKey:id=>id,paneScrollers:new Map([['all',{scrollTo(){scrolled++;}}]]),onBackToTop(){expanded++;}});
homePage.backToTop(); assert.equal(scrolled,1); assert.equal(expanded,1);
homePage.presentationActive=false; homePage.backToTop(); assert.equal(expanded,1);
homePage.presentationActive=true; homePage.paneScrollers.clear(); homePage.backToTop(); assert.equal(expanded,1,'unavailable scroller must not expand');
const searchPage=pageHost('feature_search/src/main/ets/components/PinmonySearchPage.ets'); let query='',allowed=true;
Object.assign(searchPage,{canBackToTop:()=>allowed,committedQuery:()=>query,discoveryScroller:{scrollTo(){scrolled++;}},resultsScroller:{scrollTo(){scrolled++;}},onBackToTop(){expanded++;}});
searchPage.backToTop(); assert.equal(expanded,2);
query='cats'; searchPage.backToTop(); assert.equal(expanded,2,'results do not expose root tabs');
query=''; allowed=false; searchPage.backToTop(); assert.equal(expanded,2);
for(const file of ['entry/src/main/ets/components/PinmonyHomeRootContent.ets','entry/src/main/ets/components/PinmonySearchRootContent.ets']) assert(fs.readFileSync(file,'utf8').includes('onBackToTop: () => view.expandBottomBarAfterBackToTop()'));
assert(fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8').includes('this.bottomBarCoordinator.expandAfterBackToTop()'));
console.log('Back-to-top bottom bar: current root expansion, queued collapse cancellation, page/depth/background/session/mount gates and both root bindings passed.');

assert.equal((fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8').match(/expandBottomBarAfterBackToTop: \(\): void => this\.expandBottomBarAfterBackToTop\(\)/g)||[]).length,2,'both product root adapters supply the callback');

// Page show can precede Ability foreground, and either callback can outlive a background transition.
const resumeModes=[]; let resumedForeground=true;
coordinator.ports.tabsController=()=>({applyShowAnimation:mode=>resumeModes.push(['show',mode]),applyHideAnimation:mode=>resumeModes.push(['hide',mode])});
coordinator.ports.foreground=()=>resumedForeground;
active=0; visible=true; mounted=true; authenticated=true; opening=false; resultsVisible=false;
for(active=0;active<4;active++) {
  hidden=false; scroll[active]=true; resumeModes.length=0;
  coordinator.resumeAfterForeground(); [...pending.values()].forEach(fn=>fn()); pending.clear();
  assert.deepEqual(resumeModes.slice(-2),[['show',1],['show',0]],'restore route visibility and interrupted scroll collapse for each root');
  assert.equal(scroll[active],false);
}
active=0; resumeModes.length=0;
coordinator.resumeAfterForeground(); const staleResume=[...pending.values()][0]; pending.clear();
coordinator.suspendForBackground(); resumedForeground=false; staleResume(); assert.equal(resumeModes.length,0,'no stale animation after background');
resumedForeground=true; coordinator.resumeAfterForeground(); const olderResume=[...pending.values()][0]; pending.clear();
coordinator.resumeAfterForeground(); const latestResume=[...pending.values()][0]; pending.clear();
olderResume(); assert.equal(resumeModes.length,0,'Ability foreground supersedes earlier page-show callback');
latestResume(); assert.deepEqual(resumeModes.slice(-2),[['show',1],['show',0]]);
for(const blocked of ['child','results','opening','signed-out','unmounted','background']) {
  visible=blocked!=='child'; resultsVisible=blocked==='results'; opening=blocked==='opening';
  authenticated=blocked!=='signed-out'; mounted=blocked!=='unmounted'; resumedForeground=blocked!=='background';
  resumeModes.length=0; coordinator.resumeAfterForeground(); [...pending.values()].forEach(fn=>fn()); pending.clear();
  assert(!resumeModes.some(([action])=>action==='show'),blocked+' cannot expose root tabs');
}
const pageResume=vm.runInNewContext(ts.transpileModule('class Page {'+pageMethod('entry/src/main/ets/pages/Index.ets','onAbilityForegroundChanged')+'} Page;',{
  compilerOptions:{target:ts.ScriptTarget.ES2021}
}).outputText);
let requestedResume=0; const pageResumeHost=new pageResume();
Object.assign(pageResumeHost,{businessSuspended:false,floatingTabsMounted:true,logPageLifecycle(){},bottomBarCoordinator:{resumeAfterForeground:()=>requestedResume++}});
pageResumeHost.onAbilityForegroundChanged(); assert.equal(requestedResume,1);
pageResumeHost.businessSuspended=true; pageResumeHost.onAbilityForegroundChanged(); assert.equal(requestedResume,1);
pageResumeHost.businessSuspended=false; pageResumeHost.floatingTabsMounted=false; pageResumeHost.onAbilityForegroundChanged(); assert.equal(requestedResume,1);
const lifecycleKey='pinmonyAbilityForegroundRevision'; let lifecycleRevision=0;
const abilitySource=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');
const foregroundStart=abilitySource.indexOf('  onForeground(): void {');
const foregroundMethod=abilitySource.slice(foregroundStart,abilitySource.indexOf('\n  }',foregroundStart)+4);
const Ability=vm.runInNewContext(ts.transpileModule('class Ability {'+foregroundMethod+'} Ability;',{
  compilerOptions:{target:ts.ScriptTarget.ES2021}
}).outputText,{NetworkManager:{setForeground(){}},PinmonyInboxBackgroundLifecycle:{change(){}},hilog:{info(){}},DOMAIN:0,
  AppStorage:{get:key=>{assert.equal(key,lifecycleKey);return lifecycleRevision;},setOrCreate:(key,value)=>{assert.equal(key,lifecycleKey);lifecycleRevision=value;}}});
const ability=new Ability(); Object.assign(ability,{windowStageReady:true,contentLoaded:true,logLifecycle(){},syncSystemColorMode(){},syncStatusBarHeight(){}});
ability.onForeground(); ability.onForeground(); assert.equal(lifecycleRevision,2,'each real foreground event reaches the page via an observable revision');
assert(indexSource.includes("@StorageProp('pinmonyAbilityForegroundRevision') @Watch('onAbilityForegroundChanged')"));
assert(indexSource.includes('this.businessSuspended = true;\n    this.bottomBarCoordinator.suspendForBackground();')||indexSource.includes('this.businessSuspended = true;\r\n    this.bottomBarCoordinator.suspendForBackground();'));
console.log('Foreground recovery: four roots, both animation modes, page/Ability ordering, background invalidation, latest resume, child/session/search/mount guards and lifecycle delivery passed.');
