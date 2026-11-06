const fs = require('fs');
const path = require('path');
const Module = require('module');
const assert = require('assert');

const panel = fs.readFileSync(path.join(__dirname, '../feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets'), 'utf8');
assert(panel.includes('.onReachEnd(() => this.loadNextPage())'));
assert(panel.includes('this.scroller.isAtEnd()') && panel.includes('this.scheduleFollowerEndCheck()'));
assert(panel.includes('this.followerEndCheckToken++') && panel.includes('!this.followerSearching'));
assert(panel.includes('.edgeEffect(EdgeEffect.Spring') && panel.includes('builder: this.panelRefreshIndicator'));
assert(/private panelRefreshIndicator\(\)[\s\S]*?\.offset\(\{ y: this\.contentTopInset\(\) \}\)/.test(panel), 'refresh indicator must use the content inset below the title');

const normalized = panel.match(/private normalizeFollowerSearch\(text: string\): string \{([\s\S]*?)\n  \}/)[1];
const normalize = new Function('text',normalized); assert.equal(normalize('ÉLODIE'),'elodie');
assert(!panel.includes("+ ' ' + item.id"),'user IDs must not participate in name search');

// Execute the production presentation and pagination methods with bounded UI substitutes.
const ts = require(process.argv[2] || 'typescript');
const vm = require('vm');
const uiMethods = panel.slice(panel.indexOf('  private loadNextPage()'), panel.indexOf('  private scheduleFollowerEndCheck()')) +
  panel.slice(panel.indexOf('  private openFollowerSearch()'), panel.indexOf('  private options()'));
const callbacks=[];
const Ui = vm.runInNewContext(ts.transpileModule('class PanelHarness {'+uiMethods+'}\nPanelHarness;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{setTimeout:fn=>callbacks.push(fn),NavigationOperation:{POP:2,PUSH:1},Curve:{EaseOut:'ease-out'}});
const ui = new Ui(); let loads=0, navigated=''; const events=[];
Object.assign(ui,{active:true,presentationMounted:true,scrollRestoreToken:0,searchHeaderHeight:80,followerSearching:true,rootRestorePending:false,searchRestorePending:false,
 snapshot:{mode:'followers',token:8,searchOpen:true,scrollOffset:120,searchScrollOffset:480,hasMore:true},
 scroller:{currentOffset:()=>({yOffset:120}),scrollTo:o=>events.push(['root',o.yOffset])},
 searchScroller:{currentOffset:()=>({yOffset:480}),scrollTo:o=>events.push(['search',o.yOffset])},
 paths:{pushPath:(p,a)=>events.push(['push',p.name,a]),pop:a=>events.push(['pop',a])},
 onLoadMore:()=>loads++,onPresentationChange:(...args)=>events.push(['save',...args]),onUser:url=>navigated=url});
ui.loadNextPage(); assert.equal(loads,0,'hidden root cannot page while searching');
ui.loadSearchPage(); assert.equal(loads,1); ui.snapshot.moreLoading=true; ui.loadSearchPage(); assert.equal(loads,1,'busy search cannot request again');
ui.snapshot.moreLoading=false; ui.active=false; ui.loadSearchPage(); assert.equal(loads,1,'background search cannot page');
ui.active=true; ui.followerSearching=false; ui.restorePresentation(); assert(ui.followerSearching); assert(events.some(e=>e[0]==='push'&&e[2]===false));
ui.loadSearchPage(); assert.equal(loads,1,'restore must complete before paging'); callbacks.splice(0).forEach(fn=>fn());
assert(events.some(e=>e[0]==='root'&&e[1]===120)); assert(events.some(e=>e[0]==='search'&&e[1]===480));
ui.openPanelUser('https://www.pinterest.com/person/'); assert.equal(navigated,'https://www.pinterest.com/person/');
assert(events.some(e=>e[0]==='save'&&e[1]===true&&e[2]===120&&e[3]===480),'capture before navigating');
ui.followerQuery='peer';
ui.closeFollowerSearch(); assert(ui.followerSearching); assert.equal(ui.followerQuery,'peer','keep outgoing results throughout the exit animation');
const popsBeforeRepeat=events.filter(e=>e[0]==='pop').length;
ui.closeFollowerSearch(); assert.equal(events.filter(e=>e[0]==='pop').length,popsBeforeRepeat,'repeated back cannot pop the followers page');
ui.finishFollowerSearchClose(); assert(!ui.followerSearching); assert.equal(ui.followerQuery,'');
let finishes=0;const durations=[],frames=[],animations=[];
ui.getUIContext=()=>({postFrameCallback:cb=>frames.push(cb),animateTo:(options,change)=>{durations.push(options.duration);change();animations.push(options.onFinish);}});
for(const operation of [1,2]) {
  const transition=ui.followerSearchTransition({name:operation===2?'follower-search':'profile-panel'},{name:operation===1?'follower-search':'profile-panel'},operation);
  transition.transition({finishTransition:()=>finishes++});
  assert.equal(ui.searchMotionOffset,operation===1?'100%':'0%','commit the initial position before animating');
  frames.shift().onIdle();assert.equal(ui.searchMotionOffset,operation===1?'0%':'100%');
  animations.shift()();transition.onTransitionEnd(true);
}
assert.deepEqual(durations,[180,180],'entry and return use matching durations');assert.equal(finishes,2);
assert.equal(ui.followerSearchTransition({name:'profile-panel'},{name:'other'},1),undefined,'other navigation keeps its transition');
ui.followerSearching=false;ui.snapshot.searchOpen=true;ui.searchMotionOffset='100%';ui.restorePresentation();
assert.equal(ui.searchMotionOffset,'0%','restored search cannot retain the previous exit translation');
assert(events.some(e=>e[0]==='save'&&e[1]===false&&e[3]===0),'back clears retained search state');
assert(panel.includes('.onReachEnd(() => this.loadSearchPage())'));
assert(panel.includes('.onScrollStop(() => this.retainPresentation())'));

const filename = path.join(__dirname, 'check-native-profile-settings.cjs');
let source = fs.readFileSync(filename, 'utf8');
const runner = source.indexOf('(async()=>{await require(\'./autoplay-settings-test-cases.cjs\')');
assert(runner >= 0, 'native profile test runner not found');
source = source.slice(0, runner) + `
(async()=>{
 await followersPaging();
 const searching=fixture(); await searching.profile.open('followers','users');
 searching.profile.searchFollowers('peer'); await flush();
 assert.equal(searching.req.at(-1).e.variables.count,50,'search uses captured 50-user page');
 assert.equal(searching.ps.panel.items.length,2); assert(!searching.ps.panel.moreError);
 assert(!('query' in searching.req.at(-1).e.variables),'keyword stays local');
 searching.profile.retainPanelPresentation(true,128,456);
 const retainedSearch=clone(searching.ps.panel); searching.profile.close(); await searching.profile.restore(retainedSearch);
 assert.equal(searching.ps.panel.query,'peer'); assert.equal(searching.ps.panel.searchOpen,true);
 assert.equal(searching.ps.panel.scrollOffset,128); assert.equal(searching.ps.panel.searchScrollOffset,456);
 const state=clone(searching.ps.panel); searching.active(false); searching.profile.retainPanelPresentation(false,0,0); assert.deepEqual(clone(searching.ps.panel),state,'inactive page cannot overwrite presentation');

 const cap=fixture(); await cap.profile.open('followers','users');
 let pages=0; cap.profile.graph=async()=>{pages++;return {v3GetUserHandlerQuery:{data:{id:relay('1'),followers:{connection:{edges:Array.from({length:50},(_,i)=>({node:{entityId:String(100+pages*50+i),username:'person'+pages+'_'+i,fullName:'Person',explicitlyFollowedByMe:false}})),pageInfo:{hasNextPage:true,endCursor:'cursor-'+pages}}}}}};};
 cap.profile.searchFollowers('person'); await flush();
 assert.equal(pages,20); assert.equal(cap.ps.panel.items.length,1001); assert(cap.ps.panel.hasMore);
 cap.profile.searchFollowers('other'); await flush(); assert.equal(pages,20,'threshold stops automatic search paging');
 let scrollCount=0; cap.profile.graph=async(hash,variables)=>{scrollCount=variables.count;return {v3GetUserHandlerQuery:{data:{id:relay('1'),followers:{connection:{edges:[],pageInfo:{hasNextPage:false,endCursor:''}}}}}};};
 await cap.profile.moreFollowers(); assert.equal(scrollCount,10,'scroll beyond search threshold uses ten-user page');

 const cleared=fixture(); await cleared.profile.open('followers','users'); cleared.hang('/_/graphql/');
 cleared.profile.searchFollowers('peer'); await flush(); const lateSearch=cleared.hold();
 cleared.profile.searchFollowers(''); lateSearch.resolve({data:{v3GetUserHandlerQuery:{data:{id:relay('1'),followers:{connection:{edges:[{node:{entityId:'9',username:'newuser',fullName:'New'}}],pageInfo:{hasNextPage:true,endCursor:'new-cursor'}}}}}}});
 await flush(); assert.equal(cleared.req.filter(r=>r.e.variables?.count===50).length,1,'clear stops automatic continuation');
 const failed=fixture(); await failed.profile.open('followers','users'); failed.bad(true); failed.profile.searchFollowers('peer'); await flush();
 assert(failed.ps.panel.moreError); const failedCount=failed.req.length; await flush(); assert.equal(failed.req.length,failedCount,'failed search is not replayed');
 failed.bad(false); await failed.profile.moreFollowers(); assert(!failed.ps.panel.moreError);
 const closing=fixture(); await closing.profile.open('followers','users'); closing.hang('/_/graphql/'); closing.profile.searchFollowers('peer'); await flush(); closing.profile.close(); await flush(); assert.equal(closing.ps.panel,undefined);


 const f=fixture(); await f.profile.open('followers','users');
 f.hang('/_/graphql/'); const pending=f.profile.moreFollowers(); await flush();
 assert(f.ps.panel.moreLoading); f.profile.pause(); await pending;
 assert(!f.ps.panel.moreLoading, 'cancelled paging must not remain loading');
 assert(f.ps.panel.moreError, 'cancelled paging must offer an honest retry state');
 const refresh=fixture(); await refresh.profile.open('followers','users');
 const retained=refresh.ps.panel.items.length; refresh.hang('/_/graphql/');
 const refreshing=refresh.profile.open('followers','users',true); await flush();
 assert(refresh.ps.panel.refreshing && !refresh.ps.panel.loading, 'refresh must not replace existing content with initial loading');
 assert.equal(refresh.ps.panel.items.length,retained,'refresh retains existing items while pending');
 const count=refresh.req.length; await refresh.profile.moreFollowers(); assert.equal(refresh.req.length,count,'paging must wait for refresh');
 refresh.profile.pause(); await refreshing; assert(!refresh.ps.panel.refreshing,'cancelled refresh must stop');
 console.log('Followers paging: identity, cursor, retry, duplicate requests, cancellation, stale response and end triggers passed');
})().then(()=>clearTimeout(watchdog)).catch(e=>{clearTimeout(watchdog);console.error(e);process.exitCode=1});`;
const test = new Module(filename, module);
test.filename = filename;
test.paths = Module._nodeModulePaths(__dirname);
test._compile(source, filename);
