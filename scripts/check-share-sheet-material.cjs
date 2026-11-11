const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const sheet=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyShareSheet.ets','utf8');
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const helper=fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets','utf8');
assert(!helper.includes('shareSheetOptions')&&!helper.includes('sheetMaterialActive'),'whole-sheet material helper removed');
assert(!index.includes('shareSheetOptions'));assert(!sheet.includes('Color.Transparent'),'body remains opaque');
assert(!sheet.includes('bindToScrollable')&&!sheet.includes('IMMERSIVE_GRADIENT_BLUR'),'no scrolling blur added');
assert(index.includes('onClose: () => this.closeNativeModal()'));
assert(sheet.includes('.titleMode(HdsNavigationTitleMode.MODAL)'));
const start=sheet.indexOf('  private closeTitleOptions()'),end=sheet.indexOf('\n  build()',start);
const code=ts.transpileModule('class Host {'+sheet.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
const Host=vm.runInNewContext(code,{$r:x=>x,SymbolGlyphModifier:class{fontColor(){return this;}},BlurStrategy:{DISABLE:1},IconStyleMode:{SMALL:0},PinmonyImmersiveLight:{effect:mode=>mode==='off'?undefined:{mode}}});
for(const mode of ['off','gentle','immersive','exquisite']){
 let closed=0;const h=new Host();Object.assign(h,{immersiveLightMode:mode,titleText:'share',uiText:x=>x,onClose:()=>closed++});const o=h.closeTitleOptions();
 assert.equal(o.style.blurStrategy,1);assert.equal(o.style.thermoCtrl,false);assert.equal(o.style.scrollEffectOpts.enableScrollEffect,false);
 assert.equal(o.style.originalStyle.backgroundStyle.blurRadius,0);assert.equal(o.style.originalStyle.backgroundStyle.backgroundColor,'app.color.page_background');
 assert.equal(o.style.systemMaterialEffect===undefined,mode==='off');o.content.menu.value[0].content.action();assert.equal(closed,1);
}
console.log('Share close only: whole-sheet material rolled back, opaque background, HDS menu material, no blur or scroll effect, original dismissal passed');
