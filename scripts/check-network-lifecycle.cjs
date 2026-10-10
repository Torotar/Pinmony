const assert = require('node:assert/strict');
const fs = require('node:fs');

const source = fs.readFileSync('common_network/src/main/ets/PinmonyNativeNetwork.ets', 'utf8');
const notes = fs.readFileSync('docs/NATIVE_NETWORK_NOTES.md', 'utf8');
const architecture = fs.readFileSync('docs/ARCHITECTURE.md', 'utf8');
assert(source.includes('private audit(event: string'), 'network lifecycle audit helper exists');
for (const event of ['start', 'finish', 'cancel', 'invalidate', 'reject']) {
  assert(source.includes("this.audit('" + event + "'"), 'network lifecycle event is emitted: ' + event);
}
assert(source.includes('pendingBefore='), 'invalidate records pending count before cleanup');
assert(source.includes('this.pending.size >= 12'), 'network coordinator has a 12-request bound');
assert(source.includes('new RequestScheduler(8)'), 'scheduler has an 8-task bound');
assert(source.includes("method=' + job.method"), 'request method is included in bounded audit data');
assert(notes.includes('NetworkTrace: lifecycle='), 'network notes document lifecycle audit');
assert(architecture.includes('## 网络请求与并发生命周期'), 'architecture documents network lifecycle');
console.log('Network request lifecycle, concurrency bounds, cancellation audit, and documentation checks passed');
