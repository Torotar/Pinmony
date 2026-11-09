const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
assert(index.includes(".zIndex(!this.retainProfileBoardParent() && !this.retainProfilePinParent() && this.detailProfileTransition && (this.detailProfileReturning || !!this.pinStore.detail || !!this.pinStore.detailOpeningPin) ? 1 : 0)"), 'profile must stay above detail during return but below its child board');
assert(index.includes("Column() { this.buildProfileContent() }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))"), 'profile transition must have an opaque page surface');
assert(index.includes("this.profileStore.panel || this.retainedProfilePanel") && index.includes(".zIndex(2).transition(DETAIL_PROFILE_TRANSITION)"), 'list underlay must remain mounted beneath an independently animated profile');
// Execute the actual profile transition expression with both entry and popped
// origin states: returning to search must retain the same exit transition.
const profileTransition = index.match(/\.transition\((this\.detailProfileTransition \? DETAIL_PROFILE_TRANSITION[\s\S]*?)\)\s*\n\s*\}/);
assert(profileTransition,'profile transition binding');
const transitionContext = {NATIVE_PAGE_TRANSITION:{kind:'native'},DETAIL_PROFILE_TRANSITION:{kind:'detail'},
  TransitionEffect:{IDENTITY:{kind:'identity'},asymmetric:(enter,exit)=>({enter,exit}),
    translate:()=>({animation:()=>({kind:'settings-exit'})})},Curve:{EaseIn:'easeIn'}};
const selectTransition = vm.runInNewContext('(function(){ return '+profileTransition[1]+'; })',transitionContext);
for(const origins of [[{tab:1}],[]]) {
  assert.equal(selectTransition.call({activeTab:1,profileStore:{origins},settingsProfileDepth:-1}),
    transitionContext.NATIVE_PAGE_TRANSITION,'search profile entry and exit use the shared slide');
}
for(const section of ['activity','messages','contacts']) for(const origins of [[{tab:2}],[]]) {
  assert.equal(selectTransition.call({activeTab:2,profileStore:{origins},inboxStore:{listSection:section},settingsProfileDepth:-1}),
    transitionContext.NATIVE_PAGE_TRANSITION,section+' list profile entry and exit use matching native slides');
}
assert.equal(selectTransition.call({activeTab:1,detailProfileTransition:true,settingsProfileDepth:-1}),
  transitionContext.DETAIL_PROFILE_TRANSITION,'detail profile handoff keeps its existing transition');
const nativeTransition=index.slice(index.indexOf('const NATIVE_PAGE_TRANSITION:'),index.indexOf('const DETAIL_PROFILE_TRANSITION:'));
assert.equal((nativeTransition.match(/translate\(\{ x: '100%' \}\)\.animation\(\{ duration: 180, curve: Curve\.EaseOut \}\)/g)||[]).length,2,
  'entry and exit slide right with matching duration and curve');
const searchRoot=fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets','utf8');
assert(index.includes('profileCovered: this.activeTab === 1 && this.profileStore.origins.length > 0'),
  'search profile keeps its existing search underlay');
const visibility=searchRoot.match(/\.visibility\(([^\n]+)\)/)[1];
const visible=vm.runInNewContext('(function(view){return '+visibility+';})',{Visibility:{Visible:1,Hidden:0}});
assert.equal(visible({nativeSearchPageVisible:()=>false,preparingDetailReturn:false,profileCovered:true}),1);
assert.equal(visible({nativeSearchPageVisible:()=>false,preparingDetailReturn:false,profileCovered:false}),0);
assert(searchRoot.includes('.hitTestBehavior(view.nativeSearchPageVisible() ? HitTestMode.Default : HitTestMode.None)') &&
  searchRoot.includes(".accessibilityLevel(view.nativeSearchPageVisible() ? 'auto' : 'no-hide-descendants')"),
  'retained search underlay cannot receive touches or accessibility focus');
function method(name){const start=index.search(new RegExp('  private (?:async )?'+name+'\\(')),end=index.indexOf('\n  private ',start+1);assert(start>=0,name);return index.slice(start,end);}
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const loader=createArktsLoader(ts,{'common_foundation':{PinmonyRuntimeLog:{info(){},warn(){}}},'common_network':{PIN_BUSINESS_PIN_READ_ENABLED:true},'common_session':{}});
const Reader=loader.loadFile('entry/src/main/ets/app/PinmonyProfileNativeReads.ets').PinmonyProfileNativeReads;
const Cache=loader.loadFile('feature_profile/src/main/ets/services/PinmonyProfileCache.ets').PinmonyProfileCache;
const History=loader.loadFile('entry/src/main/ets/app/PinmonyNavigationHistory.ets').PinmonyNavigationHistory;
const origin='https://www.pinterest.com',home=origin+'/',page=origin+'/visitor/',own=origin+'/sample/',pin=origin+'/pin/11/',board=origin+'/visitor/board/';
const methods=['usesNativeProfileReads','currentProfileUrl','nativeDisplayAddress','currentPinUrl','currentBoardUrl','openUserProfile','backFromUserProfile','returnToNativeProfile','openProfileBoard','openProfilePanelBoard','backFromBoard','performProfileAction','openHomeMore','openSearchPinMenu','openProfilePinMenu'];
const Host=vm.runInNewContext(ts.transpileModule('class Host{'+methods.map(method).join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{setTimeout,PIN_NATIVE_PROFILE_READS_ENABLED:true,PIN_NATIVE_BOARD_READS_ENABLED:true,PIN_NATIVE_DETAIL_READS_ENABLED:true,PIN_NATIVE_PIN_MENUS_ENABLED:true,PIN_POST_API_ENABLED:true,PIN_BOARD_API_ENABLED:true,PIN_PROFILE_API_ENABLED:true,PinmonyRuntimeLog:{info(){},warn(){}},PINTEREST_URL:home});
Host.prototype.uiText = require('./local-message-test-fixture.cjs').rawLocalMessages.text;
const profileAddress=url=>/^https:\/\/(?:www|uk)\.pinterest\.com\/[A-Za-z0-9_]+\/(?:_created\/|_saved\/)?$/.test(url)?url.replace(/_(?:created|saved)\/$/,''):'';
function fixture(){const h=new Host(),requests=[],opens=[],menus=[];let session={authenticated:true,accountId:'synthetic',generation:1,origin,userAgent:'test'};
Object.assign(h,{nativeBusinessRoutesEnabled:true,markReturnedHome(){},markRootPerformance(){},authStatus:'authenticated',businessSuspended:false,authenticatedProfileUrl:own,activeTab:0,nativeRootOnly:true,nativeBackTarget:'',navigationAddress:home,tabRequestToken:0,pageBackToken:0,activeSheetKind:'',profileSettingsVisible:false,
cancelledBoardPins:new Set(),profileBoardOrigins:new Map(),profileStore:{origins:[],profileScrollOffset:0,profileCache:new Cache(),profileSession:0},boardStore:{boardDetail:undefined,boardReturnUrl:'',boardReturnPage:'',rootTab:0,boardOpeningToken:0},pinStore:{detail:undefined,detailOpeningPin:'',detailPin:'',detailScrollOffset:44,detailCache:{put(){}},rememberDetailOrigin(){}},inboxStore:{},searchStore:{},
rootTabAddresses:new Map([[3,own]]),tabsController:{changeIndex(){}},returnCoordinator:{cancel(){}},pageHistory:new History(),pagePerformance:{mark(){},begin(){},beginSecondary(){}},rootContextCoordinator:{notify(){}},finishProfilePull(){},
profileUrlFromAddress:profileAddress,boardUrlFromAddress:url=>/\/[^/]+\/[^/]+\/$/.test(url)&&!url.includes('/pin/')&&!profileAddress(url)?url:'',extractPinUrl:url=>/\/pin\/\d+\/$/.test(url)?url:'',pinIdentity:url=>url.match(/\/pin\/(\d+)\//)?.[1]||'',
nativeRootPageAddress:()=>'',rootPresentationAddress:()=>h.activeTab===3?own:home,nativeBusinessSessionContext:()=>session,
controller:{getUrl(){throw Error('native visitor flow must not read hidden document route');},loadUrl(){throw Error('hidden navigation prohibited');},runJavaScript(){throw Error('hidden JS prohibited');}},
boardNativeReads:{pause(){},demand(){opens.push(['board',h.boardStore.boardDetail?.pageKey]);}},detailNativeReads:{owned:()=>!!h.pinStore.detailPin},inboxMessagesNativeReads:{demand(){}},inboxUpdatesNativeReads:{demand(){}},
clearRootTabGuard(){},syncFloatingTabsMotion(){},closeProfilePanel(){h.profileStore.panel=undefined;},clearDetail(){h.pinStore.detail=undefined;h.pinStore.detailOpeningPin='';h.pinStore.detailPin='';},
clearProfile(){h.profileNativeReads.pause();h.profileStore.profile=undefined;h.profileStore.profileUrl='';h.profileStore.profileLoading=false;h.profileStore.profileScrollOffset=0;},
beginDetailOpening(p,source,returning){h.nativeBackTarget='';h.nativeRootOnly=false;h.navigationAddress=p;h.pinStore.detailPin=p;h.pinStore.detail={pinUrl:p};opens.push(['pin',p,source,returning]);},
profileActionsController:{scheduleOpen(){},openPanel(mode,section){opens.push(['panel',mode,section]);h.profileStore.panel={mode,section,page:h.currentProfileUrl()};}},coordinatorTasks:{wait:async()=>true,timeout(){}},rejectOfflineAction:()=>false,traceAction(){},searchUrlFromAddress:()=>'',restoreRetainedSearch(){},backOnePage(){throw Error('legacy return');},showMessage:m=>{throw Error(m);},nativeNetwork:{cancel(){},requestBusinessProfileRead(job,s,p,id,current){assert(current());return new Promise(resolve=>requests.push({job,resolve:body=>resolve({...job,status:200,error:'',body})}));}},
profileNativeActions:{restore(panel){h.profileStore.panel=panel;}},
openCustomHomeMenu:async(...args)=>menus.push(args),ensureRootActionContext(){throw Error('menu must not prepare a Web document');},prepareProfileInteraction(){throw Error('profile menu must be native');},homeStore:{home:{pageKey:home,pins:[{id:'home11',pinUrl:pin}]}},homeMenuReady:()=>true,isCurrentSearchMenuPin:()=>true});
const init=index.match(/private readonly profileNativeReads: PinmonyProfileNativeReads = new PinmonyProfileNativeReads\(\{([\s\S]*?)\n  \} as PinmonyProfileNativeReadsPorts\);/);assert(init);
const bind=vm.runInNewContext(ts.transpileModule('(function(){this.profileNativeReads=new PinmonyProfileNativeReads({'+init[1]+'});})',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyProfileNativeReads:Reader});bind.call(h);
return{h,requests,opens,menus};}
const body=(data)=>JSON.stringify({resource_response:{status:'success',code:0,data,bookmark:'-end-'},client_context:{user:{id:'42'}}}),flush=()=>new Promise(setImmediate);
async function settle(f,name='visitor'){f.requests.at(-1).resolve(body({id:'99',type:'user',username:name,full_name:name,explicitly_followed_by_me:false}));await flush();f.requests.at(-1).resolve(body([]));await flush();}
async function main(){
for(const section of ['activity','messages','contacts']) {
  const f=fixture(),h=f.h,searchBack=()=>true;
  h.activeTab=2;h.inboxStore.listSection=section;h.inboxStore.listSearchBack=searchBack;
  h.inboxStore.inboxScrollOffset=188;h.nativeDisplayAddress=()=>origin+'/inbox/';
  h.openUserProfile(page);await settle(f);h.backFromUserProfile();
  assert.equal(h.profileStore.origins.length,0);
  assert.equal(h.activeTab,2);assert.equal(h.inboxStore.listSection,section);
  assert.equal(h.inboxStore.listSearchBack,searchBack,'retain mounted list search and navigation state');
  assert.equal(h.inboxStore.inboxScrollOffset,188);
}
for (const parentChat of [false, true]) {
  const f=fixture(),h=f.h,flow={screen:'chat',pageUrl:origin+'/inbox/',conversationId:'synthetic-chat'};
  h.inboxMessagesNativeReads.ownsFlow=()=>true;
  h.activeTab=parentChat?3:2; h.profileChatActive=parentChat;
  if(parentChat){h.openUserProfile(page);await settle(f);h.profileStore.profileScrollOffset=155;h.profileChatActive=true;}
  h.inboxStore.inboxFlow=flow;h.inboxStore.chatScrollOffset=240;
  const depth=h.profileStore.origins.length;
  h.openUserProfile(parentChat?page:own,false,true);
  assert(h.chatProfileTransition && h.chatProfileVisible,'chat avatar mounts animated profile independently of root route');
  assert.equal(h.chatProfileDepth,depth+1);assert.equal(h.profileChatActive,false);
  assert.equal(h.inboxStore.inboxFlow,flow);assert.equal(h.inboxStore.chatReturnConversation,flow.conversationId);
  h.openUserProfile(page,false,true);assert.equal(h.profileStore.origins.length,depth+1,'duplicate tap cannot push another profile');
  await settle(f,parentChat?'visitor':'sample');
  h.backFromUserProfile();assert.equal(h.chatProfileVisible,false);
  assert.equal(h.profileStore.origins.length,depth+1,'keep profile state until exit animation completes');
  h.backFromUserProfile();await new Promise(resolve=>setTimeout(resolve,210));
  assert.equal(h.profileStore.origins.length,depth);assert.equal(h.chatProfileTransition,false);
  assert.equal(h.profileChatActive,parentChat);assert.equal(h.inboxStore.inboxFlow,flow);
  assert.equal(h.inboxStore.chatScrollOffset,240,'avatar navigation preserves chat scroll');
  if(parentChat)assert.equal(h.profileStore.profileScrollOffset,155,'restore parent profile below its chat');
}
assert(index.includes('onUser: (url: string) => this.openUserProfile(url, false, true)'));
assert(index.includes('if (this.chatProfileTransition && this.chatProfileVisible &&'));
assert(index.includes(".accessibilityLevel(this.chatProfileTransition ? 'no-hide-descendants' : 'auto')"));
const staleChat=fixture();staleChat.h.activeTab=2;
staleChat.h.inboxStore.inboxFlow={screen:'chat',pageUrl:origin+'/inbox/',conversationId:'synthetic-stale'};
staleChat.h.inboxMessagesNativeReads.ownsFlow=()=>true;
staleChat.h.openUserProfile(page,false,true);await settle(staleChat);
staleChat.h.backFromUserProfile();staleChat.h.nativeBusinessSessionContext().generation++;
await new Promise(resolve=>setTimeout(resolve,210));
assert.equal(staleChat.h.profileStore.origins.length,1,'old account generation cannot pop a new session navigation');
const chatProfile=fixture();chatProfile.h.activeTab=2;chatProfile.h.inboxStore.inboxFlow={screen:'chat'};const selfPage=chatProfile.h.authenticatedProfileUrl;assert(selfPage);chatProfile.h.openUserProfile(selfPage);assert.equal(chatProfile.h.profileStore.origins.length,1,'own profile shared in chat must open as a child');assert.equal(chatProfile.requests.length,1);await settle(chatProfile,selfPage.split('/')[3]);
const f=fixture(),h=f.h;h.openUserProfile(page);assert.equal(h.profileStore.origins[0].page,home);assert.equal(h.currentProfileUrl(),page);assert.equal(f.requests.length,1);await settle(f);assert.equal(h.profileStore.profile.displayName,'visitor');
h.profileStore.profileScrollOffset=170;h.openUserProfile(origin+'/second/');await settle(f,'second');h.backFromUserProfile();await flush();assert.equal(h.currentProfileUrl(),page);assert.equal(h.profileStore.profile.displayName,'visitor');assert.equal(h.profileStore.profileScrollOffset,170);assert.equal(f.requests.length,4,'native back reuses the verified visitor route');
h.profileStore.profile.boards=[{id:'b',targetUrl:board,title:'Board'}];await h.openProfileBoard('b');assert.equal(f.opens.at(-1)[0],'board');assert.equal(h.nativeDisplayAddress(),board);assert.equal(h.currentProfileUrl(),'');h.backFromBoard();await flush();assert.equal(h.currentProfileUrl(),page);assert.equal(h.profileStore.origins.length,1);
h.profileStore.profile.createdPins=[{id:'p',targetUrl:pin}];await h.performProfileAction('p');assert.deepEqual(f.opens.at(-1).slice(0,2),['pin',pin]);assert.equal(h.currentPinUrl(),pin);h.returnToNativeProfile(page);await flush();assert.equal(h.currentProfileUrl(),page);
h.profileStore.profile.createdPins=[{id:'p',targetUrl:pin}];await h.openProfilePinMenu('p');assert.equal(f.menus.at(-1)[0],pin);h.backFromUserProfile();assert.equal(h.profileStore.origins.length,0);assert.equal(h.activeTab,0);assert.equal(h.nativeDisplayAddress(),home);
const fromPin=fixture();Object.assign(fromPin.h,{nativeRootOnly:false,navigationAddress:pin,nativeBackTarget:origin+'/search/pins/?q=sample'});fromPin.h.pinStore.detailPin=pin;fromPin.h.pinStore.detail={pinUrl:pin};fromPin.h.boardStore.boardDetail={pageKey:board};fromPin.h.openUserProfile(page);assert(fromPin.h.pinStore.detail,'retain detail during profile entry');assert.equal(fromPin.requests.length,0,'profile reads wait for detail handoff');await new Promise(resolve=>setTimeout(resolve,200));assert(!fromPin.h.pinStore.detail,'release detail after entry');await settle(fromPin);fromPin.h.backFromUserProfile();assert.equal(fromPin.h.detailProfileReturning,true,'raise profile before restoring detail');fromPin.h.backFromUserProfile();assert.equal(fromPin.h.profileStore.origins.length,1,'repeated back must not skip the prepared frame');await new Promise(resolve=>setTimeout(resolve,30));assert.equal(fromPin.opens.at(-1)[0],'pin','return to a Pin must not stop on its underlying board');assert.equal(fromPin.opens.at(-1)[3],true,'return from profile must resume the existing Pin without replaying its entrance');assert.equal(fromPin.h.boardStore.boardDetail.pageKey,board);await new Promise(resolve=>setTimeout(resolve,230));assert.equal(fromPin.h.detailProfileReturning,false,'release return layer after exit');
const searchUser=fixture(),usersPage=origin+'/search/users/?q=fixture';Object.assign(searchUser.h,{activeTab:1,navigationAddress:usersPage,nativeRootOnly:true,currentSearchPageKey:()=>usersPage,searchUrlFromAddress:u=>u.includes('/search/')?u:'',clearRootTabGuard(){this.nativeRootOnly=false;},nativeRootPageAddress:()=>origin+'/search/',commitNativeSearchReturn(target){this.searchReturned=target;this.rootTabAddresses.set(1,target);this.navigationAddress=target;this.nativeBackTarget='';this.nativeRootOnly=true;}});
searchUser.h.openUserProfile(page);assert.equal(searchUser.h.profileStore.origins[0].page,usersPage,'save filtered search before root guard changes its visible address');await settle(searchUser);searchUser.h.backFromUserProfile();assert.equal(searchUser.h.searchReturned,usersPage);assert.equal(searchUser.h.navigationAddress,usersPage);assert.equal(searchUser.h.nativeRootOnly,true);assert.equal(searchUser.h.nativeBackTarget,'');
const following=fixture();following.h.openUserProfile(page);await settle(following);following.h.profileStore.panel={page,mode:'following',section:'boards'};following.h.openProfilePanelBoard(board);assert.equal(following.h.profileStore.panel,undefined);assert.equal(following.h.followingBoardReturn.section,'boards');following.h.backFromBoard();assert.equal(following.h.immediateFollowingReturn,true,'board return restores following without an entrance transition');assert.equal(following.h.profileStore.panel.mode,'following');assert.equal(following.h.profileStore.panel.section,'boards');assert.equal(following.h.boardStore.boardDetail,undefined);assert.equal(following.h.followingBoardReturn,undefined,'return context is consumed');following.h.closeProfilePanel();assert.equal(following.h.profileStore.panel,undefined,'next back may close the following panel normally');
for(const mode of ['followers','following']) { const x=fixture(); x.h.openUserProfile(page); await settle(x); const panel={page,mode,section:'users',items:[],scrollOffset:80}; x.h.profileStore.panel=panel; x.h.openUserProfile(origin+'/second/'); assert.equal(x.h.retainedProfilePanel,panel,'preserve the original list instance on entry'); assert(x.h.panelProfileVisible); await settle(x,'second'); x.h.backFromUserProfile(); assert.equal(x.h.panelProfileVisible,false,'remove only child profile for exit'); assert.equal(x.h.retainedProfilePanel,panel,'keep list mounted during exit'); x.h.backFromUserProfile(); await new Promise(resolve=>setTimeout(resolve,210)); assert.equal(x.h.profileStore.panel,panel,'restore original list after exit'); assert.equal(x.h.retainedProfilePanel,undefined); }
const stale=fixture();stale.h.openUserProfile(page);await settle(stale);stale.h.profileStore.panel={page,mode:'following',section:'boards'};stale.h.openProfilePanelBoard(board);stale.h.followingBoardReturn.generation++;stale.h.backFromBoard();assert(!stale.h.profileStore.panel,'old account generation cannot reopen a following panel');
const menus=fixture();await menus.h.openHomeMore('home11');menus.h.searchStore.search={pageKey:origin+'/search/pins/?q=test'};await menus.h.openSearchPinMenu(pin);assert.equal(menus.menus.length,2);
console.log('Native profile navigation: actual Index reader binding, root/Pin/profile origins, nested return/scroll, profile Pin and board opening/return, underlying board preservation, and photo-menu intents without hidden Web passed');
}
main().catch(e=>{console.error(e);process.exitCode=1});
