const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function load(file,deps=()=>({})){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,{exports,require:deps,setTimeout,clearTimeout,console});return exports;}
const deps=n=>n==='feature_pin'?{PIN_POST_EXTENSIONS_ENABLED:true}:n==='common_network'?{PIN_BUSINESS_PIN_READ_ENABLED:true}:n==='common_foundation'?{PinmonyRuntimeLog:{info(){}}}:{};
const Writes=load('entry/src/main/ets/app/PinmonyCommentNativeWrites.ets',deps).PinmonyCommentNativeWrites;
const Reads=load('entry/src/main/ets/app/PinmonyDetailNativeReads.ets',deps).PinmonyDetailNativeReads;
const {PinmonyNativeNetwork:Network,acceptsNetworkJob}=load('common_network/src/main/ets/PinmonyNativeNetwork.ets',n=>n==='common_session'?{PinmonySessionCredentials:class{}}:{});
const origin='https://www.pinterest.com',pin=origin+'/pin/11/',flush=()=>new Promise(setImmediate);
const envelope=(data,endpoint='',viewer='42',extra={})=>JSON.stringify({client_context:{user:{id:viewer}},resource_response:{status:'success',code:0,endpoint_name:endpoint,data,...extra}});
const comment=(id='5',text='old',user='42',photo=false)=>({id,type:photo?'userdiditdata':'aggregatedcomment',text:photo?undefined:text,details:photo?text:undefined,user:{id:user,username:'reader'},liked_by_me:false,reaction_by_me:0,images:[],comment_count:1});
function fixture(){
 let session={authenticated:true,accountId:'profile-cache-key',generation:1,origin,userAgent:'synthetic',appVersion:'synthetic.1'},visible=true,owns=true;
 const changes=[],store={detail:{pinUrl:pin},commentToken:1,detailOpeningToken:1,detailPin:pin,detailOpeningPin:'',detailCache:{remove(){}},commentResult:{pin,loading:false,error:'',busy:false,items:[],mutationVersion:0}};
 let result=store.commentResult;Object.defineProperty(store,'commentResult',{get:()=>result,set:v=>{changes.push(v);result=v}});
 const pending=[],gets=[],cancels=[],uploads=[],server=[],readResult={error:false};
 const network={cancel:id=>cancels.push(id),requestBusinessCommentWrite(job,...args){assert(args.at(-1)());return new Promise(resolve=>pending.push({job,args,resolve:body=>resolve({status:200,error:'',body})}));},
 requestBusinessPinRead:async(job,context,p,current)=>{gets.push(job);assert(current());return {status:200,error:readResult.error?'offline':'',body:envelope(server,'','42',{bookmark:'-end-'})};},
 uploadCommentImage:async(bytes,p,context,id)=>{uploads.push({bytes,p,context,id});assert(context().authenticated);return 'a'.repeat(32);}};
 const reads=new Reads({pinStore:()=>store,session:()=>session,network:()=>network,foreground:()=>visible,rootOnly:()=>!owns,backTarget:()=>'',mark(){},legacyContext(){throw Error('Web context')}});
 Object.assign(reads,{pin,opening:1,sessionGeneration:1,aggregate:'77'});
 store.commentResult.items=[reads.mapWrittenComment(comment(), '42'),reads.mapWrittenComment(comment('6','photo','42',true),'42'),reads.mapWrittenComment(comment('7','other','99'),'42')];
 const writer=new Writes({store:()=>store,session:()=>session,network:()=>network,reads:()=>reads,readJpeg:async uri=>{assert.equal(uri,'file://media/image');return new Uint8Array([1,2,3]).buffer;}});
 const current=()=>visible&&owns&&session.authenticated;
 return {writer,reads,store,pending,gets,cancels,uploads,changes,network,server,readResult,current,session:()=>session,setSession:s=>session=s,setVisible:v=>visible=v,setOwned:v=>owns=v};
}
const input=(action,id='',text='new',more={})=>JSON.stringify({action,id,text,...more});
async function prepare(f,action,id='',text='new',more={}){
 const start=f.pending.length,p=action==='like'?f.writer.like(id,f.current):f.writer.write(input(action,id,text,more),f.current);
 assert.equal(f.pending.length,start+1);
 assert.match(f.pending[start].job.url,/PinResource\/get\//);
 f.pending[start].resolve(envelope({id:'11',aggregated_pin_data:{id:'77'}}));await flush();return {p,start,request:f.pending[start+1]};
}
async function main(){
 // Exercise every supported write with real native-read result mapping and revalidation.
 for(const spec of [
  ['create','','AggregatedCommentResource/create','v3_create_aggregated_pin_data_comment',comment('8','new')],
  ['reply','5','AggregatedCommentReplyResource/create','v3_create_aggregated_comment_reply',comment('8','new')],
  ['reply','6','DidItCommentsResource/create','v3_create_user_did_it_data_comment',comment('8','new')],
  ['edit','5','AggregatedCommentResource/update','v3_update_aggregated_comment',comment('5','new')],
  ['delete','5','AggregatedCommentResource/delete','v3_delete_aggregated_comment',null],
  ['delete','6','ApiResource/delete','v3_delete_user_did_it_data',{id:'77'}],
  ['like','5','ApiResource/create','v3_add_reaction_to_comment',{id:'5'}],
  ['like','6','ApiResource/create','v3_like_user_did_it_data',null],
  ['photo','','ApiResource/create','v3_create_user_did_it_data',{...comment('8','new','42',true),pin:{id:'11'},image_signatures:['a'.repeat(32)]}]
 ]){
  const [action,id,path,endpoint,response]=spec,f=fixture();
  const {p,request}=await prepare(f,action,id,'new',action==='photo'?{imageUri:'file://media/image'}:{});
  assert(request,action);assert(request.job.url.endsWith('/resource/'+path+'/'));assert.equal(f.store.commentResult.busy,true);
  const data=JSON.parse(new URLSearchParams(request.job.body).get('data')).options;
  if(action==='create')assert.deepEqual(data,{force:false,objectId:'77',pinId:'11',tags:'[]',text:'new'});
  if(action==='reply')assert.equal(data.objectId,id);
  if(action==='edit'||action==='delete'&&id==='5')assert.equal(data.commentId,id);
  if(action==='photo'){assert.equal(f.uploads.length,1);assert.equal(data.data.pin,'11');assert.deepEqual(data.data.image_signatures,['a'.repeat(32)]);}
  await f.writer.write(input('create'),f.current);assert.equal(f.pending.length,2,'duplicate write is locked');
  request.resolve(envelope(response,endpoint));await p;
  assert.equal(f.store.commentResult.busy,false);assert(!f.store.commentResult.uncertain,action);
  assert.equal(f.store.commentResult.mutationVersion,action==='like'?0:1);
  assert.equal(f.gets.length,1,'successful write revalidates through native reads');
  assert(f.changes.length>1,'UI receives changed root objects');
  if(action==='reply')assert.match(f.gets[0].url,id==='6'?/DidItCommentsResource/:/AggregatedCommentReplyFeedResource/);
 }
 for(const [id,endpoint] of [['5','v3_delete_reaction_from_comment'],['6','v3_unlike_user_did_it_data']]){
  const f=fixture();f.store.commentResult.items.find(x=>x.id===id).liked=true;
  const {p,request}=await prepare(f,'like',id);
  assert(request.job.url.endsWith('/ApiResource/delete/'));request.resolve(envelope(id==='5'?{id}:null,endpoint));await p;assert(!f.store.commentResult.uncertain);
 }
 const reply=fixture();const parent=reply.store.commentResult.items[0];
 parent.replies=[reply.reads.mapWrittenComment(comment('15','reply'),'42')];
 let r=await prepare(reply,'like','15');r.request.resolve(envelope({id:'15'},'v3_add_reaction_to_comment'));await r.p;assert.match(reply.gets[0].url,/AggregatedCommentReplyFeedResource/);
 for(const action of ['edit','delete']){
  const f=fixture();f.store.commentResult.items[2].canEdit=true;f.store.commentResult.items[2].canDelete=true;const r=await prepare(f,action,'7');await r.p;assert.equal(f.pending.length,1,'non-owner cannot write even if UI permission is forged');
 }
 const identity=fixture(),p0=identity.writer.write(input('create'),identity.current);identity.pending[0].resolve(envelope({id:'11',aggregated_pin_id:'wrong'}));await p0;assert.equal(identity.pending.length,1);assert(!identity.store.commentResult.uncertain);
 for(const [response,endpoint] of [[comment('9','different'),'v3_create_aggregated_pin_data_comment'],[comment('9','new','99'),'v3_create_aggregated_pin_data_comment'],[comment('9','new'),'wrong'],[null,'v3_create_aggregated_pin_data_comment']]){
  const f=fixture(),r=await prepare(f,'create');r.request.resolve(envelope(response,endpoint));await r.p;
  assert(f.store.commentResult.uncertain);assert.equal(f.store.commentResult.mutationVersion,0);
  await f.writer.write(input('create'),f.current);assert.equal(f.pending.length,2);
  await f.reads.readComments(false,f.current);assert(f.store.commentResult.uncertain,'read cannot silently unlock an unknown write');
 }
 const offline=fixture();offline.readResult.error=true;r=await prepare(offline,'create');r.request.resolve(envelope(comment('9','new'),'v3_create_aggregated_pin_data_comment'));await r.p;
 assert.equal(offline.store.commentResult.mutationVersion,1);assert(offline.store.commentResult.items.some(c=>c.id==='9'),'read failure retains confirmed write');assert(offline.store.commentResult.error);assert(!offline.store.commentResult.uncertain);
 for(const phase of ['base','post','upload']){
  const f=fixture();if(phase==='upload')f.network.uploadCommentImage=async(...args)=>{f.uploads.push(args);return new Promise(()=>{});};
  const p=f.writer.write(input(phase==='upload'?'photo':'create','','new',{imageUri:'file://media/image'}),f.current);
  if(phase!=='base'){f.pending[0].resolve(envelope({id:'11',aggregated_pin_data:{id:'77'}}));await flush();}
  f.writer.pause();await p;
  assert.equal(f.store.commentResult.busy,false);assert.equal(!!f.store.commentResult.uncertain,phase==='post');
  assert(f.cancels.length);if(phase==='upload')assert(f.cancels.some(id=>id.startsWith('native_comment_upload_')));
  f.pending.at(-1).resolve(envelope(comment('10','new'),'v3_create_aggregated_pin_data_comment'));await flush();assert.equal(f.store.commentResult.mutationVersion,0);assert.equal(f.gets.length,0);
 }
 for(const change of ['pin','token','account','foreground']){
  const f=fixture(),r=await prepare(f,'create');if(change==='pin'){f.setOwned(false);f.store.commentResult={pin:origin+'/pin/12/',items:[],loading:false,error:''};}
  if(change==='token')f.store.commentToken++;
  if(change==='account')f.setSession({...f.session(),generation:2,accountId:'different'});
  if(change==='foreground')f.setVisible(false);
  r.request.resolve(envelope(comment('8','new'),'v3_create_aggregated_pin_data_comment'));await r.p;assert.equal(f.store.commentResult.mutationVersion||0,0);assert.equal(f.gets.length,0);
 }
 const badUpload=fixture();badUpload.network.uploadCommentImage=async()=>{throw Error('upload failed')};r=await prepare(badUpload,'photo','','new',{imageUri:'file://media/image'});await r.p;assert.equal(badUpload.pending.length,1);assert(!badUpload.store.commentResult.uncertain);assert(badUpload.store.commentResult.actionError);

 const wrongViewer=fixture(),viewerRead=wrongViewer.writer.write(input('create'),wrongViewer.current);
 wrongViewer.pending[0].resolve(envelope({id:'11',aggregated_pin_id:'77'},'','99'));await viewerRead;assert.equal(wrongViewer.pending.length,1,'Cookie identity change cannot borrow an existing comment snapshot');
 for(const [action,id,response,endpoint] of [
  ['delete','6',{id:'11'},'v3_delete_user_did_it_data'],
  ['edit','5',comment('99','new'),'v3_update_aggregated_comment'],
  ['like','5',null,'v3_add_reaction_to_comment'],
  ['like','6',{id:'6'},'v3_like_user_did_it_data'],
  ['photo','',{...comment('8','new','42',true),pin:{id:'12'},image_signatures:['a'.repeat(32)]},'v3_create_user_did_it_data'],
  ['photo','',{...comment('8','new','42',true),pin:{id:'11'},image_signatures:['b'.repeat(32)]},'v3_create_user_did_it_data']
 ]){
  const f=fixture(),r=await prepare(f,action,id,'new',{imageUri:'file://media/image'});
  r.request.resolve(envelope(response,endpoint));await r.p;assert(f.store.commentResult.uncertain);assert.equal(f.store.commentResult.mutationVersion,0);assert.equal(f.gets.length,0);
 }

 const panelToken=fixture(),pendingToken=await prepare(panelToken,'create');
 panelToken.store.commentToken++;panelToken.store.commentResult={pin,loading:false,error:'',items:[]};
 panelToken.writer.pause();await pendingToken.p;
 assert.equal(panelToken.store.commentResult.uncertain,undefined,'cancelling an old write cannot lock a reopened same-Pin Sheet');
 const nestedAggregate=fixture(),nestedWrite=nestedAggregate.writer.write(input('create'),nestedAggregate.current);
 nestedAggregate.pending[0].resolve(envelope({id:'11',aggregated_pin_id:'invalid',aggregated_pin_data:{id:'77'}}));await flush();
 assert.equal(nestedAggregate.pending.length,2);nestedAggregate.writer.pause();await nestedWrite;
 const malformed=fixture();malformed.server.push({unexpected:'bad'});
 const malformedWrite=await prepare(malformed,'create');malformedWrite.request.resolve(envelope(comment('9','new'),'v3_create_aggregated_pin_data_comment'));await malformedWrite.p;
 assert(malformed.store.commentResult.items.some(c=>c.id==='9'),'malformed refresh preserves a confirmed comment');
 assert.equal(malformed.reads.commentAuthor('9'),'42');assert(malformed.store.commentResult.error);assert.equal(malformed.store.commentResult.mutationVersion,1);

 const offlineReply=fixture();offlineReply.readResult.error=true;
 const replyWrite=await prepare(offlineReply,'reply','5');replyWrite.request.resolve(envelope(comment('9','new'),'v3_create_aggregated_comment_reply'));await replyWrite.p;
 assert(offlineReply.store.commentResult.items[0].replies.some(c=>c.id==='9'),'failed reply refresh retains the confirmed reply');
 assert(offlineReply.store.commentResult.items[0].repliesError);
 await policy();await integration();
 console.log('Native comment writes passed: text/photo/replies, own edit/delete, likes, strict contracts, server identity, native rereads, unknown/duplicate/cancel isolation and zero Web context.');
}
async function policy(){
 const captures=[];
 for(const [action,id] of [['create',''],['reply','5'],['reply','6'],['edit','5'],['delete','5'],['delete','6'],['like','5'],['like','6'],['photo','']]){
  const f=fixture(),r=await prepare(f,action,id,'new',{imageUri:'file://media/image'});captures.push(...f.pending.map(x=>({...x,session:f.session})));f.writer.pause();await r.p;
 }
 const network=new Network();let sent=0,context;
 network.request=async(job,ctx)=>{context=ctx;if(!ctx().authenticated)return {error:'rejected'};assert(acceptsNetworkJob(job,ctx()));sent++;return {error:''};};
 for(const capture of captures){
  const [session,...args]=capture.args;args[5]=()=>true;const send=(job,rest=args)=>network.requestBusinessCommentWrite(job,session,...rest);
  assert.equal((await send(capture.job)).error,'','valid contract '+capture.job.url);
  const before=sent;
  for(const job of [{...capture.job,method:'DELETE'},{...capture.job,page:origin+'/pin/99/'},{...capture.job,epoch:4},{...capture.job,headers:{...capture.job.headers,'X-Pinterest-Pws-Handler':'bad'}},{...capture.job,url:capture.job.url.replace('pinterest.com','example.com')}]){
   assert.equal((await send(job)).error,'rejected');
  }
  if(capture.job.method==='POST'){
   const mutate=fn=>{const form=new URLSearchParams(capture.job.body),body=JSON.parse(form.get('data'));fn(body);form.set('data',JSON.stringify(body));return {...capture.job,body:form.toString()};};
   assert.equal((await send(mutate(e=>e.options.extra='bad'))).error,'rejected');
   assert.equal((await send(mutate(e=>e.context={unexpected:'bad'}))).error,'rejected');
   if(/AggregatedCommentResource\/(?:update|delete)|\/v3\/did_it\/6\/$/.test(capture.job.url+decodeURIComponent(capture.job.body))){
    const denied=args.slice();denied[4]=false;assert.equal((await send(capture.job,denied)).error,'rejected');
   }
  }
  assert.equal(sent,before);
 }
}
async function integration(){
 const Panels=load('feature_pin/src/main/ets/controllers/PinmonyPostPanelsController.ets',()=>({PinmonyTaskRegistry:class{invalidate(){}}})).PinmonyPostPanelsController;
 const f=fixture();let sheet='',calls=[];
 const panels=new Panels(f.store,{authenticated:()=>true,foreground:()=>true,sheet:()=>sheet,show:s=>sheet=s,currentPin:()=>pin,pinIdentity:x=>x,document(){throw Error('Web document')},runScript(){throw Error('Web submit')},adoptComments(){throw Error('Web adoption')},prepareComment(){throw Error('Web photo prep')},
 nativeComments:async()=>{f.store.commentResult={pin,items:[],loading:false,error:''};},cancelNativeComments(){},cancelNativeCommentWrites:()=>f.writer.pause(),
 nativeCommentWrite:async(encoded,current)=>{assert(current());calls.push(JSON.parse(encoded).action);},
 nativeCommentLike:async(id,current)=>{assert(current());calls.push(id);}});
 await panels.openComments();await panels.writeComment(input('create'));await panels.commentAction('commentLike','5');panels.dismiss('comments');
 assert.deepEqual(calls,['create','5']);
 const script=load('feature_pin/src/main/ets/services/PinmonyPostExtensionsScript.ets').PIN_POST_EXTENSIONS_SCRIPT;
 const api={reset(){}},window={PinmonyPostApi:api,PinmonyPostExtensionsEnabled:true,PinmonyNativeCommentWritesEnabled:true};
 vm.runInNewContext(script,{window});
 assert.equal(api.commentsAdopt(pin,'{}'),false);assert.equal(api.commentPhotoBegin(pin),false);assert.equal(api.commentPhotoFail(pin),false);
 assert.equal(await api.commentWrite(pin,input('create')),false);assert.equal(await api.commentLike(pin,'5'),false);
 const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');assert(index.includes('nativeCommentWrite: PIN_NATIVE_COMMENT_WRITES_ENABLED'));assert(index.includes('cancelNativeCommentWrites:'));assert(index.includes('commentActionsReady: PIN_NATIVE_COMMENT_WRITES_ENABLED'));
}
const timeout=setTimeout(()=>{console.error('native comment test timeout');process.exit(1)},20000);
main().then(()=>clearTimeout(timeout)).catch(error=>{clearTimeout(timeout);console.error(error);process.exitCode=1});
