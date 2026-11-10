const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets', 'utf8');
const method = source.slice(source.indexOf('  private showMessageTime('), source.indexOf('  private messageTime('));
const Chat = new Function(ts.transpileModule(`class Chat { snapshot = { messages: [] }; ${method} } return Chat;`,
  { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText)();
const chat = new Chat();
const time = new Date(2026, 10, 7, 23, 0).getTime();
const message = offset => ({ id: String(offset), createdAt: new Date(time + offset * 60000).toISOString() });
chat.snapshot.messages = [message(0), message(2), message(8), message(13), message(14)];
assert.deepEqual(chat.snapshot.messages.map(item => chat.showMessageTime(item.id)), [true, false, true, false, false]);
chat.snapshot.messages = [message(-1), ...chat.snapshot.messages];
assert.equal(chat.showMessageTime(chat.snapshot.messages[1].id), false, 'history prepend updates former first-row boundary');
chat.snapshot.messages = [message(59), message(60)];
assert.equal(chat.showMessageTime(chat.snapshot.messages[1].id), true, 'midnight retains date boundary');
chat.snapshot.messages = [{ id: 'invalid', createdAt: 'invalid' }, message(0), message(-1)];
assert.equal(chat.showMessageTime(chat.snapshot.messages[0].id), false);
assert.equal(chat.showMessageTime(chat.snapshot.messages[1].id), true, 'invalid predecessor cannot hide valid time');
assert.equal(chat.showMessageTime(chat.snapshot.messages[2].id), true, 'out-of-order timestamps do not merge');
assert.equal(chat.showMessageTime('missing'), false);
assert.match(source, /if \(this\.showMessageTime\(message\.id\)\)/);
assert.match(source, /message\.id \+ ':time:' \+ this\.showMessageTime\(message\.id\)/);
assert.match(source, /this\.uiText\('pm_message_reaction_title'\)/);
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  const resources = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8'));
  assert(resources.string.some(item => item.name === 'pm_message_reaction_title' && item.value), locale);
}
console.log('Chat time groups: five-minute boundary, history prepend, midnight, invalid/out-of-order dates and localized reaction title passed.');
