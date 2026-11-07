const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript'),output={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('common_ui/src/main/ets/services/PinmonyHdsTitleBar.ets','utf8'),{
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:output,require:()=>({})});
const api=output.PinmonyHdsTitleBar;let dark=false;
const context={getHostContext:()=>({resourceManager:{getColorSync:id=>dark?0xffeeeeee-id:0xff111111+id}})};
const resource={id:123,type:10001,params:[]},action=()=>{};
const options={padding:{top:4},enableHoverMode:true,avoidLayoutSafeArea:true,enableComponentSafeArea:false,
  content:{title:{mainTitle:'source title'},backIcon:{action}},
  style:{blurStrategy:1,thermoCtrl:true,systemMaterialEffect:{materialType:2,materialLevel:1},scrollEffectOpts:{enableScrollEffect:true},
    originalStyle:{backgroundStyle:{backgroundColor:resource,maskExtraHeight:0,blurRadius:18},contentStyle:{
      backIconStyle:{iconColor:resource,backgroundColor:0,textColor:'#fff'},
      menuStyle:{iconColor:resource},subIconStyle:{iconColor:resource},dividerStyle:{dividerColor:resource},
      titleStyle:{mainTitleColor:resource,subTitleColor:resource,mainTitleShadowColor:resource,subTitleShadowColor:resource}}},
    scrollEffectStyle:{backgroundStyle:{backgroundColor:resource},contentStyle:{menuStyle:{textColor:resource}}}}};
function freeze(item){if(item&&typeof item==='object'){Object.freeze(item);Object.values(item).forEach(freeze);}}freeze(options);
const light=api.resolve(context,options,false);assert.equal(light.style.originalStyle.contentStyle.backIconStyle.iconColor,0xff111111+123);
assert.equal(light.style.originalStyle.backgroundStyle.blurRadius,18);assert.equal(light.content,options.content);
assert.equal(light.padding,options.padding);assert.equal(light.style.systemMaterialEffect,options.style.systemMaterialEffect);
assert.equal(light.style.scrollEffectOpts,options.style.scrollEffectOpts);
assert.equal(light.style.originalStyle.contentStyle.backIconStyle.backgroundColor,0,'transparent color is preserved');
assert.equal(light.content.backIcon.action,action,'actions and navigation callback identity are preserved');
dark=true;const next=api.resolve(context,options,true);
assert.equal(next.style.originalStyle.contentStyle.backIconStyle.iconColor,0xffeeeeee-123,'same options can be resolved again after mode changes');
assert.equal(options.style.originalStyle.backgroundStyle.backgroundColor,resource,'resource inputs remain intact');
const unavailable=api.resolve({getHostContext:()=>undefined},options,false);
assert.equal(unavailable.style.originalStyle.backgroundStyle.backgroundColor,resource,'unavailable context retains the original resource');
const throwing=api.resolve({getHostContext:()=>({resourceManager:{getColorSync:()=>{throw Error('not ready');}}})},options,false);
assert.equal(throwing.style.originalStyle.backgroundStyle.backgroundColor,resource);
let count=0;
function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,item.name);if(item.isDirectory())walk(file);
  else if(file.endsWith('.ets')){const source=fs.readFileSync(file,'utf8');for(const call of source.matchAll(/\.titleBar\(/g)){
    if(source.slice(call.index-4,call.index)==='this')continue;
    assert(source.slice(call.index+call[0].length).startsWith('PinmonyHdsTitleBar.resolve('),file+' unadapted HDS colors');count++;
  }if(source.includes('PinmonyHdsTitleBar.resolve('))assert(source.includes("@StorageLink('systemDarkMode') private hdsDarkMode"),file+' missing live theme dependency');}}}
for(const root of ['feature_pin','feature_board','feature_profile','feature_search','feature_inbox','feature_settings'])walk(root+'/src/main/ets/components');
assert.equal(count,34);console.log('HDS colors: 34 title bars, light/dark re-resolution, immutable inputs, callbacks, safe areas, materials and fallback passed');
