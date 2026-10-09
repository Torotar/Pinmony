const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const path = require('node:path');

const apiSource = readSourceFileSync(path.join(__dirname, '../feature_home/src/main/ets/services/PinWebHomeApiScript.ets'), 'utf8');
const bridgeSource = readSourceFileSync(path.join(__dirname, '../feature_home/src/main/ets/services/PinWebHomeScript.ets'), 'utf8');
assert.match(apiSource, /pin\.grid_title[\s\S]*pin\.title[\s\S]*pin\.description/,
  'card titles are mapped from the home API response');
assert.doesNotMatch(apiSource, /DOMParser|document\.|innerText|textContent|PinWebHomeReadTitles/,
  'home title mapping does not read HTML or DOM text');
assert.doesNotMatch(bridgeSource, /DOMParser|document\.|innerText|textContent|PinWebHomeReadTitles/,
  'home bridge does not fetch or parse DOM titles');
console.log('home API title source: grid_title/title/description only; DOM title reads removed');
