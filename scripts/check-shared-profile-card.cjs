const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets','utf8');
const start=source.indexOf('  private openSharedProfile('),end=source.indexOf('\n  private ',start+1);assert(start>=0&&end>start);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const calls=[],h=new Host();h.active=true;h.snapshot={messages:[]};h.captureChatOffset=()=>calls.push('offset');h.onUser=url=>calls.push(url);
for(const own of [true,false]){h.snapshot.messages=[{id:'1',own,profile:{name:'Shared user',profileUrl:'https://www.pinterest.com/shared_user/'},sender:{profileUrl:'https://www.pinterest.com/sender/'}}];calls.length=0;h.openSharedProfile('1');assert.deepEqual(calls,['offset','https://www.pinterest.com/shared_user/']);}
for(const state of ['deleted','missing','inactive','stale']){calls.length=0;h.active=state!=='inactive';h.snapshot.messages=[{id:'1',deleted:state==='deleted',profile:state==='missing'?{}:{profileUrl:'https://www.pinterest.com/shared_user/'}}];h.openSharedProfile(state==='stale'?'2':'1');assert.equal(calls.length,0);}
assert(source.includes('.onClick(() => this.openSharedProfile(message.id))'));
assert(source.includes(".alignItems(HorizontalAlign.Center).hitTestBehavior(HitTestMode.None)"));
console.log('Shared profile card: sent/received target, current message, deleted/missing/inactive guards, offset and unified touch surface passed');
