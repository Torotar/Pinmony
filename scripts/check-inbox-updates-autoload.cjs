const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8');
const method=source.match(/  private loadMoreUpdatesAtEnd\(\): void \{[\s\S]*?\n  \}/);assert(method);
const View=vm.runInNewContext(ts.transpileModule('class View {'+method[0]+'} View;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
function fixture(){const v=new View();v.calls=0;Object.assign(v,{interactionReady:true,actionsReady:true,restoringScroll:false,loading:false,refreshing:false,snapshot:{section:'updates',dataSource:'api',hasMore:true},onLoadMore:()=>{v.calls++;v.snapshot.moreLoading=true;}});return v;}
let v=fixture();v.loadMoreUpdatesAtEnd();v.loadMoreUpdatesAtEnd();assert.equal(v.calls,1,'in-flight pagination cannot repeat');v.snapshot.moreLoading=false;v.loadMoreUpdatesAtEnd();assert.equal(v.calls,2,'next cursor can load on next reach-end');
for(const [key,value] of [['interactionReady',false],['actionsReady',false],['restoringScroll',true],['loading',true],['refreshing',true]]){v=fixture();v[key]=value;v.loadMoreUpdatesAtEnd();assert.equal(v.calls,0,key);}
for(const [key,value] of [['section','messages'],['dataSource','dom'],['hasMore',false],['moreLoading',true],['moreError','error']]){v=fixture();v.snapshot[key]=value;v.loadMoreUpdatesAtEnd();assert.equal(v.calls,0,key);}
assert(source.includes('.onReachEnd(() => this.loadMoreUpdatesAtEnd())'));assert(!source.includes('pm_load_more_af90a08f'));assert(source.includes('PinmonyI18n.render(this.snapshot.moreError, this.uiLanguage)'));
console.log('Inbox updates: automatic reach-end pagination, duplicate/loading/hidden/refresh/restore/end/error guards and removal of load-more button passed');
