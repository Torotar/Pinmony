const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
function option(name) {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  if (!args[i + 1] || args[i + 1].startsWith('--')) throw Error('Missing value for ' + name);
  return args[i + 1];
}
if (args.includes('--help')) {
  console.log('node scripts/run-checks.cjs [--typescript MODULE_PATH] [--filter NAME] [--compiled] [--report FILE]\n--compiled includes compiled Store checks; build entry HAP first. Checks do not prove device or online behavior.');
  process.exit(0);
}
const ts = option('--typescript') || process.env.PINMONY_TYPESCRIPT;
const filter = option('--filter');
const report = option('--report');
const compiled = args.includes('--compiled');
const compiledChecks = new Set(['check-compiled-store-access.cjs', 'check-index-composition.cjs']);
const files = fs.readdirSync(__dirname).filter(n => /^check-.*\.cjs$/.test(n) &&
  (compiled || !compiledChecks.has(n)) && (!filter || n.includes(filter))).sort();
if (!files.length) throw Error('No checks matched');
const results = [];
for (const file of files) {
  const started = Date.now();
  const argv = [path.join(__dirname, file)];
  if (file === 'check-compiled-store-access.cjs') argv.push('debug');
  else if (ts && /require\s*\(\s*process\.argv\[2\]/.test(fs.readFileSync(path.join(__dirname, file), 'utf8'))) argv.push(ts);
  const child = spawnSync(process.execPath, argv, { cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
  const passed = !child.error && child.status === 0;
  results.push({ file, kind: compiledChecks.has(file) ? 'compiled' : 'local', passed, durationMs: Date.now() - started });
  console.log((passed ? 'PASS ' : 'FAIL ') + file + ' ' + results.at(-1).durationMs + 'ms');
  if (!passed) process.stderr.write(child.error ? child.error.message + '\n' : child.stdout + child.stderr);
}
if (report) fs.writeFileSync(path.resolve(root, report), JSON.stringify({ deviceVerified: false, onlineVerified: false, results }, null, 2) + '\n');
const failed = results.filter(r => !r.passed).length;
console.log('Checks: ' + (results.length - failed) + ' passed, ' + failed + ' failed. Device and online verification excluded.');
process.exitCode = failed ? 1 : 0;
