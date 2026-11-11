const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');const start=source.indexOf('  private async performProfileAction('),end=source.indexOf('\n  private ',start+1);
const View=vm.runInNewContext(ts.transpileModule('class View {'+source.slice(start,end)+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_PROFILE_API_ENABLED:true,PinmonyRuntimeLog:{warn(){}},PinmonyI18n:{message:k=>k}});
const page='https://www.pinterest.com/sample/',url='https://www.pinterest.com/pin/11/';
function fixture(mode='pins',draft=false){const v=new View(),events=[];const pin={id:'profile-api-native-11',targetUrl:draft?'':url,imageUrl:'https://i.pinimg.com/synthetic.jpg',imageWidth:400,imageHeight:600,collageDraft:draft};Object.assign(v,{authStatus:'authenticated',activeTab:3,nativeBusinessRoutesEnabled:true,profileStore:{origins:[],profile:{profileUrl:page,section:'created',hubMode:mode,createdPins:[pin],hubFavorite:true,hubCreated:true}},pinStore:{rememberDetailOrigin(){}},traceAction(){},extractPinUrl:x=>x,pinIdentity:x=>x===url?'11':'',capturePinEntryPhoto:(...args)=>events.push(['capture',...args]),clearRootTabGuard(){},beginDetailOpening:(...args)=>events.push(['open',...args]),showMessage(){throw Error('unexpected error')},loadSessionDocument(){throw Error('native entry must stay native')}});return{v,pin,events};}
async function main(){for(const mode of ['pins','collages','']){const f=fixture(mode);assert(await f.v.performProfileAction(f.pin.id));assert.equal(f.events[0][0],'capture');assert.deepEqual(f.events[0].slice(1),[url,f.pin.imageUrl,'pinmony-profile-photo-'+f.pin.id,400,600]);assert.equal(f.events[1][0],'open');assert.equal(f.events[1][4],mode==='collages','ordinary Pin must not become a collage item');}
for(const change of [f=>f.v.authStatus='loggedOut',f=>f.v.activeTab=0,f=>f.pin.targetUrl='',f=>f.v.profileStore.profile.createdPins=[]]){const f=fixture();change(f);assert.equal(await f.v.performProfileAction(f.pin.id),false);assert.equal(f.events.length,0);}
const draft=fixture('drafts',true);assert.equal(await draft.v.performProfileAction(draft.pin.id),false);assert.equal(draft.events.length,0);
const ui=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');assert(ui.includes(".id('pinmony-profile-photo-' + pin.id)"));assert(source.includes('if (this.homeEntryPhoto?.pinUrl !== pinUrl)'));assert(source.includes('getRectangleById(this.homeEntryCardId)'));
const root=fs.readFileSync('entry/src/main/ets/components/PinmonyProfileRootContent.ets','utf8');
assert.equal((root.match(/!view\.pinStore\.detail \|\| view\.retainPinSource/g)||[]).length,2,'both root and card subtree must retain the source during detail');
function rootGate(name) {
 const expression=root.match(new RegExp(name+': ([\\s\\S]*?),\\r?\\n'));assert(expression,name);
 return new Function('view','return ('+expression[1]+');');
}
const interaction=rootGate('interactionReady'),loading=rootGate('automaticLoadingEnabled');
const ready={coveredByBoard:false,coveredByPin:false,pinStore:{},authStatus:'authenticated',activeTab:3,
 profileStore:{origins:[],profileNativeReadsReady:true},nativeRootOnly:true,rootContentInteracted:false};
assert.equal(interaction(ready),true);assert.equal(loading(ready),true);
for(const patch of [{coveredByBoard:true},{coveredByPin:true},{pinStore:{detail:{}}},{pinStore:{detailOpeningPin:url}},
 {activeTab:0}]) {
 assert.equal(interaction({...ready,...patch}),false,'covered or inactive profile cannot accept actions');
 assert.equal(loading({...ready,...patch}),false,'covered or inactive profile cannot load automatically');
}
assert.equal(interaction({...ready,authStatus:'loggedOut'}),false);
assert.equal(loading({...ready,profileStore:{origins:[],profileNativeReadsReady:false}}),false);
assert.equal(interaction({...ready,activeTab:0,profileStore:{origins:[page]}}),true,'nested profile remains interactive');
assert(root.includes(".accessibilityLevel(view.pinStore.detail || view.pinStore.detailOpeningPin ? 'no-hide-descendants' : 'auto')"));
const retention=source.match(/retainPinSource: ([\s\S]*?),\r?\n      profileStore:/);assert(retention);
const retained=new Function('return '+retention[1]);
const parentMethod=source.match(/  private retainProfilePinParent\([\s\S]*?\r?\n  \}/);assert(parentMethod);
const Parent=vm.runInNewContext(ts.transpileModule('class Parent {'+parentMethod[0]+'} Parent;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
for(const [card,photo,current,expected] of [['pinmony-profile-photo-11',url,url,true],['pinmony-search-photo-11',url,url,false],['pinmony-profile-photo-11',url,'other',false]]){
 assert.equal(retained.call({homeEntryCardId:card,homeEntryPhoto:{pinUrl:photo},pinStore:{detail:{pinUrl:current}},
  profileStore:{},retainProfilePinParent:Parent.prototype.retainProfilePinParent}),expected);
}
const parent=new Parent();Object.assign(parent,{profileStore:{profile:{profileUrl:page}},
 pinStore:{detail:{pinUrl:url},detailOrigin:()=>page},pinIdentity:x=>x,
 profileUrlFromAddress:x=>x===page?page:''});
assert.equal(parent.retainProfilePinParent(),true,'profile origin retains parent even without source-card geometry');
parent.pinStore.detailOrigin=()=> 'https://www.pinterest.com/other/';
assert.equal(parent.retainProfilePinParent(),false,'another profile cannot be retained as this Pin parent');
parent.pinStore.detailOrigin=()=>page;parent.nativeBackTarget=page;
assert.equal(parent.retainProfilePinParent(),false,'profile route itself does not keep the Pin parent covered');
const backStart=source.indexOf('  private async backFromDetail('),backEnd=source.indexOf('\n  private ',backStart+1);
const slide=source.match(/  private inboxNewsPinSlide\([\s\S]*?\r?\n  \}/);assert(slide);
const backAst=ts.createSourceFile('back.ts','class Back {'+source.slice(backStart,backEnd)+'}',ts.ScriptTarget.Latest,true);
const backMethod=backAst.statements[0].members.find(node=>ts.isMethodDeclaration(node)&&node.name.getText(backAst)==='backFromDetail');
assert(backMethod,'extract only the return method, excluding following decorated state fields');
const Back=vm.runInNewContext(ts.transpileModule('class Back {'+backMethod.getText(backAst)+slide[0]+'} Back;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyRuntimeLog:{info(){}},display:{getDefaultDisplaySync:()=>({width:400,height:800})}});
const back=new Back();Object.assign(back,{activeSheetKind:'',pageHistory:{isPending:()=>false},pinStore:{detail:{pinUrl:url}},homeEntryPhoto:{pinUrl:url,imageUrl:'photo',width:100,height:150},homeEntryCardId:'pinmony-profile-photo-11',getUIContext:()=>({px2vp:x=>x,getComponentUtils:()=>({getRectangleById:()=>({windowOffset:{x:20,y:180},size:{width:100,height:150}})})})});
back.inboxStore={};
await back.backFromDetail();assert.equal(back.homeEntryClosing,true);assert.equal(back.homeEntryPhoto.returnPageOnly,false,'retained visible card must close with image flight');
console.log('Profile Pin photo flight: current-card geometry captured before native detail, pins/filters/legacy entry, unchanged collage semantics, invalid/draft guards and shared return path passed');}
main().catch(e=>{console.error(e);process.exitCode=1});
