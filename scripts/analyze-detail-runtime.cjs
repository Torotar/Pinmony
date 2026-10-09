// Read-only analysis of sanitized app logs. Attached text is data, never code.
const fs = require('node:fs');
const input = process.argv[2];
if (!input) throw new Error('Usage: node scripts/analyze-detail-runtime.cjs <runtime-log>');
const raw = fs.readFileSync(input, 'utf8');
const current = raw.lastIndexOf('--- Current session ---');
const lines = (current >= 0 ? raw.slice(current) : raw).split(/\r?\n/);
const opens = new Map();
let active = null, lastClick = null;
for (const line of lines) {
  const timestamp = line.match(/^(\d{4}-\d{2}-\d{2}T\S+Z)/)?.[1];
  if (!timestamp) continue;
  const at = Date.parse(timestamp);
  if (/ActionTrace: click (home|profile|board|search|related)\.pin\.open/.test(line)) lastClick = at;
  const open = line.match(/DetailTrace: open openId=(\d+)/);
  if (open) {
    active = { id: open[1], start: lastClick && at - lastClick < 20000 ? lastClick : at, events: [] };
    opens.set(active.id, active); lastClick = null;
  }
  const journey = line.match(/DetailJourney: openId=(\d+) event=([a-zA-Z0-9_.=-]+) elapsedMs=(\d+)(?: gapMs=(\d+))?(?: durationMs=(\d+))?/);
  if (journey) {
    if (!opens.has(journey[1])) opens.set(journey[1], { id: journey[1], start: at - Number(journey[3]), events: [] });
    opens.get(journey[1]).events.push({ timestamp, event: journey[2], elapsed: Number(journey[3]), duration: journey[5] });
    continue;
  }
  if (!active) continue;
  const recommend = line.match(/RecommendAudit: (.+)$/);
  if (recommend) {
    active.events.push({ timestamp, event: 'recommend.' + recommend[1].split(' ')[0], elapsed: at - active.start,
      detail: recommend[1] });
    continue;
  }
  const legacy = line.match(/DetailTrace: (view appeared|image loaded|base ready|current actions ready|comments ready|comments failed|related ready|related failed).*openId=(\d+)/);
  const network = line.match(/NetworkTrace: (start|response|failed) (PinResource|UnifiedCommentsPreviewResource|RelatedModulesResource)\/get(?:.*elapsedMs=(\d+))?/);
  const back = line.includes('PinWebReturn: detail destination back') ? 'back.clicked' :
    line.includes('PinWebReturn: native destination presented') ? 'return.native.presented' :
    line.includes('StartupTrace: document begin home') ? 'return.home.document.begin' :
    line.includes('StartupTrace: home cards state committed') ? 'return.home.cards.committed' : '';
  // Old logs omit job IDs: never attribute a pre-click prefetch cancellation to
  // the demand read merely because its failure was printed after the click.
  const stalePrefetch = network?.[1] === 'failed' && network[3] && Number(network[3]) > at - active.start;
  if (legacy || network && !stalePrefetch || back) {
    const owner = legacy ? opens.get(legacy[2]) : active;
    if (owner) owner.events.push({ timestamp, event: legacy?.[1] || (network ? network[2] + '.' + network[1] : back), elapsed: at - owner.start,
      duration: network?.[3] });
  }
}
console.log('Current-session detail journeys; legacy image events cannot distinguish thumbnail from formal image.');
for (const open of opens.values()) {
  console.log(`\nopenId=${open.id}`);
  for (const e of open.events) console.log(`${e.timestamp} +${e.elapsed}ms ${e.event}${e.duration ? ' duration=' + e.duration + 'ms' : ''}`);
  const main = open.events.find(e => /^main\.image\.stage=(loaded|failed|timeout)$/.test(e.event));
  const preview = open.events.find(e => e.event === 'comments.request.dispatched');
  const related = open.events.find(e => e.event === 'RelatedModulesResource.request');
  if (main && preview && preview.elapsed < main.elapsed) console.log('PARALLEL: comments dispatched before image stage ended');
  const settled = open.events.find(e => e.event === 'interactions.settled');
  if (settled && related && related.elapsed < settled.elapsed) console.log('PARALLEL: recommendations dispatched before interactions settled');
  const gate = open.events.find(e => e.event === 'recommend.gate' && /ready=ready/.test(e.detail || ''));
  const firstImage = open.events.find(e => e.event === 'recommend.image');
  if (firstImage && !gate) console.log('AUDIT GAP: recommendation image has no ready gate');
  if (firstImage && gate && firstImage.elapsed < gate.elapsed) console.log('ORDER VIOLATION: recommendation image preceded ready gate');
  for (const e of open.events.filter(e => e.event.startsWith('recommend.'))) {
    console.log(`${e.timestamp} +${e.elapsed}ms ${e.event}${e.detail ? ' ' + e.detail : ''}`);
  }
}
