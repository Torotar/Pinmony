const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let ts;
try { ts = require('typescript'); }
catch (_) {
  if (!process.argv[2]) throw new Error('Pass the DevEco TypeScript module path as the first argument');
  ts = require(process.argv[2]);
}
const source = readSourceFileSync('entry/src/main/ets/components/PinmonyCommentsSheet.ets', 'utf8');
const methods = source.slice(source.indexOf('  private ageLabel'), source.indexOf('  @Builder'));
const compiled = ts.transpileModule('class Presentation {' + methods + '} Presentation;',
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const now = Date.parse('2026-10-01T06:30:00Z');
const Presentation = vm.runInNewContext(compiled, { Date: { now: () => now, parse: Date.parse }, JSON, Number, Math });
const view = new Presentation();
assert.equal(view.ageLabel('Thu, 01 Oct 2026 06:29:30 +0000'), '刚刚');
assert.equal(view.ageLabel('2026-10-01T04:30:00Z'), '2小时');
assert.equal(view.ageLabel('2026-08-01T06:30:00Z'), '2个月');
assert.equal(view.ageLabel('2024-12-17T08:29:26Z'), '1年');
assert.equal(view.ageLabel('invalid'), '');
assert.equal(view.ageLabel('2026-10-02T06:30:00Z'), '刚刚');
const item = { id: '301', repliesOpen: false, repliesLoading: false, replies: [] };
const closed = view.commentKey(item);
assert.equal(view.commentKey(JSON.parse(JSON.stringify(item))), closed, 'Unchanged polling snapshots reuse rows');
item.repliesOpen = true; item.repliesLoading = true;
const loading = view.commentKey(item);
assert.notEqual(loading, closed, 'Opening a fold must invalidate the retained ForEach closure');
item.repliesLoading = false; item.replies = [{ id: '401', text: 'reply', liked: false }];
const ready = view.commentKey(item);
assert.notEqual(ready, loading, 'Loaded reply content must replace the loading row');
item.replies[0].liked = true;
assert.notEqual(view.commentKey(item), ready, 'Nested reply reactions invalidate the parent snapshot');
console.log('comments: compact age labels, stable unchanged rows, fold/loading/content/reaction refresh OK');
