const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const compile=source=>ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText;
const source=fs.readFileSync('common_foundation/src/main/ets/services/PinmonyDisplayPreference.ets','utf8');
const modes={COLOR_MODE_DARK:0,COLOR_MODE_LIGHT:1,COLOR_MODE_NOT_SET:-1};
function boot(disk=new Map(),legacy={},fault={}) {
  const state=new Map(Object.entries(legacy)),cache=new Map(disk),events=[],exports={};
  const app={get:key=>state.get(key),setOrCreate:(key,value)=>{if(['themePreference','screenOrientationPreference','bottomBarScrollCollapseEnabled'].includes(key))assert.equal(disk.get(key),value,'publish only after flush');state.set(key,value);events.push(['publish',key,value]);}};
  const storage={getSync:(key,fallback)=>cache.has(key)?cache.get(key):fallback,
    putSync:(key,value)=>{if(fault.put)throw Error('put');cache.set(key,value);},
    flushSync:()=>{if(fault.flush)throw Error('flush');disk.clear();for(const [key,value] of cache)disk.set(key,value);events.push(['flush']);}};
  vm.runInNewContext(compile(source),{exports,AppStorage:app,require:name=>name==='@kit.ArkData'?{preferences:{getPreferencesSync:(_ctx,options)=>{assert.equal(options.name,'pinmony_display');if(fault.open)throw Error('open');return storage;}}}:name==='@kit.AbilityKit'?{ConfigurationConstant:{ColorMode:modes}}:{PinmonyRuntimeLog:{info(){},warn(){}}}});
  const service=exports.PinmonyDisplayPreference; service.initialize({});
  return {service,state,events,disk,fault};
}
for(const theme of ['system','light','dark'])for(const orientation of ['system','auto','portrait','landscape'])for(const collapse of [false,true]) {
  const first=boot();
  assert(first.service.saveTheme(theme));assert(first.service.saveOrientation(orientation));assert(first.service.saveCollapse(collapse));
  const cold=boot(first.disk,{themePreference:'wrong',screenOrientationPreference:'wrong',bottomBarScrollCollapseEnabled:!collapse});
  assert.equal(cold.state.get('themePreference'),theme);assert.equal(cold.state.get('screenOrientationPreference'),orientation);assert.equal(cold.state.get('bottomBarScrollCollapseEnabled'),collapse);
}
const migrated=boot(new Map(),{themePreference:'light',screenOrientationPreference:'landscape',bottomBarScrollCollapseEnabled:false});
const applying=boot();
for(const [theme,mode] of [['dark',0],['light',1],['system',-1]]) {
  let applied;
  applying.service.applyTheme({getApplicationContext:()=>({setColorMode:value=>{applied=value;}})},theme);
  assert.equal(applied,mode);
  if(theme!=='system')assert.equal(applying.state.get('systemDarkMode'),theme==='dark');
}
const previousDark=applying.state.get('systemDarkMode');
for(const context of [{getApplicationContext(){throw Error('context');}},
  {getApplicationContext:()=>({setColorMode(){throw Error('color mode');}})}]) {
  assert.throws(()=>applying.service.applyTheme(context,'dark'),/theme configuration/);
  assert.equal(applying.state.get('systemDarkMode'),previousDark,'failed theme application cannot publish an unapplied system mode');
}
assert.equal(migrated.disk.get('themePreference'),'light');assert.equal(migrated.disk.get('screenOrientationPreference'),'landscape');assert.equal(migrated.disk.get('bottomBarScrollCollapseEnabled'),false);
const invalid=boot(new Map([['themePreference','invalid'],['screenOrientationPreference',7],['bottomBarScrollCollapseEnabled','false']]));
assert.equal(invalid.state.get('themePreference'),'system');assert.equal(invalid.state.get('screenOrientationPreference'),'system');assert.equal(invalid.state.get('bottomBarScrollCollapseEnabled'),true);
assert.equal(invalid.service.saveTheme('invalid'),false);assert.equal(invalid.service.saveOrientation('invalid'),false);
for(const faultName of ['put','flush'])for(const [method,value,key] of [['saveTheme','light','themePreference'],['saveOrientation','landscape','screenOrientationPreference'],['saveCollapse',false,'bottomBarScrollCollapseEnabled']]) {
  const host=boot();const previous=host.state.get(key);host.fault[faultName]=true;
  assert.equal(host.service[method](value),false);assert.equal(host.state.get(key),previous);assert.equal(boot(host.disk).state.get(key),previous,'failed writes do not become saved choices on cold start');
  host.fault[faultName]=false;assert(host.service[method](value));assert.equal(boot(host.disk).state.get(key),value);
}
for(const fault of [{open:true},{put:true},{flush:true}]){const host=boot(new Map(),{},fault);assert.equal(host.service.saveTheme('light'),false);}
function method(file,name){const text=fs.readFileSync(file,'utf8'),ast=ts.createSourceFile('source.ts',text.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);let result;function visit(node){if(ts.isMethodDeclaration(node)&&node.name?.getText(ast)===name)result=node.getText(ast);ts.forEachChild(node,visit);}visit(ast);assert(result,name);return result;}
const pagePath='feature_settings/src/main/ets/components/PinmonyDisplaySettingsPage.ets';
async function callbacks(){
  const host=boot(),calls=[],errors=[];let failNative=false;
  const appContext={setColorMode:mode=>{calls.push(mode);if(failNative)throw Error('native');assert.equal(host.state.get('themePreference'),mode===0?'dark':mode===1?'light':'system','synchronous configuration event sees committed preference');}};
  const Page=vm.runInNewContext(compile('class Page {'+method(pagePath,'selectTheme')+'\n'+method(pagePath,'selectOrientation')+'} globalThis.Page=Page;')+'\nPage;',{
    PinmonyDisplayPreference:host.service,PinmonyImmersiveLight:{toastOptions:x=>x},PinmonyRuntimeLog:{warn(){}},
    window:{Orientation:{AUTO_ROTATION_RESTRICTED:0,AUTO_ROTATION:1,PORTRAIT:2,LANDSCAPE:3},getLastWindow:async()=>mainWindow}});
  const page=new Page();
  for(const [property,key] of [['themePreference','themePreference'],['orientationPreference','screenOrientationPreference']])Object.defineProperty(page,property,{get:()=>host.state.get(key),set:value=>host.state.set(key,value)});
  page.uiText=x=>x;page.getUIContext=()=>({getHostContext:()=>({getApplicationContext:()=>appContext}),getPromptAction:()=>({showToast:x=>errors.push(x)})});
  for(const theme of ['light','dark','system']){page.selectTheme(theme);assert.equal(boot(host.disk).state.get('themePreference'),theme);}
  failNative=true;page.selectTheme('light');assert.equal(page.themePreference,'system');assert.equal(boot(host.disk).state.get('themePreference'),'system');assert.equal(errors.length,1);failNative=false;
  host.fault.flush=true;const count=calls.length;page.selectTheme('dark');assert.equal(calls.length,count);assert.equal(page.themePreference,'system');host.fault.flush=false;
  const rotations=[];const mainWindow={setPreferredOrientation:async value=>rotations.push(value)};
  page.supportsOrientation=true;page.orientationBusy=false;
  await page.selectOrientation(3);assert.equal(boot(host.disk).state.get('screenOrientationPreference'),'landscape');
  host.fault.flush=true;await page.selectOrientation(2);assert.deepEqual(rotations.slice(-2),[2,3]);assert.equal(page.orientationPreference,'landscape');assert.equal(page.orientationBusy,false);host.fault.flush=false;
  page.supportsOrientation=false;const previous=rotations.length;await page.selectOrientation(0);assert.equal(rotations.length,previous);
  await page.selectOrientation(-1);await page.selectOrientation(4);
  // Execute actual window-load and configuration callbacks, not only source assertions.
  const abilityPath='entry/src/main/ets/entryability/EntryAbility.ets';let loaded,resourceSyncs=0;
  const Ability=vm.runInNewContext(compile('class Ability {'+method(abilityPath,'onWindowStageCreate')+'\n'+method(abilityPath,'onConfigurationUpdate')+'} globalThis.Ability=Ability;')+'\nAbility;',{
    AppStorage:{get:key=>host.state.get(key),setOrCreate:(key,value)=>host.state.set(key,value)},
    PinmonyDisplayPreference:host.service,PinmonyI18n:{attachLayoutContext(){},syncResourceColorMode(){resourceSyncs++;},syncSystemLanguage(){}},
    PinmonyRuntimeLog:{info(){},error(){},warn(){}},hilog:{info(){},error(){}},DOMAIN:0});
  const ability=new Ability();Object.assign(ability,{context:{getApplicationContext:()=>appContext},contentLoaded:false,windowStageReady:false,logLifecycle(){},canConfigureOrientation:()=>false,syncStatusBarHeight(){},syncSystemColorMode(){}});
  const stage={getMainWindowSync:()=>({on(){},setWindowLayoutFullScreen:async()=>{}}),loadContent:(_page,callback)=>{loaded=callback;}};
  host.service.saveTheme('light');const beforeLoad=calls.length;ability.onWindowStageCreate(stage);assert.equal(calls.length,beforeLoad);
  loaded({code:1});assert.equal(calls.length,beforeLoad,'failed load does not apply native theme');
  loaded({code:0});assert.equal(calls.at(-1),1);assert.equal(ability.contentLoaded,true);
  ability.onConfigurationUpdate({colorMode:1});ability.onConfigurationUpdate({colorMode:0});assert.equal(resourceSyncs,2);assert.equal(host.state.get('pinmonyThemeConfigurationRevision'),2);
}
// Exercise the existing independent display stores against actual disk snapshots too.
for(const [file,className,steps] of [
  ['PinmonyProfileLayoutPreference','PinmonyProfileLayoutPreference',[['saveLegacyLayout',true,'profileLegacyLayout'],['saveAvatarRight',true,'profileAvatarRight']]],
  ['PinmonyDetailDisplayPreference','PinmonyDetailDisplayPreference',[['savePhotoFit',true,'detailPhotoFitEnabled']]],
  ['PinmonyImmersiveLightPreference','PinmonyImmersiveLightPreference',[['save','exquisite','immersiveLightMode']]]
]){
  const disk=new Map();
  function load(){const state=new Map(),cache=new Map(disk),exports={};vm.runInNewContext(compile(fs.readFileSync('common_foundation/src/main/ets/services/'+file+'.ets','utf8')),{exports,AppStorage:{get:key=>state.get(key),setOrCreate:(key,value)=>state.set(key,value)},require:name=>name==='@kit.ArkData'?{preferences:{getPreferencesSync:()=>({getSync:(key,fallback)=>cache.has(key)?cache.get(key):fallback,putSync:(key,value)=>cache.set(key,value),flushSync:()=>{disk.clear();for(const [key,value]of cache)disk.set(key,value);}})}}:{PinmonyRuntimeLog:{info(){},warn(){}}}});exports[className].initialize({});return {service:exports[className],state};}
  const first=load();for(const [save,value,key] of steps){assert(first.service[save](value));assert.equal(load().state.get(key),value,file+' cold restart');}
}
const page=fs.readFileSync(pagePath,'utf8'),startup=fs.readFileSync('entry/src/main/ets/startup/PreferencesTask.ets','utf8'),ability=fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8');
assert(page.includes('PinmonyDisplayPreference.saveCollapse(value)'));
assert(page.includes('PinmonyI18n.select(value)')&&page.includes('this.request(action, String(next))'));
assert(startup.indexOf('PinmonyDisplayPreference.initialize(context)')<startup.indexOf('PinmonyI18n.initialize(context)'));
assert(ability.indexOf('PinmonyDisplayPreference.applyTheme(this.context')>ability.indexOf('this.contentLoaded = true'));
assert(ability.includes("AppStorage.get<string>('screenOrientationPreference')"));
callbacks().then(()=>console.log('Display settings: 24 cold restarts, legacy migration, invalid values, put/flush/open failure, theme callback ordering and rollback, orientation rollback, existing layout/avatar/photo/material persistence and startup bindings passed.')).catch(error=>{console.error(error);process.exitCode=1;});
