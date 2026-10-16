const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('feature_profile/src/main/ets/services/PinmonyProfilePanelScript.ets', 'utf8');
const script = Function('return ' + source.slice(source.indexOf('`'), source.lastIndexOf('`') + 1))();
new Function(script);
const flush = async () => { for (let i = 0; i < 8; i++) await new Promise(r => setImmediate(r)); };
function harness() {
  const page = 'https://www.pinterest.com/sample/';
  const location = { href: page, origin: 'https://www.pinterest.com', pathname: '/sample/' };
  const info = { userId: '123', viewerId: '999', isOwn: false, followingUser: false, blocked: false };
  const calls = [], notices = [];
  const window = { PinmonyProfileApi: { currentInfo: p => p === page ? info : null } };
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, btoa,
    fetch: (url, options) => new Promise(resolve => calls.push({ url, options, resolve })) });
  const respond = (i, data) => calls[i].resolve({ ok: true, json: async () => data });
  return { api: window.PinmonyProfilePanel, calls, notices, page, info, location, respond };
}

(async()=>{
 for(const matched of [true,false]) {
  const h=harness();h.info.board=true;
  h.api.shareOpen(h.page,1,v=>h.notices.push(v));
  h.respond(0,{data:{v3InviteUserExternalQuery:{data:{inviteUrl:'https://pin.it/Example',inviteCode:'example',title:'Board',message:'Example'}}}});
  h.respond(1,{resource_response:{status:'success',code:0,data:[{id:'456',username:'other'}]}});await flush();
  assert.equal(h.api.shareContact(h.page,1,'profile-contact:456',v=>h.notices.push(v)),true);
  assert.equal(h.api.shareContact(h.page,1,'profile-contact:456',v=>h.notices.push(v)),false);
  const options=JSON.parse(new URLSearchParams(h.calls[2].options.body).get('data')).options;
  assert.equal(options.board,'123');assert.equal(options.user,undefined);
  h.respond(2,{resource_response:{status:'success',code:0,endpoint_name:'v3_create_conversation',data:{users:[{id:'456'}],last_message:{id:'789',board:{id:matched?'123':'321'}}}}});await flush();
  assert.equal(h.notices.at(-1).feedback,matched?'已发送':'发送结果未确认，请先核对会话');
 }
 console.log('Board share: board payload, duplicate sending guard and returned board identity passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
