const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets','utf8');
const start=source.indexOf('  public static sheetOptions('),end=source.indexOf('  public static alertOptions(',start);
let api=true,supported=true;const empty={empty:true};
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{deviceInfo:{apiAvailable:()=>api},uiMaterial:{isImmersiveMaterialSupported:()=>supported,ImmersiveMaterial:class{constructor(o){this.options=o;}},ImmersiveStyle:{THICK:1,REGULAR:2},Material:{empty}}});
for(api of [false,true])for(supported of [false,true])for(const enabled of [false,true])for(const mode of ['off','gentle','immersive','exquisite']){
 let calls=0;const callback=()=>calls++;const opts={title:{title:'Options'},showClose:true,backgroundColor:'theme',onWillDismiss:callback};
 const result=Host.sheetOptions(opts,mode,enabled);assert.equal(result,opts);assert.equal(result.showClose,true);assert.equal(result.title.title,'Options');result.onWillDismiss();assert.equal(calls,1);
 if(!api||!enabled){assert(!('systemMaterial' in result));assert.equal(result.backgroundColor,'theme');}
 else if(!supported||mode==='off'){assert.equal(result.systemMaterial,empty);assert.equal(result.backgroundColor,'theme');}
 else{assert.equal(result.backgroundColor,'#00000000');assert.equal(result.systemMaterial.options.style,mode==='gentle'?1:2);}
}
const paths=['entry/src/main/ets/pages/Index.ets','feature_board/src/main/ets/components/PinmonyBoardPage.ets','feature_profile/src/main/ets/components/PinmonyProfilePage.ets','feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets','feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets','feature_search/src/main/ets/components/PinmonySearchPage.ets','feature_settings/src/main/ets/components/PinmonyVisibilitySettingsPage.ets','common_ui/src/main/ets/components/PinmonyImageSearchView.ets'];
let hosts=0;for(const p of paths){const s=fs.readFileSync(p,'utf8');assert(!s.includes('PinmonySheetTitle'));assert(!s.includes('materialSheetTitle'));const count=(s.match(/\.bindSheet\(/g)||[]).length;assert.equal((s.match(/PinmonyImmersiveLight\.sheetOptions\(/g)||[]).length,count,p);hosts+=count;}
assert.equal(hosts,17);
const publish=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyPublishSheet.ets','utf8');
const publishBody=publish.slice(publish.indexOf('  build() {'));
assert(publishBody.includes(".backgroundColor($r('app.color.page_background'))"),'publish body retains the same theme background as its HDS title');
assert(!/Scroll\(|edgeEffect\(/.test(publishBody),'publish body damping remains disabled as requested');
const index=fs.readFileSync(paths[0],'utf8');
const nativeHost=index.slice(index.indexOf('.bindSheet($$this.showNativeSheet,'));
assert(nativeHost.includes("backgroundColor: $r('app.color.page_background')"),'native Sheet retains theme fallback for API24/off/unsupported material');
assert(nativeHost.includes('title: this.nativeSheetHasHdsTitle() ? undefined : { title: this.nativeModalLabel() }'),'native host selects one title owner');
const save=fs.readFileSync('feature_pin/src/main/ets/components/PinmonySaveSheet.ets','utf8');assert(save.includes('.bindToScrollable([this.boardScroller, this.createScroller])'));assert(save.includes('Scroll(this.boardScroller)'));assert(save.includes('Scroll(this.createScroller)'));assert.equal((save.match(/\.clip\(false\)/g)||[]).length,2);assert(save.includes('IMMERSIVE_GRADIENT_BLUR'));assert(save.includes('systemMaterialEffect: PinmonyImmersiveLight.effect'));
console.log('Native Sheet material: 17 native hosts, API24 fallback, off/unsupported modes, title ownership and callbacks retained; save HDS actual Scrollers and unclipped blur checked');
