const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2] || 'typescript');
const source=fs.readFileSync('feature_settings/src/main/ets/services/PinmonyUpdateNotice.ets','utf8').replace(/^import .*;\r?\n/gm,'').replace('export class','class');
const code=ts.transpileModule(source+'\nPinmonyUpdateNotice;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
const disk=new Map();
function boot(tag='v2.4.0', fail=false) {
 const state=new Map();let requests=0,resolve;
 const pending=new Promise(r=>resolve=r);
 const Notice=vm.runInNewContext(code,{preferences:{getPreferencesSync:()=>({getSync:(k,d)=>disk.get(k)||d,putSync:(k,v)=>disk.set(k,v),flushSync:()=>{}})},bundleManager:{BundleFlag:{GET_BUNDLE_INFO_DEFAULT:0},getBundleInfoForSelfSync:()=>({versionName:'2.3.0'})},PinmonyReleaseClient:class{async latest(){requests++;await pending;if(fail)throw Error('offline');return {tag_name:tag};}},PinmonyRuntimeLog:{warn:()=>{}},AppStorage:{get:k=>state.get(k),setOrCreate:(k,v)=>state.set(k,v)},isNewerRelease:(a,b)=>{const parse=s=>/^v?\d+\.\d+\.\d+$/i.test(s)?s.replace(/^v/i,'').split('.').map(Number):null;const x=parse(a),y=parse(b);if(!x||!y)return false;for(let i=0;i<3;i++)if(x[i]!==y[i])return x[i]>y[i];return false;}});
 return {Notice,state,resolve,requests:()=>requests};
}
(async()=>{
 let x=boot();const p=x.Notice.start({});await x.Notice.start({});assert.equal(x.requests(),1);x.resolve();await p;assert.equal(x.state.get('pinmonyUpdateUnread'),true);
 x.Notice.setAboutVisible(true);assert.equal(x.state.get('pinmonyUpdateUnread'),false);x.Notice.setAboutVisible(false);assert.equal(disk.get('seenVersion'),'v2.4.0');
 x=boot('2.4.0');let run=x.Notice.start({});x.resolve();await run;assert.equal(x.state.get('pinmonyUpdateUnread'),false);
 x=boot('v2.5.0');run=x.Notice.start({});x.resolve();await run;assert.equal(x.state.get('pinmonyUpdateUnread'),true);
 x.Notice.confirm('v2.4.0','2.3.0');assert.equal(x.state.get('pinmonyUpdateUnread'),true);
 x=boot('v2.6.0');run=x.Notice.start({});x.Notice.setAboutVisible(true);x.resolve();await run;assert.equal(x.state.get('pinmonyUpdateUnread'),false);assert.equal(disk.get('seenVersion'),'v2.6.0');
 x=boot('v2.3.0');run=x.Notice.start({});x.resolve();await run;assert.equal(x.state.get('pinmonyUpdateUnread'),false);
 x=boot('v2.7.0',true);run=x.Notice.start({});x.resolve();await run;assert.notEqual(x.state.get('pinmonyUpdateUnread'),true);assert.equal(disk.get('seenVersion'),'v2.6.0');
 console.log('Update notice: startup deduplication, newer version, viewed persistence/restart, stale results, visible-about completion and offline failure passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
