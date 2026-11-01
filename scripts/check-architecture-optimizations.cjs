const fs = require('node:fs'), path = require('node:path'), { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
function resolveTypeScript() {
  const supplied = process.argv.slice(2).find(arg => !arg.startsWith('--'));
  if (supplied) return require.resolve(supplied, { paths: [root, process.cwd()] });
  try { return require.resolve('typescript', { paths: [root] }); } catch (_) {}
  const candidates = [];
  if (process.env.DEVECO_SDK_HOME) candidates.push(path.join(process.env.DEVECO_SDK_HOME,
    'default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
  for (const value of [process.env.DEVECO_STUDIO_PATH, process.env['DevEco Studio']]) {
    if (!value) continue;
    const installation = value.replace(/;+$/, '').replace(/[\\/]bin[\\/]?$/i, '');
    candidates.push(path.join(installation, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
  }
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return require.resolve(candidate);
  }
  throw Error('TypeScript not found. Pass its module path, or set DEVECO_STUDIO_PATH / DEVECO_SDK_HOME.');
}
try {
  const ts = resolveTypeScript();
  const checks = ['check-log-performance-followup.cjs', 'check-official-action-notices.cjs', 'check-profile-hub.cjs', 'check-startup.cjs', 'check-global-performance.cjs', 'check-native-detail-reads.cjs', 'check-page-performance.cjs',
    'check-native-search-reads.cjs', 'check-native-search-discovery.cjs', 'check-search-quiz-presentation.cjs',
    'check-home-return-timing.cjs', 'check-board-section-scroll.cjs', 'check-native-feature-gates.cjs', 'check-cache-invalidation.cjs', 'check-cache-age.cjs',
    'check-cache-consistency.cjs', 'check-home-disk-cache.cjs', 'check-native-home-reads.cjs',
    'check-home-feature-isolation.cjs', 'check-native-request-boundaries.cjs',
    'check-home-refresh-visibility.cjs', 'check-home-first-paint.cjs', 'check-native-entry-isolation.cjs',
    'check-native-cleanup-isolation.cjs',
    'check-search-photo-menu.cjs', 'check-runtime-error-diagnostics.cjs', 'check-runtime-log.cjs', 'check-home-pagination-trace.cjs',
    'check-native-profile-reads.cjs', 'check-native-post-button-flows.cjs',
    'check-native-pin-menus.cjs', 'check-native-profile-settings.cjs', 'check-native-share-publish.cjs',
    'check-native-board-aux.cjs', 'check-board-collaborators.cjs', 'check-native-board-collaborator-writes.cjs',
    'check-board-section-navigation.cjs', 'check-profile-organize.cjs', 'check-board-cover.cjs',
    'check-board-card-refresh.cjs', 'check-board-refresh-intent.cjs', 'check-profile-pin-return.cjs',
    'check-recommendation-boards.cjs', 'check-board-edit-initial-values.cjs',
    'check-shuffle-presentation.cjs', 'check-shuffle-flight-lifecycle.cjs',
    'check-flow-title-blur.cjs', 'check-loading-regressions.cjs', 'check-snackbar-back.cjs', 'check-card-layout-motion.cjs',
    'check-root-page-retention.cjs', 'check-secondary-root-context.cjs', 'check-controller-lifecycle.cjs', 'check-logout-api.cjs',
    'check-business-lifecycle.cjs', 'check-session-startup.cjs', 'check-detached-session.cjs',
    'check-native-navigation-completion.cjs', 'check-foundation-architecture.cjs',
    'check-module-architecture.cjs', 'check-page-state-architecture.cjs',
    'check-language-coverage.cjs', 'check-language.cjs'].map(file => ({ file, args: [ts] }));
  if (process.argv.includes('--compiled')) checks.push({ file: 'check-compiled-store-access.cjs', args: ['debug'] });
  let failures = 0;
  for (const check of checks) {
    const result = spawnSync(process.execPath, [path.join(__dirname, check.file), ...check.args], {
      cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024
    });
    const passed = !result.error && result.status === 0;
    console.log((passed ? 'PASS ' : 'FAIL ') + check.file);
    if (!passed) {
      failures++;
      process.stderr.write(result.stderr || result.stdout || String(result.error || result.signal || result.status));
    }
  }
  console.log('Architecture optimization checks: ' + (checks.length - failures) + ' passed, ' + failures + ' failed.');
  process.exitCode = failures ? 1 : 0;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
