const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const { rawLocalMessages } = require('./local-message-test-fixture.cjs');

// Loads real non-UI ArkTS modules. Native kits are explicitly mocked by callers.
function createArktsLoader(ts, mocks = {}, globals = {}) {
  const cache = new Map(), packages = new Map();
  function loadPackage(name) {
    if (Object.hasOwn(mocks, name)) return name === 'common_foundation' ? { PinmonyI18n: rawLocalMessages, ...mocks[name] } : mocks[name];
    if (name.startsWith('@')) throw Error('Missing native kit mock: ' + name);
    if (packages.has(name)) return packages.get(name);
    const barrel = path.join(root, name, 'Index.ets');
    const source = ts.createSourceFile(barrel, fs.readFileSync(barrel, 'utf8'), ts.ScriptTarget.Latest, true);
    const exports = new Proxy({}, { get(_, key) {
      if (name === 'common_foundation' && key === 'PinmonyI18n') return rawLocalMessages;
      for (const statement of source.statements.filter(ts.isExportDeclaration)) {
        if (!statement.moduleSpecifier || !statement.exportClause || !ts.isNamedExports(statement.exportClause)) continue;
        const match = statement.exportClause.elements.find(e => e.name.text === key);
        if (match) return loadFile(path.resolve(path.dirname(barrel), statement.moduleSpecifier.text) + '.ets')[match.propertyName?.text || key];
      }
      throw Error('Missing public export ' + name + '.' + String(key));
    } });
    packages.set(name, exports);
    return exports;
  }
  function loadFile(file) {
    file = path.resolve(root, file);
    if (cache.has(file)) return cache.get(file);
    const exports = {};
    cache.set(file, exports);
    const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
      target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS, experimentalDecorators: true
    } }).outputText;
    vm.runInNewContext(code, { exports, Observed: type => type, console,
      setTimeout, clearTimeout, setInterval, clearInterval, URL, ...globals,
      require: spec => spec.startsWith('.') ? loadFile(path.resolve(path.dirname(file), spec) + '.ets') : loadPackage(spec)
    }, { filename: file });
    return exports;
  }
  return { loadFile, loadPackage };
}
module.exports = { createArktsLoader };
