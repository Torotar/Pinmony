const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const { rawLocalMessages } = require('./local-message-test-fixture.cjs');
class TaskRegistry {}
const foundation = new Proxy({}, { get: (_, key) => key === 'PinmonyTaskRegistry' ? TaskRegistry : undefined });
const loader = createArktsLoader(ts, { common_foundation: foundation });
assert.equal(loader.loadPackage('common_foundation').PinmonyTaskRegistry, TaskRegistry,
  'lazy Proxy exports survive localization injection');
assert.equal(loader.loadPackage('common_foundation').PinmonyI18n, rawLocalMessages);
const customMessages = { text: value => value };
assert.equal(createArktsLoader(ts, { common_foundation: { PinmonyI18n: customMessages } })
  .loadPackage('common_foundation').PinmonyI18n, customMessages, 'explicit localization mocks are retained');
const { runtime } = require('./product-coordination-harness.cjs');
const reads = 'entry/src/main/ets/app/PinmonyDetailNativeReads.ets';
assert.equal(runtime(ts, { PIN_NATIVE_DETAIL_READS_ENABLED: false }).loadFile(reads).PIN_NATIVE_DETAIL_READS_ENABLED,
  false, 'explicit legacy selection reaches imported coordinators');
assert.equal(runtime(ts).loadFile(reads).PIN_NATIVE_DETAIL_READS_ENABLED,
  true, 'legacy fixtures do not change the production default');
assert.throws(() => loader.loadPackage('@kit.MissingFixtureKit'), /Missing native kit mock/);
console.log('Harness module exports: lazy dependencies, localization and branch isolation passed');
