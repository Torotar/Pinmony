const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const calls=[],exportsObject={};
const webview={WebCookieManager:{async fetchCookie(url){calls.push(['read',url]);return 'session=synthetic';},async configCookie(url,value){calls.push(['write',url,value]);}}};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_session/src/main/ets/services/PinmonySessionCredentials.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:exportsObject,require:()=>({webview})});
(async()=>{
 const credentials=new exportsObject.PinmonySessionCredentials();
 for(const host of ['www','uk']){
  const url=`https://${host}.pinterest.com/resource/UserResource/get/`;
  await credentials.read(url);await credentials.update(url,['session=synthetic; Secure'],()=>true);
  assert.equal(calls.at(-2)[1],url);assert.equal(calls.at(-1)[1],url);
 }
 for(const url of ['http://uk.pinterest.com/','https://uk.pinterest.com.evil.example/','https://evil@uk.pinterest.com/','https://uk.pinterest.com:443/','https://fr.pinterest.com/']){
  const before=calls.length;await assert.rejects(credentials.read(url));await assert.rejects(credentials.update(url,[],()=>true));assert.equal(calls.length,before);
 }
 const before=calls.length;await assert.rejects(credentials.update('https://uk.pinterest.com/',['session=synthetic'],()=>false));assert.equal(calls.length,before);
 console.log('Regional credentials: actual URL, bounded origins and stale cookie protection passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
