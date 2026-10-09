const fs = require('node:fs');

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/analyze-network-runtime.cjs <runtime-log>');
  process.exitCode = 2;
} else {
  const text = fs.readFileSync(file, 'utf8');
  const lifecycle = [];
  const lifecyclePattern = /NetworkTrace: lifecycle=(start|finish|cancel|invalidate|reject) generation=(\d+) pending=(\d+) jobs=(\d+) cancelled=(\d+)(?: label=([A-Za-z]+Resource\/(?:get|create|update|delete)|GraphQL) method=(GET|POST))?(?: status=(\d+) error=([a-z-]+))?(?: requestIdPresent=(true|false))?(?: pendingBefore=(\d+))?/g;
  let match;
  while ((match = lifecyclePattern.exec(text)) !== null) lifecycle.push({
    event: match[1], generation: Number(match[2]), pending: Number(match[3]), jobs: Number(match[4]),
    cancelled: Number(match[5]), label: match[6] || '', method: match[7] || '',
    status: match[8] ? Number(match[8]) : undefined, error: match[9] || '',
    pendingBefore: match[11] ? Number(match[11]) : undefined
  });
  const queue = [];
  const queuePattern = /NetworkTrace: queue-start priority=([A-Z]+) order=(\d+) active=(\d+) queued=(\d+) max=(\d+)/g;
  while ((match = queuePattern.exec(text)) !== null) queue.push({ active: Number(match[3]), max: Number(match[5]) });
  const starts = lifecycle.filter(item => item.event === 'start');
  const finishes = lifecycle.filter(item => item.event === 'finish');
  const invalidates = lifecycle.filter(item => item.event === 'invalidate');
  const maxPending = lifecycle.reduce((max, item) => Math.max(max, item.pending), 0);
  const maxActive = queue.reduce((max, item) => Math.max(max, item.active), 0);
  const checks = [
    ['pendingLimit', lifecycle.length > 0 && maxPending <= 12],
    ['schedulerLimit', queue.length === 0 || queue.every(item => item.active <= item.max && item.max <= 8)],
    ['invalidateZero', invalidates.length > 0 && invalidates.every(item => item.pending === 0 && item.jobs === 0)],
    ['finishObserved', finishes.length > 0],
    ['startObserved', starts.length > 0]
  ];
  console.log('NetworkTrace lifecycle=' + lifecycle.length + ' starts=' + starts.length +
    ' finishes=' + finishes.length + ' invalidates=' + invalidates.length +
    ' maxPending=' + maxPending + ' maxSchedulerActive=' + maxActive);
  if (lifecycle.length === 0) console.log('UNOBSERVED lifecycle events; install the rebuilt HAP and capture a fresh runtime log.');
  if (queue.length === 0) console.log('UNOBSERVED scheduler events in this log.');
  for (const [name, passed] of checks) console.log((passed ? 'PASS ' : 'UNOBSERVED/FAIL ') + name);
  if (lifecycle.length > 0 && (maxPending > 12 || !checks[1][1] || !checks[2][1])) process.exitCode = 1;
}
