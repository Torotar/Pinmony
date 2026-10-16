const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts; try { ts = require('typescript'); } catch (_) { ts = require(process.argv[2]); }
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const start = source.indexOf('  private updateSavedFeedback('), end = source.indexOf('\n  private phase(', start);
const code = ts.transpileModule('class View {' + source.slice(start, end) +
  ' phase() { return this.snapshot.flow.phase; } getUIContext() { return {}; }} globalThis.View = View;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const messages = [];
const context = { $r: x => x, SnackBarIconType: { NORMAL: 1 },
  SymbolGlyphModifier: class { fontColor() { return this; } },
  HdsSnackBar: class { show(icon, message) { messages.push(message.title); } dismiss() {} } };
vm.runInNewContext(code, context);
const view = new context.View();
view.savedSession = 'board:1'; view.confirmedSaved = [];
view.snapshot = { pageKey: 'board', session: 1, title: '风景', flow: { phase: 'ideas', saved: [], busy: true } };
view.updateSavedFeedback(); assert.equal(messages.length, 0, 'button dispatch is not a success');
view.snapshot.flow.saved = ['101']; view.updateSavedFeedback(); assert.equal(messages.length, 0, 'busy snapshot does not notify');
view.snapshot.flow.busy = false; view.updateSavedFeedback();
assert.deepEqual(messages, ['已收藏至 风景']);
view.updateSavedFeedback(); assert.equal(messages.length, 1, 'repeated snapshots do not repeat feedback');
view.snapshot.flow.uncertain = true; view.snapshot.flow.saved.push('102'); view.updateSavedFeedback();
assert.equal(messages.length, 1, 'unconfirmed results do not notify');
view.snapshot.session = 2; view.snapshot.flow.uncertain = false; view.updateSavedFeedback();
assert.equal(messages.length, 1, 'new session does not replay old saved state');
// Native writes retain one feedback scope despite Web document session changes.
view.snapshot = {pageKey:'native-board',session:7,nativeAccountGeneration:3,title:'原生图板',flow:{phase:'ideas',saved:[],busy:false}};
view.updateSavedFeedback();view.snapshot.session=0;view.snapshot.flow.saved.push('201');view.updateSavedFeedback();
assert.equal(messages.at(-1),'已收藏至 原生图板');const count=messages.length;
view.snapshot.session=99;view.updateSavedFeedback();assert.equal(messages.length,count,'Web session updates cannot replay native feedback');
view.snapshot.nativeAccountGeneration=4;view.updateSavedFeedback();assert.equal(messages.length,count,'a different account generation never replays saved feedback');
console.log('board save feedback: confirmed success only, dedupe, uncertain and session isolation passed');
