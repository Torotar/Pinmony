const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const root='https://www.pinterest.com/',requests=[],messages=[],timers=[],events={};
const window={top:null,PinmonyHomeApiEnabled:true,PinmonyShareBridge:{homeState:value=>messages.push(JSON.parse(value))},addEventListener:(name,fn)=>{(events[name] ||= []).push(fn);}};window.top=window;
const location={origin:root.slice(0,-1),hostname:'www.pinterest.com',pathname:'/',href:root};
const context={window,location,URL,AbortController,Date,console:{warn(){},info(){}},setInterval:()=>0,clearTimeout(){},setTimeout:fn=>{timers.push(fn);return timers.length;},fetch:(url,options)=>new Promise(resolve=>requests.push({url,options,resolve}))};
function script(file){const template=fs.readFileSync(file,'utf8').match(/`([\s\S]*?)`;/)[1];return Function('return `'+template+'`')();}
vm.runInNewContext(script('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets')+script('feature_home/src/main/ets/services/PinmonyHomeScript.ets'),context);
const publish=()=>timers.splice(0).filter(fn=>fn.name==='publish').forEach(fn=>fn());
publish();assert.equal(requests.length,0,'document startup has no authenticated identity');
assert.equal(window.PinmonyHomeDemand(root+'pin/1/'),false);assert.equal(requests.length,0);
window.PinmonyHomeSetUsername('synthetic');publish();assert.equal(requests.length,2,'current identity starts All feed and categories independently of DOM layout');
window.PinmonyHomeDemand(root);publish();assert.equal(requests.length,2,'same request is adopted without duplicate reads');
events.pagehide.forEach(fn=>fn({persisted:true}));assert(requests.every(r=>r.options.signal.aborted),'freeze cancels unfinished reads');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const opening=fs.readFileSync('entry/src/main/ets/app/PinmonyDetailOpeningCoordinator.ets','utf8');
assert.match(opening,/!this\.pinStore\.detailOpeningPin/);assert.match(fs.readFileSync('entry/src/main/ets/components/PinmonyHomeRootContent.ets','utf8'),/feedActive:[^\n]*!view\.pinStore\.detailOpeningPin/);
assert(!fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeScript.ets','utf8').includes('querySelector'),'API-only home does not depend on DOM controls');
console.log('Home demand: real API-only bridge, identity gate, before-layout parallel reads, deduplication, freeze cancellation and detail-opening prefetch guard passed');
