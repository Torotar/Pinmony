const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const runtime = require('./search-controller-harness.cjs').createSearchRuntime(ts);
async function main() {
  const h = runtime.harness(), host = h.controller, page = 'https://www.pinterest.com/search/';
  h.setPage(page);
  const topic = (id, q) => ({ id, actionId: id, title: '角色插画', eyebrow: '热门',
    targetUrl: 'https://www.pinterest.com/search/pins/?q=' + q,
    items: [{ id: id + '-0', title: '角色插画', imageUrl: 'https://i.pinimg.com/a.jpg',
      targetUrl: 'https://www.pinterest.com/search/pins/?q=' + q, enabled: true }] });
  let sections = host.mergeSearchIdeaSections([], [topic('first', 'art')]);
  assert.equal(sections[0].targetUrl, topic('first', 'art').targetUrl);
  assert.equal(host.mergeSearchIdeaSections(sections, [])[0].targetUrl, sections[0].targetUrl);
  const lastTarget = () => h.events.filter(e => e[0] === 'search').at(-1)[1];
  for (const next of [sections, host.mergeSearchIdeaSections(sections, [topic('updated', 'new')])]) {
    h.store.search = { pageKey: page, discoveryApi: true, ideaSections: next };
    await host.performSearchAction(next[0].actionId, 'ideaSection');
    assert.equal(lastTarget(), next[0].targetUrl);
    await host.performSearchAction(next[0].items[0].id, 'idea');
    assert.equal(lastTarget(), next[0].targetUrl);
  }
  h.setActive(false); const count = h.events.length;
  await host.performSearchAction('updated', 'ideaSection');
  assert.equal(h.events.length, count);
  h.setActive(true);
  const retained = topic('retained', 'cached'); delete retained.targetUrl;
  h.store.search = { pageKey: page, discoveryApi: true, ideaSections: [retained] };
  await host.performSearchAction('retained', 'ideaSection');
  assert.equal(lastTarget(), retained.items[0].targetUrl);
  h.store.search = { kind: 'state', pageKey: page, api: true, categories: [{ id: 'guide', enabled: true,
    targetUrl: 'https://www.pinterest.com/search/pins/?q=character%20art' }] };
  await host.performSearchAction('guide', 'category');
  assert.equal(lastTarget(), h.store.search.categories[0].targetUrl);
  const beforeGuide = h.events.length; h.setActive(false);
  await host.performSearchAction('guide', 'category');
  assert.equal(h.events.length, beforeGuide, 'signed-out guides cannot navigate');
  h.setActive(true); h.store.search.categories[0].targetUrl = 'https://untrusted.example/search/pins/?q=x';
  await host.performSearchAction('guide', 'category');
  assert.equal(h.events.length, beforeGuide, 'foreign guide URL is rejected');
  host.invalidatePending();
  console.log('Topic URL retention, refreshed actions, section/card navigation and stale-page rejection passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
