const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const loader=createArktsLoader(ts,{'@kit.RemoteCommunicationKit':{rcp:{}},'@kit.BasicServicesKit':{},'common_network':{PIN_BUSINESS_PIN_READ_ENABLED:true},'common_session':{PinmonySessionCredentials:class{}},'common_foundation':{PinmonyRuntimeLog:{info(){},warn(){}}}});
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const client=loader.loadFile('entry/src/main/ets/app/PinmonyBusinessAuxiliaryClient.ets');
let now=1000000;class Clock extends Date{static now(){return now;}}
const exportsObject={};
vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, fs.readFileSync('entry/src/main/ets/app/PinmonyBoardInvitationNotice.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports:exportsObject,Date:Clock,require:n=>n.includes('BusinessAuxiliaryClient')?client:n.includes('UpdatesNativeReads')?{PIN_NATIVE_INBOX_UPDATES_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){},warn(){}}}:{}});
assert.equal(exportsObject.PIN_BOARD_INVITATION_NOTICE_POLL_MS,5000);
const invite=(id='81',extra={})=>({status:'new',board:{id,url:'/peer/art/',name:'原图板名称'},invited_user:{id:'41'},invited_by_user:{id:'42',username:'peer',full_name:'原邀请者',image_medium_url:'https://i.pinimg.com/avatar.jpg',avatar_color_index:3},...extra});
function fixture(){let session={authenticated:true,accountId:'synthetic',generation:1,origin:'https://www.pinterest.com'},active=true;const jobs=[],cancelled=[],shown=[];
 const network=Object.create(Network.prototype);network.cancel=id=>cancelled.push(id);
 network.request=(job,current)=>{assert(acceptsNetworkJob(job,current()),'real native allowlist admits exact read');assert.equal(current().authenticated,true);assert.equal(job.method,'GET');assert.equal(job.body,'');const q=new URL(job.url);assert.equal(q.searchParams.get('source_url'),'/inbox/');assert.deepEqual(JSON.parse(q.searchParams.get('data')),{options:{current_user:true,field_set_key:'news'},context:{}});return new Promise(resolve=>jobs.push({job,current,reply:(rows,patch={})=>resolve({status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:'v3_user_board_invites',data:rows,...patch},client_context:{user:{id:'41',username:'viewer'}}})})}));};
 const reader=new exportsObject.PinmonyBoardInvitationNotice({session:()=>session,network:()=>network,active:()=>active,username:()=> 'viewer',observed:v=>shown.push(v)});
 return {reader,jobs,shown,cancelled,active:v=>active=v,account:()=>session={...session,accountId:'other',generation:session.generation+1}};
}
async function main(){
 const f=fixture();let p=f.reader.poll();await f.reader.poll();assert.equal(f.jobs.length,1,'single flight');f.jobs[0].reply([invite()]);await p;assert.equal(f.shown.at(-1)[0].boardName,'原图板名称');assert.equal(f.shown.at(-1)[0].inviterAvatar,'https://i.pinimg.com/avatar.jpg');assert.equal(f.shown.at(-1)[0].createdAt,'','missing HAR timestamp is not fabricated');
 const displayed=f.shown.filter(Boolean).length;now+=4999;await f.reader.poll();assert.equal(f.jobs.length,1);now++;p=f.reader.poll();assert.equal(f.jobs.length,2,'exact five second boundary');f.jobs[1].reply([invite()]);await p;assert.equal(f.shown.length,displayed+1,'validated snapshots reach shared publisher');
 now+=5000;p=f.reader.poll();f.jobs.at(-1).reply([invite(),invite('82')]);await p;assert.equal(f.shown.at(-1)[1].boardId,'82','next new invitation appears');
 now+=5000;p=f.reader.poll();f.jobs.at(-1).reply([]);await p;assert.equal(f.shown.at(-1).length,0,'accepted/removed invites are withdrawn');
 for(const rows of [[invite('83',{status:'accepted'})],[invite('83',{invited_user:{id:'99'}})],[invite('83',{board:{id:'83',url:'https://example.com/peer/art/'}})]]){now+=5000;p=f.reader.poll();f.jobs.at(-1).reply(rows);await p;assert.equal(f.shown.at(-1).length,0);}
 now+=5000;p=f.reader.poll();f.jobs.at(-1).reply([invite('84')],{endpoint_name:'wrong'});await p;assert.equal(f.shown.at(-1).length,0,'wrong endpoint rejected');
 now+=5000;p=f.reader.poll();f.reader.pause();f.jobs.at(-1).reply([invite('84')]);await p;assert.equal(f.shown.at(-1).length,0,'cancelled late response rejected');assert(f.cancelled.length);
 f.active(false);now+=5000;const count=f.jobs.length;await f.reader.poll();assert.equal(f.jobs.length,count,'no background invitation reads');
 f.active(true);p=f.reader.poll();f.account();f.jobs.at(-1).reply([invite('85')]);await p;assert.equal(f.shown.at(-1).length,0,'old account response rejected');
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
 assert(index.includes('this.boardInvitationNotice.poll();'));
 assert(index.includes('this.inboxMessageNotice.observeInvitations(items)'));
 assert(index.includes('this.openBoardInvitationNotice(item)'));
 assert(!index.includes('PinmonyBoardInvitationNoticeCard'));
 assert(!fs.existsSync('entry/src/main/ets/components/PinmonyBoardInvitationNoticeCard.ets'));
 const copy=JSON.parse(fs.readFileSync('common_foundation/src/main/resources/zh_CN/element/string.json','utf8')).string.find(row=>row.name==='pm_board_invitation_notice_text');
 assert.equal(copy.value,'{0}邀请你在{1}上进行合作');
 const boardPage=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');assert(boardPage.includes('this.onDeclineInvitation()'));assert(!boardPage.includes('PanGesture({ direction: PanDirection.Up }).onActionEnd(() => { if (!this.invitationBusy) this.onDismissInvitation(); })'));
 assert(index.includes('this.previewBoardInvitation(item,true)'));assert(index.includes('onDeclineInvitation: () => this.declineBoardInvitationPreview()'));
 console.log('Board invitation notices: real read contract, 5s/single flight, sender/avatar, pending baseline, shared publisher forwarding, invalid/removed invites, failure retry, account/background cancellation and embedded card isolation passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
