const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const transpile=path=>ts.transpileModule(fs.readFileSync(path,'utf8').replace(/^import .*;\r?$/gm,''),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText;
const page='https://www.pinterest.com/sample/',ids=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'];
function harness({host='https://pinterest-media-upload.s3.amazonaws.com/',owner='1',extra=false,late=false,uploadStatus=204}={}){
 const uploads=[],jobs=[],context={authenticated:true,epoch:1,page,userAgent:'synthetic'};
 const scope={exports:{},setTimeout,PinmonySessionCredentials:class{},PinmonyRuntimeLog:{info(){},warn(){}},rcp:{
  MultipartForm:class{constructor(fields){this.fields=fields;}},Request:class{constructor(url,method,headers,body){Object.assign(this,{url,method,headers,body});}},
  createSession:()=>({fetch:async request=>{uploads.push(request);return {statusCode:uploadStatus,toString:()=>'<Error><Code>MalformedPOSTRequest</Code></Error>'};},cancel(){},close(){}})}};
 const policy={exports:{},PinmonyRuntimeLog:scope.PinmonyRuntimeLog};vm.runInNewContext(transpile('common_network/src/main/ets/PinmonyRequestPolicy.ets'),policy);scope.PinmonyRequestPolicy=policy.exports.PinmonyRequestPolicy;
 vm.runInNewContext(transpile('common_network/src/main/ets/PinmonyNativeNetwork.ets'),scope);
 const network=new scope.exports.PinmonyNativeNetwork();
 network.request=async(job,current)=>{
  assert(current().authenticated);jobs.push(job);
  const o=JSON.parse(new URLSearchParams(job.method==='GET'?job.url.split('?')[1]:job.body).get('data')).options;
  let data,endpoint;
  if(job.method==='POST'){
   assert.equal(o.url,'/v3/media/uploads/register/batch/');assert.deepEqual(JSON.parse(o.data.media_info_list),ids.map(id=>({id,media_type:'image-story-pin'})));
   const fields={'x-amz-date':'synthetic','x-amz-signature':'synthetic','x-amz-security-token':'synthetic','x-amz-algorithm':'synthetic',key:':image-story-pin:'+owner+':303:',policy:'synthetic','x-amz-credential':'synthetic','Content-Type':'image/jpeg'};
   if(extra)fields.Cookie='forbidden';data={[ids[0]]:{upload_id:'303',upload_url:host,upload_parameters:fields}};endpoint='register_media_upload_batch';if(late)context.epoch++;
  }else{assert.equal(o.url,'/v3/media/uploads/');assert.deepEqual(o.data.upload_ids,['303']);data={'303':{upload_id:'303',status:'succeeded',type:'image-story-pin',signature:'a'.repeat(32)}};endpoint='get_media_uploads';}
  return {status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data}})};
 };
 return {network,context,uploads,jobs};
}
async function main(){
 const bytes=new Uint8Array([255,216,255,1,2]).buffer;
 const run=h=>h.network.uploadPublishImage(bytes,'image/jpeg',page,()=>h.context,'1','native_publish_upload_1',ids);
 const h=harness();const result=await run(h);assert.equal(result.signature,'a'.repeat(32));assert.equal(result.uploadId,'303');assert.equal(h.uploads.length,1);assert.equal(h.jobs.length,2);
 assert.deepEqual(Object.keys(h.uploads[0].headers),['Content-Type'],'signed upload receives only its multipart content type');
 const boundary=h.uploads[0].headers['Content-Type'].split('boundary=')[1];
 const body=Buffer.from(h.uploads[0].body),text=body.toString('latin1');
 assert(text.startsWith('--'+boundary+'\r\n'));assert(text.endsWith('\r\n--'+boundary+'--\r\n'));
 const fileAt=text.indexOf('name="file"; filename="pin.jpg"');
 assert(fileAt>text.indexOf('name="policy"'),'file follows every signed field');
 assert(fileAt>text.indexOf('name="Content-Type"'));
 const dataAt=text.indexOf('\r\n\r\n',fileAt)+4;assert.deepEqual(body.subarray(dataAt,dataAt+bytes.byteLength),Buffer.from(bytes));
 assert.equal(text.indexOf('Content-Disposition:',dataAt),-1,'no fields may follow file bytes');
 for(const options of [{host:'https://attacker.test/'},{owner:'2'},{extra:true},{late:true}]){const bad=harness(options);await assert.rejects(run(bad));assert.equal(bad.uploads.length,0);}
 const hidden=harness();hidden.network.setForeground(false);await assert.rejects(run(hidden),/background/);assert.equal(hidden.jobs.length,0);
 const rejected=harness({uploadStatus:400});await assert.rejects(run(rejected),/image-upload/);assert.equal(rejected.jobs.length,1,'failed upload must not poll status or submit a draft');
 console.log('Story upload: batch registration, viewer-bound signed fields, isolated multipart, status signature, invalid host/fields/owner, late session and background passed');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
