const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const ast=ts.createSourceFile('profile.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
const names=['canPullProfileRefresh','showProfileRefreshIndicator','requestProfileRefresh','suppressContentLoading'],methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);
assert.equal(methods.length,names.length);
const RefreshStatus={Inactive:0,Drag:1,OverDrag:2,Refresh:3,Done:4};
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{RefreshStatus});
let requests=0;
function fixture(){return Object.assign(new Host(),{interactionReady:true,restoringScroll:false,loading:false,refreshing:false,modern:()=>true,profile:{contentLoading:false},profileRefreshState:RefreshStatus.Inactive,onRefresh:()=>requests++});}
const h=fixture();
for(const state of [RefreshStatus.Drag,RefreshStatus.Inactive,RefreshStatus.Drag,RefreshStatus.Done]){
 h.profileRefreshState=state;assert.equal(h.showProfileRefreshIndicator(),false,'short pull after reaching top must not display a spinner');
}
h.profileRefreshState=RefreshStatus.OverDrag;assert(h.showProfileRefreshIndicator(),'threshold readiness stays visible');
h.requestProfileRefresh();assert.equal(requests,1);
h.refreshing=true;h.profileRefreshState=RefreshStatus.Inactive;assert(h.showProfileRefreshIndicator(),'actual refresh stays visible after release');
h.requestProfileRefresh();assert.equal(requests,1,'no duplicate in-flight request');
h.refreshing=false;assert.equal(h.showProfileRefreshIndicator(),false);
for(const key of ['interactionReady','restoringScroll','loading']){
 const f=fixture();f[key]=key!=='interactionReady';f.profileRefreshState=RefreshStatus.OverDrag;
 assert.equal(f.canPullProfileRefresh(),false,key);assert.equal(f.showProfileRefreshIndicator(),false,key);
 f.requestProfileRefresh();assert.equal(requests,1,key);
}
const busy=fixture();busy.profile.contentLoading=true;busy.profileRefreshState=RefreshStatus.OverDrag;
assert.equal(busy.showProfileRefreshIndicator(),false);busy.requestProfileRefresh();assert.equal(requests,1);
h.refreshing=true;h.interactionReady=false;assert.equal(h.showProfileRefreshIndicator(),false,'inactive pager pane hides retained spinner');
assert(source.includes('.pullToRefresh(this.canPullProfileRefresh())'));
assert(source.includes('.onRefreshing(() => this.requestProfileRefresh())'));
assert(source.includes('.visibility(this.showProfileRefreshIndicator() ? Visibility.Visible : Visibility.Hidden)'));
assert(source.includes('.offset({ y: this.modern() ? this.hubContentInset() : this.profileBodyTopInset() })'),'indicator stays below the active modern or legacy profile header');
const primary=source.match(/if \(\(this.loading \|\| this.profile.contentLoading\) && !this.suppressContentLoading\(\)\)/);
assert(primary,'refresh suppresses the duplicate primary content spinner');
const primaryVisible=vm.runInNewContext('(function(){return (this.loading || this.profile.contentLoading) && !this.suppressContentLoading();})');
for(const refreshing of [true,false])for(const loading of [true,false])for(const contentLoading of [true,false]){
 assert.equal(primaryVisible.call({refreshing,loading,profile:{contentLoading},suppressContentLoading:()=>refreshing}),!refreshing&&(loading||contentLoading));
}
assert(source.includes('if (!this.modern() && this.profile.unorganizedLoading && !this.suppressContentLoading())'),'modern profile never displays the auxiliary bottom spinner');
for(const modern of [true,false])for(const refreshing of [true,false])for(const state of Object.values(RefreshStatus)){
 const f=fixture();f.modern=()=>modern;f.refreshing=refreshing;f.profileRefreshState=state;
 const expected=refreshing || [RefreshStatus.Drag,RefreshStatus.OverDrag,RefreshStatus.Refresh].includes(state);
 assert.equal(f.suppressContentLoading(),expected,'modern pull states and real refresh suppress body indicators');
}
const content=source.slice(source.indexOf('  private profileContent()'),source.indexOf('  private requestProfileBack()'));
const footerGuards=content.split('\n').filter(line=>line.includes('if')&&line.includes('suppressContentLoading')&&
 (line.includes('contentLoadingMore')||line.includes('automaticPhotoPaging()')));
assert.equal(footerGuards.length,2,'photo and board pagination spinners both gated');
console.log('Profile pull refresh: short pull/rebound hidden, threshold and actual refresh visible, busy/restore/inactive guards and Refresh wiring passed');
