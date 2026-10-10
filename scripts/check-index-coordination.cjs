const fs = require('node:fs'), assert = require('node:assert/strict'), crypto = require('node:crypto');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const scripts = createArktsLoader(ts).loadFile('entry/src/main/ets/app/PinmonyScriptRegistry.ets').pinWebDocumentStartScripts();
const hashes = scripts.map(item => ({ sha256: crypto.createHash('sha256').update(item.script).digest('hex'), scriptRules: Array.from(item.scriptRules) }));
assert.equal(JSON.stringify(hashes), JSON.stringify(require('./fixtures/document-start-script-hashes.json')),
  'ordered document-start scripts, switches, rules and native adapters preserve the pre-refactor contract');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const controller = fs.readFileSync('feature_search/src/main/ets/controllers/PinmonySearchController.ets', 'utf8');
assert.match(index, /documentStartScripts: ScriptItem\[\] = pinWebDocumentStartScripts\(\)/);
assert.match(index, /runJavaScriptOnDocumentStart\(this\.documentStartScripts\)/);
assert.equal((index.match(/new PinmonySearchStore\(\)/g) || []).length, 1);
assert.match(index, /new PinmonySearchController\(this\.searchStore,/);
assert.doesNotMatch(controller, /from ['"][^'"]*(?:entry|feature_pin|feature_home|feature_profile|feature_inbox)[^'"]*['"]/);
assert.doesNotMatch(controller, /this\.(?:controller|pinStore|profileStore|homeStore|inboxStore|navigationAddress|activeTab)\b/);
assert.match(index, /searchController\.invalidatePending\(\)/);
assert.match(index, /systemActions\.dispose\(\)/);
console.log('Index composition: identical ordered injection, stable Store binding, feature boundaries and lifecycle ownership passed');
