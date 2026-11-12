const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { withLocalMessages } = require('./local-message-test-fixture.cjs');
function load(file) {
  const exports = {};
  vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, fs.readFileSync(file, 'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,
    {exports,require:withLocalMessages(() => ({})),setTimeout,clearTimeout,console});
  return exports;
}
function methods(file, names) {
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct\b/g,'class');
  const ast = ts.createSourceFile('avatar.ts',source,ts.ScriptTarget.Latest,true), bodies=[];
  function visit(node) {if(ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast)))bodies.push(node.getText(ast));ts.forEachChild(node,visit);} visit(ast);
  assert.equal(bodies.length,names.length,file);
  return vm.runInNewContext(require('./native-network-test-fixture.cjs').transpile(ts, 'class Host {'+bodies.join('\n')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{$r:x=>x,inheritUserAvatarColor:load('entry/src/main/ets/app/PinmonyUserAvatarMetadata.ets').inheritUserAvatarColor});
}
const source = fs.readFileSync('common_ui/src/main/ets/components/PinmonyUserAvatar.ets','utf8');
assert.match(source,/websiteFallback: boolean = true/);
assert.match(source,/@StorageProp\('systemDarkMode'\)/);
const Avatar=methods('common_ui/src/main/ets/components/PinmonyUserAvatar.ets',['fallbackInitial','fallbackBackground','resetImage']);
const avatar=Object.assign(new Avatar(),{websiteFallback:true,name:'  😀 name',colorIndex:9,systemDarkMode:false,failed:true});
assert.equal(avatar.fallbackInitial(),'😀');avatar.name='名称';assert.equal(avatar.fallbackInitial(),'名');
for(let color=1;color<=10;color++){avatar.colorIndex=color;avatar.systemDarkMode=false;const light=avatar.fallbackBackground();avatar.systemDarkMode=true;assert.notEqual(avatar.fallbackBackground(),light);}
for(const invalid of [undefined,null,0,11,1.5,'9',NaN]){avatar.colorIndex=invalid;assert.equal(avatar.fallbackBackground(),'app.color.surface_muted');}
avatar.resetImage();assert.equal(avatar.failed,false);
const Comments=methods('entry/src/main/ets/app/PinmonyDetailNativeReads.ets',['mapComment']);
const comments=Object.assign(new Comments(),{ports:{session:()=>({origin:'https://www.pinterest.com'})},commentAuthors:new Map(),commentViewer:'1'});
const Inbox=methods('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets',['user']);
const inbox=Object.assign(new Inbox(),{conversations:[],self:()=>false,clean:x=>typeof x==='string'?x:'',image:x=>x||'',origin:'https://www.pinterest.com'});
for(const color of [1,9,10,undefined,null,0,11,1.5,'9']) {
  const raw={id:'1',username:'sample',full_name:'Sample',avatar_color_index:color,image_medium_url:'https://i.pinimg.com/user/default.jpg'};
  const expected=Number.isInteger(color)&&color>=1&&color<=10?color:undefined;
  const comment=comments.mapComment({id:'42',type:'aggregatedcomment',text:'comment',user:raw});
  assert.equal(comment.avatarColorIndex,expected);assert.equal(comment.canEdit,true);
  assert.equal(inbox.user(raw).avatarColorIndex,expected);
}
const {mapPrefetchedDetail}=load('feature_pin/src/main/ets/services/PinmonyDetailPrefetch.ets');
const pin='https://www.pinterest.com/pin/42/';
for(const color of [2,9,undefined,11,'2']) {
 const detail=mapPrefetchedDetail(JSON.stringify({resource_response:{status:'success',data:{id:'42',type:'pin',images:{'orig':{url:'https://i.pinimg.com/originals/synthetic.jpg',width:800,height:1000}},pinner:{username:'sample',full_name:'Sample',avatar_color_index:color}}}}),pin);
 assert(detail,'detail maps');assert.equal(detail.creatorAvatarColorIndex,Number.isInteger(color)&&color>=1&&color<=10?color:undefined);
 const {PinmonyDetailCache}=load('feature_pin/src/main/ets/services/PinmonyDetailCache.ets');const cache=new PinmonyDetailCache();
 // The explicit cache projection must retain creator metadata; action authorization remains handled by existing cache tests.
 assert.match(fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailCache.ets','utf8'),/creatorAvatarColorIndex: detail.creatorAvatarColorIndex/);
}
for(const file of ['feature_pin/src/main/ets/components/PinmonyDetailPage.ets','feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets','feature_settings/src/main/ets/components/PinmonySettingsPage.ets','feature_settings/src/main/ets/components/PinmonySocialPermissionsPage.ets','feature_inbox/src/main/ets/components/PinmonyInboxActivityRow.ets','feature_board/src/main/ets/components/PinmonyBoardCollaboratorsPage.ets','feature_search/src/main/ets/components/PinmonySearchPage.ets']) {
 const text=fs.readFileSync(file,'utf8');assert.match(text,/PinmonyUserAvatar\(\{[^\n]*colorIndex:/,file);
}
const board=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');assert(!board.includes('Image(avatar)'));assert(!board.includes('Image(this.joinedAvatar)'));
const host=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');assert.match(host,/settingsProfileAvatarColorIndex = this.profileStore.profile\?\.avatarColorIndex/);assert.match(host,/profileAvatarColorIndex:this.settingsProfileDepth >= 0/);
function scanAvatars(dir) {for(const item of fs.readdirSync(dir,{withFileTypes:true})){const file=dir+'/'+item.name;if(item.isDirectory())scanAvatars(file);else if(file.endsWith('.ets'))for(const line of fs.readFileSync(file,'utf8').split('\n'))if(line.includes('PinmonyUserAvatar({'))assert(line.includes('colorIndex:'),file+' must pass account color');}}
for(const dir of fs.readdirSync('.').filter(name=>name.startsWith('feature_')))scanAvatars(dir+'/src/main/ets');
console.log('User avatars: shared default, Unicode initials, 10 theme palettes, invalid colors, comment/reply/write mapper, inbox user mapper, detail metadata and avatar entry coverage passed');

// Real partial metadata cases: omitted fields may inherit only from the same user.
const {inheritUserAvatarColor:inherit}=load('entry/src/main/ets/app/PinmonyUserAvatarMetadata.ets');
for (const id of ['1','2']) {
 const target={id};inherit(target,[{id:'1',avatar_color_index:9}]);
 assert.equal(target.avatar_color_index,id==='1'?9:undefined);
}
for(const value of [null,0,11,'9',1.5]) {
 const target={id:'1',avatar_color_index:value};inherit(target,[{id:'1',avatar_color_index:9}]);
 assert.equal(target.avatar_color_index,value,'explicit invalid metadata is not silently replaced');
}
inbox.conversations=[{users:[{id:'1',username:'sample',full_name:'Sample',avatar_color_index:9,image_medium_url:'https://i.pinimg.com/custom.jpg'}]}];
const partial=inbox.user({id:'1'});assert.equal(partial.avatarColorIndex,9);assert.equal(partial.name,'Sample');assert.equal(partial.avatar,'https://i.pinimg.com/custom.jpg');
assert.equal(inbox.user({id:'1',avatar_color_index:0}).avatarColorIndex,undefined);
assert.equal(inbox.user({id:'2'}).avatarColorIndex,undefined);
assert.match(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets','utf8'),/'user.avatar_color_index'/);
assert.match(fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets','utf8'),/'user.avatar_color_index'/);
const nativeBoard=fs.readFileSync('entry/src/main/ets/app/PinmonyBoardNativeReads.ets','utf8');
assert.match(nativeBoard,/inheritUserAvatarColor\(board\?\.owner/);
assert.match(nativeBoard,/owner.avatarColorIndex = known.avatarColorIndex/);
const nativeComments=fs.readFileSync('entry/src/main/ets/app/PinmonyDetailNativeReads.ets','utf8');
assert.match(nativeComments,/inheritUserAvatarColor\(item\?\.user/);
assert.match(nativeComments,/inheritUserAvatarColor\(raw\?\.user/);
console.log('Avatar metadata audit: partial users, same-id inheritance, explicit-invalid rejection, native request fields and board/comment/reply paths passed');

async function partialResponsePaths() {
 const BoardRequest=methods('entry/src/main/ets/app/PinmonyBoardNativeReads.ets',['request']);
 const origin='https://www.pinterest.com',page=origin+'/sample/board/';
 let color=9, viewer='1', active=true;
 const host=Object.assign(new BoardRequest(),{origin,page,generation:1,revision:1,sequence:0,viewer:'1',
  requests:new Set(),sectionRequests:new Set(),flowRequests:new Set(),collabRequests:new Set(),
  current:()=>active,digits:id=>/^\d{1,40}$/.test(id||''),
  ports:{session:()=>({}),network:()=>({requestBusinessBoardRead:async()=>({status:200,error:'',body:JSON.stringify({
   resource_response:{status:'success',code:0,data:{type:'board',id:'42',owner:{id:'1'},collaborating_users:[{id:'1'},{id:'2'}]}},
   client_context:{user:{id:viewer,avatar_color_index:color}}
  })})})}
 });
 const result=await host.request('BoardResource',{field_set_key:'profile_grid_item'},1);
 assert.equal(result.resource_response.data.owner.avatar_color_index,9,'actual board read inherits current viewer color');
 assert.equal(result.resource_response.data.collaborating_users[0].avatar_color_index,9);
 assert.equal(result.resource_response.data.collaborating_users[1].avatar_color_index,undefined,'another user never gets the viewer color');
 viewer='2';await assert.rejects(host.request('BoardResource',{},1),/viewer/);
 viewer='1';active=false;await assert.rejects(host.request('BoardResource',{},1),/cancelled/);
 const RealInbox=methods('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets',['self','user']);
 const reader=Object.assign(new RealInbox(),{ports:{username:()=> 'self'},viewer:'',account:'1',conversations:[],clean:x=>x||'',image:x=>x||'',origin});
 assert(reader.self({id:'1',username:'self',avatar_color_index:9}));
 assert.equal(reader.user({id:'1',username:'self'}).avatarColorIndex,9,'chat participant retains client context color');
 assert.equal(reader.user({id:'2',username:'other'}).avatarColorIndex,undefined);
 console.log('Avatar real read paths: board context inheritance, collaborator identity, viewer mismatch, cancellation and chat partial participant passed');
}
partialResponsePaths().catch(error=>{console.error(error);process.exitCode=1;});
