const resources = require('../common_foundation/src/main/resources/base/element/string.json').string;
const copy = Object.fromEntries(resources.map(row => [row.name, row.value]));
const resolve = source => copy[source] ?? source;
// Existing business unit tests inspect raw Chinese state. Keep message identity
// at that boundary; check-language.cjs exercises the real message/storage service.
const rawLocalMessages = {
  message: resolve, text: resolve, render: source => source,
  syncAccountLanguage: () => {}, // Real locale persistence is covered by check-language.cjs.
  format: (source, values) => resolve(source).replace(/\{(\d+)\}/g, (m,i) => values[i] === undefined ? m : String(values[i])),
  isText: (value, source) => value === resolve(source),
  includesText: (value, source) => value.includes(resolve(source)),
  isUnconfirmed: value => /未确认|待确认|not confirmed|unconfirmed/i.test(value)
};
function withLocalMessages(requireDependency) {
  return name => {
    const dependency = requireDependency(name);
    if (name !== 'common_foundation') return dependency;
    const { createArktsLoader } = require('./arkts-module-loader.cjs');
    const ts = require(process.argv[2] || 'typescript');
    const product = createArktsLoader(ts, {}).loadFile('common_foundation/src/main/ets/PinmonyProductPin.ets');
    return { PinmonyI18n: rawLocalMessages, ...product, ...dependency };
  };
}
module.exports = { rawLocalMessages, withLocalMessages };
