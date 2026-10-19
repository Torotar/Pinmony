const resources = require('../common_foundation/src/main/resources/base/element/string.json').string;
const copy = Object.fromEntries(resources.map(row => [row.name, row.value]));
const resolve = source => copy[source] ?? source;
// Existing business unit tests inspect raw Chinese state. Keep message identity
// at that boundary; check-language.cjs exercises the real message/storage service.
const rawLocalMessages = {
  message: resolve, text: resolve, render: source => source,
  format: (source, values) => resolve(source).replace(/\{(\d+)\}/g, (m,i) => values[i] === undefined ? m : String(values[i])),
  isText: (value, source) => value === resolve(source),
  includesText: (value, source) => value.includes(resolve(source)),
  isUnconfirmed: value => /未确认|待确认|not confirmed|unconfirmed/i.test(value)
};
function withLocalMessages(requireDependency) {
  return name => {
    const dependency = requireDependency(name);
    return name === 'common_foundation' ? { PinmonyI18n: rawLocalMessages, ...dependency } : dependency;
  };
}
module.exports = { rawLocalMessages, withLocalMessages };
