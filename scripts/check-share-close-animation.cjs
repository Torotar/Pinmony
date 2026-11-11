const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=source.indexOf('  private requestShareSheetClose()'),end=source.indexOf('  private closeNativeModal()',start);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const compile=(body,globals={})=>vm.runInNewContext(ts.transpileModule('class Subject {'+body+'} Subject;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,globals);
const messages={message:key=>key,isText:(value,text)=>value===text};
const controllerSource=fs.readFileSync('feature_pin/src/main/ets/controllers/PinmonySharePanelsController.ets','utf8');
const Controller=compile(controllerSource.slice(controllerSource.indexOf('  pause('),controllerSource.indexOf('  private current(')),{PinmonyI18n:messages});
const nativeSource=fs.readFileSync('entry/src/main/ets/app/PinmonyShareNativeFlow.ets','utf8');
const Native=compile(nativeSource.slice(nativeSource.indexOf('    pause('),nativeSource.indexOf('    close(')),{PinmonyI18n:messages,clearTimeout});
for(const native of [false,true]){
 const h=new Host(),contacts=[{id:'contact'}];let paused=0,cleared=0;
 const store={shareContacts:contacts,shareLoading:true,shareError:'',shareFeedback:'正在加载联系人…'};
 let cancels=0,contactUpdates=0;
 const flow=new Native();Object.assign(flow,{store,busy:true,pending:'sending',unknown:new Set(),revision:3,searchRevision:5,timer:-1,account:'synthetic',generation:1,ports:{session:()=>({authenticated:true,accountId:'synthetic',generation:1})},contacts(){contactUpdates++;},client:{cancel(){cancels++;}},contactsClient:{cancel(){cancels++;}}});
 const controller=new Controller();Object.assign(controller,{store,generation:2,searchToken:3,refreshToken:4,searchTasks:{invalidate(){}},tasks:{invalidate(){}},ports:{nativeShare:()=>native,nativePause:keep=>{paused++;flow.pause(keep);},activeSheetKind:()=>h.activeSheetKind}});
 Object.assign(h,{activeSheetKind:'share',showNativeSheet:true,homeStore:{},pinStore:store,nativeBusinessRoutesEnabled:native,sharePanelsController:controller,dismissShareSheet(){cleared++;}});
 h.requestShareSheetClose();assert.equal(h.showNativeSheet,false);assert.equal(h.activeSheetKind,'share');assert.equal(h.pinStore.shareContacts,contacts);assert.equal(paused,native?1:0);assert.equal(cleared,0);
 assert.equal(store.shareLoading,true);assert.equal(store.shareError,'');assert.equal(store.shareFeedback,'正在加载联系人…');assert.equal(contactUpdates,0);assert.equal(controller.generation,3);
 if(native){assert.equal(cancels,2);assert(flow.unknown.has('sending'),'unconfirmed mutation remains blocked');assert.equal(flow.revision,4);assert.equal(flow.searchRevision,6);}
 h.requestShareSheetClose();assert.equal(paused,native?1:0,'repeated close remains idempotent');
 h.showNativeSheet=true;h.homeStore.customHomeMenu={};h.requestShareSheetClose();assert.equal(cleared,1,'custom photo menus retain original dismissal');
 controller.pause();assert.equal(store.shareLoading,false,'ordinary pause still exposes retry state');assert(store.shareError);
}
const navigationPorts=source.slice(source.indexOf('    dismissSearchFilters: (): void =>'),source.indexOf('    editPinAction: (method:',source.indexOf('    dismissSearchFilters: (): void =>')));
assert(navigationPorts.includes('dismissShareSheet: (): void => this.requestShareSheetClose()'),'system back shares animated close');
const actionStart=source.indexOf('  private async performShareAction('),actionEnd=source.indexOf('  private sharePlatformName(',actionStart);
const Actions=compile(source.slice(actionStart,actionEnd));
const actions=new Actions();let calls=0;Object.assign(actions,{showNativeSheet:false,activeSheetKind:'share',sharePanelsController:{performShareAction(){calls++;},searchShareContacts(){calls++;},refreshShareSheet(){calls++;}}});
Promise.all([actions.performShareAction('contact'),actions.searchShareContacts('a'),actions.refreshShareSheet()]).then(()=>assert.equal(calls,0,'closing content cannot submit actions'));
const sheetStart=source.indexOf('.bindSheet($$this.showNativeSheet');const disappearStart=source.indexOf('onDisappear:',sheetStart),willStart=source.indexOf('onWillDismiss:',disappearStart);
const disappear=source.slice(disappearStart,willStart);
assert(disappear.includes("!this.showNativeSheet && this.activeSheetKind === 'share' && !this.detailSystemShareClosed"));
assert(disappear.includes('this.dismissShareSheet();'),'cleanup retained at native disappearance');
assert(source.slice(willStart).includes("else if (this.activeSheetKind === 'share') this.requestShareSheetClose();"));
assert(source.slice(end,source.indexOf('\n  @Builder',end)).includes('this.requestShareSheetClose()'),'HDS close requests native exit before cleanup');
console.log('Share exit: button/gesture request native dismissal, contacts/title retained, one pause, cleanup deferred, custom menus preserved passed');
