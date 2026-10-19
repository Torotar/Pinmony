// Existing business unit tests inspect raw Chinese state. Keep message identity
// at that boundary; check-language.cjs exercises the real message/storage service.
const rawLocalMessages = {
  message: source => source, text: source => source, render: source => source,
  format: (source, values) => source.replace(/\{(\d+)\}/g, (m,i) => values[i] === undefined ? m : String(values[i])),
  isText: (value, source) => value === source,
  includesText: (value, source) => value.includes(source),
  isUnconfirmed: value => /未确认|待确认|not confirmed|unconfirmed/i.test(value)
};
function withLocalMessages(requireDependency) {
  return name => {
    const dependency = requireDependency(name);
    return name === 'common_foundation' ? { PinmonyI18n: rawLocalMessages, ...dependency } : dependency;
  };
}
module.exports = { rawLocalMessages, withLocalMessages };
