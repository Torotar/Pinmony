const fs = require('node:fs');

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/analyze-page-lifecycle.cjs <runtime-log>');
  process.exitCode = 2;
} else {
  const text = fs.readFileSync(file, 'utf8');
  const pattern = /PageLifecycle: event=([a-z-]+) sequence=(\d+) sinceStartMs=(-?\d+) sincePreviousMs=(-?\d+) activeTab=(\d+) rootVisible=(true|false) sheet=(open|closed) detail=(true|false) inboxFlow=(true|false) profileFlow=(true|false)/g;
  const events = [];
  let match;
  while ((match = pattern.exec(text)) !== null) {
    events.push({
      event: match[1], sequence: Number(match[2]), sinceStartMs: Number(match[3]),
      sincePreviousMs: Number(match[4]), activeTab: Number(match[5]), rootVisible: match[6] === 'true',
      sheet: match[7] === 'open', detail: match[8] === 'true', inboxFlow: match[9] === 'true', profileFlow: match[10] === 'true'
    });
  }
  if (events.length === 0) {
    console.error('No PageLifecycle events found; capture a fresh runtime log after installing the rebuilt HAP.');
    process.exitCode = 2;
  } else {
    const sequenceGaps = [];
    const negativeIntervals = [];
    for (let i = 1; i < events.length; i++) {
      if (events[i].sequence !== events[i - 1].sequence + 1) sequenceGaps.push([events[i - 1].sequence, events[i].sequence]);
      if (events[i].sincePreviousMs < 0) negativeIntervals.push(events[i].sequence);
    }
    const counts = new Map();
    const tabs = new Set();
    let hidden = 0;
    let maxGap = 0;
    for (const item of events) {
      counts.set(item.event, (counts.get(item.event) || 0) + 1);
      tabs.add(item.activeTab);
      if (!item.rootVisible) hidden++;
      maxGap = Math.max(maxGap, item.sincePreviousMs);
    }
    const expected = ['about-to-appear', 'page-show', 'root-tabs-appear'];
    let expectedIndex = 0;
    for (const item of events) if (item.event === expected[expectedIndex]) expectedIndex++;
    const checks = [
      ['sequence-contiguous', sequenceGaps.length === 0],
      ['intervals-nonnegative', negativeIntervals.length === 0],
      ['startup-order', expectedIndex === expected.length],
      ['root-tab-observed', tabs.size > 0],
      ['secondary-depth-observed', hidden > 0]
    ];
    console.log('PageLifecycle events=' + events.length +
      ' firstSequence=' + events[0].sequence + ' lastSequence=' + events[events.length - 1].sequence +
      ' maxSincePreviousMs=' + maxGap + ' activeTabs=' + Array.from(tabs).sort().join(',') +
      ' rootHiddenEvents=' + hidden);
    console.log('Event counts: ' + Array.from(counts.entries()).map(([name, count]) => name + '=' + count).join(' '));
    for (const [name, passed] of checks) console.log((passed ? 'PASS ' : 'FAIL ') + name);
    if (sequenceGaps.length || negativeIntervals.length || expectedIndex !== expected.length) process.exitCode = 1;
  }
}
