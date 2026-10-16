const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const ports=source.slice(source.indexOf('  private readonly postNativeOperations:'),source.indexOf('  private readonly systemActions:'));
function compile(code){return vm.runInNewContext(ts.transpileModule(code,{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);}
const showLine=ports.split(/\r?\n/).find(line=>line.trim().startsWith('show: '));
const show=compile('('+showLine.trim().slice(6,-1).replace('(kind: string): void =>','function(kind: string): void')+')');
const savedStart=ports.indexOf('    saved: '),savedEnd=ports.indexOf('    dismissed:',savedStart);
const saved=compile('('+ports.slice(savedStart,savedEnd).trim().slice(7,-1).replace('(pin: string, copy: string, message: string): void =>','function(pin: string, copy: string, message: string): void')+')');
const closeStart=source.indexOf("        if (!this.showNativeSheet && ['save', 'edit'].includes(this.activeSheetKind)) {",source.indexOf('.bindSheet($$this.showNativeSheet'));
const closeEnd=source.indexOf("        if (!this.showNativeSheet && this.activeSheetKind === 'searchFilter')",closeStart);
const close=compile('(function(){'+source.slice(closeStart,closeEnd)+'})');
for(const home of [false,true]){
  const events=[],h={activeSheetKind:'save',showNativeSheet:true,pinStore:{},homeStore:{customHomeMenu:home?{}:undefined},
    nativeBusinessSessionContext:()=>({authenticated:true,accountId:'synthetic',generation:1}),
    dismissShareSheet(){assert.equal(this.activeSheetKind,'');events.push('home-close');this.homeStore.customHomeMenu=undefined;},
    showUndoSnack(){events.push('snack');},undoSavedPin(){}};
  show.call(h,'');assert.equal(h.showNativeSheet,false);assert.equal(h.activeSheetKind,'save','retain Sheet type during animation');
  h.postSheetDismissed=true;saved.call(h,'pin','copy','saved');assert.deepEqual(events,[]);
  close.call(h);close.call(h);assert.equal(h.activeSheetKind,'');assert.deepEqual(events,home?['home-close','snack']:['snack']);
}
console.log('Save Sheet: home/detail retain type until disappearance, cleanup precedes feedback, callback runs once');
