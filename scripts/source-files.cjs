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
