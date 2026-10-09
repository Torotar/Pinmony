const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=readSourceFileSync('entry/src/main/ets/pages/Index.ets','utf8');
function method(start,end){return source.slice(source.indexOf(start),source.indexOf(end,source.indexOf(start))).replace(/private /g,'').replace(/: Promise<void>/g,'').replace(/: (?:string|number|boolean|RegExpMatchArray \| null)/g,'');}
const m=method('  private async selectInboxSection(', '  private async performInboxAction(');
let calls=0;
const obj=vm.runInNewContext('({'+m+'})',{setTimeout:()=>{},console});
Object.assign(obj,{traceAction:()=>{},inboxSectionReady:true,inboxActionsReady:false,inbox:{session:7,section:'messages',dataSource:'api'},inboxSession:7,inboxUrl:'root',currentInboxUrl:()=> 'root',inboxError:'HTTP 403',inboxLoading:false,restoringInboxSection:'',pendingInboxSection:'',inboxRequestToken:0,inboxCache:{put:()=>{throw new Error('failed contents must not enter cache')}},controller:{runJavaScript:async()=>{calls++;return 'true'}},showMessage:()=>{}});
(async()=>{await obj.selectInboxSection('updates');assert.equal(calls,1);obj.pendingInboxSection='';obj.inboxSectionReady=false;await obj.selectInboxSection('updates');assert.equal(calls,1);
const profile=method('  private profileUrlFromAddress(', '  private currentProfileUrl(');
const routes=vm.runInNewContext('({'+profile+'})',{});routes.inboxUrlFromAddress=a=>/^https:\/\/www\.pinterest\.com\/(?:inbox|messages|updates|notifications)\//.test(a)?a:'';
for(const route of ['inbox','messages','updates','notifications'])assert.equal(routes.profileUrlFromAddress('https://www.pinterest.com/'+route+'/'),'');assert.equal(routes.profileUrlFromAddress('https://www.pinterest.com/testuser/'),'https://www.pinterest.com/testuser/');
console.log('PASS native navigation: API failure permits segment switching, stale cache controls stay blocked, inbox root routes cannot trigger profile loading');})().catch(e=>{console.error(e);process.exitCode=1});
