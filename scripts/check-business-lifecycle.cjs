const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const searchRuntime=require('./search-controller-harness.cjs').createSearchRuntime(ts);
const src=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8'),a=src.indexOf('  private businessSuspended:'),b=src.indexOf('  private pageBackToken:',a);
const Host=require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Host {'+src.slice(a,b)+'}\nHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){},flush(){return Promise.resolve()}}});
const h=new Host(),events=[];Object.assign(h,{activeTab:1,authStatus:'authenticated',activeSheetKind:'',tabRequestToken:1,pendingWebTab:1,rootReadToken:1,homeRecoveryToken:0,pinStore:{videoForeground:true,detailPrefetch:{pause(){events.push('pause')}}},nativeNetwork:{setForeground(v){events.push(['network',v]);return v}},detailReadNetwork:{setForeground(v){events.push(['detail',v]);return false},invalidate(){}},controller:{runJavaScript:async()=>true},logPageLifecycle(){},rootActionContextReady(){return false},requestRootPage(i){events.push(['root',i])},scheduleInterruptedHomeRecovery(){},retryDetailApi(){events.push('retry')}});
h.profileActionsController={pause(){},resume(){},reset(){}};h.profileReadController={pause(){},resume(){}};h.postPanelsController={pause(){},resume(){}};h.boardStateController={pause(){},resume(){}};h.boardInvitationController={pause(){},resume(){},reset(){},clearPreview(){}};h.publishController={pause(){},resume(){}};h.boardStore={};h.returnCoordinator={cancel(){}};h.boardCollaboratorsController={pause(){}};
h.searchStore=new searchRuntime.Store();searchRuntime.bindIndex(h);require('./home-controller-harness.cjs').createHomeRuntime(ts).bindIndex(h);
require('./controller-lifecycle-harness.cjs').bind(h,ts);
h.onPageHide();assert.equal(h.businessSuspended,true);assert.equal(h.pendingWebTab,-1);assert.equal(h.tabRequestToken,2);h.onPageShow();assert.equal(h.businessSuspended,false);assert.equal(events.filter(e=>Array.isArray(e)&&e[0]==='root').length,1);h.onPageShow();assert.equal(events.filter(e=>Array.isArray(e)&&e[0]==='root').length,1,'duplicate foreground never repeats root preparation');
h.activeSheetKind='save';h.onPageHide();h.onPageShow();assert.equal(events.filter(e=>Array.isArray(e)&&e[0]==='root').length,1,'write panel cannot trigger implicit reload/replay');
function method(start,next){return src.slice(src.indexOf(start),src.indexOf(next,src.indexOf(start)));}
let now=1000;const timers=[],notices=[];
const ReturnHost=require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class ReturnHost {'+
  method('  private presentNativeBackTarget(', '  private returnToHistoryEntry(')+
  method('  private rootReadInFlight(', '  private requestRootPage(')+
  method('  private waitForWebTabConfirmation(', '  private async refreshWebNavigation(')+'}\nReturnHost;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
  {Date:{now:()=>now},setTimeout:cb=>timers.push(cb),PinmonyRuntimeLog:{info(){},warn(){}}});
const r=new ReturnHost(),home='https://www.pinterest.com/';
Object.assign(r,{pinStore:{detail:{}},tabRequestToken:0,profileStore:{origins:[]},homeStore:{},inboxStore:{},searchStore:{},
  detailReadCache:{setPin(){}},
  extractPinUrl(){return ''},pinIdentity(v){return v},clearRootTabGuard(){},rootTabIndexFromAddress(){return 0},
  clearDetail(){this.pinStore.detail=undefined},profileUrlFromAddress(){return ''},inboxUrlFromAddress(){return ''},
  searchUrlFromAddress(){return ''},isHomeRootAddress(){return true},prepareHomeForPageBegin(){},tabsController:{changeIndex(){}},
  boardUrlFromAddress(){return ''},
  controller:{getUrl(){return home}},
  rootActionContextReady(){return false},pageHistory:{key:v=>v},loadFailed:false,webPageLoading:true,
  showMessage(v){notices.push(v)}});
require('./medium-priority-controller-harness.cjs').bindWork(r, ts, {Date:{now:()=>now},setTimeout:cb=>timers.push(cb),clearTimeout(){}});
r.boardStore = {}; r.pagePerformance={begin(){}}; r.rootTabIndexFromAddress=()=>0;
r.presentNativeBackTarget(home);
assert.equal(r.rootReadInFlight(0,home),true,'return preparation is shared with root content demand');
assert.equal(r.rootReadInFlight(0,home+'search/'),false,'a different target cannot join return preparation');
now+=12001;timers.shift()();
assert.equal(r.pendingWebTab,-1,'web loading cannot hold root preparation forever');
assert.equal(r.rootReadToken,-1);assert.equal(notices.length,1);
const source=fs.readFileSync('common_network/src/main/ets/PinmonyNetworkScript.ets','utf8'),tick=String.fromCharCode(96),script=Function('return '+source.slice(source.indexOf(tick),source.lastIndexOf(tick)+1))();
async function bridge(){const messages=[],cancel=[];const env={document:{hidden:false},location:{origin:'https://www.pinterest.com',href:'https://www.pinterest.com/search/'},URL,Headers,Response,Map,Promise,setTimeout,clearTimeout,Math,PinmonyNativeNetworkEnabled:true,addEventListener(){},fetch(){throw Error('web fallback')},PinmonyShareBridge:{networkRequest(v){messages.push(JSON.parse(v))},cancelNetwork(id){cancel.push(id)}}};env.window=env;env.top=env;require('./product-coordination-harness.cjs').run(ts,script,env);env.PinmonyNetwork.bind(1,env.location.href);const read=env.PinmonyNetwork.fetch('/resource/BaseSearchResource/get/',{method:'POST'});const write=env.PinmonyNetwork.fetch('/resource/ApiResource/delete/',{method:'POST'});const rejected=read.catch(e=>e.name);env.PinmonyNetwork.setForeground(false);assert.equal(await rejected,'AbortError');assert.equal(cancel.length,1);assert.equal(cancel[0],messages[0].id);await assert.rejects(env.PinmonyNetwork.fetch('/resource/ApiResource/delete/',{method:'POST'}),{name:'AbortError'});env.PinmonyNetwork.complete({id:messages[1].id,epoch:1,page:env.location.href,status:200,body:'{}',headers:{},url:'https://www.pinterest.com/resource/ApiResource/delete/'});assert.equal((await write).status,200);env.PinmonyNetwork.setForeground(true);assert.equal(messages.length,2,'resume never replays write');console.log('Business foreground, current-root recovery, bridge POST reads and write no-replay passed');}
bridge().catch(e=>{console.error(e);process.exitCode=1});
