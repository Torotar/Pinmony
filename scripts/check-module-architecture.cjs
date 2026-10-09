const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const modules = fs.readdirSync(root).filter(n => /^(common_|feature_)/.test(n));
const packages = new Map(modules.map(m => [m, JSON.parse(fs.readFileSync(path.join(root,m,'oh-package.json5'),'utf8'))]));
function walk(dir) {
  return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e => e.isDirectory() ? walk(path.join(dir,e.name)) : [path.join(dir,e.name)]);
}
const graph = new Map();
for (const [module, pkg] of packages) {
  const deps = Object.keys(pkg.dependencies || {});
  graph.set(module,deps);
  for (const dep of deps) {
    assert(packages.has(dep), `${module}: unknown dependency ${dep}`);
    assert(dep.startsWith('common_'), `${module}: business modules must not depend on other features`);
  }
  for (const file of walk(path.join(root,module,'src/main/ets')).filter(f => f.endsWith('.ets'))) {
    const source = fs.readFileSync(file,'utf8');
    for (const [,spec] of source.matchAll(/\bfrom\s+['"]([^'"]+)['"]/g)) {
      if (spec.startsWith('.')) {
        const resolved = path.resolve(path.dirname(file),spec)+'.ets';
        assert(resolved.startsWith(path.join(root,module)+path.sep), `${file}: crosses module boundary`);
        assert(fs.existsSync(resolved), `${file}: missing ${spec}`);
      } else if (!spec.startsWith('@')) {
        assert(deps.includes(spec), `${file}: undeclared dependency ${spec}`);
      }
    }
  }
  assert.equal(JSON.parse(fs.readFileSync(path.join(root,module,'src/main/module.json5'),'utf8')).module.type,'har');
  const entry = fs.readFileSync(path.join(root,module,pkg.main),'utf8');
  for (const [,spec] of entry.matchAll(/\bfrom\s+['"]([^'"]+)['"]/g)) assert(fs.existsSync(path.resolve(root,module,spec)+'.ets'));
}
function visit(module, stack = []) {
  assert(!stack.includes(module), 'Circular dependency: '+[...stack,module].join(' -> '));
  for (const dep of graph.get(module)) visit(dep,[...stack,module]);
}
for (const m of modules) visit(m);
for (const [old,current] of Object.entries(require('./module-source-map.json'))) {
  assert(fs.existsSync(path.join(root,current)), 'Missing migrated source: '+current);
  assert(!fs.existsSync(path.join(root,old)), 'Duplicate legacy source: '+old);
}
console.log(`Three-layer dependency, source ownership and HAR boundary checks passed (${modules.length} modules).`);
