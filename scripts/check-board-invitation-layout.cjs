const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyBoardInvitationList.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const brace = source.indexOf('{', start); let depth = 1, end = brace + 1;
  while (depth && end < source.length) { if (source[end] === '{') depth++; if (source[end] === '}') depth--; end++; }
  assert.equal(depth, 0); return source.slice(start, end);
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['measuredLabelWidth', 'invitationActionWidth', 'invitationActionsInline', 'invitationTime'].map(method).join('\n') + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
  { FontWeight: { Normal: 400, Medium: 500, Bold: 700 }, Date: class extends Date {
    constructor(value) { super(arguments.length === 0 ? '2026-11-14T14:00:00' : value); }
  } });
const host = new Host(); let scale = 1;
const labels = { decline: '拒绝', accept: '接受', title: '图板邀请' };
host.uiText = key => key.includes('decline') ? labels.decline : key.includes('accept') ? labels.accept : labels.title;
host.getUIContext = () => ({ px2vp: value => value, getMeasureUtils: () => ({
  measureTextSize: ({ textContent, fontSize }) => ({ width: [...textContent].reduce((sum, ch) => sum + (ch.charCodeAt(0) > 255 ? fontSize : fontSize * 0.6), 0) * scale })
}) });
host.all = false; host.invitationCardWidth = 320;
assert(host.invitationActionsInline({ inviter: 'Owner' }));
assert.equal(host.invitationActionWidth('decline'), 60, 'Button uses measured label plus horizontal padding');
labels.decline = 'Eine sehr lange Einladung ablehnen'; labels.accept = 'Einladung jetzt annehmen';
assert(!host.invitationActionsInline({ inviter: 'Owner' }), 'Long localized actions move below instead of squeezing text');
assert(host.invitationActionWidth('decline') <= 157, 'Fallback action remains inside the card');
labels.decline = '拒绝'; labels.accept = '接受';
assert(host.invitationActionsInline({ inviter: 'Owner' }), 'Live language restoration returns actions inline');
scale = 2; assert(!host.invitationActionsInline({ inviter: 'Owner' }), 'Large measured type also selects fallback');
scale = 1; host.invitationCardWidth = 230; assert(!host.invitationActionsInline({ inviter: 'Owner' }));
host.invitationCardWidth = 700; host.all = true; assert(host.invitationActionsInline({ inviter: 'Owner' }));
const builder = source.slice(source.indexOf('@Builder private invitationActions'), source.indexOf('@Builder private content'));
assert(!builder.includes('.layoutWeight(1)'), 'Actions never stretch to equal half-card columns');
assert.equal((builder.match(/!this.snapshot.uncertain && item.status === 'new'/g) || []).length, 2);
assert(builder.includes('this.onDecline(item)') && builder.includes('this.onAccept(item)'));
assert(source.includes('if (this.invitationActionsInline(item))') && source.includes('if (!this.invitationActionsInline(item))'));
assert(source.includes('.onAreaChange('));
assert(!source.includes("Text(this.invitationTime(item)).fontSize(12)"), 'timestamp no longer occupies a separate full-width row');
const inlineAt = source.indexOf('if (this.invitationActionsInline(item))');
const timeAt = source.indexOf("Text(this.invitationTime(item).split('\\n')[0])", inlineAt);
const rowEnd = source.indexOf("}.width('100%').alignItems(VerticalAlign.Center)", inlineAt);
assert(timeAt > inlineAt && timeAt < rowEnd, 'timestamp remains at the trailing edge of the original header row');
assert(source.slice(timeAt, rowEnd).includes('.alignItems(HorizontalAlign.End).flexShrink(0).alignSelf(ItemAlign.Center)'));
host.all = false; host.invitationCardWidth = 320; host.uiLanguage = 'zh';
const zh = JSON.parse(fs.readFileSync('common_foundation/src/main/resources/zh_CN/element/string.json', 'utf8'));
let messages = new Map(zh.string.map(item => [item.name, item.value]));
host.uiText = key => messages.get(key) || key;
const invite = { inviter: 'Owner', createdAt: '2026-11-10T13:24:00' };
assert.equal(host.invitationTime(invite), '13:24\n星期二', 'clock above weekday matches adjacent inbox messages');
assert(host.invitationActionsInline(invite), 'Chinese actions and two-line time fit together at regular width');
host.invitationCardWidth = 300;
assert(!host.invitationActionsInline(invite), 'time width is reserved before deciding to wrap actions');
assert.equal(host.invitationTime({ createdAt: 'invalid' }), '');
assert.equal(host.invitationTime({ createdAt: '2026-11-14T09:05:00' }), '09:05\n星期六');
for (const [dir, locale] of [['en_US','en'], ['ru','ru'], ['ar','ar'], ['zh_CN','zh']]) {
  messages = new Map(JSON.parse(fs.readFileSync('common_foundation/src/main/resources/' + dir + '/element/string.json', 'utf8')).string.map(item => [item.name, item.value]));
  host.uiLanguage = locale;
  const parts = host.invitationTime(invite).split('\n');
  assert.equal(parts.length, 2); assert(parts.every(Boolean));
  assert.equal(parts[1], messages.get('pm_tuesday_8621c00d'), 'weekday follows current language without reloading data');
  const old = host.invitationTime({ createdAt: '2025-10-01T13:24:00' });
  assert(old.split('\n')[1].length > 0, 'older dates remain visible below the clock');
}
console.log('Invitation actions: compact historical row, trailing clock/calendar, measured wrapping including timestamp, live language/font scale, narrow/wide cards and permission guards passed');
