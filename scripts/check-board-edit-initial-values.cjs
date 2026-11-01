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
assert.equal(h.recommend, true); assert.equal(h.invites, true); assert.equal(h.requests, false);
h.editName = '正在修改'; h.syncEditValues(); assert.equal(h.editName, '正在修改');
h.snapshot.flow.phase = ''; h.syncEditValues(); h.snapshot.flow.phase = 'edit'; h.syncEditValues();
assert.equal(h.editName, '插画');
h.snapshot.pageKey = 'https://www.pinterest.com/owner/other/'; h.snapshot.title = '其他'; h.syncEditValues();
assert.equal(h.editName, '其他');
h.snapshot.nativeAccountGeneration = 2; h.snapshot.title = '新账号图板'; h.syncEditValues();
assert.equal(h.editName, '新账号图板');
h.snapshot.flow.phase = ''; h.syncEditValues(); h.snapshot.flow.phase = 'edit'; h.snapshot.flow.error = 'unavailable'; h.syncEditValues();
assert.equal(h.editingSession, '', 'failed reads cannot freeze initial defaults into the edit session');
h.snapshot.flow.error = ''; h.snapshot.flow.recommend = false; h.syncEditValues(); assert.equal(h.recommend, false);
assert.match(source, /private setting\(\$\$: BoardSettingOptions\)/, 'checkbox builders receive reactive reference arguments');
assert.match(source, /Checkbox\(\)\.select\(\$\$\.selected\)/, 'render the current selected state instead of the first false snapshot');
assert.match(source, /selected: this\.recommend, changed:/);
const recommendation = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyRecommendationSettingsPage.ets', 'utf8');
assert(!recommendation.includes("Button(this.uiText('pm_reload_current_settings_d2b82d8a'))"), 'no bottom reload button');
assert(source.includes('this.syncEditValues();', source.indexOf('aboutToAppear')));
console.log('Board edit initial values: native session zero, loading, draft preservation, reopen, board/account changes passed');
