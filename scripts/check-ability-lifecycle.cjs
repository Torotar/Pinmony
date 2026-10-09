const assert = require('node:assert/strict');
const fs = require('node:fs');

const source = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
for (const event of ['create-start', 'create-complete', 'window-stage-create', 'content-load-start',
  'content-load-complete', 'content-load-failed', 'foreground', 'background', 'window-stage-destroy',
  'destroy-start', 'destroy-complete', 'configuration-update']) {
  assert(source.includes("logLifecycle('" + event + "'"), 'lifecycle event is logged: ' + event);
}
assert(source.includes('sinceStartMs='), 'lifecycle startup timing is logged');
assert(source.includes('sincePreviousMs='), 'lifecycle interval is logged');
assert(source.includes('windowStage='), 'window stage state is logged');
assert(source.includes('content='), 'content state is logged');
assert(source.includes('NetworkManager.destroy()'), 'ability destroy closes shared network session');
assert(source.includes("this.mainWindow?.off('avoidAreaChange')"), 'window avoid-area listener is removed');
assert(source.includes("this.logLifecycle('content-load-start'"), 'content load start uses lifecycle logger');
assert(source.includes("this.logLifecycle('content-load-complete'"), 'content load completion uses lifecycle logger');
assert(source.includes("this.logLifecycle('window-stage-destroy'"), 'window stage destroy uses lifecycle logger');
assert(source.includes("this.logLifecycle('destroy-start'"), 'ability destroy start uses lifecycle logger');
assert(source.includes("this.logLifecycle('destroy-complete'"), 'ability destroy completion uses lifecycle logger');
console.log('Ability lifecycle logging, window cleanup, content timing, and destroy ownership checks passed');
