const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const method=source.match(/  private rootPresentationAddress\([\s\S]*?(?=\r?\n  private )/)[0];
const context={PINTEREST_URL:'https://www.pinterest.com/'};
vm.runInNewContext(ts.transpile('class Native {'+method+'} globalThis.Native=Native;',{target:ts.ScriptTarget.ES2021}),context);
for(const host of ['www','uk']){
 const origin='https://'+host+'.pinterest.com';
 const native=new context.Native();Object.assign(native,{navigationAddress:origin+'/',authenticatedProfileUrl:origin+'/fixture/',rootTabAddresses:new Map(),homeStore:{},searchStore:{},inboxStore:{}});
 for(const [index,path] of [[0,'/'],[1,'/search/'],[2,'/inbox/'],[3,'/fixture/']]) assert.equal(native.rootPresentationAddress(index),origin+path);
 native.navigationAddress=origin+'/pin/123/';assert.equal(native.rootPresentationAddress(1),origin+'/search/');
}
const exportsObject={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyRelatedPresentation.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject,require:()=>({})});
const body=JSON.stringify({resource_response:{status:'success',data:[{type:'pin',id:'456',images:{'474x':{url:'https://i.pinimg.com/fixture.jpg',width:474,height:600}}}]}});
assert.equal(exportsObject.readRelatedPresentation(body,'https://uk.pinterest.com/pin/123/').pins[0].pinUrl,'https://uk.pinterest.com/pin/456/');
assert.equal(exportsObject.readRelatedPresentation(body,'https://uk.pinterest.com.evil.test/pin/123/'),undefined);
console.log('Regional root routes and related mapping preserve supported document origins');
