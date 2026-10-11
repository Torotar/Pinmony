const { readSourceFileSync } = require('./source-files.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=readSourceFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(start,end){return source.slice(source.indexOf(start),source.indexOf(end,source.indexOf(start))).replace(/private /g,'').replace(/: Promise<void>/g,'').replace(/: (?:string|number|boolean|RegExpMatchArray \| null)/g,'');}
const ts=require(process.argv[2] || 'typescript');
const {Store,PinmonyInboxReadController}=require('./inbox-read-controller-harness.cjs').create(ts,{setTimeout:()=>0,clearTimeout(){}});
const store=new Store(); let calls=0;
Object.assign(store,{inboxSectionReady:true,inboxActionsReady:false,inbox:{session:7,section:'messages',dataSource:'api'},inboxSession:7,inboxUrl:'root',inboxError:'HTTP 403',inboxLoading:false});
store.inboxCache.put=()=>{throw Error('failed contents must not enter cache')};
const controller=new PinmonyInboxReadController(store,{authenticated:()=>true,foreground:()=>true,activeTab:()=>2,
 document:()=> 'root',currentInbox:()=> 'root',prepareContext:async()=>true,runScript:async()=>{calls++;return 'true'},feedback(){},readStarted(){},cancelled(){}});
(async()=>{await controller.selectSection('updates');assert.equal(calls,1);store.pendingInboxSection='';store.inboxSectionReady=false;await controller.selectSection('updates');assert.equal(calls,1);
const profile=method('  private profileUrlFromAddress(', '  private currentProfileUrl(');
const routes=require('./product-coordination-harness.cjs').run(ts,'({'+profile+'})',{});routes.inboxUrlFromAddress=a=>/^https:\/\/www\.pinterest\.com\/(?:inbox|messages|updates|notifications)\//.test(a)?a:'';
for(const route of ['inbox','messages','updates','notifications'])assert.equal(routes.profileUrlFromAddress('https://www.pinterest.com/'+route+'/'),'');assert.equal(routes.profileUrlFromAddress('https://www.pinterest.com/testuser/'),'https://www.pinterest.com/testuser/');
console.log('PASS native navigation: API failure permits segment switching, stale cache controls stay blocked, inbox root routes cannot trigger profile loading');})().catch(e=>{console.error(e);process.exitCode=1});
