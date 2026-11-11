const fs = require('node:fs'), assert = require('node:assert/strict'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonySaveSheet.ets','utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
assert(source.includes('Scroll(this.boardScroller)') && source.includes('Scroll(this.createScroller)'));
assert(source.includes('.bindToScrollable([this.boardScroller, this.createScroller])'));
assert(source.includes('.titleMode(HdsNavigationTitleMode.MODAL).hideBackButton(true)'));
assert(source.includes('avoidLayoutSafeArea: false, enableComponentSafeArea: true'));
assert(index.includes("title: this.nativeSheetHasHdsTitle() ? undefined : { title: this.nativeModalLabel() }"));
assert(index.includes("showClose: !this.nativeSheetHasHdsTitle()"));
assert(index.includes("dragBar: this.activeSheetKind !== 'save'"));
assert(index.includes('PinmonySaveSheet({ result: this.pinStore.saveResult, onClose: () => this.closeNativeModal()'));
const start = source.indexOf('  private titleOptions()'), end = source.indexOf('\n  build()',start);
const code = ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
const Host = vm.runInNewContext(code,{SymbolGlyphModifier: class {fontColor(){return this;}}, $r:x=>x, Color:{Transparent:'transparent'}, BlurStrategy:{ENABLE:1,DISABLE:0},ScrollEffectType:{IMMERSIVE_GRADIENT_BLUR:1},PinmonyImmersiveLight:{effect:x=>x}});
for(const mode of ['off','gentle','immersive','exquisite']) for(const creating of [false,true]) for(const language of ['zh','en']) {
 const h = new Host(); let closed=0; Object.assign(h,{immersiveLightMode:mode,creating,uiText:x=>language+':'+x,onClose:()=>closed++});
 const o=h.titleOptions(); assert.equal(o.style.scrollEffectOpts.enableScrollEffect,mode!=='off');
 assert.equal(o.style.scrollEffectStyle.backgroundStyle.blurRadius,mode==='off'?0:18);
 assert.equal(o.content.title.mainTitle,language+':'+(creating?'pm_create_board_513babc9':'pm_save_to_board_0233a416'));
 o.content.menu.value[0].content.action();assert.equal(closed,1);
}
console.log('Save HDS title: actual scroll bindings, single title/close, theme modes, live title keys and dismissal passed');

assert.equal((source.match(/\.clip\(false\)/g)||[]).length,2, 'both actual Scroll viewports allow content beneath HDS title');
assert(source.includes(".backgroundColor($r('app.color.page_background')).clip(true)"), 'outer panel still clips overflow at sheet bounds');
assert(source.includes(".backgroundColor($r('app.color.page_background')).zIndex(1)"), 'fixed footer masks list overflow at bottom');
