const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const file='feature_profile/src/main/ets/components/PinmonyPublishPhotoEditor.ets';
const source=fs.readFileSync(file,'utf8').replace('export struct PinmonyPublishPhotoEditor','export class PinmonyPublishPhotoEditor');
const sf=ts.createSourceFile(file,source,ts.ScriptTarget.Latest,true);
const view=sf.statements.find(n=>ts.isClassDeclaration(n)&&n.name.text==='PinmonyPublishPhotoEditor');
const methods=['aboutToAppear','syncPhase','back','openChild','startProducts'];
const selected=methods.map(name=>{const m=view.members.find(n=>ts.isMethodDeclaration(n)&&n.name?.getText(sf)===name);assert(m,name);return m.getText(sf);}).join('\n');
const scope={exports:{},clearTimeout};
vm.runInNewContext(ts.transpileModule('export class TestView{'+selected+'}',{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,scope);
const host=new scope.exports.TestView(),events=[],routes=[];
Object.assign(host,{state:{token:1,phase:'select'},viewState:{prepare(){},productQuery:'query',productLink:'',productTab:0},productsStarted:false,topicTimer:-1,productTimer:-1,
 paths:{pushPath(info){routes.push(info.name);},replacePath(info){assert.equal(routes.length,1);routes[0]=info.name;},size(){return routes.length;}},
 onAction(action,value){events.push({action,value});if(action==='searchProducts'){host.state={...host.state,productLoading:true};host.syncPhase();}}});
host.aboutToAppear();assert.deepEqual(routes,['select']);assert.equal(events.length,0,'mount must not synchronously update the parent snapshot');
for(const phase of ['topics','select','products','productImages','products','select','advanced','select','products']){
 host.state={...host.state,phase};host.syncPhase();assert.deepEqual(routes,[phase],'replace a destination without rebuilding its Navigation');
 if(phase==='products'){const before=events.length;host.startProducts('select');assert.equal(events.length,before);host.startProducts(phase);assert.equal(events.length,before+1);host.startProducts(phase);assert.equal(events.length,before+1,'data updates cannot restart destination initialization');}
}
host.state={...host.state,phase:'select'};host.syncPhase();
for(const action of ['next','topics','products','advanced']){host.openChild(action);assert.equal(events.at(-1).action,action);}
host.viewState.productTab=1;host.state={...host.state,phase:'productImages'};host.syncPhase();host.state={...host.state,phase:'products'};host.syncPhase();const oldCount=events.length;host.startProducts('products');assert.equal(events.length,oldCount,'returning to Use link preserves its tab and avoids a product search');
assert(source.includes('Stack({alignContent:Alignment.Center})'));assert(source.includes('PinmonyLoadingOverlay({message:'));assert(source.includes("this.onAction('confirmProductImage','',false)"));assert(!source.includes('this.productResults(true)'),'link candidates belong to the independent image page');
host.back('topics');assert.equal(events.at(-1).action,'back');assert.equal(events.at(-1).value,'topics','back carries its originating destination even after the snapshot changes');
const parent=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyPublishPage.ets','utf8');assert(!parent.includes('ForEach([this.state.phase]'),'do not remount an entire Navigation for a phase change');
const indexSource=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const indexFile=ts.createSourceFile('Index.ts',indexSource.replace('struct Index','class Index'),ts.ScriptTarget.Latest,true);
const indexClass=indexFile.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='Index');
const visible=indexClass.members.find(n=>ts.isMethodDeclaration(n)&&n.name?.getText(indexFile)==='publishPageVisible');
const visibilityScope={exports:{}};
vm.runInNewContext(ts.transpileModule('export class VisibilityTest{'+visible.getText(indexFile)+'}',{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,visibilityScope);
const visibilityHost=new visibilityScope.exports.VisibilityTest();
for(const picking of [false,true])for(const loading of [false,true]){visibilityHost.profileStore={publishPicking:picking,publishFlow:{kind:'photo',phase:'photo',pins:[],loading,error:''}};assert.equal(visibilityHost.publishPageVisible(),true,'empty/loading draft inbox remains visible and mounted');}
visibilityHost.profileStore={};assert.equal(visibilityHost.publishPageVisible(),false);
assert(source.includes('.onShown((): void => this.startProducts(phase))'));
for(const action of ['next','topics','products','advanced'])assert(source.includes(".onClick(() => this.openChild('"+action+"'))"),'each editor option has its own literal action');
console.log('Publish navigation: stable Navigation, phase replacement, initialization after shown, all four actions, and destination-bound back passed');
