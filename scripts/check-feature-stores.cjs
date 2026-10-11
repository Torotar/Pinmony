const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const projectRoot = path.resolve(__dirname, '..');
const cache = new Map();
function resolveImport(file, spec) {
  if (spec.startsWith('@')) return undefined;
  if (spec.startsWith('.')) return path.resolve(path.dirname(file), spec) + '.ets';
  const packageRoot = path.join(projectRoot, spec);
  const packageSource = fs.readFileSync(path.join(packageRoot, 'oh-package.json5'), 'utf8');
  const main = packageSource.match(/"main"\s*:\s*"([^"]+)"/)?.[1] || 'Index.ets';
  return path.join(packageRoot, main.endsWith('.ets') ? main : main + '.ets');
}
function load(file) {
  file=path.resolve(file);
  if(cache.has(file))return cache.get(file);
  const exports={};cache.set(file,exports);
  require('./product-coordination-harness.cjs').run(ts,ts.transpileModule(fs.readFileSync(file,'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS,experimentalDecorators:true}
  }).outputText,{exports,Observed:type=>type,require:spec=>{
    const resolved = resolveImport(file, spec);
    return resolved ? load(resolved) : {};
  }});
  return exports;
}
const names=['Home','Search','Inbox','Profile','Board','Pin'];
const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const context={};
for(const name of names) {
  const className='Pinmony'+name+'Store',module='feature_'+name.toLowerCase();
  const Store=load(module+'/src/main/ets/stores/'+className+'.ets')[className];
  const first=new Store(),second=new Store();
  context[className]=Store;
  assert.notEqual(first,second);
  for(const key of Object.keys(first)) {
    if(first[key] && typeof first[key]==='object')assert.notEqual(first[key],second[key],className+' does not share mutable default '+key);
  }
  assert(source.includes('@State private '+name.toLowerCase()+'Store: '+className));
}
assert.doesNotMatch(source, /private (?:get|set) \w+\(/, 'ArkUI structs must not use the dropped compatibility accessors');
const host={};
for(const name of names)host[name.toLowerCase()+'Store']=new context['Pinmony'+name+'Store']();
let changes=0;
for(const name of names) host[name.toLowerCase()+'Store'].onNavigationChange=()=>changes++;
const snapshot={session:1,pageKey:'synthetic',pins:[]};
host.homeStore.home=snapshot;host.homeStore.homeError='offline';host.homeStore.homeRequestToken++;
assert.equal(host.homeStore.home,snapshot);
assert.equal(host.homeStore.homeError,'offline');assert.equal(host.homeStore.homeRequestToken,1);
host.homeStore.cachedHome=snapshot;assert.equal(host.homeStore.cachedHome,snapshot,'retained content belongs to the feature');
assert.equal(host.searchStore.search,undefined,'home updates do not replace another root');
host.pinStore.detail={pinUrl:'synthetic'};assert.equal(changes,1,'secondary page mutation still notifies product navigation');
host.profileStore.profileLoading=true;assert.equal(changes,2);
host.profileStore.profileLoading=true;assert.equal(changes,2,'unchanged values do not enqueue duplicate navigation notifications');
host.inboxStore.inboxError='offline';assert.equal(host.inboxStore.inboxError,'offline');
for(const name of ['profileStore','inboxStore','searchStore']) {
  const field=name.replace('Store','')+'Cache';
  assert(host[name][field]);assert.doesNotThrow(()=>host[name][field].clear(),'login cleanup has a live '+field);
}
console.log('Direct feature Store access, cache initialization and navigation notifications passed');
