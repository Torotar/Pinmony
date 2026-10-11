const assert = require('node:assert/strict'), fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { spawnSync } = require('node:child_process');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'pinmony-identity-'));
function write(name, value) { const p = path.join(fixture, name); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, value); }
function run(check = false) {
  const p = spawnSync(process.execPath, [path.join(fixture, 'scripts/update-build-identity.cjs'), ...(check ? ['--check'] : [])], { encoding: 'utf8' });
  assert.equal(p.status, 0, p.stderr);
  return fs.readFileSync(path.join(fixture, 'entry/src/main/ets/app/PinmonyBuildIdentity.ets'), 'utf8');
}
try {
  write('scripts/update-build-identity.cjs', fs.readFileSync(path.join(__dirname, 'update-build-identity.cjs'), 'utf8'));
  write('AppScope/app.json5', '{"versionName":"test","versionCode":1,"buildVersion":1}');
  write('entry/src/main/ets/app/Main.ets', 'export const value = 1;');
  write('entry/src/main/resources/base/element/color.json', '{"color":[]}');
  const original = run();
  assert.equal(run(), original, 'generated identity must not hash itself');
  write('entry/src/main/resources/base/element/color.json', '{"color":[1]}');
  const resource = run();
  assert.notEqual(resource, original, 'resource-only changes must alter identity');
  write('entry/src/main/module.json5', '{"module":{"name":"entry"}}');
  const moduleIdentity = run();
  assert.notEqual(moduleIdentity, resource, 'module configuration must alter identity');
  write('AppScope/resources/base/media/icon.svg', '<svg/>');
  assert.notEqual(run(), moduleIdentity, 'AppScope resources must alter identity');
  run(true);
  console.log('Build identity: deterministic, resource/config changes and current check passed');
} finally { fs.rmSync(fixture, { recursive: true, force: true }); }
