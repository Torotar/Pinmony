const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const {createHomeRuntime}=require('./home-controller-harness.cjs');
const globals={setTimeout:()=>0,clearTimeout(){},PinmonyRuntimeLog:{info(){},warn(){}}};
const runtime=createHomeRuntime(ts,globals), root='https://www.pinterest.com/';
const before=fs.readFileSync('diagnostics/home-controller-refactor-20261009/before/entry/src/main/ets/pages/Index.ets','utf8').replaceAll('PinWeb','Pinmony'); // Normalize only the historical product name; keep the protected snapshot unchanged.
function method(name){const start=before.search(new RegExp('  private (?:async )?'+name+'\\('));assert(start>=0,name);return before.slice(start,before.indexOf('\n  }',start)+4);}
const retainHomePins=runtime.loader.loadFile('feature_home/src/main/ets/services/PinmonyHomeRetention.ets').retainHomePins;
const Legacy=require('./product-coordination-harness.cjs').run(ts,ts.transpileModule('class Legacy {'+['prepareHomeForPageBegin','clearHome','expectHome','updateHome','selectHomeTab','loadMoreHome','refreshHome','normalizeHomeBoard'].map(method).join('\n')+'} Legacy;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{...globals,Date,PIN_HOME_API_ENABLED:true,retainHomePins});
const pin=id=>({id,pinUrl:root+'pin/'+id+'/',imageUrl:'https://i.pinimg.com/'+id+'.jpg',imageWidth:200,imageHeight:300,title:'title-'+id,hasMore:true});
const tabs=[{id:'all',label:'所有',selected:true,enabled:true},{id:'board',label:'Board',selected:false,enabled:true}];
const state=(session,pins=[pin('123')],changes={})=>({kind:'state',session,pageKey:root,selectedTab:'所有',tabs,pins,dataSource:'api',...changes});
const clone=value=>JSON.parse(JSON.stringify(value));
const fields=['home','cachedHome','cachedHomeScrollOffset','homeSourceWarning','retainingHomeFeed','homeAppendRequested','homeRefreshing',
 'homeRefreshAwaitingPage','homeActionsReady','homeLoading','homeError','homeRequestToken','homeRefreshToken','homeMoreRequestToken',
 'pendingHomeTab','homeTabNeedsRedispatch','homeMoreLoadingId','homeMenuPin'];
function pair(cached=false){
 const h=runtime.harness({knownPinTitle:id=>id==='456'?'known title':'',isSaved:id=>id==='123'}),old=new Legacy(),scripts=[];
 Object.assign(old,{homeStore:new runtime.Store(),authStatus:'authenticated',activeTab:0,currentHomePageKey:()=>root,homePresentationPageKey:()=>root,
  homePageKeyFromAddress:url=>url===root?root:'',searchUrlFromAddress:()=>'',inboxUrlFromAddress:()=>'',profileUrlFromAddress:()=>'',
  pinIdentity:url=>url.match(/\/pin\/(\d+)/)?.[1]||'',searchStore:{knownSearchPinTitles:new Map([['456','known title']])},pinStore:{confirmedSaves:{isSaved:id=>id==='123'}},
  rootTabAddresses:new Map(),persistHomeDiskCache(){},showMessage(){},traceAction(){},rejectOfflineAction:()=>false,ensureRootActionContext:async()=>true,
  controller:{runJavaScript:async text=>{scripts.push(text);return 'true';},refresh(){},loadUrl(){}},homeDiskCacheRestored:false,homeDiskCacheRestoredAt:0});
 if(cached){const saved=state(9,[pin('123'),pin('456')]);old.homeStore.cachedHome=clone(saved);h.store.cachedHome=clone(saved);old.homeStore.cachedHomeScrollOffset=h.store.cachedHomeScrollOffset=400;}
 return{h,old,scripts};
}
let comparisons=0;
function compare(p,label){
 for(const field of fields)assert.equal(JSON.stringify(p.h.store[field]),JSON.stringify(p.old.homeStore[field]),label+': '+field);
 assert.equal(p.h.store.startupFeedCommitted,!!p.old.homeStartupFeedCommitted,label+': network commit marker');
 assert.deepEqual(p.h.events.filter(e=>e[0]==='js').map(e=>e[1]),p.scripts,label+': script/session/page payload');comparisons++;
}
async function main(){
 for(const cached of [false,true]){
  const p=pair(cached);p.old.prepareHomeForPageBegin(root);p.h.controller.prepareHomeForPageBegin(root);compare(p,'prepare');
  for(const message of [state(1,[pin('456')],{kind:'loading'}),state(1,[pin('789'),pin('456')]),state(2,[],{kind:'failed',error:'real failure'}),
   state(2,[],{kind:'loading'}),state(2,[pin('789')]),state(1,[pin('999')]),state(3,[],{pageKey:root+'today/'}),state(3,[])]){
   p.old.updateHome(JSON.stringify(message));p.h.controller.updateHome(JSON.stringify(message));compare(p,message.kind);
  }
  p.old.homeStore.homeActionsReady=p.h.store.homeActionsReady=true;
  await p.old.loadMoreHome();await p.h.controller.loadMoreHome();compare(p,'pagination');
  const next=state(4,[pin('777')]);p.old.updateHome(JSON.stringify(next));p.h.controller.updateHome(JSON.stringify(next));compare(p,'append');
  p.old.refreshHome();p.h.controller.refreshHome();compare(p,'refresh dispatch');
  const refreshed=state(5,[pin('888')]);p.old.updateHome(JSON.stringify(refreshed));p.h.controller.updateHome(JSON.stringify(refreshed));compare(p,'refresh commit');
  await p.old.selectHomeTab('board');await p.h.controller.selectHomeTab('board');compare(p,'category dispatch');
  const board=state(6,[pin('999')],{selectedTab:'Board',tabs:[{...tabs[0],selected:false},{...tabs[1],selected:true}],board:{id:'42',name:' Board ',pinCount:2.8,thumbnailUrl:''}});
  p.old.updateHome(JSON.stringify(board));p.h.controller.updateHome(JSON.stringify(board));compare(p,'category commit');
  p.old.clearHome();p.h.controller.clearHome();compare(p,'clear');
 }
 console.log('Home migration equivalence: '+comparisons+' state/dispatch comparisons against the preserved pre-migration implementation passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
