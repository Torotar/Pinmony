const fs = require('node:fs');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const files = cp.execFileSync('rg', ['-l', '\\.bindSheet\\(', 'entry', 'common_ui',
  'feature_board', 'feature_profile', 'feature_search', 'feature_inbox', 'feature_pin',
  'feature_settings', '-g', '*.ets'], { encoding: 'utf8' }).trim().split(/\r?\n/);
let count = 0;
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  const root = file.replaceAll('\\', '/').startsWith('entry/');
  if (!root) assert.match(source, /@StorageProp\('pinmonySheetWindowWidthVp'\)/, file);
  for (const match of source.matchAll(/\.bindSheet\([^\n]*?\{/g)) {
    const options = source.slice(match.index, match.index + 450);
    const expression = options.match(/preferType:\s*([^,\n]+(?:\n[^,]+)?),/);
    assert(expression, `${file}: every sheet needs an explicit wide-window policy`);
    const policy = expression[1];
    const widthName = root ? 'nativeSheetWindowWidth' : 'sheetWindowWidthVp';
    assert(policy.startsWith(`this.${widthName} >= 600 ? SheetType.CENTER :`), file);
    // Evaluate the actual source policy across the breakpoint and after shrinking again.
    const resolve = new Function('SheetType', `return (${policy});`);
    for (const width of [0, 599, 600, 840, 1280, 599]) {
      const type = resolve.call({ [widthName]: width, activeSheetKind: 'more' },
        { CENTER: 'center', BOTTOM: 'bottom' });
      assert.equal(type, width >= 600 ? 'center' :
        (policy.includes(': SheetType.BOTTOM') ? 'bottom' : undefined), file);
    }
    count++;
  }
}
const root = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
assert.match(root, /AppStorage\.setOrCreate<number>\('pinmonySheetWindowWidthVp', width\)/);
assert.equal(count, 18, 'Audit every added or removed sheet entry');
console.log(`Wide-window sheets: ${count} entries, breakpoint, shrink-back and shared width binding passed; device geometry excluded.`);
