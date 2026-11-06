const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = ts.transpileModule(fs.readFileSync('common_network/src/main/ets/PinmonyPinLinkResolver.ets','utf8'),
  {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText;
function fixture(responses, overrides = {}) {
  const requests = [], sessions = [], timers = new Map(); let serial = 0;
  const rcp = {Request: class {constructor(url, method, headers) {Object.assign(this,{url,method,headers});}},
    createSession() {const session = {fetch: async request => {
      requests.push(request); const next = responses.shift();
      return typeof next === 'function' ? next(request) : next;
    },cancel() {session.cancelled = true;},close() {session.closed = true;}};sessions.push(session);return session;}};
  const exports = {};
  vm.runInNewContext(source,{exports, Uint8Array, Promise, setTimeout: fn => {const id=++serial;timers.set(id,fn);return id;},
    clearTimeout: id=>timers.delete(id), require: name => name==='@kit.RemoteCommunicationKit' ? {rcp} :
      name==='common_foundation' ? {PinmonyRuntimeLog:{info(){}}} :
      {Priority:{NORMAL:1},NetworkManager:{enqueue: async (_,job)=>job(),...overrides}}});
  return {reader:new exports.PinmonyPinLinkResolver(),...exports,requests,sessions,timers};
}
const middle = 'https://api.pinterest.com/url_shortener/Example/redirect/';
const pin = 'https://www.pinterest.com/pin/123/sent/?invite_code=example&sender=synthetic';
const reply = (status, location) => ({statusCode:status,headers:{location}});
async function flush() {await new Promise(resolve=>setImmediate(resolve));}
async function main() {
  const f=fixture([reply(308,middle),reply(302,pin)]);
  assert.equal(await f.reader.resolve('https://pin.it/Example',()=>true),'123');
  assert.deepEqual(f.requests.map(r=>r.url),['https://pin.it/Example',middle]);
  for (const request of f.requests) {
    assert.equal(request.method,'GET'); assert.deepEqual(Object.keys(request.headers),['Accept']);
    assert.equal(request.configuration.transfer.autoRedirect,false);assert.equal(request.configuration.proxy,'system');
  }
  assert(f.sessions[0].closed); assert.equal(f.timers.size,0);
  assert.equal(f.redirectedPinIdentity('https://pinterest.com/pin/123/'),'123');
  for (const target of ['https://evil.test/pin/123/','https://pinterest.com.evil.test/pin/123/',
    'https://user@pinterest.com/pin/123/','http://pinterest.com/pin/123/','https://pinterest.com/pin/123/other']) {
    assert.equal(f.redirectedPinIdentity(target),'');
  }
  for (const response of [reply(200,pin),reply(302,'https://evil.test/'),reply(302,'/relative'),
    reply(302,middle+'?extra=1'),reply(302,middle.replace('Example','Other')),reply(302,['a','b'])]) {
    const b=fixture([response]);await assert.rejects(b.reader.resolve('https://pin.it/Example',()=>true));
    assert.equal(b.requests.length,1);assert(b.sessions[0].closed);
  }
  const loop=fixture([reply(308,middle),reply(302,middle)]);
  await assert.rejects(loop.reader.resolve('https://pin.it/Example',()=>true));assert.equal(loop.requests.length,2);
  let finish;const late=fixture([()=>new Promise(resolve=>finish=resolve)]);
  const pending=late.reader.resolve('https://pin.it/Example',()=>true);await flush();late.reader.cancel();
  await assert.rejects(pending,/cancelled/);finish(reply(302,pin));await flush();assert(late.sessions[0].cancelled);
  const timeout=fixture([()=>new Promise(()=>{})]);const waiting=timeout.reader.resolve('https://pin.it/Example',()=>true);
  await flush();timeout.timers.values().next().value();await assert.rejects(waiting,/cancelled/);assert(timeout.sessions[0].closed);
  let active=true, complete;const stale=fixture([()=>new Promise(resolve=>complete=resolve)]);
  const old=stale.reader.resolve('https://pin.it/Example',()=>active);await flush();active=false;complete(reply(302,pin));
  await assert.rejects(old,/cancelled/);
  const invalid=fixture([]);await assert.rejects(invalid.reader.resolve('https://evil.test/Example',()=>true));assert.equal(invalid.sessions.length,0);
  const huge=fixture([request=>{request.destination(new ArrayBuffer(65537));return reply(302,pin);}]);
  await assert.rejects(huge.reader.resolve('https://pin.it/Example',()=>true),/response/);
  console.log('Pin short link: observed two-hop route, no credentials, allowlist, bounds, timeout, cancellation and stale replies passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
