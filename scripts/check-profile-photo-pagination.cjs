const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const start=source.indexOf('  private automaticPhotoPaging()'),end=source.indexOf('  @Builder',start);
const View=vm.runInNewContext(ts.transpileModule('class View {'+source.slice(start,end)+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{});
function fixture(){const v=new View();let calls=0;Object.assign(v,{modern:()=>true,hubPane:true,hubTab:'pins',interactionReady:true,readsReady:true,actionsReady:false,restoringScroll:false,loading:false,refreshing:false,automaticLoadingEnabled:false,syncError:'',profile:{contentHasMore:true,createdPins:[{id:'1'}]},onLoadMore:()=>calls++});return {v,calls:()=>calls};}
let f=fixture();f.v.loadMoreAtEnd();assert.equal(f.calls(),1,'photo end loads even with old manual paging policy');
for(const change of [v=>v.interactionReady=false,v=>v.restoringScroll=true,v=>v.readsReady=false,v=>v.loading=true,v=>v.refreshing=true,v=>v.profile.contentLoading=true,v=>v.profile.contentLoadingMore=true,v=>v.profile.contentError='failure',v=>v.syncError='failure',v=>v.profile.contentHasMore=false,v=>v.profile.createdPins=[]]){f=fixture();change(f.v);f.v.loadMoreAtEnd();assert.equal(f.calls(),0);}
for(const tab of ['boards','collages']){f=fixture();f.v.hubTab=tab;f.v.loadMoreAtEnd();assert.equal(f.calls(),0,'other tabs retain manual policy');f.v.automaticLoadingEnabled=true;f.v.loadMoreAtEnd();assert.equal(f.calls(),1);}
assert(source.includes('.onReachEnd(() => this.loadMoreAtEnd())'));
assert(source.includes('!this.automaticPhotoPaging() && !this.automaticFollowingBoardPaging() && this.profile.contentHasMore'));
assert(source.includes("Text(this.uiText('pm_profile_pins_end'))"));assert(source.includes("Text(this.uiText('pm_loading_4927a53b'))"));
function following(){const f=fixture();Object.assign(f.v,{hubTab:'boards',boardFilter:'following'});Object.assign(f.v.profile,{hubMode:'following',boards:[{id:'board-1'}],createdPins:[]});return f;}
f=following();f.v.loadMoreAtEnd();assert.equal(f.calls(),1,'followed boards load on reach-end even when manual paging preference is selected');
for(const change of [v=>v.interactionReady=false,v=>v.restoringScroll=true,v=>v.readsReady=false,v=>v.loading=true,v=>v.refreshing=true,v=>v.profile.contentLoading=true,v=>v.profile.contentLoadingMore=true,v=>v.profile.contentError='failure',v=>v.syncError='failure',v=>v.profile.contentHasMore=false,v=>v.profile.boards=[],v=>v.profile.hubMode='boards',v=>v.boardFilter='secret',v=>v.hubPane=false]){f=following();change(f.v);f.v.loadMoreAtEnd();assert.equal(f.calls(),0,'followed board loading respects visible mode, readiness, busy/error/end and restoration guards');}
const buttonLine=source.split('\n').find(line=>line.includes('if(')&&line.includes('!this.automaticPhotoPaging()')&&line.includes('contentHasMore'));
const buttonVisible=vm.runInNewContext('(function(){return '+buttonLine.trim().slice(3,-3)+';})');
f=following();assert.equal(buttonVisible.call(f.v),false,'followed boards never show manual load-more button');
f.v.boardFilter='';f.v.profile.hubMode='boards';assert.equal(buttonVisible.call(f.v),true,'other board filters retain their existing button');
const footer=source.match(/else if \(([^\n]+this\.profile\.contentLoadingMore)\) \{\s*LoadingProgress\(\)/);
assert(footer,'board paging retains its footer spinner');
const footerVisible=new Function('return '+footer[1]);
for(const state of [{},{suppressed:true},{loading:true},{initial:true},{idle:true}]) {
  assert.equal(!!footerVisible.call({suppressContentLoading:()=>!!state.suppressed,loading:!!state.loading,
    profile:{contentLoading:!!state.initial,contentLoadingMore:!state.idle}}),Object.keys(state).length===0,
    'footer shows only during visible pagination, never during suppression or initial loading');
}
console.log('Profile photo pagination: reach-end loading, active/read/loading/error/end guards, footer status and other-tab policy passed');
