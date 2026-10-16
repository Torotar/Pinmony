const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const start = source.indexOf('  private syncEditValues(');
const method = source.slice(start, source.indexOf('\n  ', source.indexOf('\n  }', start) + 4));
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const h = new Host(); h.editingSession = ''; h.phase = () => h.snapshot.flow?.phase || '';
h.snapshot = {pageKey:'https://www.pinterest.com/owner/art/',session:0,nativeAccountGeneration:1,
  title:'插画',flow:{phase:'edit',loading:true,description:'描述',privacy:'secret',recommend:true,invites:true,requests:false}};
h.syncEditValues(); assert.equal(h.editingSession, '');
h.snapshot.flow.loading = false; h.syncEditValues();
assert.equal(h.editName, '插画'); assert.equal(h.editDescription, '描述'); assert.equal(h.secret, true);
h.editName = '正在修改'; h.syncEditValues(); assert.equal(h.editName, '正在修改');
h.snapshot.flow.phase = ''; h.syncEditValues(); h.snapshot.flow.phase = 'edit'; h.syncEditValues();
assert.equal(h.editName, '插画');
h.snapshot.pageKey = 'https://www.pinterest.com/owner/other/'; h.snapshot.title = '其他'; h.syncEditValues();
assert.equal(h.editName, '其他');
h.snapshot.nativeAccountGeneration = 2; h.snapshot.title = '新账号图板'; h.syncEditValues();
assert.equal(h.editName, '新账号图板');
assert(source.includes('this.syncEditValues();', source.indexOf('aboutToAppear')));
console.log('Board edit initial values: native session zero, loading, draft preservation, reopen, board/account changes passed');
