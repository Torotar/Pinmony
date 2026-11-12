const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const crypto = require('node:crypto'), ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('scripts/check-inbox-message-notice.cjs', 'utf8');
const { fixture, row } = new Function('require', 'process', source.slice(0, source.indexOf('async function main()')) + '\nreturn {fixture,row};')(require, process);
const turn = async () => { for (let i = 0; i < 12; i++) await new Promise(setImmediate); };
let now = Date.now(), flushFails = false;
class Clock extends Date { static now() { return now; } }
const saved = new Map();
function recovery() {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/app/PinmonyInboxNoticeRecovery.ets', 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, Date: Clock, require: name => name === '@kit.ArkData' ? { preferences: {
    getPreferences: async () => ({ get: async (key, fallback) => saved.get(key) || fallback,
      put: async (key, value) => saved.set(key, value), delete: async key => saved.delete(key),
      flush: async () => { if (flushFails) throw Error('synthetic persistence failure'); } })
  } } : name === 'common_foundation' ? { hashCacheString: value => crypto.createHash('sha256').update(value).digest('hex') } : {} });
  const service = exports.PinmonyInboxNoticeRecovery;
  service.initialize({});
  return service;
}
(async () => {
  const store = recovery();
  await store.save('cold-token', 'self', 'https://www.pinterest.com', '100');
  const cold = fixture(recovery(), { parameters: { pinmonyMessageNotice: 'cold-token' } });
  await turn(); assert.deepEqual(cold.opened, ['100'], 'Want received before component binding is consumed after cold start');
  cold.notice.consumeTap(); await turn(); assert.equal(cold.opened.length, 1, 'a click is consumed once');
  await store.save('pending-token', 'self', 'https://www.pinterest.com', '101');
  const pending = fixture(recovery()); pending.setActive(false);
  pending.receive({parameters:{pinmonyMessageNotice:'pending-token'}}); await turn(); assert.equal(pending.opened.length, 0);
  pending.setActive(true); pending.notice.consumeTap(); await turn(); assert.deepEqual(pending.opened, ['101']);
  await store.save('wrong-account', 'other', 'https://www.pinterest.com', '102');
  const wrong = fixture(recovery(), {parameters:{pinmonyMessageNotice:'wrong-account'}}); await turn(); assert.equal(wrong.opened.length, 0);
  await store.save('expired-token', 'self', 'https://www.pinterest.com', '103'); now += 86400001;
  assert.equal(await recovery().read('expired-token','self','https://www.pinterest.com'), undefined);
  saved.set('target', '{broken'); assert.equal(await store.read('expired-token','self','https://www.pinterest.com'), undefined);
  now = Date.now();
  const invite = {boardId:'81', boardUrl:'https://www.pinterest.com/peer/art/', boardName:'Board', inviter:'Peer', inviterAvatar:'', invitedUser:'self', createdAt:'', status:'new'};
  await store.save('invite-token','self','https://www.pinterest.com','invite:81:self:',invite);
  const board = fixture(recovery(), {parameters:{pinmonyMessageNotice:'invite-token'}}); await turn(); assert.equal(board.openedInvitations[0].boardId, '81');
  await store.save('clear-token','self','https://www.pinterest.com','104'); store.clear();
  assert.equal(await store.read('clear-token','self','https://www.pinterest.com'), undefined);
  await store.save('newer-token','self','https://www.pinterest.com','105');store.consume('older-token');
  assert.equal((await store.read('newer-token','self','https://www.pinterest.com')).target,'105','consuming old notification preserves newer slot');
  await store.save('replacement-token','self','https://www.pinterest.com','106');
  assert.equal((await recovery().read('newer-token','self','https://www.pinterest.com')).target,'105','previous notification survives publication replacement');
  flushFails = true; await assert.rejects(store.save('failed-token','self','https://www.pinterest.com','104'));
  flushFails = false;
  assert(!saved.get('target')?.includes('csrftoken'), 'recovery has no session credentials');
  console.log('Notice recovery: early Want, new process, deferred activation, once-only consumption, account isolation, expiry, malformed data, invitations, clear and storage failure passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
