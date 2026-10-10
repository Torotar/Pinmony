const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const scripts = createArktsLoader(ts, {common_foundation: {allowsSpeculativeReads: () => false}})
  .loadFile('entry/src/main/ets/app/PinmonyScriptRegistry.ets').pinWebDocumentStartScripts();
// Authorized feature changes invalidate old byte hashes; retain injection boundaries,
// parse every real script and verify the dependency-sensitive order explicitly.
const baseline = require('./fixtures/document-start-script-hashes.json');
assert.equal(scripts.length, baseline.length);
assert.deepEqual(Array.from(scripts, item => Array.from(item.scriptRules)), baseline.map(item => item.scriptRules));
for (const item of scripts) new Function(item.script);
assert.match(scripts[0].script, /window\.PinmonySpeculativeReadsEnabled = false;/);
assert.match(scripts[0].script, /window\.PinmonyReadMergingEnabled = true;/);
assert.match(scripts[0].script, /window\.PinmonyNetwork =/);
assert.match(scripts[1].script, /window\.PinmonyAuthSync =/);
const flags = ['Post', 'Detail', 'Profile', 'Board', 'Inbox', 'Home', 'Search', 'SearchDiscovery', 'SearchQuiz'];
let previous = 1;
for (const flag of flags) {
  const assignment = new RegExp('window\\.Pinmony' + flag + 'ApiEnabled = (?:true|false);');
  const position = scripts.findIndex(item => assignment.test(item.script));
  assert(position > previous, flag + ' injection preserves feature order'); previous = position;
}
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
console.log('Index composition: parsed ordered injection, request policy switches, stable Store binding and lifecycle ownership passed');
