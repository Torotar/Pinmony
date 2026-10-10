const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const featureModules = ['feature_home', 'feature_search', 'feature_inbox', 'feature_profile',
  'feature_pin', 'feature_board', 'feature_settings'];
const commonModules = ['common_session', 'common_network', 'common_ui', 'common_foundation'];

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const fullPath = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(fullPath) : [fullPath];
  });
}

function sourcesFor(moduleName) {
  return walk(path.join(root, moduleName, 'src', 'main', 'ets'))
    .filter(file => file.endsWith('.ets'))
    .map(file => ({ file, source: fs.readFileSync(file, 'utf8') }));
}

function importedPackages(source) {
  return Array.from(source.matchAll(/\bfrom\s+['"]([^'"]+)['"]/g), match => match[1])
    .filter(specifier => !specifier.startsWith('.') && !specifier.startsWith('@'));
}

function declaredDependencies(moduleName) {
  const packageSource = read(path.join(moduleName, 'oh-package.json5'));
  const block = packageSource.match(/"dependencies"\s*:\s*\{([\s\S]*?)\}/)?.[1] || '';
  return new Set(Array.from(block.matchAll(/"([a-zA-Z0-9_]+)"\s*:/g), match => match[1]));
}

const modules = [...featureModules, ...commonModules];
for (const moduleName of modules) {
  assert(fs.existsSync(path.join(root, moduleName, 'Index.ets')), `${moduleName}: missing public Index.ets`);
  assert(read(path.join(moduleName, 'src', 'main', 'module.json5')).includes('"type": "har"'),
    `${moduleName}: must remain a HAR module`);
  const declared = declaredDependencies(moduleName);
  for (const { file, source } of sourcesFor(moduleName)) {
    for (const imported of importedPackages(source)) {
      assert(declared.has(imported), `${file}: undeclared package import ${imported}`);
      assert(!featureModules.includes(moduleName) || !featureModules.includes(imported),
        `${file}: feature modules must not depend on another feature (${imported})`);
      assert(!commonModules.includes(moduleName) || !imported.startsWith('feature_'),
        `${file}: common modules must not depend on feature code (${imported})`);
    }
    assert(!/from\s+['"][^'"]*entry(?:\/|['"])/.test(source),
      `${file}: lower layers must not import entry code`);
  }
}

const entrySource = read('entry/src/main/ets/pages/Index.ets');
assert.equal((entrySource.match(/@Entry\b/g) || []).length, 1, 'entry must have one ArkUI entry component');
assert.match(entrySource, /@Entry\s+@Component\s+struct Index/);
for (const store of ['PinmonyHomeStore', 'PinmonySearchStore', 'PinmonyInboxStore', 'PinmonyProfileStore',
  'PinmonyBoardStore', 'PinmonyPinStore', 'PinmonySettingsStore']) {
  assert(entrySource.includes(store), `entry must own ${store}`);
}

const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
const moduleConfig = read('entry/src/main/module.json5');
assert.match(moduleConfig, /"mainElement"\s*:\s*"EntryAbility"/);
assert.match(moduleConfig, /"srcEntry"\s*:\s*"\.\/ets\/entryability\/EntryAbility\.ets"/);
for (const event of ['create-start', 'create-complete', 'window-stage-create', 'content-load-start',
  'content-load-complete', 'foreground', 'background', 'window-stage-destroy', 'destroy-start',
  'destroy-complete', 'configuration-update']) {
  assert(ability.includes("logLifecycle('" + event + "'"), `Ability lifecycle event is missing: ${event}`);
}
assert(ability.includes('NetworkManager.destroy()'), 'Ability owns shared network shutdown');
assert(ability.includes("this.mainWindow?.off('avoidAreaChange')"), 'window listeners are released');

const rcpFiles = [];
for (const { file, source } of [...sourcesFor('entry'), ...modules.flatMap(sourcesFor)]) {
  if (source.includes('@kit.RemoteCommunicationKit') || /\brcp\./.test(source)) rcpFiles.push(file);
}
assert.equal(rcpFiles.length, 1, 'RemoteCommunicationKit must be owned by common_network');
assert(rcpFiles[0].endsWith(path.join('common_network', 'src', 'main', 'ets', 'PinmonyNativeNetwork.ets')),
  'RCP ownership must stay in PinmonyNativeNetwork');

const architecture = read('docs/ARCHITECTURE.md');
for (const heading of ['## 工程边界', '## Ability 与生命周期', '## ArkUI 页面与状态管理',
  '## 网络请求与并发生命周期', '## 缓存与数据一致性', '## 路径和验证']) {
  assert(architecture.includes(heading), `architecture documentation is missing ${heading}`);
}
console.log('Foundation architecture boundaries, Ability ownership, Store ownership, and RCP ownership passed');
