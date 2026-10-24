const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(name){const start=source.search(new RegExp('  private (?:async )?'+name+'\\('));assert(start>=0,name);return source.slice(start,source.indexOf('\n  private ',start+1));}
function field(name){const start=source.indexOf('  private readonly '+name+':'),end=source.indexOf('\n  private ',start+1);assert(start>=0);return source.slice(start,end).trim().replace(/^private readonly /,'this.').replace(/: [A-Za-z]+ = /,' = ');}
const flag={PinmonyRouteParser:require('./product-coordination-harness.cjs').runtime(ts).loadFile('entry/src/main/ets/app/PinmonyRouteParser.ets').PinmonyRouteParser,PIN_NATIVE_DETAIL_READS_ENABLED:true,PIN_NATIVE_BOARD_READS_ENABLED:true,PIN_NATIVE_PROFILE_READS_ENABLED:true,PIN_NATIVE_SEARCH_READS_ENABLED:true,PIN_NATIVE_HOME_READS_ENABLED:true,PIN_NATIVE_SEARCH_DISCOVERY_ENABLED:true,PIN_NATIVE_INBOX_UPDATES_ENABLED:true,PIN_BOARD_API_ENABLED:true,PIN_POST_API_ENABLED:true,PINTEREST_URL:'https://www.pinterest.com/',PinmonyRuntimeLog:{info(){},warn(){}}};
const ports={};class Home{constructor(store,p){ports.home=p;}}class Search{constructor(store,p){ports.search=p;}}
const output={};vm.runInNewContext(ts.transpileModule('export class Host{'+['searchUrlFromAddress','commitNativeSearchReturn','completeNativeBack','openNativeSearchResult','openInboxBoard','previewBoardInvitation','performSearchQuizAction','openDetailTagSearch','openImageRelated'].map(method).join('\n')+'} export function bind(){'+['homeController','searchController'].map(field).join('\n')+'}',{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:output,...flag,PinmonyHomeController:Home,PinmonySearchController:Search});
const origin='https://www.pinterest.com',home=origin+'/',search=origin+'/search/pins/?q=art',pin=origin+'/pin/11/',board=origin+'/peer/board/',profile=origin+'/peer/',inbox=origin+'/inbox/';
function fixture(){const h=new output.Host(),events=[];Object.assign(h,{authStatus:'authenticated',activeTab:1,businessSuspended:false,activeSheetKind:'',nativeBackTarget:'',nativeRootOnly:true,pageBackToken:0,
 shouldKeepSearchRootMounted:()=>true,nativeSearchPageVisible:()=>true,nativeBusinessSessionContext:()=>({authenticated:true,accountId:'synthetic',generation:1,origin}),rootTabAddresses:new Map(),homeStore:{},profileStore:{origins:[]},searchStore:{searchLoading:false,search:{pageKey:search,results:[{targetUrl:pin,enabled:true},{targetUrl:board,enabled:true},{targetUrl:profile,enabled:true}],quiz:{mode:'entry',cards:[]}},searchCache:{put(){}},searchScrollOffset:67},pinStore:{detailPrefetch:{pause(){}}},inboxStore:{inboxSession:0},boardStore:{boardOpeningToken:0},
 selectNativeRootTab(i){h.activeTab=i;events.push(['tab',i]);},searchDiscoveryNativeReads:{demand(){}},returnCoordinator:{cancel(){}},pageHistory:{visit:(...a)=>events.push(['history',...a]),cancelBack(){}},tabsController:{changeIndex:i=>events.push(['tab',i])},pagePerformance:{beginSecondary(){}},
 extractPinUrl:url=>/\/pin\/\d+\/$/.test(url)?url:'',boardUrlFromAddress:url=>url===board?board:'',profileUrlFromAddress:url=>url===profile?profile:'',rootTabIndexFromAddress:url=>url===home?0:url.startsWith(origin+'/search/')?1:url===inbox?2:url===profile?3:-1,
 returnToNativeProfile:url=>{if(url===profile){events.push(['profile-back',url]);return true;}return false;},clearDetail(){h.pinStore.detail=undefined;h.pinStore.detailOpeningPin='';h.pinStore.detailPin='';},
 beginDetailOpening:(url,parent)=>events.push(['pin',url,parent]),openUserProfile:url=>events.push(['user',url]),syncBoardRoute:url=>events.push(['board-route',url]),boardNativeReads:{demand:()=>events.push(['board-read']),pause(){}},syncFloatingTabsMotion(){},
 presentNativeBackTarget:url=>{h.clearDetail();events.push(['present',url]);},inboxMessagesNativeReads:{ownsFlow:()=>true,demand:()=>events.push(['chat-read'])},inboxUpdatesNativeReads:{},
 currentInboxUrl:()=>inbox,currentBoardUrl:()=>h.boardStore.boardDetail?.pageKey||'',nativeBoardVisible:()=>false,clearRootTabGuard(){},rejectOfflineAction:()=>false,traceAction(){},coordinatorTasks:{timeout(){throw Error('legacy timeout');}},
 searchNativeReads:{demand(){events.push(['search-read']);},pause(){},eligible:()=>true,quizAction:async(k,id)=>events.push(['quiz',k,id]),navigate:url=>events.push(['search',url])},
 controller:{loadUrl(){throw Error('hidden navigation');},getUrl(){throw Error('hidden route read');},runJavaScript(){throw Error('hidden script');}},readBoardInvitations:preview=>events.push(['invitation',preview]),boardInvitationController:{preparePreview:item=>{h.inboxStore.boardInvitationPreview=item;return true;}},showMessage:m=>events.push(['message',m])
});output.bind.call(h);return {h,events};}
async function main(){
 const f=fixture();ports.home.openPin(pin,home);assert.deepEqual(f.events.find(e=>e[0]==='pin'),['pin',pin,home]);
 ports.search.navigateResult(board,search);assert.equal(f.h.nativeBackTarget,board);assert.equal(f.h.boardStore.boardReturnUrl,search);assert(f.events.some(e=>e[0]==='board-read'));
 ports.search.navigateResult(profile,search);assert(f.events.some(e=>e[0]==='user'));
 ports.search.navigateResult(pin,search);assert(f.events.some(e=>e[0]==='pin'&&e[2]===search));
 const n=f.events.length;ports.search.navigateResult(origin+'/pin/99/',search);assert.equal(f.events.length,n,'unknown target must not navigate');
 for(const target of [home,search,inbox,pin,board,profile]){const r=fixture();assert(r.h.completeNativeBack(target));assert(r.events.length>0);assert(!r.h.pageHistory.isPending?.());}
 const r=fixture();r.h.inboxStore.retainedChat={screen:'chat',pageUrl:inbox,conversationId:'17'};assert(r.h.completeNativeBack(inbox));assert.equal(r.h.inboxStore.inboxFlow.conversationId,'17');assert.equal(r.h.nativeRootOnly,false);assert(r.events.some(e=>e[0]==='chat-read'));
 const c=fixture();c.h.activeTab=2;c.h.inboxStore.inboxFlow={screen:'chat',session:0,pageUrl:inbox,messages:[{id:'8',board:{id:'81',url:board,title:'Board'}}]};c.h.openInboxBoard('8');assert.equal(c.h.boardStore.boardReturnUrl,inbox);assert.equal(c.h.nativeBackTarget,board);assert(c.events.some(e=>e[0]==='board-read'));
 const i=fixture();i.h.previewBoardInvitation({boardId:'81',boardUrl:board,boardName:'Art'});assert.equal(i.h.nativeBackTarget,board);assert(i.events.some(e=>e[0]==='invitation'&&e[1]));
 const q=fixture();await q.h.performSearchQuizAction('topic','0');assert(q.events.some(e=>e[0]==='quiz'));
 console.log('Native remaining navigation: actual Index home/search ports, validated Pin/board/user results, chat/invitation boards, root/Pin/board/profile return and quiz actions without hidden Web passed');
}
main().then(backgroundDocument).catch(e=>{console.error(e);process.exitCode=1});

async function backgroundDocument(){
 const {createArktsLoader}=require('./arkts-module-loader.cjs'),auth=url=>/\/(?:login|signup|logout)(?:\/|$)/.test(url),logs=[];
 const loader=createArktsLoader(ts,{'common_foundation':{PinmonyRuntimeLog:{info:v=>logs.push(v),warn(){}}},'common_session':{isPinterestAuthRoute:auth},'@kit.ArkWeb':{}});
 const Lifecycle=loader.loadFile('entry/src/main/ets/app/PinmonyWebLifecycleCoordinator.ets').PinmonyWebLifecycleCoordinator;
 let epoch=7,url=home,loading=false,begins='',beginAt=0,sync=0,invalidates=0;const data={detail:{pinUrl:pin},shareSession:8};
 const ports={homeStore:()=>({}),searchStore:()=>({}),inboxStore:()=>({}),profileStore:()=>({}),pinStore:()=>data,nativeBusinessOnly:()=>true,authStatus:()=> 'authenticated',controller:()=>({getUrl:()=>url}),
 authEpoch:()=>epoch,setAuthEpoch:v=>epoch=v,lastDocumentBeginUrl:()=>begins,setLastDocumentBeginUrl:v=>begins=v,lastDocumentBeginAt:()=>beginAt,setLastDocumentBeginAt:v=>beginAt=v,webPageLoading:()=>loading,setWebPageLoading:v=>loading=v,
 nativeNetwork:()=>({invalidateDocument:()=>invalidates++}),setWebPageLoadFinishedAt(){},syncAuthentication:()=>sync++,navigationBegun(){throw Error('business route reset');},ignoreSupersededDetailDocument(){throw Error('business guard');},logPageLifecycle(){throw Error('legacy page end');}};
 const l=new Lifecycle(ports);l.pageBegin(home);assert.equal(epoch,8);assert.equal(invalidates,1);assert.equal(data.shareSession,8);assert.equal(data.detail.pinUrl,pin);l.pageEnd();assert.equal(sync,1);assert(!loading);
 l.pageBegin(board);assert.equal(epoch,8,'late event for a different hidden document ignored');
 l.mainFrameError(home,-2,'network');assert.equal(data.detail.pinUrl,pin);assert(logs.some(v=>v.includes('failure ignored')));
 // Authentication navigation must still reach the existing login/expiry lifecycle.
 url=origin+'/login/';assert.throws(()=>l.pageBegin(url),/business route reset/);

 const Nav=loader.loadFile('entry/src/main/ets/app/PinmonyNavigationCoordinator.ets').PinmonyNavigationCoordinator;let back=0;
 const n=new Nav({boardStore:()=>({}),homeStore:()=>({}),searchStore:()=>({}),inboxStore:()=>({}),profileStore:()=>({}),pinStore:()=>({}),nativeBusinessOnly:()=>true,showNativeSheet:()=>false,activeSheetKind:()=>'',currentPinUrl:()=>'',returnFromSearchQuiz:()=>false,backInProgress:()=>false,pageHistory:()=>({isPending:()=>false}),backOnePage:()=>{back++;return true;},setLastRootBackAt(){},controller:()=>({runJavaScript(){throw Error('Web back probe prohibited');}})});
 await n.handleBack();assert.equal(back,1);
 assert(source.includes('nativeBusinessOnly: (): boolean => this.nativeBusinessRoutesEnabled'));
 assert(source.includes("if(this.nativeBusinessRoutesEnabled && this.authStatus === 'authenticated' && !isPinterestAuthRoute(url)){this.syncAuthentication();return;}"));
}
