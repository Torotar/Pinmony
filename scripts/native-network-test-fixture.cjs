const fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '..');
const groups = ['profile', 'search', 'board', 'pin', 'inbox', 'home', 'settings'];

// Legacy contract tests instantiate the old aggregate network API. Compose the real
// feature clients over their mocked transport, without restoring business code to common_network.
// check-framework-completion separately exercises the production module imports/facade.
function source(text) {
  if (!text.includes('export class PinmonyNativeNetwork {')) return text;
  let result = text;
  for (const group of groups) {
    const name = 'Pinmony' + group[0].toUpperCase() + group.slice(1) + 'Network';
    const feature = fs.readFileSync(path.join(root, `feature_${group}/src/main/ets/services/${name}.ets`), 'utf8');
    result += '\n' + feature.replace(/^import[^;]+;\r?\n/gm, '');
    result += `\nfor (const name of Object.getOwnPropertyNames(${name}.prototype)) {
      if (name === 'constructor') continue;
      PinmonyNativeNetwork.prototype[name] = function(...args) { return new ${name}(this)[name](...args); };
    }\n`;
  }
  return result;
}
const compiled = new Map();
function transpile(ts, text, options) {
  if (!text.includes('export class PinmonyNativeNetwork {')) return ts.transpileModule(text, options);
  const key = text + JSON.stringify(options);
  if (compiled.has(key)) return compiled.get(key);
  const result = ts.transpileModule(source(text), options);
  if (compiled.size >= 8) compiled.delete(compiled.keys().next().value);
  compiled.set(key, result);
  return result;
}
module.exports = { source, transpile };
