const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const start=source.indexOf('  private automaticPhotoPaging()'),end=source.indexOf('  @Builder',start);
const View=vm.runInNewContext(ts.transpileModule('class View {'+source.slice(start,end)+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{});
function fixture(){const v=new View();let calls=0;Object.assign(v,{modern:()=>true,hubPane:true,hubTab:'pins',interactionReady:true,readsReady:true,actionsReady:false,restoringScroll:false,loading:false,refreshing:false,automaticLoadingEnabled:false,syncError:'',profile:{contentHasMore:true,createdPins:[{id:'1'}]},onLoadMore:()=>calls++});return {v,calls:()=>calls};}
let f=fixture();f.v.loadMoreAtEnd();assert.equal(f.calls(),1,'photo end loads even with old manual paging policy');
for(const change of [v=>v.interactionReady=false,v=>v.restoringScroll=true,v=>v.readsReady=false,v=>v.loading=true,v=>v.refreshing=true,v=>v.profile.contentLoading=true,v=>v.profile.contentLoadingMore=true,v=>v.profile.contentError='failure',v=>v.syncError='failure',v=>v.profile.contentHasMore=false,v=>v.profile.createdPins=[]]){f=fixture();change(f.v);f.v.loadMoreAtEnd();assert.equal(f.calls(),0);}
for(const tab of ['boards','collages']){f=fixture();f.v.hubTab=tab;f.v.loadMoreAtEnd();assert.equal(f.calls(),0,'other tabs retain manual policy');f.v.automaticLoadingEnabled=true;f.v.loadMoreAtEnd();assert.equal(f.calls(),1);}
assert(source.includes('.onReachEnd(() => this.loadMoreAtEnd())'));
assert(source.includes('!this.automaticPhotoPaging() && this.profile.contentHasMore'));
assert(source.includes("Text(this.uiText('pm_profile_pins_end'))"));assert(source.includes("Text(this.uiText('pm_loading_4927a53b'))"));
console.log('Profile photo pagination: reach-end loading, active/read/loading/error/end guards, footer status and other-tab policy passed');
