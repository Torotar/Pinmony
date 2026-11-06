const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const native=fs.readFileSync('entry/src/main/ets/app/PinmonyPostNativeOperations.ets','utf8');
const a=native.indexOf('  async detailAction('),b=native.indexOf('\n  private ',a);
const Entry=vm.runInNewContext(ts.transpileModule('class Entry {'+native.slice(a,b)+'} Entry;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_POST_OPERATIONS_ENABLED:true});
const exportsObject={};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/controllers/PinmonyDetailController.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,
 {exports:exportsObject,require:()=>({PinmonyTaskRegistry:class {},PinmonyI18n:{message:key=>key}})});
async function main(){
 for(const selected of [false,true]){
  const pin='https://www.pinterest.com/pin/11/',opened=[];
  const detail={pinUrl:pin,kind:'state',actions:[{id:'save',kind:'save',enabled:true,selected,label:selected?'Long board name':'Save'}]};
  const entry=new Entry();Object.assign(entry,{ports:{owns:()=>true},busy:false,store:{detail},openSave:async p=>opened.push(p),cancelSave(){throw Error('save entry must never delete a saved copy');}});
  assert.equal(await entry.detailAction('save'),true);assert.deepEqual(opened,[pin]);
  const controller=new exportsObject.PinmonyDetailController({store:{detail,detailActionsReady:true,viewerSaveBusy:false},traceAction(){},isOffline:()=>false,isAuthenticated:()=>true,
   currentPinUrl:()=>pin,pinIdentity:p=>p,postApiEnabled:()=>true,postExtensionsEnabled:()=>true,openBoards:async()=>opened.push(pin),cancelSave(){throw Error('legacy entry must not unsave');}});
  await controller.performAction('save','save');assert.equal(opened.length,2);
  entry.busy=true;await entry.detailAction('save');assert.equal(opened.length,2,'busy guard remains active');
 }
 const ui=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
 const start=ui.indexOf("if (this.action('save'))"),end=ui.indexOf(".alignItems(VerticalAlign.Center)",start),button=ui.slice(start,end);
 const label=`this.action('save')!.selected ? PinmonyI18n.render(this.action('save')!.label, this.uiLanguage) : this.uiText("pm_save_60a53514")`;
 assert(button.includes('Text('+label+')'));
 assert(button.includes('.accessibilityText('+label+')'));
 assert(button.includes('.maxLines(2).textAlign(TextAlign.Center).textOverflow({ overflow: TextOverflow.Ellipsis })'));
 assert(button.includes(".height('auto')") && button.includes('minHeight: 44'),'two-line button grows while keeping minimum touch height');
 const photo=ui.slice(ui.indexOf('  private shuffleSelectedCard('),ui.indexOf('\n  @Builder',ui.indexOf('  private shuffleSelectedCard(')));
 assert(photo.includes('Button({type:ButtonType.Normal}) {\n            Text('),'photo viewer uses a truncatable Text child');
 assert(photo.includes("this.action('save')?.selected"),'photo save label follows confirmed selection');
 assert(photo.includes('.maxLines(2).textAlign(TextAlign.Center).textOverflow({overflow:TextOverflow.Ellipsis})'),'photo board label wraps to two lines');
 assert(photo.includes(".height('auto').constraintSize({ minHeight: 44 })"),'photo button accommodates both lines');
 assert(photo.includes('.accessibilityText(item.id ==='),'photo accessible label keeps the full board name');
 assert.match(ui,/@Prop @Watch\('onPinChanged'\) currentDetail/);
 const changed=ui.slice(ui.indexOf('  private onPinChanged()'),ui.indexOf('  private notifyImageLoaded('));
 assert(changed.includes('this.syncDetailFlow();'),'incoming confirmed action updates notify the lazy content');
 const savedExports={};
 vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyConfirmedSaves.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,
  {exports:savedExports,require:()=>({PinmonyI18n:{message:key=>key}})});
 const saves=new savedExports.PinmonyConfirmedSaves(),actions=[{id:'save',kind:'save',label:'pm_save_60a53514',selected:false,enabled:true,countText:''}];
 assert.equal(saves.actions('11',actions)[0].selected,false);
 saves.confirm('11',true,'22','我的 Recipes 图板');
 assert.equal(saves.actions('11',actions)[0].label,'我的 Recipes 图板');
 assert.equal(saves.actions('11',actions)[0].selected,true);
 assert.equal(saves.actions('33',actions)[0].selected,false,'other Pin retains save label');
 saves.confirm('11',false);
 assert.equal(saves.actions('11',actions)[0].selected,false);
 assert.equal(saves.actions('11',actions)[0].label,'pm_save_60a53514');
 const sheet=fs.readFileSync('feature_pin/src/main/ets/components/PinmonySaveSheet.ets','utf8');
 const undo=sheet.slice(sheet.indexOf('        if (this.result.savedId) {'));
 assert.equal((undo.match(/Button\(/g)||[]).length,1,'saved picker footer has one undo button');
 assert(undo.includes('Button({ type: ButtonType.Normal })'),'undo uses a single rounded rectangular footer button');
 assert(undo.includes(".layoutWeight(1).height('auto').constraintSize({ minHeight: 48 }).borderRadius(20)"));
 assert(undo.includes(".backgroundColor($r('app.color.detail_save_accent'))") && undo.includes('.fontColor(Color.White)'),'undo uses the same colors as the detail save button');
 assert(undo.includes(".width('100%').padding({ left: 4, right: 4, top: 0, bottom: 28 })"),'undo keeps side and bottom insets while reducing the gap above it');
 assert(sheet.includes('compact:!!this.result.savedId'),'saved picker uses the compact create-board footer');
 assert(!button.slice(0,button.indexOf('.accessibilityText(')).includes('.width('),'button and label use intrinsic width for short board names');
 assert(button.includes("maxWidth: '42%'"),'long board names stay within the action row');
 assert(button.includes('.wordBreak(WordBreak.BREAK_ALL)'),'long board names wrap within the button');
 const createFooter=sheet.slice(sheet.indexOf('        Row({ space: 12 }) {',sheet.indexOf('if (this.creating)')),sheet.indexOf('      } else {',sheet.indexOf('if (this.creating)')));
 assert.equal((createFooter.match(/height\(48\)\.fontSize\(16\)\.fontWeight\(FontWeight.Medium\)\.borderRadius\(20\)/g)||[]).length,2,'both create footer buttons match reference dimensions');
 assert(createFooter.includes(".backgroundColor($r('app.color.surface_muted'))") && createFooter.includes(".backgroundColor($r('app.color.detail_save_accent'))"),'back stays secondary and create matches the detail save button');
 assert(createFooter.includes(".padding({ left: 4, right: 4, top: 12, bottom: 28 })"),'create footer shares reference insets');
 assert(undo.includes('.enabled(!this.result.busy)') && undo.includes('this.onRemove();'),'undo retains busy gate and existing operation');
 console.log('Detail save entry: confirmed board label, undo and Pin isolation, picker dispatch, busy guard and accessible label passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
