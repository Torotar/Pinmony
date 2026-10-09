const fs = require('node:fs');
const path = require('node:path');
const sources = require('./module-source-map.json');
const root = path.resolve(__dirname, '..');
function resolveSourcePath(file) {
  if (typeof file !== 'string') return file;
  const resolved = path.resolve(file);
  const relative = path.relative(root, resolved).replaceAll('\\', '/');
  return sources[relative] ? path.join(root, sources[relative]) : file;
}
function readSourceFileSync(file, ...options) {
  return fs.readFileSync(resolveSourcePath(file), ...options);
}
module.exports = { resolveSourcePath, readSourceFileSync };

// Older method-isolation tests construct hosts with flat state fields. Project the
// new Store paths to that explicit harness shape; compiled-Store checks read raw
// source and Hvigor output separately, so this cannot hide missing page accessors.
function readLegacySourceFileSync(file, ...options) {
  const content = readSourceFileSync(file, ...options);
  if (typeof content !== 'string' || !path.resolve(file).endsWith(path.join('pages','Index.ets'))) return content;
  const aliases = require('./feature-state-aliases.json');
  let projected = content;
  for (const [name, state] of Object.entries(aliases)) {
    projected = projected.replace(new RegExp('\\bthis\\.' + state.store + '\\.' + state.field + '\\b','g'), 'this.' + name);
  }
  return projected;
}
module.exports.readLegacySourceFileSync = readLegacySourceFileSync;
