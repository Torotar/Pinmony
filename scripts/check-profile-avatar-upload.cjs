const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const origin = 'https://www.pinterest.com', page = origin + '/sample/';
const bytes = new Uint8Array([255,216,255,1,2,3,4,5,6,7,8,9]).buffer;
const photo = { data:'data:image/jpeg;base64,synthetic', bytes, mime:'image/jpeg' };
const defer = () => { let resolve; const promise = new Promise(r => resolve = r); return { promise, resolve }; };
const flush = async () => { for(let i=0;i<8;i++) await new Promise(setImmediate); };
function fixture() {
  let active = true, choose = async () => ['file://media/synthetic'], fetchHook = async () => reply(200, {success:true,image_upload_tracking_id:'synthetic-tracking'}), readHook;
  const jobs=[], uploads=[], feedback=[], updates=[], cancels=[];
  const session={authenticated:true,generation:1,accountId:'synthetic',origin,userAgent:'synthetic-agent'};
  const store={panelToken:0,profile:{profileUrl:page,section:'saved',avatarUrl:'https://i.pinimg.com/old.jpg'},profileCache:{clear(){}},origins:[]};
  let reads=0, refreshes=0, picks=0, photoReads=0;
  const states=[0,0,4];
  const kits={rcp:{MultipartForm:class {constructor(fields){this.fields=fields}},Request:class {constructor(url,method,headers,body,_1,_2,configuration){Object.assign(this,{url,method,headers,body,configuration});}}}};
  const loader=createArktsLoader(ts,{
    common_foundation:{PinmonyRuntimeLog:{info(){},warn(){}}},
    common_network:{PIN_BUSINESS_PIN_READ_ENABLED:true},common_session:{PinmonySessionCredentials:class {async read(){reads++;return 'csrftoken=synthetic'}async update(...args){updates.push(args)}}},
    '@kit.RemoteCommunicationKit':kits,'@kit.BasicServicesKit':{},
    feature_profile:{PIN_PROFILE_ORGANIZE_ENABLED:true,pickPublishPhotoUris:async count=>{picks++;assert.equal(count,1);return choose()},readProfileAvatarPhoto:async()=>{photoReads++;return photo}}
  },{setTimeout:(fn,ms)=>setTimeout(fn,ms>100?0:ms)});
  const {PinmonyNativeNetwork,NetworkManager}=loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
  const net=new PinmonyNativeNetwork();
  NetworkManager.getSession=()=>({fetch:async r=>{uploads.push(r);return fetchHook(r)},cancel:r=>cancels.push(r)});
  net.request=async(job,context)=>{
    jobs.push(job);assert(context().authenticated,'owner checked before read');
    const options=JSON.parse(new URL(job.url).searchParams.get('data')||new URLSearchParams(job.body).get('data')).options;
    let data,endpoint;
    if(job.url.includes('/UserResource/')) data={id:'1',type:'user',username:'sample'};
    else if(options.url==='/v3/users/settings/') data={id:'1',username:'sample',first_name:'First',profile_image_url:uploads.length?'https://i.pinimg.com/new.jpg':'https://i.pinimg.com/old.jpg'};
    else if(options.url==='/v3/images/upload/status/') {data={ [options.data.tracking_id]:states.length>1?states.shift():states[0] };endpoint='v3_get_image_upload_status';}
    else throw Error('unexpected read');
    const body={resource_response:{status:'success',code:0,endpoint_name:endpoint,data},client_context:{user:{id:'1'}}};
    if(readHook) await readHook(job,body);
    return {status:200,error:'',body:JSON.stringify(body)};
  };
  const {PinmonyProfileNativeActions}=loader.loadFile('entry/src/main/ets/app/PinmonyProfileNativeActions.ets');
  const actions=new PinmonyProfileNativeActions({store:()=>store,session:()=>({...session}),network:()=>net,active:()=>active,page:()=>page,ownPage:()=>page,motion(){},feedback:m=>feedback.push(m),saved(){throw Error('avatar does not submit profile save')},refresh(){refreshes++},morePins:async()=>false});
  function reply(statusCode,body){return {statusCode,headers:{'set-cookie':['synthetic=value; Path=/']},toString:()=>JSON.stringify(body)}}
  return {actions,net,loader,session,store,jobs,uploads,feedback,updates,cancels,states,photo,reply,
    choose:f=>choose=f,fetch:f=>fetchHook=f,read:f=>readHook=f,active:v=>active=v,picks:()=>picks,photoReads:()=>photoReads,reads:()=>reads,refreshes:()=>refreshes};
}
async function workflow(){
  const h=fixture();await h.actions.open('edit','users');const token=h.store.panel.token;
  await h.actions.changeAvatar();assert.equal(h.uploads.length,1);assert.equal(h.store.panel.avatar,'https://i.pinimg.com/new.jpg');assert.equal(h.store.panel.avatarPreview,'');assert.equal(h.store.panel.token,token,'avatar update preserves edit draft token');assert(!h.store.panel.avatarBusy);assert.equal(h.store.profile.avatarUrl,'https://i.pinimg.com/new.jpg');assert.equal(h.refreshes(),1);assert.equal(h.feedback.at(-1),'头像已更新');assert.equal(h.jobs.filter(j=>j.url.includes('/_/graphql/')).length,0,'no second profile save');
  const request=h.uploads[0];assert.equal(request.url,origin+'/upload-profile-image/');assert.equal(request.method,'POST');assert.deepEqual(Object.keys(request.body.fields),['img']);assert.equal(request.body.fields.img.contentOrPath.content,bytes);assert.equal(request.body.fields.img.contentType,'image/jpeg');assert.equal(request.headers.Cookie,'csrftoken=synthetic');assert.equal(request.headers['X-CSRFToken'],'synthetic');assert(!request.headers['Content-Type'],'RCP sets multipart boundary');assert.equal(request.configuration.transfer.autoRedirect,false);assert.equal(h.updates.length,1);
  assert.equal(h.jobs.filter(j=>j.url.includes('tracking_id')).length,3,'processing is read-only polling');
  const p=fixture();await p.actions.open('edit','users');const pick=defer();p.choose(()=>pick.promise);const first=p.actions.changeAvatar();await p.actions.changeAvatar();assert.equal(p.picks(),1,'second tap cannot open another picker');p.actions.pause();pick.resolve(['file://media/synthetic']);await first;assert.equal(p.uploads.length,1,'picker survives system background in same account and panel');
  const old=fixture();await old.actions.open('edit','users');const late=defer();old.choose(()=>late.promise);const pending=old.actions.changeAvatar();old.session.generation++;late.resolve(['file://media/synthetic']);await pending;assert.equal(old.photoReads(),0);assert.equal(old.uploads.length,0);
  const cancelled=fixture();await cancelled.actions.open('edit','users');cancelled.choose(async()=>[]);await cancelled.actions.changeAvatar();assert.equal(cancelled.uploads.length,0);assert(!cancelled.store.panel.avatarBusy);
  const unknown=fixture();await unknown.actions.open('edit','users');unknown.fetch(async()=>{throw Error('lost response')});await unknown.actions.changeAvatar();assert.equal(unknown.store.panel.avatarAction,'refresh');const before=unknown.jobs.length;await unknown.actions.changeAvatar();assert.equal(unknown.jobs.length,before+1,'missing tracking ID performs a real profile avatar read');assert(unknown.jobs.at(-1).url.includes('/ApiResource/get/'));assert.equal(unknown.store.panel.avatarPreview,'');assert.equal(unknown.store.panel.avatar,'https://i.pinimg.com/new.jpg');assert(unknown.store.panel.avatarError.includes('仍未确认'));assert.equal(unknown.feedback.at(-1),'已刷新当前头像');assert(!unknown.feedback.includes('头像已更新'),'profile read is not upload confirmation');assert.equal(unknown.uploads.length,1,'unknown upload has no replay');assert.equal(unknown.picks(),1);unknown.actions.close();await unknown.actions.open('edit','users');assert.equal(unknown.store.panel.avatarAction,'refresh','reopened panel restores recovery action');const reopened=unknown.jobs.length;await unknown.actions.changeAvatar();assert.equal(unknown.jobs.length,reopened+1);assert.equal(unknown.uploads.length,1);
  unknown.read((job,body)=>{if(job.url.includes('/ApiResource/get/'))body.resource_response.data.id='999';});await unknown.actions.changeAvatar();assert.equal(unknown.store.panel.avatarAction,'refresh');assert(unknown.store.panel.avatarError.includes('重新读取'));assert.equal(unknown.uploads.length,1);unknown.read(undefined);await unknown.actions.changeAvatar();assert.equal(unknown.feedback.at(-1),'已刷新当前头像','failed read remains recoverable without another upload');
  const staleRefresh=fixture();await staleRefresh.actions.open('edit','users');staleRefresh.fetch(async()=>{throw Error('lost')});await staleRefresh.actions.changeAvatar();const readBack=defer();staleRefresh.read(()=>readBack.promise);const checking=staleRefresh.actions.changeAvatar();await flush();staleRefresh.actions.close();await checking;staleRefresh.session.generation++;readBack.resolve();await flush();assert.equal(staleRefresh.store.panel,undefined,'late refresh cannot reopen old panel');assert.equal(staleRefresh.feedback.length,0);assert.equal(staleRefresh.uploads.length,1);
  const recovering=fixture();await recovering.actions.open('edit','users');recovering.read((job,body)=>{if(job.url.includes('tracking_id'))body.resource_response.endpoint_name='wrong';});await recovering.actions.changeAvatar();assert(!recovering.feedback.includes('头像已更新'));const picks=recovering.picks();recovering.read(undefined);await recovering.actions.changeAvatar();assert.equal(recovering.uploads.length,1,'known tracking resumes status only');assert.equal(recovering.picks(),picks);assert.equal(recovering.feedback.at(-1),'头像已更新');
  const rejected=fixture();await rejected.actions.open('edit','users');rejected.states.splice(0,3,5);await rejected.actions.changeAvatar();assert(rejected.store.panel.avatarError.includes('未能完成'));rejected.states.splice(0,1,4);await rejected.actions.changeAvatar();assert.equal(rejected.uploads.length,2,'confirmed failure permits an explicit new choice');
  const close=fixture();await close.actions.open('edit','users');const held=defer();close.fetch(()=>held.promise);const writing=close.actions.changeAvatar();await flush();assert.equal(close.uploads.length,1);close.actions.close();await writing;held.resolve(close.reply(200,{success:true,image_upload_tracking_id:'late'}));await flush();assert.equal(close.store.panel,undefined);assert.equal(close.feedback.length,0);await close.actions.open('edit','users');await close.actions.changeAvatar();assert.equal(close.uploads.length,1,'closing an in-flight write retains unknown outcome');
}
async function avatarCache(){
 const f=fixture(),{PinmonyProfileNativeReads}=f.loader.loadFile('entry/src/main/ets/app/PinmonyProfileNativeReads.ets');
 const r=new PinmonyProfileNativeReads({store:()=>f.store,session:()=>({...f.session}),selected:()=>true,active:()=>true,page:()=>page,network:()=>f.net});
 Object.assign(r,{account:f.session.accountId,generation:f.session.generation,origin,page,info:{isOwn:true,avatar:'https://i.pinimg.com/old.jpg'},requestId:'synthetic-old-read'});
 const revision=r.revision;r.confirmAvatar(page,'https://i.pinimg.com/new.jpg');assert(r.revision>revision,'confirmed avatar retires older reads');assert.equal(r.info.avatar,'https://i.pinimg.com/new.jpg');r.apply();assert.equal(f.store.profile.avatarUrl,'https://i.pinimg.com/new.jpg','native cache cannot restore old avatar');
}
async function photoReader(){
 let max=0,closed=0;const loader=createArktsLoader(ts,{
 '@kit.MediaLibraryKit':{photoAccessHelper:{PhotoSelectOptions:class{},PhotoViewMIMETypes:{IMAGE_TYPE:'image'},PhotoViewPicker:class{async select(options){max=options.maxSelectNumber;return {photoUris:['file://media/synthetic','file://media/extra']}}}}},
 '@kit.CoreFileKit':{fileIo:{OpenMode:{READ_ONLY:1},open:async()=>({fd:1}),stat:async()=>({size:bytes.byteLength}),read:async(_fd,b)=>{new Uint8Array(b).set(new Uint8Array(bytes));return bytes.byteLength},close:async()=>closed++}},
 '@kit.ArkTS':{util:{Base64Helper:class{encodeToStringSync(b){return Buffer.from(b).toString('base64')}decodeSync(s){return new Uint8Array(Buffer.from(s,'base64'))}}}},common_foundation:{PinmonyRuntimeLog:{warn(){}}}});
 const photoModule=loader.loadFile('feature_profile/src/main/ets/services/PinmonyPublishPhoto.ets');
 assert.equal((await photoModule.pickPublishPhotoUris(1)).length,1);assert.equal(max,1);const result=await photoModule.readProfileAvatarPhoto('file://media/synthetic');assert.equal(result.mime,'image/jpeg');assert.deepEqual(Buffer.from(result.bytes),Buffer.from(bytes));assert.equal(closed,1);
}
async function transport(){
 const h=fixture(),current=()=>true,id='native_profile_avatar_900';
 for(const [b,m,p,own] of [[bytes,'image/png',page,page],[bytes,'image/jpeg',page,origin+'/other/'],[bytes,'image/jpeg','https://evil.test/sample/','https://evil.test/sample/']])await assert.rejects(h.net.uploadProfileAvatar(b,m,p,own,()=>h.session,current,id,()=>{}));
 assert.equal(h.uploads.length,0);assert.equal(h.reads(),0);
 h.net.setForeground(false);await assert.rejects(h.net.uploadProfileAvatar(bytes,'image/jpeg',page,page,()=>h.session,current,id,()=>{}));assert.equal(h.uploads.length,0);
 const stale=fixture();stale.fetch(async()=>{stale.session.generation++;return stale.reply(200,{success:true,image_upload_tracking_id:'tracking'})});await assert.rejects(stale.net.uploadProfileAvatar(bytes,'image/jpeg',page,page,()=>stale.session,current,id,()=>{}));assert.equal(stale.uploads.length,1);assert.equal(stale.updates.length,0,'late account response cannot update cookies');
 const malformed=fixture();malformed.read((_,body)=>{body.resource_response.data={other:4}});await assert.rejects(malformed.net.readProfileAvatarStatus('tracking',page,()=>malformed.session,current,id));
 const fail=fixture();fail.fetch(async()=>{throw Error('lost')});await assert.rejects(fail.net.uploadProfileAvatar(bytes,'image/jpeg',page,page,()=>fail.session,current,id,()=>{}));assert.equal(fail.uploads.length,1,'multipart write never retries');
}
(async()=>{await workflow();await transport();await avatarCache();await photoReader();console.log('Avatar upload: actual native workflow/multipart/status/readback, once-only writes, recovery, draft retention, picker lifecycle, cancellation and account isolation passed');})().catch(e=>{console.error(e);process.exitCode=1});
