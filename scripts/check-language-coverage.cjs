// Build-time localization gate. Website/user data is deliberately not translated.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const locales = ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru'];
const tables = locales.map(locale => JSON.parse(read(`common_foundation/src/main/resources/${locale}/element/string.json`)).string);
const names = tables[0].map(row => row.name).sort();
for (let i = 0; i < tables.length; i++) {
  assert.equal(new Set(tables[i].map(row => row.name)).size, tables[i].length, `Duplicate language key: ${locales[i]}`);
  assert.deepEqual(tables[i].map(row => row.name).sort(), names, `Language key parity: ${locales[i]}`);
  const values = new Map(tables[i].map(row => [row.name, row.value]));
  for (const row of tables[0]) {
    assert.equal(typeof values.get(row.name), 'string');
    assert.deepEqual((values.get(row.name).match(/\{\d+\}/g) || []).sort(), (row.value.match(/\{\d+\}/g) || []).sort(), `Placeholder mismatch: ${row.name}`);
  }
}
for (const localeIndex of [3, 4]) {
  for (const row of tables[localeIndex]) assert(!/[\u3400-\u9fff]/.test(row.value), `Chinese in English resource: ${locales[localeIndex]}:${row.name}`);
}
const known = new Set(names), errors = [];
function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => entry.isDirectory() ? walk(path.join(dir, entry.name)) : entry.name.endsWith('.ets') ? [path.join(dir, entry.name)] : []);
}
const modules = fs.readdirSync(root).filter(name => name === 'entry' || /^(feature_|common_)/.test(name));
let checked = 0;
for (const module of modules) {
  const dir = path.join(root, module, 'src/main/ets');
  if (!fs.existsSync(dir)) continue;
  for (const file of walk(dir)) {
    const source = fs.readFileSync(file, 'utf8'), relative = path.relative(root, file);
    if (/Script\.ets$/.test(file)) continue; // JS website bridges have a separate source boundary.
    checked++;
    const report = (offset, message) => errors.push(`${relative}:${source.slice(0, offset).split('\n').length}: ${message}`);
    for (const match of source.matchAll(/(['"])(pm_[a-z0-9_]+)\1/g)) {
      if (!match[2].endsWith('_') && !known.has(match[2])) report(match.index, `Missing resource ${match[2]}`);
    }
    for (const match of source.matchAll(/\b(?:uiText|uiFormat|text|message|format)\(\s*(['"])([^'"\r\n]*[\u3400-\u9fff][^'"\r\n]*)\1/g)) {
      // Only localization calls; classifiers and website parsing remain outside this rule.
      const prefix = source.slice(Math.max(0, match.index - 16), match.index);
      if (/^(uiText|uiFormat)/.test(match[0]) || /PinmonyI18n\.$/.test(prefix)) report(match.index, 'Use a stable resource key instead of Chinese copy');
    }
    for (const match of source.matchAll(/(?:\b(?:label|title|error|feedback|subtitle)\s*:|\.(?:label|title|error|feedback|subtitle)\s*=)\s*(['"])([^'"\r\n]*[\u3400-\u9fff][^'"\r\n]*)\1/g)) {
      report(match.index, 'Local display state must store a resource marker rather than inline Chinese');
    }
    if (/[\\/](components|pages)[\\/]/.test(file)) {
      for (const match of source.matchAll(/\b(?:Text|Button|accessibilityText|accessibilityDescription)\(\s*(['"])([^'"\r\n]+)\1/g)) {
        if (/[\u3400-\u9fffA-Za-z]/.test(match[2]) && match[2] !== 'Pinmony' && match[2] !== 'www.pinterest.com/') report(match.index, 'Inline UI copy must use language resources');
      }
    }
  }
}
assert.equal(errors.length, 0, '\n' + errors.join('\n'));
console.log(`Language coverage: ${checked} source files; ${names.length} keys in all locales; resource references, placeholders and inline copy passed`);
