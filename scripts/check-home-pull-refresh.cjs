const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets','utf8');
const ast=ts.createSourceFile('pane.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
const names=['canPullRefresh','showRefreshIndicator','requestPullRefresh'],methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);
assert.equal(methods.length,names.length);
const RefreshStatus={Inactive:0,Drag:1,OverDrag:2,Refresh:3,Done:4};
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{RefreshStatus});
let requests=0;
function fixture(){return Object.assign(new Host(),{paneActive:true,feedActive:true,interactionReady:true,offlinePreview:false,loading:false,refreshing:false,home:{refreshing:false},pendingTabId:'',refreshGestureState:RefreshStatus.Inactive,onRefresh:()=>requests++});}
const h=fixture();
for(const state of [RefreshStatus.Inactive,RefreshStatus.Drag,RefreshStatus.Inactive,RefreshStatus.Drag,RefreshStatus.Done]){h.refreshGestureState=state;assert.equal(h.showRefreshIndicator(),false,'short pull/rebound without reaching the threshold never shows a spinner');}
h.refreshGestureState=RefreshStatus.OverDrag;assert(h.showRefreshIndicator(),'deliberate pull past threshold shows refresh readiness');
h.requestPullRefresh();assert.equal(requests,1,'normal refresh remains connected');
h.refreshing=true;h.refreshGestureState=RefreshStatus.Inactive;assert(h.showRefreshIndicator(),'confirmed in-flight refresh stays visible after release');
h.requestPullRefresh();assert.equal(requests,1,'in-flight refresh does not dispatch twice');
h.refreshing=false;assert.equal(h.showRefreshIndicator(),false,'completion hides the indicator');
h.home.refreshing=true;assert(h.showRefreshIndicator(),'snapshot refresh remains visible');
for(const [key,value] of [['paneActive',false],['feedActive',false],['interactionReady',false],['offlinePreview',true],['loading',true],['pendingTabId','next']]){
  const f=fixture();f[key]=value;f.refreshGestureState=RefreshStatus.OverDrag;
  assert.equal(f.canPullRefresh(),false,key);assert.equal(f.showRefreshIndicator(),false,key);
  f.requestPullRefresh();assert.equal(requests,1,key+' cannot refresh');
}
h.paneActive=false;assert.equal(h.showRefreshIndicator(),false,'hidden category cannot display a retained refresh spinner');
assert(source.includes('.pullToRefresh(this.canPullRefresh())'));
assert(source.includes('.onRefreshing(() => this.requestPullRefresh())'));
assert(source.includes('.visibility(this.showRefreshIndicator() ? Visibility.Visible : Visibility.Hidden)'));
assert(source.includes('.offset({ y: this.homeTopInset() + 48 + (this.home.board ? 68 : 0) })'),'preserve placement below the title/board header');
console.log('Home pull refresh: short pull/rebound hidden, threshold readiness, active refresh lifetime, hidden/busy/offline isolation and actual Refresh wiring passed');
