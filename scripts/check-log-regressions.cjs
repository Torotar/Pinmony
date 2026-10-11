const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const {runtime}=require('./return-coordinator-harness.cjs');
const flush=()=>new Promise(resolve=>setImmediate(resolve));
async function main(){
  let now=0,pending=true,loads=0,confirm=0,throws=false;
  const timers=[],events=[];
  const {PinmonyReturnCoordinator}=runtime(ts,{Date:{now:()=>now},setTimeout(fn,ms){timers.push({fn,ms});return timers.length;},clearTimeout(){}});
  const page='https://www.pinterest.com/search/pins/?q=design';
  const coordinator=new PinmonyReturnCoordinator({isCurrent:()=>true,isPending:()=>pending,isHome:()=>false,isBoard:()=>false,
    documentMatches:()=>false,runScript(){if(throws)throw Error('controller unavailable');return Promise.resolve('false');},
    useHistory:()=>true,load(){loads++;},confirm(){confirm++;},cancelHistory(){events.push('cancel');},mark:s=>events.push(s)});
  coordinator.synchronize(page,1,false,true);
  assert.equal(timers[0].ms,2500,'history receives a bounded grace period before fallback');
  coordinator.navigationBegun(page);now=2500;timers.shift().fn();
  assert.equal(loads,0,'in-progress target navigation is not superseded');
  pending=false;timers.shift().fn();await flush();assert.equal(loads,0);
  coordinator.synchronize(page,2,false,true);pending=true;throws=true;now+=2500;timers.shift().fn();await flush();
  assert.equal(loads,1,'synchronous platform failure reaches the one fallback instead of unhandled rejection');
  throws=false;coordinator.synchronize(page,3,false,true);coordinator.navigationBegun(page);now+=6000;timers.shift().fn();await flush();
  assert.equal(loads,2,'navigation progress cannot postpone recovery forever');assert.equal(confirm,0);
  const exported={};vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinmonyNetworkScript.ets','utf8'),
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:exported});
  const listeners={},messages=[],doc={hidden:false},location={origin:'https://www.pinterest.com',href:page};
  const window={PinmonyNativeNetworkEnabled:true,fetch(){throw Error('unexpected fallback');},addEventListener(k,fn){listeners[k]=fn;},
    PinmonyShareBridge:{networkRequest(raw){messages.push(JSON.parse(raw));},cancelNetwork(){throw Error('expired native object');}}};
  window.top=window;
  vm.runInNewContext(exported.PIN_NATIVE_NETWORK_SCRIPT,{window,document:doc,location,URL,Headers,Response,Map,Set,AbortController,Promise,setTimeout,clearTimeout,console});
  window.PinmonyNetwork.setForeground(true);window.PinmonyNetwork.bind(1,page);
  doc.hidden=true;listeners.visibilitychange();
  assert(window.PinmonyNetwork.isForeground(),'hidden Web rendering does not mean native app background');
  const read=window.PinmonyNetwork.fetch('/resource/BoardInvitesResource/get/');
  assert.equal(messages.length,1);const settled=assert.rejects(read,{name:'AbortError'});
  window.PinmonyNetwork.setForeground(false);await settled;
  assert.equal(window.PinmonyNetwork.isForeground(),false);
  await assert.rejects(window.PinmonyNetwork.fetch('/resource/BoardInvitesResource/get/'),{name:'AbortError'});
  window.PinmonyNetwork.setForeground(true);window.PinmonyNetwork.bind(2,page);
  const last=window.PinmonyNetwork.fetch('/resource/BoardInvitesResource/get/');const detached=assert.rejects(last,{name:'AbortError'});
  listeners.pagehide();await detached;
  const routeListeners={},routeMessages=[];
  const routeWindow={PinmonyShareBridge:{pageNavigation(...args){routeMessages.push(args);},pageBack(){throw Error('expired object');}},addEventListener(k,fn){routeListeners[k]=fn;}};
  routeWindow.top=routeWindow;
  const nav=fs.readFileSync('entry/src/main/ets/app/PinmonyNavigationScript.ets','utf8').match(/`([\s\S]*)`;/)[1];
  const history={pushState(){},replaceState(){},back(){return 'history';},go(){}};
  vm.runInNewContext(nav,{window:routeWindow,location,history,document:{querySelectorAll:()=>[],addEventListener(){}},console});
  const count=routeMessages.length;routeListeners.pagehide();history.replaceState();assert.equal(routeMessages.length,count);
  routeListeners.pageshow({persisted:true});assert.equal(routeMessages.at(-1)[1],'restore');assert.equal(history.back(),'history');
  const ability=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');
  assert(ability.indexOf('PinmonyRuntimeLog.initialize(this.context.filesDir)')<ability.indexOf("PinmonyRuntimeLog.info('RuntimeBuild:"));
  console.log('Device-log regressions: bounded navigation progress, synchronous rejection, hidden-Web native reads, background cancellation, expired proxies and startup identity passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
