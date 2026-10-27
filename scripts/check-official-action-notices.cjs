const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'common_ui/src/main/ets/components/PinmonyActionNotice.ets';
const source = fs.readFileSync(file, 'utf8');
assert(source.includes("from '@kit.UIDesignKit'"));
assert(!/openCustomDialog|ComponentContent|PanGesture|Row\(|Column\(/.test(source), 'all visible notice content belongs to official HDS');
const code = source.slice(source.indexOf('class PinmonyActionNoticeLease'), source.indexOf('  build()')) + '}\nPinmonyActionNotice;';
const executable = code.replace('@Component', '').replace('export struct', 'class').replace(/@Prop\s*/g, '').replace(/@Watch\('[^']+'\)\s*/g, '');
const shown = [], dismissed = []; let actions = 0;
const Notice = vm.runInNewContext(ts.transpileModule(executable, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
  HdsSnackBar: class { show(icon, message, operation, style) { shown.push({ owner: this, icon, message, operation, style }); } dismiss() { dismissed.push(this); } },
  SnackBarIconType: { NORMAL: 1 }, SnackBarOperationType: { TEXT_WITH_CLOSE: 3, CLOSE_BUTTON_ONLY: 1 }, $r: x => x
});
function notice(message = 'failure') {
  const n = new Notice(); n.message = message; n.actionText = 'reload'; n.onAction = () => actions++; n.getUIContext = () => ({}); return n;
}
const first = notice(); first.syncNotice(); assert.equal(shown.length, 0);
first.aboutToAppear(); assert.equal(shown.length, 1); const old = shown[0];
first.syncNotice(); assert.equal(shown.length, 1, 'no duplicate notices for unchanged state');
first.scope = 'another-document'; first.syncNotice(); old.operation.onContentClick(); assert.equal(actions, 0);
shown.at(-1).operation.onContentClick(); assert.equal(actions, 1); first.syncNotice(); assert.equal(shown.length, 2, 'explicitly dismissed state stays closed');
first.message = ''; first.syncNotice(); first.message = 'failure'; first.syncNotice(); assert.equal(shown.length, 3, 'a new failure may show the same message');
first.actionEnabled = false; first.syncNotice(); assert.equal(shown.at(-1).operation.operationType, 1); shown.at(-1).operation.onContentClick(); assert.equal(actions, 1, 'disabled operation is never dispatched');
const second = notice('second'); second.aboutToAppear(); const current = shown.at(-1); const count = dismissed.length;
first.aboutToDisappear(); assert.equal(dismissed.length, count, 'old page cannot dismiss a newer page notice');
current.style.pressBackCallback(); assert.equal(actions, 1, 'back only dismisses');
second.message = 'English failure'; second.syncNotice(); assert.equal(shown.at(-1).message.title, 'English failure');
const inactive = shown.at(-1); second.active = false; second.syncNotice(); inactive.operation.onContentClick(); assert.equal(actions, 1);
second.active = true; second.syncNotice(); assert.equal(shown.at(-1).message.title, 'English failure');
second.aboutToDisappear(); shown.at(-1).operation.onContentClick(); assert.equal(actions, 1);
let pages = 0;
for (const dir of fs.readdirSync('.').filter(x => x.startsWith('feature_'))) {
  const root = path.join(dir, 'src/main/ets/components');
  for (const name of fs.readdirSync(root).filter(x => x.endsWith('.ets'))) {
    const text = fs.readFileSync(path.join(root, name), 'utf8');
    if (text.includes('PinmonyActionNotice({') || text.includes('new HdsSnackBar(')) pages++;
  }
}
assert(pages >= 30, 'migration must cover all feature groups, not a single settings page');
console.log(`Official action notices: ${pages} pages/panels, no custom drawing, lifecycle, owner replacement, retry, disabled writes, stale callbacks and language refresh passed`);
