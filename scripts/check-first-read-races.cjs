const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
function script(p){return Function('return `'+fs.readFileSync(p,'utf8').match(/`([\s\S]*?)`;/)[1]+'`')();}
async function main(){
 const page='https://www.pinterest.com/fixture_owner/';const messages=[],listeners={};
 const window={PinmonyNativeNetworkEnabled:true,PinmonyReadMergingEnabled:false,addEventListener(k,f){(listeners[k]||=[]).push(f);},fetch(){throw Error('Web fallback forbidden');},PinmonyShareBridge:{networkRequest:v=>messages.push(JSON.parse(v)),cancelNetwork(){throw Error('expired proxy');}}};window.top=window;
 const location={href:page,origin:'https://www.pinterest.com',hostname:'www.pinterest.com',pathname:'/fixture_owner/'};
 const context={window,location,document:{hidden:true},URL,Headers,Response,AbortController,Map,Set,Promise,setTimeout,clearTimeout,console};
 vm.runInNewContext(script('common_network/src/main/ets/PinmonyNetworkScript.ets'),context);
 assert.equal(window.PinmonyNetwork.isReady(),false);
 const queued=window.PinmonyNetwork.fetch('/resource/UserResource/get/');assert.equal(messages.length,0);
 window.PinmonyNetwork.setForeground(true);window.PinmonyNetwork.bind(1,page);assert.equal(window.PinmonyNetwork.isReady(),true);assert.equal(messages.length,1);
 const cancel=assert.rejects(queued,e=>e.name==='AbortError'&&e.pinmonyCancelled===true);
 window.PinmonyNetwork.bind(2,page);await cancel;
 const controller=new AbortController();const timed=window.PinmonyNetwork.fetch('/resource/UserResource/get/',{signal:controller.signal});const timedReject=assert.rejects(timed,e=>e.name==='AbortError'&&e.pinmonyCancelled===false);controller.abort();await timedReject;
 const jobs=[],states=[],calls=[];let ready=false;
 const host={setInterval(){},PinmonyNativeNetworkEnabled:true,PinmonyProfileApiEnabled:true,PinmonyNetwork:{isReady:()=>ready},PinmonyShareBridge:{profileState:v=>states.push(JSON.parse(v))},addEventListener(){},PinmonyProfileApi:{read(){calls.push('read');return {kind:'loading'};}}};host.top=host;
 vm.runInNewContext(script('feature_profile/src/main/ets/services/PinmonyProfileScript.ets'),{window:host,location,document:{readyState:'complete',documentElement:{},querySelectorAll:()=>[]},MutationObserver:class{observe(){}},URL,setTimeout(fn){jobs.push(fn);return jobs.length;},clearTimeout(){},console,navigator:{language:'zh'},innerHeight:1000});
 host.setInterval=()=>{};
 while(jobs.length)jobs.shift()();assert.equal(calls.length,0,'profile does not begin before native binding');
 ready=true;host.PinmonyProfileDemand(page);assert.equal(calls.length,1,'binding wakes first read');assert.equal(states.at(-1).kind,'apiPending');
 console.log('First-read regressions: hidden document queues transport, epoch cancellation differs from timeout, profile waits for binding and wakes once');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
