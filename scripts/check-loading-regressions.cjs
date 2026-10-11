const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm');
const ts=require(process.argv[2]||'typescript');
const {runtime}=require('./return-coordinator-harness.cjs');
const flush=()=>new Promise(r=>setImmediate(r));
async function main(){
 const timers=[],events=[];let loads=0,histories=0,pending=true;
 const {PinmonyReturnCoordinator}=runtime(ts,{setTimeout(fn,ms){timers.push({fn,ms});return timers.length;},clearTimeout(){}});
 const home='https://www.pinterest.com/';
 const c=new PinmonyReturnCoordinator({isCurrent:()=>true,isPending:()=>pending,isHome:p=>p===home,isBoard:()=>false,documentMatches:()=>false,runScript:()=>Promise.resolve('false'),useHistory(){histories++;return true;},load(){loads++;},confirm(){},cancelHistory(){},mark:v=>events.push(v)});
 c.synchronize(home,1,false,true);assert.equal(histories,1);assert.equal(loads,0);assert(events.includes('return.history.used'));
 pending=false;timers.shift().fn();await flush();assert.equal(loads,0,'confirmed history return must not reload');
 const source=fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeApiScript.ets','utf8');
 const script=Function('return `'+source.match(/`([\s\S]*?)`;/)[1]+'`')();
 const jobs=[],requests=[],warnings=[];let changed=0;
 const location={hostname:'www.pinterest.com',pathname:'/',href:home,origin:home.slice(0,-1)};
 const window={PinmonyHomeApiEnabled:true,PinmonyHomeUsername:'fixture_owner',PinmonyHomeDemand(){changed++;}};window.top=window;
 vm.runInNewContext(script,{window,location,URL,AbortController,console:{warn:v=>warnings.push(v)},setTimeout(fn,ms){jobs.push({fn,ms});return jobs.length;},clearTimeout(){},fetch(url,opt){requests.push({url,opt});return new Promise(()=>{});}});
 window.PinmonyHomeApi.initialTabs();assert.equal(requests.length,1);jobs.find(v=>v.ms===15000).fn();
 assert.equal(window.PinmonyHomeApi.savedTabsFailed(),true,'timeout ends category loading');assert.equal(changed,1);assert(requests[0].opt.signal.aborted);assert(warnings.includes('HomeCategoryTrace: timeout'));
 window.PinmonyHomeApi.initialTabs();assert.equal(requests.length,1,'failure does not automatically replay');
 window.PinmonyHomeApi.retrySavedTabs();assert.equal(requests.length,2,'explicit retry creates a new read');
 const bridgeSource=fs.readFileSync('feature_home/src/main/ets/services/PinmonyHomeScript.ets','utf8');
 const bridgeScript=Function('return `'+bridgeSource.match(/`([\s\S]*?)`;/)[1]+'`')();
 const callbacks=[],listeners={},out=[];let broken=true;
 const host={PinmonyHomeApiEnabled:true,addEventListener(k,fn){(listeners[k] ||= []).push(fn);},history:{pushState(){},replaceState(){}},
 PinmonyHomeApi:{identityReady:()=>true,savedTabsReady:()=>true,savedTabsFailed:()=>false,initialTabs:()=>[],reset(){},read:()=>({active:true,pins:[],ended:true})}};host.top=host;
 Object.defineProperty(host,'PinmonyShareBridge',{get(){if(broken)throw Error('expired proxy');return {homeState:v=>out.push(v)};}});
 vm.runInNewContext(bridgeScript,{window:host,location,console:{warn(){}},setTimeout(fn){callbacks.push(fn);return callbacks.length;},clearTimeout(){},setInterval(){}});
 callbacks.shift()();assert.equal(out.length,0,'proxy failure is contained');broken=false;
 listeners.pagehide.forEach(fn=>fn());host.PinmonyHomeDemand(home);while(callbacks.length)callbacks.shift()();assert.equal(out.length,0,'departed document cannot publish');
 listeners.pageshow.forEach(fn=>fn({persisted:true}));host.PinmonyHomeDemand(home);while(callbacks.length)callbacks.shift()();assert.equal(out.length,1,'resumed current document retries failed delivery');
 const idx=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');assert(idx.includes('!this.profileStore.profile.contentLoading'));assert(idx.includes('homePersistSignature'));
 console.log('Loading regressions: history reuse, category timeout and explicit retry, latest read cancellation; device timing excluded');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
