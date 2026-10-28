const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function host(path,names){
  const text=fs.readFileSync(path,'utf8'),ast=ts.createSourceFile(path,text,ts.ScriptTarget.Latest,true);
  const cls=ast.statements.find(ts.isClassDeclaration);
  const body=names.map(name=>{const member=cls.members.find(m=>m.name?.getText(ast)===name);assert(member,name);return member.getText(ast);}).join('\n');
  return vm.runInNewContext(ts.transpileModule('class Host {'+body+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:{message:k=>k}});
}
(async()=>{
  const Native=host('entry/src/main/ets/app/PinmonySearchNativeReads.ets',['recoveryFilterFeed','filters','filterTarget']);
  const origin='https://www.pinterest.com',pins=origin+'/search/pins/?q=test',video=origin+'/search/videos/?q=test';
  const feed={snapshot:{pageKey:pins},filters:[{id:'pins',label:'Pins',enabled:true,selected:true},{id:'video',label:'Videos',enabled:true,selected:false}],targets:new Map([['pins',pins+'&rs=content_type_filter'],['video',video+'&rs=content_type_filter']])};
  const h=new Native();Object.assign(h,{page:video,feeds:new Map([[pins,feed]]),store:{searchFilterToken:1},revision:1,filterRevision:0,
    bind:()=>true,owned:()=>true,query:p=>new URL(p).searchParams.get('q'),param:()=>''});
  await h.filters();assert.equal(h.store.searchFilterError,'');assert.equal(h.store.searchFilterOptions.length,2);
  assert.equal(h.store.searchFilterOptions[0].selected,false);assert.equal(h.store.searchFilterOptions[1].selected,true);
  assert.equal(h.filterTarget('pins'),pins+'&rs=content_type_filter');assert.equal(h.filterTarget('video'),'');
  h.page=video.replace('test','different');await h.filters();assert.equal(h.store.searchFilterOptions.length,0);assert.equal(h.filterTarget('pins'),'');
  h.page=video;h.owned=()=>false;assert.equal(h.recoveryFilterFeed(),undefined);assert.equal(h.filterTarget('pins'),'');
  const Controller=host('feature_search/src/main/ets/controllers/PinmonySearchController.ets',['openSearchFilters']);
  const c=new Controller();let opened=0,loaded=0;
  Object.assign(c,{searchStore:{searchNativeReadsReady:false,searchNativeInputReady:true,search:{query:'test'},searchFilterToken:0},ports:{nativeSearch:()=>true,sheetKind:()=>'',setFilterVisible:()=>opened++,nativeSearchFilters:async()=>loaded++}});
  await c.openSearchFilters();assert.equal(opened,1);assert.equal(loaded,1);
  console.log('Search filter recovery: failed feed can reopen, same-query validated targets, selection refresh, query and session isolation passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
