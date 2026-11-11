const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const read=file=>fs.readFileSync(file,'utf8');
function method(source,name){
 const match=new RegExp('^  private (?:async )?'+name+'\\(', 'm').exec(source);assert(match,name);
 const start=match.index,next=/\n  (?:private |@Builder|@State|@Prop|aboutToAppear\(|build\()/g;next.lastIndex=start+1;
 const end=next.exec(source);return source.slice(start,end?end.index:source.length);
}
function host(source,names){return vm.runInNewContext(ts.transpileModule('class Host {'+names.map(n=>method(source,n)).join('\n')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);}
function reboundBodies(source){
 const result=[],pattern=/onWillSpringBackWhenDismiss\s*:\s*\([^)]*\)\s*:\s*void\s*=>\s*\{/g;let match;
 while((match=pattern.exec(source))){let end=pattern.lastIndex,depth=1;for(;end<source.length&&depth;end++){if(source[end]==='{')depth++;if(source[end]==='}')depth--;}result.push(source.slice(pattern.lastIndex,end-1));}
 return result;
}
const paths={index:'entry/src/main/ets/pages/Index.ets',search:'feature_search/src/main/ets/components/PinmonySearchPage.ets',inbox:'feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets',board:'feature_board/src/main/ets/components/PinmonyBoardPage.ets',section:'feature_board/src/main/ets/components/PinmonyBoardSectionPage.ets',publish:'feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets',privacy:'feature_settings/src/main/ets/components/PinmonyVisibilitySettingsPage.ets',image:'common_ui/src/main/ets/components/PinmonyImageSearchView.ets'};
const sources=Object.fromEntries(Object.entries(paths).map(([k,p])=>[k,read(p)]));
const counts={index:2,search:1,inbox:2,board:4,section:1,publish:1,privacy:1,image:1};
for(const [name,source] of Object.entries(sources)){
 const bodies=reboundBodies(source);assert.equal(bodies.length,counts[name],name+' audited Sheet hooks');
 for(const [i,body] of bodies.entries()){
  const Hook=vm.runInNewContext(ts.transpileModule('class Hook {run(action: SpringBackAction):void{'+body+'}} Hook;',{}).outputText);
  const h=new Hook();Object.assign(h,{activeSheetKind:'share',busy:false,settingsStore:{busy:false},store:{busy:false},state:{busy:false},snapshot:{flow:{busy:false,uncertain:false}},pinStore:{saveResult:{busy:false},editResult:{busy:false,picker:{busy:false},phase:'edit'}}});
  let springs=0;const action={springBack(){springs++;}};h.run(action);assert.equal(springs,0,name+': ordinary exit is continuous');
  if(['section','publish','privacy','board'].includes(name)||name==='index'){
   h.busy=true;h.settingsStore.busy=true;h.store.busy=true;h.state.busy=true;h.snapshot.flow.busy=true;h.activeSheetKind='edit';h.pinStore.editResult.busy=true;h.run(action);assert.equal(springs,1,name+': busy gate rebounds');
  }
  if(name==='board'&&i>=2){h.snapshot.flow.busy=false;h.snapshot.flow.uncertain=true;h.run(action);assert.equal(springs,2,'uncertain write remains protected');}
 }
}
// The section host stays mounted until the Sheet finishes, including repeated close requests.
const Section=host(sources.section,['backRequested','requestClose','finishClose']);const section=new Section();let closed=0;
Object.assign(section,{visible:true,busy:true,closePending:false,onClose(){closed++;}});section.requestClose();assert.equal(section.visible,true);
section.busy=false;section.requestClose();section.requestClose();assert.equal(closed,0);assert.equal(section.visible,false);section.finishClose();section.finishClose();assert.equal(closed,1);
section.visible=true;section.closeRequest=1;section.backRequested();assert.equal(section.visible,false);assert.equal(closed,1);section.finishClose();assert.equal(closed,2,'global back requests native exit before host cleanup');
assert(sources.index.includes('if (this.boardSectionVisible) { this.boardSectionCloseRequest++; return true; }'));
assert(sources.section.includes('onDisappear: (): void => this.finishClose()'));
// Search keeps picker data through exit and stale snapshots cannot reopen it while back is pending.
const Search=host(sources.search,['quizBackRequested','syncQuizPresentation','quizContextKey','requestQuizClose','finishQuizClose']);
function search(){const h=new Search(),events=[];Object.assign(h,{quizClosingKey:'',quizCloseDispatched:false,quizSheetOpen:true,snapshot:{pageKey:'search',session:1,quiz:{mode:'picker',cards:[{id:'card'}]},results:[]},syncResultRows(){},contentColumns:()=>2,flowSections:{length:()=>0,splice(){}},onQuizAction(...args){events.push(args);}});return {h,events};}
let q=search();q.h.requestQuizClose();assert.equal(q.events.length,0);assert.equal(q.h.snapshot.quiz.mode,'picker');q.h.syncQuizPresentation();assert.equal(q.h.quizSheetOpen,false);q.h.finishQuizClose();q.h.finishQuizClose();assert.equal(q.events.length,1);q.h.syncQuizPresentation();assert.equal(q.h.quizSheetOpen,false);q.h.snapshot.quiz.mode='entry';q.h.syncQuizPresentation();assert.equal(q.h.quizClosingKey,'');
q=search();q.h.requestQuizClose();q.h.snapshot.session++;q.h.finishQuizClose();assert.equal(q.events.length,0,'late close does not return a new session');q.h.syncQuizPresentation();assert.equal(q.h.quizSheetOpen,true);
q=search();q.h.quizSheetOpen=false;q.h.requestQuizClose();q.h.finishQuizClose();assert.equal(q.events.length,1,'two-way binding may clear visibility before interactive callback');
q=search();q.h.quizCloseRequest=1;q.h.quizBackRequested();assert.equal(q.events.length,0);q.h.finishQuizClose();assert.equal(q.events.length,1,'root back waits for native Sheet disappearance');
const Root=host(sources.index,['requestSearchQuizClose']);const root=new Root();Object.assign(root,{searchStore:{search:{pageKey:'search',quiz:{mode:'picker'}}},currentSearchPageKey:()=> 'search',searchQuizCloseRequest:0});assert.equal(root.requestSearchQuizClose(),true);assert.equal(root.searchQuizCloseRequest,1);assert.equal(root.searchStore.search.quiz.mode,'picker');root.searchStore.search.quiz.mode='entry';assert.equal(root.requestSearchQuizClose(),false);
// Publish creation retains the create phase until disappearance and ignores stale tokens.
const Publish=host(sources.publish,['syncCreate','requestCreateClose','finishCreateClose','closeCreate']);
function publish(){const h=new Publish(),events=[];Object.assign(h,{state:{phase:'create',token:1,page:'profile',kind:'photo',busy:false},createVisible:true,createClosing:false,createCloseDispatched:false,sectionPaths:{size:()=>0,pushPath(){}},onAction(...args){events.push(args);}});return {h,events};}
let p=publish();p.h.requestCreateClose();assert.equal(p.events.length,0);p.h.syncCreate();assert.equal(p.h.createVisible,false);p.h.finishCreateClose();p.h.finishCreateClose();assert.equal(p.events.length,1);assert.equal(p.events[0][0],'boards');p.h.syncCreate();assert.equal(p.h.createVisible,false);p.h.state.phase='boards';p.h.syncCreate();assert.equal(p.h.createClosing,false);
p=publish();p.h.requestCreateClose();p.h.state.token++;p.h.finishCreateClose();assert.equal(p.events.length,0);p.h.syncCreate();assert.equal(p.h.createVisible,true);
p=publish();p.h.createVisible=false;p.h.requestCreateClose();p.h.finishCreateClose();assert.equal(p.events.length,1,'publish interactive close does not depend on visibility callback ordering');
// Single-pin move defers its phase change; same-context reads cannot reopen the closing Sheet.
const Move=host(sources.board,['syncMoveVisibility','requestMoveClose','finishMoveClose','confirmationKey','act','back']);
function move(){const h=new Move(),events=[];Object.assign(h,{singlePinMove:true,moveSheetOpen:true,moveClosingKey:'',moveCloseDispatched:false,snapshot:{pageKey:'board',session:1,flow:{phase:'targets',busy:false,uncertain:false}},onAction(raw){events.push(JSON.parse(raw));},phase:()=>''});return {h,events};}
let m=move();m.h.requestMoveClose();m.h.act('createTarget');assert.equal(m.events.length,0);m.h.syncMoveVisibility();assert.equal(m.h.moveSheetOpen,false);m.h.finishMoveClose();m.h.finishMoveClose();assert.equal(m.events.length,1);assert.equal(m.events[0].action,'close');m.h.syncMoveVisibility();assert.equal(m.h.moveSheetOpen,false);m.h.snapshot.flow.phase='select';m.h.syncMoveVisibility();assert.equal(m.h.moveClosingKey,'');
m=move();m.h.requestMoveClose();m.h.snapshot.session++;m.h.finishMoveClose();assert.equal(m.events.length,0,'old move dismissal cannot close a new board session');
m=move();m.h.back();assert.equal(m.events.length,0,'move back also waits for Sheet disappearance');m.h.finishMoveClose();assert.equal(m.events.length,1);
console.log('Panel dismissal: all 13 Sheet hooks, busy/uncertain gates, deferred section/search/publish/move cleanup, duplicate callbacks, snapshot reentry and stale contexts passed');
