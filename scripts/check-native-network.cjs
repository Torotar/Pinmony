const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const flush = () => new Promise(resolve => setImmediate(resolve));
async function until(predicate) {
  const deadline = Date.now() + 2000;
  while (!predicate()) {
    assert(Date.now() < deadline, 'asynchronous body stream did not complete');
    await new Promise(resolve => setTimeout(resolve, 5));
  }
}
function compiled(file, requireFn) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: requireFn, console, Promise, setTimeout, clearTimeout, Math });
  return exports;
}
const requests = [], writes = [], sessions = [], requestSessions = [];
const runtimeLogs = [];
let response = { statusCode: 200, headers: {}, toString: () => JSON.stringify({ resource_response: { status: 'success', data: [] } }) };
let readCookie = async () => 'session=synthetic; csrftoken=synthetic';
class Credentials {
  read(url) { return readCookie(url); }
  async update(url, cookies, current) { for(const cookie of cookies) { assert(current()); writes.push({url,cookie}); } }
}
const rcp = {
  Request: class { constructor(url,method,headers,content) { Object.assign(this,{url,method,headers,content}); } },
  createSession(config) {
    const session = { cancelled:false, closed:false, config,
      async fetch(req) { requests.push(req); requestSessions.push(session); return typeof response === 'function' ? response(req) : response; },
      cancel() { session.cancelled=true; }, close() { session.closed=true; } };
    sessions.push(session); return session;
  }
};
const policy = compiled('common_network/src/main/ets/PinmonyRequestPolicy.ets', () =>
  ({PinmonyRuntimeLog:{info(message){runtimeLogs.push({level:'info',message});},warn(message){runtimeLogs.push({level:'warn',message});}}}));
const { PinmonyNativeNetwork, NetworkManager, RequestScheduler, Priority, acceptsNetworkJob } = compiled('common_network/src/main/ets/PinmonyNativeNetwork.ets', name =>
  name === './PinmonyRequestPolicy' ? policy :
  name === 'common_session' ? {PinmonySessionCredentials:Credentials} : name === 'common_foundation' ?
    {PinmonyRuntimeLog:{info(message){runtimeLogs.push({level:'info',message});},warn(message){runtimeLogs.push({level:'warn',message});}}} : {rcp});
const {PIN_NATIVE_NETWORK_SCRIPT,useNativeTransport} = compiled('common_network/src/main/ets/PinmonyNetworkScript.ets',()=>({}));
const native = new PinmonyNativeNetwork();
const state = { authenticated:true,epoch:3,page:'https://www.pinterest.com/',userAgent:'synthetic-agent' };
const base = { id:'test',epoch:3,page:state.page,url:'https://www.pinterest.com/resource/UserHomefeedResource/get/?data=synthetic',method:'GET',headers:{Accept:'application/json'},body:'' };
async function main() {
  const documentGuard = new PinmonyNativeNetwork();
  documentGuard.pending.add('web-document'); documentGuard.pending.add('native_board_1');
  documentGuard.pending.add('native_search_discovery_1');
  documentGuard.invalidateDocument();
  assert.equal(documentGuard.pending.has('web-document'), false);
  assert.equal(documentGuard.pending.has('native_board_1'), true, 'hidden navigation preserves account-owned board read');
  assert.equal(documentGuard.pending.has('native_search_discovery_1'), true);
  documentGuard.invalidate(); assert.equal(documentGuard.pending.size, 0, 'full session invalidation still cancels native jobs');

  const sectionState = { ...state, page: 'https://www.pinterest.com/sample/board/' };
  const sectionOptions = { board_id: '123', name: 'New section', initial_pins: [] };
  const sectionBody = options => 'source_url=' + encodeURIComponent('/board/123/create_section/') +
    '&data=' + encodeURIComponent(JSON.stringify({ options, context: {} }));
  const sectionJob = { ...base, page: sectionState.page,
    url: 'https://www.pinterest.com/resource/BoardSectionResource/create/', method: 'POST',
    headers: { 'X-Pinterest-Pws-Handler': 'www/board/[id]/create_section.js' }, body: sectionBody(sectionOptions) };
  assert(acceptsNetworkJob(sectionJob, sectionState), 'captured empty section creation is admitted');
  assert(!acceptsNetworkJob({ ...sectionJob, body: sectionBody({ ...sectionOptions, initial_pins: ['111'] }) }, sectionState));
  assert(!acceptsNetworkJob({ ...sectionJob, body: sectionBody({ ...sectionOptions, extra: true }) }, sectionState));
  assert(!acceptsNetworkJob({ ...sectionJob, headers: {} }, sectionState));
  assert(!acceptsNetworkJob({ ...sectionJob, url: sectionJob.url.replace('/create/', '/delete/') }, sectionState));
  assert(!acceptsNetworkJob({ ...sectionJob, body: sectionBody({ ...sectionOptions, board_id: '999' }) }, sectionState));
  const regionalState = {...state, page:'https://uk.pinterest.com/'};
  const regionalJob = {...base, page:regionalState.page, url:base.url.replace('www.pinterest.com','uk.pinterest.com')};
  assert(acceptsNetworkJob(regionalJob, regionalState), 'regional same-origin resource is allowed');
  assert(!acceptsNetworkJob(regionalJob, state), 'regional job cannot borrow canonical document ownership');
  assert(!acceptsNetworkJob({...regionalJob,url:base.url},regionalState), 'cross-region request remains blocked');
  assert(!acceptsNetworkJob({...regionalJob,url:regionalJob.url.replace('uk.pinterest.com','uk.pinterest.com.evil.example')},regionalState));
  const regionalLocation = {origin:'https://uk.pinterest.com',hostname:'uk.pinterest.com',href:regionalState.page};
  const regionalWindow = {addEventListener(){},PinmonyNativeNetworkEnabled:true,
    fetch(){throw Error('regional Web fallback forbidden');},PinmonyShareBridge:{
      networkRequest(raw){native.request(JSON.parse(raw),()=>regionalState).then(reply=>regionalWindow.PinmonyNetwork.complete(reply));},
      cancelNetwork(id){native.cancel(id);}}};
  regionalWindow.top=regionalWindow;
  vm.runInNewContext(PIN_NATIVE_NETWORK_SCRIPT,{window:regionalWindow,location:regionalLocation,URL,Headers,Response,Map,Set,AbortController,Promise,setTimeout,clearTimeout,console});
  assert(regionalWindow.PinmonyNetwork, 'regional document installs native transport');
  regionalWindow.PinmonyNetwork.setForeground(true);
  regionalWindow.PinmonyNetwork.bind(regionalState.epoch,regionalState.page);
  const cookieUrls=[];const savedCookieReader=readCookie;
  readCookie=async url=>{cookieUrls.push(url);return 'session=synthetic; csrftoken=synthetic';};
  response={statusCode:200,headers:{'content-type':'application/json','set-cookie':'session=synthetic; Secure'},toString:()=>'{"regional":true}'};
  const regionalReply=await regionalWindow.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/');
  assert.equal((await regionalReply.json()).regional,true);
  const regionalRequest=requests.at(-1);
  assert.equal(regionalRequest.url,'https://uk.pinterest.com/resource/UserHomefeedResource/get/');
  assert.equal(regionalRequest.headers.Origin,'https://uk.pinterest.com');
  assert.equal(regionalRequest.headers.Referer,regionalState.page);
  assert.equal(cookieUrls.at(-1),regionalRequest.url);
  assert.equal(writes.at(-1).url,regionalRequest.url);
  assert.equal(regionalReply.headers.get('set-cookie'),null);
  const regionalSnapshots=[];
  regionalWindow.PinmonyHomeApiEnabled=true;
  regionalWindow.PinmonyShareBridge.homeState=raw=>regionalSnapshots.push(JSON.parse(raw));
  regionalLocation.pathname='/';
  const regionalHomeContext={window:regionalWindow,location:regionalLocation,URL,Headers,Response,Map,Set,AbortController,Promise,setTimeout,clearTimeout,setInterval(){},console};
  const regionalHomeApi=compiled('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets',()=>({}));
  const regionalHomeBridge=compiled('feature_home/src/main/ets/services/PinmonyHomeScript.ets',()=>({}));
  response=req=>({statusCode:200,headers:{'content-type':'application/json'},toString:()=>JSON.stringify({resource_response:{status:'success',data:
    req.url.includes('BoardsFeedResource') ? [] : [{id:'12345',type:'pin',title:'regional fixture',images:{orig:{url:'https://i.pinimg.com/originals/fixture.jpg',width:600,height:900}}}]}})});
  vm.runInNewContext(useNativeTransport(regionalHomeApi.PIN_HOME_API_SCRIPT),regionalHomeContext);
  vm.runInNewContext(regionalHomeBridge.PIN_HOME_BRIDGE_SCRIPT,regionalHomeContext);
  regionalWindow.PinmonyHomeSetUsername('fixture_owner');
  regionalWindow.PinmonyHomeDemand(regionalState.page);
  await until(()=>regionalSnapshots.some(snapshot=>snapshot.pins?.length));
  assert.equal(regionalSnapshots.at(-1).dataSource,'api');
  assert.equal(regionalSnapshots.at(-1).pins[0].id,'12345');
  assert(requests.some(req=>req.url.startsWith('https://uk.pinterest.com/resource/UserHomefeedResource/')));
  regionalWindow.PinmonyHomePauseForReturn();
  readCookie=savedCookieReader;
  response={statusCode:200,headers:{},toString:()=>JSON.stringify({resource_response:{status:'success',data:[]}})};
  requests.length=0;writes.length=0;sessions.length=0;requestSessions.length=0;NetworkManager.destroy();
  for (const name of ['BoardInvitesResource', 'BoardInviteResource']) {
    const invite = {...base, url: 'https://www.pinterest.com/resource/' + name + '/get/?data=synthetic'};
    assert(acceptsNetworkJob(invite, state), 'documented invitation read is admitted');
    assert(!acceptsNetworkJob({...invite, method:'POST'}, state));
    assert(!acceptsNetworkJob({...invite, epoch:2}, state));
    assert(!acceptsNetworkJob({...invite, url:invite.url.replace('/get/', '/delete/')}, state));
  }
  const inviteBody = options => 'source_url=%2F&data=' + encodeURIComponent(JSON.stringify({options, context:{}}));
  const inviteWrite = {...base, method:'POST', url:'https://www.pinterest.com/resource/BoardInviteResource/update/',
    body:inviteBody({board_id:'123',invited_user_id:'456'})};
  assert(acceptsNetworkJob(inviteWrite, state), 'documented acceptance with only the two IDs is admitted');
  assert(!acceptsNetworkJob({...inviteWrite,body:inviteBody({board_id:'123',invited_user_id:'456',status:'declined'})},state));
  assert(!acceptsNetworkJob({...inviteWrite,body:inviteBody({board_id:'123'})},state));
  const scheduler = new RequestScheduler(1), order = [];
  let releaseBlocker;
  const blocker = scheduler.enqueue(Priority.NORMAL, () => new Promise(resolve => { releaseBlocker = resolve; order.push('blocker'); }));
  await flush();
  const low = scheduler.enqueue(Priority.LOW, async () => { order.push('low'); return 'low'; });
  const high = scheduler.enqueue(Priority.HIGH, async () => { order.push('high'); return 'high'; });
  releaseBlocker();
  await Promise.all([blocker, low, high]);
  assert.deepEqual(order, ['blocker', 'high', 'low'], 'queued requests are drained by priority');
  let helperRetryCalls = 0;
  const retryResponse = await NetworkManager.requestWithRetry(
    { fetch: async () => ({ statusCode: ++helperRetryCalls < 3 ? 500 : 200 }) },
    { method: 'GET' }, 2, 0);
  assert.equal(retryResponse.statusCode,200); assert.equal(helperRetryCalls,3,'GET 5xx uses bounded retries');
  let postCalls = 0;
  const postResponse = await NetworkManager.requestWithRetry(
    { fetch: async () => ({ statusCode: ++postCalls < 2 ? 500 : 200 }) },
    { method: 'POST' }, 2, 0);
  assert.equal(postResponse.statusCode,500); assert.equal(postCalls,1,'POST responses are never replayed');
  await assert.rejects(NetworkManager.requestWithRetry(
    { fetch: async () => ({ statusCode: 503 }) }, { method: 'GET' }, 1, 0), 'retry exhaustion is an exception');
  assert(acceptsNetworkJob({...base, url:'https://www.pinterest.com/resource/VisualSearchFlashlightUnifiedResource/get/?data=synthetic'}, state), 'captured visual-search resource is allowed by native transport');
  assert(acceptsNetworkJob({...base, method:'POST', url:'https://www.pinterest.com/resource/ConversationMessagesResource/create/'}, state), 'confirmed chat send reaches native transport');
  assert(!acceptsNetworkJob({...base, method:'POST', url:'https://www.pinterest.com/resource/ConversationMessagesResource/delete/'}, state), 'unconfirmed message resource operations stay blocked');
  const cookieCalls=[];
  const {PinmonySessionCredentials:ActualCredentials}=compiled('common_session/src/main/ets/services/PinmonySessionCredentials.ets',()=>({webview:{WebCookieManager:{
    fetchCookie:async url=>{cookieCalls.push({url,read:true});return 'session=synthetic';},
    configCookie:async (...args)=>cookieCalls.push({args})
  }}}));
  const actualCredentials=new ActualCredentials();
  await assert.rejects(actualCredentials.read('https://evil.example/'));
  const expires='session=synthetic; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/; Secure; HttpOnly';
  await actualCredentials.update(base.url,[expires],()=>true);
  assert.deepEqual(Array.from(cookieCalls[0].args),[base.url,expires,false,true],'Set-Cookie attributes and HttpOnly survive synchronization');
  await assert.rejects(actualCredentials.update(base.url,['session=stale'],()=>false));
  assert.equal(cookieCalls.length,1,'invalidated cookie updates are not dispatched');
  for (const bad of [ {...base,url:'https://evil.example/resource/UserHomefeedResource/get/'},
    {...base,url:'https://www.pinterest.com.evil.example/resource/UserHomefeedResource/get/'},
    {...base,url:'https://www.pinterest.com/resource/UnknownResource/create/',method:'POST'},
    {...base,epoch:2}, {...base,page:state.page+'search/'}, {...base,body:'x'.repeat(262145)} ]) {
    assert.equal(acceptsNetworkJob(bad,state),false); await native.request(bad,()=>state);
  }
  assert.equal(requests.length,0,'invalid jobs never reach the network');
  await native.request(base,()=>state);
  assert.equal(requests[0].headers.Cookie,'session=synthetic; csrftoken=synthetic');
  assert.equal(requests[0].headers['User-Agent'],'synthetic-agent');
  assert.equal(sessions[0].config.requestConfiguration.transfer.autoRedirect,false);
  assert.equal(sessions.length,1,'all requests reuse one application session');
  assert.equal(sessions[0].closed,false,'request completion does not close the shared session');
  assert.equal(sessions[0].config.requestConfiguration.tracing.collectTimeInfo,true,'Session timing collection is enabled');
  const beforePreConnect = requests.length;
  await NetworkManager.preConnect('https://www.pinterest.com');
  assert.equal(requests[beforePreConnect].connectOnly,true,'startup pre-connect uses connectOnly');
  assert.equal(requestSessions[beforePreConnect],requestSessions[0],'preconnect and business calls use the same Session object');
  response = { statusCode:200,headers:{'set-cookie':['session=new-synthetic; Path=/; Secure; HttpOnly']},toString:()=>'{"ok":true}' };
  const write = await native.request({...base,id:'write',url:'https://www.pinterest.com/resource/RepinResource/create/',method:'POST',body:'data=synthetic'},()=>state);
  assert.equal(requests.at(-1).headers['X-CSRFToken'],'synthetic');
  assert.equal(requestSessions.at(-1),requestSessions[beforePreConnect]);
  assert(runtimeLogs.some(log => log.message.includes('connection-context sharedSession=true') && log.message.includes('preconnect=ok')));
  assert.equal(writes.length,1); assert.equal(write.body,'{"ok":true}');
  const suspendCalls = requests.length;
  const suspendedResolvers = {};
  response = req => new Promise(resolve => { suspendedResolvers[req.url.includes('RepinResource') ? 'POST' : 'GET'] = resolve; });
  const pendingRead = native.request({...base,id:'background-read',method:'POST'},()=>state);
  const pendingWrite = native.request({...base,id:'background-write',url:'https://www.pinterest.com/resource/RepinResource/create/',method:'POST',body:'data=synthetic'},()=>state);
  await until(()=>suspendedResolvers.GET && suspendedResolvers.POST);
  native.setForeground(false);
  const blocked = await native.request({...base,id:'background-new'},()=>state);
  assert.equal(blocked.error,'background');assert.equal(requests.length,suspendCalls+2,'background requests do not dispatch');
  suspendedResolvers.GET({statusCode:200,headers:{},toString:()=>'{"read":true}'});
  suspendedResolvers.POST({statusCode:200,headers:{},toString:()=>'{"write":true}'});
  assert.equal((await pendingRead).error,'cancelled');assert.equal((await pendingWrite).status,200,'already sent write can finish once');
  assert.equal(native.setForeground(true),true);assert.equal(requests.length,suspendCalls+2,'resume never replays writes');
  let suspendedCookieReady; const oldReadCookie = readCookie; const beforeUnsent = requests.length;
  readCookie = () => new Promise(resolve => { suspendedCookieReady = resolve; });
  const unsentWrite = native.request({...base,id:'unsent-write',url:'https://www.pinterest.com/resource/RepinResource/create/',method:'POST',body:'data=synthetic'},()=>state);
  await flush();native.setForeground(false);suspendedCookieReady('session=synthetic; csrftoken=synthetic');
  assert.equal((await unsentWrite).error,'cancelled');assert.equal(requests.length,beforeUnsent,'unsent write is revoked on background');
  native.setForeground(true);readCookie=oldReadCookie;
  let done;
  response = () => new Promise(resolve=>done=resolve);
  const late = native.request({...base,id:'late'},()=>state); await flush();
  native.invalidate(); done({ statusCode:200,headers:{'set-cookie':['session=stale']},toString:()=>'{"stale":true}' });
  assert.equal((await late).error,'cancelled'); assert.equal(writes.length,1,'stale responses cannot replace cookies');
  let cookieReady;
  readCookie=()=>new Promise(resolve=>cookieReady=resolve);
  const waiting=native.request({...base,id:'waiting'},()=>state);
  native.cancel('waiting'); cookieReady('session=synthetic');
  const before=requests.length; assert.equal((await waiting).error,'cancelled'); assert.equal(requests.length,before);
  readCookie=async ()=>'session=synthetic; csrftoken=synthetic';
  const guarded = new PinmonyNativeNetwork();
  const guardedJob=guarded.request({...base,id:'cleanup-exception'},()=>state);await flush();
  const cleanupSession=sessions.at(-1);
  cleanupSession.cancel=()=>{throw new Error('synthetic cancel failure');};
  cleanupSession.close=()=>{cleanupSession.closed=true;throw new Error('synthetic close failure');};
  assert.doesNotThrow(()=>guarded.invalidate(),'SDK cleanup errors must not escape navigation callbacks');
  assert.equal(cleanupSession.closed,false,'per-request invalidation does not close the shared session');
  done({statusCode:200,headers:{},toString:()=>'{"late":true}'});
  assert.equal((await guardedJob).error,'cancelled');
  NetworkManager.destroy();
  const create=rcp.createSession;rcp.createSession=()=>{throw new Error('synthetic create failure');};
  assert.equal((await guarded.request({...base,id:'create-exception'},()=>state)).error,'network-unavailable');
  rcp.createSession=create;

  let webRequests=0, messages=[], cancelled=[];
  const location={ origin:'https://www.pinterest.com',hostname:'www.pinterest.com',href:state.page };
  const window={ addEventListener() {}, PinmonyNativeNetworkEnabled:true,fetch:()=>{webRequests++;return Promise.resolve(new Response('{}'));},
    PinmonyShareBridge:{ networkRequest(raw) {
      const job=JSON.parse(raw);messages.push(job);
      native.request(job,()=>state).then(reply=>window.PinmonyNetwork.complete(reply));
    },cancelNetwork(id){cancelled.push(id);native.cancel(id);} } };
  window.top=window;
  vm.runInNewContext(PIN_NATIVE_NETWORK_SCRIPT,{window,location,URL,Headers,Response,Map,Set,AbortController,Promise,setTimeout,clearTimeout,console});
  // Put an observer outside the transport, as the production auth/contract scripts do.
  let observed=0;const wrapped=window.fetch;
  window.fetch=(url,init)=>wrapped(url,init).then(async res=>{
    assert(res instanceof Response, 'website fetch observers require a real Response');
    assert(res.headers instanceof Headers);
    const copy=res.clone(); assert.notEqual(copy,res); assert.equal(copy.url,res.url);
    await copy.arrayBuffer(); assert.equal(copy.bodyUsed,true); assert.equal(res.bodyUsed,false);
    observed++;return res;
  });
  response={statusCode:200,headers:{'content-type':'application/json','set-cookie':'session=synthetic; Secure'},toString:()=>'{"value":1}'};
  const waitingJS=window.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/',{headers:{Cookie:'must-not-cross',Authorization:'must-not-cross','X-CSRFToken':'must-not-cross'}});
  assert.equal(messages.length,0,'requests wait for current login confirmation');
  window.PinmonyNetwork.bind(3,state.page);
  const result=await waitingJS;assert.equal((await result.json()).value,1);
  assert.equal(result.headers.get('content-type'),'application/json');
  assert.equal(result.headers.get('set-cookie'),null,'credentials never cross into the synthetic response');
  assert.equal(result.bodyUsed,true);
  await assert.rejects(result.json(),'a Response body can only be consumed once');
  assert.equal(observed,1,'native response reaches existing observers');
  assert.equal(webRequests,0);assert.deepEqual(messages[0].headers,{});
  const controller=new AbortController();response=()=>new Promise(resolve=>done=resolve);
  const abort=window.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/',{signal:controller.signal});
  await flush();controller.abort();await assert.rejects(abort,e=>e.name==='AbortError');
  done({statusCode:200,headers:{},toString:()=>'{"late":1}'});await flush();
  assert.equal(cancelled.length,1);assert.equal(webRequests,0,'cancelled requests never replay in Web');
  response={statusCode:403,headers:{},toString:()=>'<html>denied</html>'};
  const denied=await window.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/');
  assert.equal(denied.status,403);await assert.rejects(denied.json());assert(state.authenticated,'HTTP 403 is not logout evidence');
  assert.equal(webRequests,0);
  // A transient TLS/peer receive failure retries one GET, while writes never replay.
  let transient = true, retryCalls = 0;
  response = () => { retryCalls++; if (transient) { transient = false; const error = new Error('tls'); error.code = 1007900035; throw error; } return {statusCode:200,headers:{},toString:()=>'{"ok":true}'}; };
  const retried = await native.request(base,()=>state);
  assert.equal(retryCalls,2); assert.equal(retried.status,200);
  let detailRetryCalls = 0;
  response = () => { detailRetryCalls++; return { statusCode: 503, headers: {}, toString: () => '{}' }; };
  const detailFailure = await native.request({ ...base, id: 'detail-retry-bound',
    url: 'https://www.pinterest.com/resource/PinResource/get/?data=synthetic' }, () => state);
  assert.equal(detailRetryCalls, 2, 'detail GET retries at most once');
  assert.equal(detailFailure.error, 'network-unavailable');
  // A retry notification may invalidate the page synchronously; the stale
  // request must not be dispatched a second time after that callback.
  const retryGuard = new PinmonyNativeNetwork();
  let guardedCalls = 0;
  response = () => { guardedCalls++; const error = new Error('tls'); error.code = 1007900035; throw error; };
  retryGuard.onTransientRetry = () => retryGuard.invalidate();
  const skipped = await retryGuard.request({...base,id:'retry-context-change'},()=>state);
  assert.equal(guardedCalls,1,'stale retry is not dispatched after the retry callback invalidates the context');
  assert.equal(skipped.error,'cancelled');
  const logMessages = runtimeLogs.map(entry => entry.message);
  assert(logMessages.some(message => message.includes('NetworkTrace: session-created generation=')), 'shared Session creation is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: session-reused generation=')), 'shared Session reuse is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: session-destroy generation=')), 'shared Session destruction is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: preconnect-start')), 'pre-connect start is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: preconnect-ok connectOnly=true')), 'pre-connect success is logged');
  assert(logMessages.some(message => message.includes('protocol=unknown dnsMs=-1 connectMs=-1 tlsMs=-1 preTransferMs=-1 firstByteMs=-1 totalTransferMs=-1 redirectMs=-1')), 'protocol and timing fields are logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: retry kind=http method=GET')), 'HTTP retry is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: retry kind=transport method=GET')), 'transport retry is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: retry-skip method=POST')), 'POST retry suppression is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: queue-start priority=HIGH')), 'HIGH queue dispatch is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: queue-start priority=LOW')), 'LOW queue dispatch is logged');
  assert(logMessages.some(message => message.includes('NetworkTrace: queue-finish')), 'queue completion is logged');
  const authMessages=[];
  window.PinmonyShareBridge.authState=value=>authMessages.push(JSON.parse(value));
  const authSource=fs.readFileSync('common_session/src/main/ets/services/PinmonyAuthScript.ets','utf8');
  const authScript=Function('return `'+authSource.match(/= `([\s\S]*?)`;/)[1]+'`')();
  vm.runInNewContext(authScript,{window,location,URL,document:{getElementById:()=>null,addEventListener(){}},console});
  window.PinmonyAuthSync(3);
  response={statusCode:200,headers:{},toString:()=>'{"client_context":{"is_authenticated":false}}'};
  await window.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/');await until(()=>authMessages.length > 0);
  assert.equal(authMessages.at(-1).status,'unauthenticated','native response remains a source of explicit session evidence');
  window.PinmonyNativeNetworkEnabled=false;
  await window.PinmonyNetwork.fetch('/resource/UserHomefeedResource/get/');
  assert.equal(webRequests,1,'explicit manual transport rollback uses the original Web path');
  window.PinmonyNativeNetworkEnabled=true;webRequests=0;
  // Exercise an actual business API script through the native adapter, including mapping.
  const homeSource=fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets','utf8');
  const homeScript=Function('return `'+homeSource.match(/`([\s\S]*?)`;/)[1]+'`')();
  const fixture=JSON.parse(fs.readFileSync('scripts/fixtures/home-api.json','utf8'));
  window.PinmonyHomeApiEnabled=true;
  response={statusCode:200,headers:{},toString:()=>JSON.stringify(fixture)};
  vm.runInNewContext(useNativeTransport(homeScript),{window,location,document:{getElementById:()=>null},AbortController,setTimeout,clearTimeout,console});
  window.PinmonyHomeApi.read('home',true,()=>{},()=>true);
  await until(()=>window.PinmonyHomeApi.read('home',true,()=>{},()=>true).pins.length > 0);
  assert(window.PinmonyHomeApi.read('home',true,()=>{},()=>true).pins.length>0,'native JSON still maps through the current business contract');
  assert.equal(webRequests,0);
  // Exercise the real search scripts through JS transport, native admission and RCP.
  state.page = 'https://www.pinterest.com/search/';
  location.href = state.page; location.pathname = '/search/'; location.search = '';
  window.PinmonyNetwork.bind(state.epoch, state.page);
  window.PinmonySearchDiscoveryApiEnabled = true; window.PinmonySearchUiApiEnabled = true;
  const searchSource = name => {
    const source = fs.readFileSync('feature_search/src/main/ets/services/' + name + '.ets', 'utf8');
    return Function('return ' + source.match(/SCRIPT: string = (\x60[\s\S]*\x60);/)[1])();
  };
  const searchContext = { window, location, URL, URLSearchParams, AbortController,
    document: { cookie: '' }, setTimeout, clearTimeout, console };
  response = { statusCode: 200, headers: {}, toString: () => JSON.stringify({ data: {
    v3SearchTabHandlerQuery: { data: { connection: { edges: [{ node: { storyId: 'synthetic-topic', story_type: 'slp_search_recommendation',
      title: { format: '测试主题' }, action: { url: '/search/pins/?q=test' },
      objects: [{ imageMediumUrl: 'https://i.pinimg.com/236x/synthetic.jpg' }] } }],
      pageInfo: { endCursor: null, hasNextPage: false } } } }
  } }) };
  vm.runInNewContext(useNativeTransport(searchSource('PinmonySearchDiscoveryApiScript')), searchContext);
  const discovery = () => window.PinmonySearchDiscoveryApi.read(state.page, () => {});
  discovery(); await until(() => discovery().active);
  assert.equal(discovery().sections[0].title, '测试主题');
  const discoveryJob = messages.find(job => job.url.includes('/_/graphql/'));
  assert(discoveryJob && acceptsNetworkJob(discoveryJob, state), 'discovery GraphQL reaches native admission');
  assert(requests.some(req => req.url.includes('/_/graphql/')), 'discovery reaches RCP');
  response = { statusCode: 200, headers: {}, toString: () => JSON.stringify({ resource_response: {
    status: 'success', data: { items: [{ query: '测试联想', type: 'recent_query' }] }
  } }) };
  vm.runInNewContext(useNativeTransport(searchSource('PinmonySearchUiApiScript')), searchContext);
  const suggestions = () => window.PinmonySearchUiApi.readSuggestions(state.page, '测试', true, () => {});
  suggestions(); await until(() => suggestions().items.length > 0);
  assert.equal(suggestions().items[0].label, '测试联想');
  assert(requests.some(req => req.url.includes('/resource/AdvancedTypeaheadResource/get/')), 'typeahead reaches RCP');
  for (const resource of ['AdvancedTypeaheadResource']) {
    const accepted = messages.find(job => job.url.includes('/resource/' + resource + '/get/'));
    assert(accepted && acceptsNetworkJob(accepted, state), resource + ' real request is admitted');
    const rejected = [
      [{ ...accepted, epoch: state.epoch - 1 }, state],
      [{ ...accepted, page: state.page + '?q=old' }, state],
      [accepted, { ...state, authenticated: false }],
      [{ ...accepted, url: accepted.url.replace('www.pinterest.com', 'evil.example') }, state],
      [{ ...accepted, method: 'POST' }, state],
      [{ ...accepted, body: 'unexpected' }, state],
      ...['create', 'update', 'delete'].map(operation => [{ ...accepted, method: 'POST',
        url: 'https://www.pinterest.com/resource/' + resource + '/' + operation + '/' }, state])
    ];
    const before = requests.length;
    for (const [job, context] of rejected) {
      assert.equal(acceptsNetworkJob(job, context), false, resource + ' rejects invalid context or operation');
      assert.equal((await native.request(job, () => context)).error, 'request-unavailable');
    }
    assert.equal(requests.length, before, 'rejected search requests never reach RCP');
  }
  window.PinmonySearchUiApi.reset(); window.PinmonySearchDiscoveryApi.reset();
  assert.equal(webRequests, 0, 'search integration never falls back to webpage fetch');
  // Run the actual board request builder through native admission and RCP, not a fetch-only stub.
  const boardSource = compiled('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets', () => ({}));
  for (const region of ['www', 'uk']) {
    const origin = 'https://' + region + '.pinterest.com';
    const boardState = { ...state, page: origin + '/fixture/board/' };
    const snapshots = [], boardJobs = [];
    const boardLocation = { origin, hostname: region + '.pinterest.com', href: boardState.page, pathname: '/fixture/board/' };
    const boardWindow = { PinmonyNativeNetworkEnabled: true, PinmonyBoardApiEnabled: true,
      addEventListener() {}, setInterval() {}, fetch() { throw Error('board Web fallback forbidden'); },
      PinmonyShareBridge: {
        boardState(raw) { snapshots.push(JSON.parse(raw)); },
        networkRequest(raw) {
          const job = JSON.parse(raw); boardJobs.push(job);
          native.request(job, () => boardState).then(reply => boardWindow.PinmonyNetwork.complete(reply));
        }, cancelNetwork(id) { native.cancel(id); }
      } };
    boardWindow.top = boardWindow;
    const boardContext = { window: boardWindow, location: boardLocation, URL, Headers, Response, Map, Set,
      AbortController, Promise, setTimeout, clearTimeout, console };
    vm.runInNewContext(PIN_NATIVE_NETWORK_SCRIPT, boardContext);
    boardWindow.PinmonyNetwork.setForeground(true);
    boardWindow.PinmonyNetwork.bind(boardState.epoch, boardState.page);
    const sectionPin = id => ({ type: 'pin', id, title: 'Section Pin', board: { id: '123' },
      images: { '474x': { url: 'https://i.pinimg.com/fixture.jpg', width: 474, height: 700 } } });
    response = req => {
      const resource = new URL(req.url).pathname.split('/')[2];
      const options = JSON.parse(new URL(req.url).searchParams.get('data')).options;
      const data = resource === 'BoardResource' ? { type: 'board', id: '123', url: '/fixture/board/',
        name: 'Board', pin_count: 2, section_count: 1, owner: { id: '700', username: 'fixture' } } :
        resource === 'BoardSectionsResource' ? [{ type: 'board_section', id: '456', title: 'Section', pin_count: 2,
          preview_pins: [{ image_medium_url: 'https://i.pinimg.com/fixture.jpg' }] }] :
        resource === 'BoardSectionPinsResource' ? [sectionPin(options.bookmarks ? '222' : '111')] : [];
      const bookmark = resource === 'BoardSectionPinsResource' && !options.bookmarks ? 'fixture-next' : '-end-';
      return { statusCode: 200, headers: {}, toString: () => JSON.stringify({
        resource_response: { status: 'success', data, bookmark }, resource: { options: { bookmarks: [bookmark] } }
      }) };
    };
    vm.runInNewContext(useNativeTransport(boardSource.PIN_BOARD_API_SCRIPT), boardContext);
    await until(() => snapshots.at(-1)?.sections?.length === 1 && snapshots.at(-1)?.ready);
    const currentBoard = () => snapshots.at(-1);
    const flow = action => boardWindow.PinmonyBoardApi.flow(currentBoard().session, currentBoard().pageKey, JSON.stringify(action));
    assert.equal(currentBoard().sectionsError, '');
    flow({ action: 'section', value: '456' });
    await until(() => currentBoard().flow.pins.length === 1 && !currentBoard().flow.loading);
    flow({ action: 'sectionMore' });
    await until(() => currentBoard().flow.pins.length === 2 && !currentBoard().flow.loading);
    assert.equal(currentBoard().flow.hasMore, false);
    for (const resource of ['BoardSectionsResource', 'BoardSectionPinsResource']) {
      const actualJobs = boardJobs.filter(job => job.url.includes('/' + resource + '/get/'));
      assert.equal(actualJobs.length, resource === 'BoardSectionsResource' ? 1 : 2);
      for (const job of actualJobs) {
        assert(acceptsNetworkJob(job, boardState), resource + ' actual builder admitted in ' + region);
        assert(requests.some(req => req.url === job.url), resource + ' reaches RCP in ' + region);
      }
      const job = actualJobs[0];
      const withOptions = options => {
        const url = new URL(job.url);
        url.searchParams.set('data', JSON.stringify({ options, context: {} }));
        return { ...job, url: url.href };
      };
      const options = JSON.parse(new URL(job.url).searchParams.get('data')).options;
      const idKey = resource === 'BoardSectionsResource' ? 'board_id' : 'section_id';
      const invalid = [
        [{ ...job, method: 'POST' }, boardState], [{ ...job, body: 'unexpected' }, boardState],
        [{ ...job, epoch: 2 }, boardState], [job, { ...boardState, authenticated: false }],
        [{ ...job, page: boardState.page + '?old' }, boardState],
        [{ ...job, url: job.url.replace(region + '.pinterest.com', 'evil.example') }, boardState],
        [{ ...job, url: job.url.replace(region + '.pinterest.com', (region === 'www' ? 'uk' : 'www') + '.pinterest.com') }, boardState],
        [{ ...job, url: job.url.replace('/get/', '/update/') }, boardState],
        [{ ...job, url: job.url.split('?')[0] + '?data=malformed' }, boardState],
        [withOptions({ ...options, [idKey]: 'invalid' }), boardState],
        [withOptions({ ...options, unexpected: true }), boardState],
        [withOptions({ ...options, ...(resource === 'BoardSectionsResource' ? { redux_normalize_feed: false } : { prepend: true }) }), boardState],
        ...(resource === 'BoardSectionPinsResource' ? [[], [''], [123], ['a', 'b'], ['x'.repeat(8193)]].map(bookmarks =>
          [withOptions({ ...options, bookmarks }), boardState]) : [])
      ];
      const before = requests.length;
      for (const [bad, context] of invalid) {
        assert.equal(acceptsNetworkJob(bad, context), false, resource + ' rejects invalid contract');
        assert.equal((await native.request(bad, () => context)).error, 'request-unavailable');
      }
      assert.equal(requests.length, before, 'invalid section jobs never reach RCP');
    }
    flow({ action: 'close' });
  }
  for(const module of ['feature_home','feature_pin','feature_search','feature_inbox','feature_profile','feature_board']) {
    for(const file of fs.readdirSync(module+'/src/main/ets/services').filter(n=>n.endsWith('Script.ets'))) {
      const s=fs.readFileSync(module+'/src/main/ets/services/'+file,'utf8');const match=s.match(/= `([\s\S]*?)`;/);
      if(match) new Function(useNativeTransport(Function('return `'+match[1]+'`')()));
    }
  }
  native.invalidate();
  console.log('Native transport, credential isolation, observers, cancellation, stale cookies and actual home/search/board sections mapping passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
