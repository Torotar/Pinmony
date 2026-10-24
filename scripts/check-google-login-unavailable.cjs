const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function compile(source,deps=()=>({}),globals={}){const out={};vm.runInNewContext(ts.transpileModule(source,{
 compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}
}).outputText,{exports:out,require: require('./local-message-test-fixture.cjs').withLocalMessages(deps),...globals});return out;}
const contract=compile(fs.readFileSync('common_session/src/main/ets/services/PinmonyGoogleLoginUnavailable.ets','utf8'));
const {PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT:script,GOOGLE_LOGIN_UNAVAILABLE_EVENT:signal,isGoogleLoginTarget}=contract;
const auth=compile(fs.readFileSync('common_session/src/main/ets/models/PinmonyAuth.ets','utf8'));
assert(auth.isPinterestAuthRoute('https://www.pinterest.com/password/reset/'));
assert(!auth.isPinterestAuthRoute('https://www.pinterest.com/password/reset-now/'));
function frame({host='accounts.google.com',path='/gsi/button',top=false,protocol='https:'}={}){
 const events=[],handlers={};let now=1000;const win={addEventListener:(name,fn,options)=>{assert.equal(options.capture,true);assert.equal(options.passive,false);handlers[name]=fn;}};
 win.top=top?win:{};
 vm.runInNewContext(script,{window:win,location:{protocol,hostname:host,pathname:path},console:{info:v=>events.push(v)},Date:{now:()=>now}});
 return {events,handlers,tick:()=>now+=1000};
}
const f=frame();
for(const type of ['pointerdown','pointerup','mousedown','mouseup','touchstart','touchend','click','keydown','keyup']){
 let prevented=0,stopped=0;f.handlers[type]({type,key:'Enter',preventDefault:()=>prevented++,stopImmediatePropagation:()=>stopped++});
 assert.equal(prevented,1,type);assert.equal(stopped,1,type);
}
assert.deepEqual(f.events,[signal],'activation duplicates are merged');
f.tick();f.handlers.keydown({type:'keydown',key:' ',preventDefault(){},stopImmediatePropagation(){}});assert.equal(f.events.length,2);
f.handlers.keydown({type:'keydown',key:'Tab',preventDefault(){throw Error('Tab must remain usable');},stopImmediatePropagation(){throw Error('Tab must remain usable');}});
for(const setup of [{top:true},{host:'www.pinterest.com',path:'/login/'},{host:'accounts.google.com.evil.test'},{path:'/signin/'},{protocol:'http:'}])
 assert.equal(Object.keys(frame(setup).handlers).length,0,'only the confirmed Google button frame is modified');
assert(!script.includes('window.open'));assert(!script.includes('credentials.get'));assert(!script.includes('cookie'));
const component=fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets','utf8');
const helpers=compile(component.split('@Builder')[0],name=>name==='common_session'?contract:{});
let hints=0;const view={controller:{},isCurrent:()=>true,visible:true,authenticated:false,onUnsupportedLogin:()=>hints++};
assert.equal(helpers.rejectGoogleLoginNavigation(view,'https://accounts.google.com/signin/?secret=token',true),true);assert.equal(hints,1);
for(const [url,main] of [['https://accounts.google.com/gsi/button',false],['https://www.pinterest.com/login/',true],['https://www.pinterest.com/password/reset/',true],['https://accounts.google.com.evil.test/',true]])
 assert.equal(helpers.rejectGoogleLoginNavigation(view,url,main),false);
for(const patch of [{visible:false},{authenticated:true},{isCurrent:()=>false}])helpers.notifyUnsupportedLogin({...view,...patch});assert.equal(hints,1);
function callback(name,fixture){const tail=component.slice(component.indexOf('.'+name+'(')+name.length+2);const end=tail.indexOf('\n            })');
 return compile('export const callback='+tail.slice(0,end)+'\n};',()=>({}),{view:fixture,...contract,...helpers}).callback;}
let lifecycleCalls=0;
view.lifecycle={consoleMessage:()=>{lifecycleCalls++;return false;},overrideUrl:()=>{lifecycleCalls++;return false;},interceptLoad:()=>{lifecycleCalls++;return false;}};
const consoleHandler=callback('onConsole',view);assert.equal(consoleHandler({message:{getMessage:()=>signal}}),true);assert.equal(hints,2);assert.equal(lifecycleCalls,0);
consoleHandler({message:{getMessage:()=>signal+' secret'}});assert.equal(hints,2);assert.equal(lifecycleCalls,1);
view.visible=false;consoleHandler({message:{getMessage:()=>signal}});assert.equal(hints,2);view.visible=true;
const override=callback('onOverrideUrlLoading',view);assert.equal(override({isMainFrame:()=>true,getRequestUrl:()=> 'https://accounts.google.com/signin/'}),true);
const intercept=callback('onLoadIntercept',view);assert.equal(intercept({data:{isMainFrame:()=>true,getRequestUrl:()=> 'https://accounts.google.com/signin/'}}),true);
assert.equal(lifecycleCalls,1,'blocked Google navigations do not start coordinator or authentication work');
assert.equal(intercept({data:{isMainFrame:()=>true,getRequestUrl:()=> 'https://www.pinterest.com/login/'}}),false);
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const methods=['showUnsupportedLogin','showNetworkNotice'].map(name=>{const start=index.indexOf('  private '+name+'(');const tail=index.slice(start);return tail.slice(0,tail.slice(1).search(/\n  private /)+1);});
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:require('./local-message-test-fixture.cjs').rawLocalMessages});
const h=new Host();let timer,scheduled=0;Object.assign(h,{authStatus:'unauthenticated',authWebVisible:()=>true,networkNotice:'',networkNoticeTimer:-1,
 pageTasks:{timeout:(fn,ms)=>{assert.equal(ms,4500);timer=fn;scheduled++;return 1;},cancelTimeout(){}}});
h.showUnsupportedLogin();h.showUnsupportedLogin();assert.equal(h.networkNotice,'该登录方式暂不可用');assert.equal(scheduled,1);timer();assert.equal(h.networkNotice,'');
h.authStatus='authenticated';h.showUnsupportedLogin();assert.equal(scheduled,1);
for(const token of ['loginComparison','PIN_GOOGLE_LOGIN_DIAGNOSTICS','Google 登录对照测试','记录环境诊断'])assert(!index.includes(token),token+' removed');
assert(fs.readFileSync('entry/src/main/ets/startup/WebEngineTask.ets','utf8').includes('setWebDebuggingAccess(false)'));
console.log('Google unavailable: capture activation, keyboard/Tab, deduped hint, visibility/stale guards, navigation fallback, password pass-through and cleanup passed');
