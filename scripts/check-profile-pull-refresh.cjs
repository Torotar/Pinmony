const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const ast=ts.createSourceFile('profile.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
const names=['canPullProfileRefresh','showProfileRefreshIndicator','requestProfileRefresh'],methods=[];
function visit(node){if(ts.isMethodDeclaration(node)&&names.includes(node.name.getText(ast)))methods.push(node.getText(ast));ts.forEachChild(node,visit);}visit(ast);
assert.equal(methods.length,names.length);
const RefreshStatus={Inactive:0,Drag:1,OverDrag:2,Refresh:3,Done:4};
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{RefreshStatus});
let requests=0;
function fixture(){return Object.assign(new Host(),{interactionReady:true,restoringScroll:false,loading:false,refreshing:false,profile:{contentLoading:false},profileRefreshState:RefreshStatus.Inactive,onRefresh:()=>requests++});}
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
assert(source.includes('.offset({ y: this.hubContentInset() })'),'indicator stays below profile header and filters');
const primary=source.match(/if \(\(this.loading \|\| this.profile.contentLoading\) && !this.refreshing\)/);
assert(primary,'refresh suppresses the duplicate primary content spinner');
const primaryVisible=vm.runInNewContext('(function(){return (this.loading || this.profile.contentLoading) && !this.refreshing;})');
for(const refreshing of [true,false])for(const loading of [true,false])for(const contentLoading of [true,false]){
 assert.equal(primaryVisible.call({refreshing,loading,profile:{contentLoading}}),!refreshing&&(loading||contentLoading));
}
assert(source.includes('if (this.profile.unorganizedLoading && !this.refreshing)'),'refresh suppresses auxiliary content spinner');
console.log('Profile pull refresh: short pull/rebound hidden, threshold and actual refresh visible, busy/restore/inactive guards and Refresh wiring passed');
