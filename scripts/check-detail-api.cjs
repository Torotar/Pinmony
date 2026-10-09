const { readLegacySourceFileSync: readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = readSourceFileSync('entry/src/main/ets/services/PinWebDetailApiScript.ets', 'utf8');
const script = Function('return `' + source.match(/= `([\s\S]*?)`;/)[1] + '`')();
new Function(script);
const requests = [];
const window = { PinWebDetailApiEnabled: true }; window.top = window;
vm.runInNewContext(script, { window, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com' },
  AbortController, setTimeout, clearTimeout, console: { warn() {} },
  fetch: (url, options) => new Promise(resolve => requests.push({ url, options, resolve })) });
const api = window.PinWebDetailApi;
const pin = id => ({ id, type: 'pin', title: '', images: { '474x': { url: 'https://i.pinimg.com/test.jpg', width: 474, height: 700 } } });
const flush = () => new Promise(resolve => setImmediate(resolve));
async function respond(index, data, bookmark = '') {
  requests[index].resolve({ ok: true, json: async () => ({ resource_response: { status: 'success', data, bookmark } }) });
  await flush();
}
async function main() {
  const url = 'https://www.pinterest.com/pin/123/';
  const read = () => api.read(url, () => {}, () => true);
  const release = () => { api.settleImage(url, pin('123').images['474x'].url, 'loaded'); api.settleInteractions(url); };
  read(); read(); assert.equal(requests.length, 1);
  assert.equal(requests[0].options.credentials, 'same-origin');
  assert.equal(requests[0].options.headers.Cookie, undefined);
  assert.match(requests[0].url, /PinResource\/get/);
  await respond(0, pin('123'));
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(requests.length, 2, 'Detail completion starts related content without waiting for interactions');
  assert.match(requests[1].url, /RelatedModulesResource\/get/);
  assert.equal(api.startRelated('https://www.pinterest.com/pin/999/'), false);
  assert.equal(api.startRelated(url), false, 'related request is deduplicated after automatic scheduling');
  api.settleImage(url, pin('123').images['474x'].url, 'timeout');
  assert.equal(read().imageLoaded,false);
  release();
  assert.equal(read().imageLoaded,true,'late current image load upgrades timeout to loaded');
  assert.equal(api.startRelated(url), false);
  await respond(1, [pin('456'), pin('456'), pin('123')], 'next');
  assert.equal(read().detail.id, '123'); assert.equal(read().related.length, 1);
  assert.equal(read().related[0].id, 'api:456');
  assert.equal(api.relatedUrl('api:456'), 'https://www.pinterest.com/pin/456/');
  api.loadMore(); api.loadMore(); assert.equal(requests.length, 3);
  const data = JSON.parse(new URL(requests[2].url, url).searchParams.get('data'));
  assert.equal(data.options.bookmarks[0], 'next');
  await respond(2, [pin('789')], '-end-'); assert.equal(read().related.length, 2);
  api.loadMore(); assert.equal(requests.length, 3);
  api.reset(); read(); api.reset();
  await respond(3, pin('123'));
  assert.equal(api.relatedUrl('api:456'), '');
  read();
  requests[4].resolve({ ok: false, status: 503 });
  await flush();
  assert.ok(read().detailError); assert.equal(read().detail, null);
  api.retry(); assert.equal(requests.length, 6);
  await respond(5, pin('123')); await new Promise(resolve => setTimeout(resolve, 0));
  release(); api.startRelated(url);
  requests[6].resolve({ ok: true, json: async () => { throw new Error('HTML instead of JSON'); } });
  await flush();
  assert.ok(read().relatedError);
  api.retry(); assert.equal(requests.length, 8);
  await respond(7, [], '-end-');
  assert.equal(read().detailError, ''); assert.equal(read().relatedError, '');
  assert.equal(read().ended, true); assert.equal(read().related.length, 0);
  api.reset(); const videoRequest = requests.length; read();
  await respond(videoRequest, { ...pin('123'), is_video: true }); await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(api.startRelated(url), false);
  assert.equal(read().mediaUnsupported, true); assert.equal(read().detail, null);
  api.retry(); assert.equal(requests.length, videoRequest + 2);
  api.reset();
  for (const media of [{ carousel_data: {}, story_pin_data: {} }, { carousel_data: [], story_pin_data: [] },
      { is_video: false, carousel_data: null, story_pin_data: null },
      { story_pin_data: { pages: [{ blocks: [{ block_type: 2 }] }] } },
      { story_pin_data: { pages: [{ blocks: [{ __typename: 'StoryPinImageBlock', blockType: 2 }] }] } },
      { carousel_data: { __typename: 'Carousel', carousel_slots: [] },
        story_pin_data: { __typename: 'Story', pages: [], page_count: 0 },
        videos: { __typename: 'Videos', video_list: {} } }]) {
    const next = requests.length;
    read(); await respond(next, { ...pin('123'), ...media }); release(); api.startRelated(url); await respond(next + 1, []);
    assert.equal(read().mediaUnsupported, false, 'Empty media metadata must not reject an image Pin');
    assert.equal(read().detail.id, '123'); api.reset();
  }
  for (const media of [{ is_video: true, images: {} }, { carousel_data: { carousel_slots: [{ id: '1' }] } },
      { story_pin_data: { pages: [{ id: '1' }] } },
      { story_pin_data: { pages: [{ blocks: [{ block_type: 2 }, { block_type: 1 }] }] } },
      { story_pin_data: { pages: [{ blocks: [{ block_type: 2 }] }, { blocks: [{ block_type: 2 }] }] } },
      { story_pin_data: { pages: [{ blocks: [{ block_type: 3 }] }] } }]) {
    const next = requests.length;
    read(); await respond(next, { ...pin('123'), ...media }); assert.equal(api.startRelated(url), false);
    assert.equal(read().mediaUnsupported, true);
    assert.match(read().detailError, /暂不支持/);
    assert.equal(read().detail, null, 'Do not present a video cover as the full post'); api.reset();
  }
  const bridgeSource = readSourceFileSync('entry/src/main/ets/services/PinWebDetailScript.ets', 'utf8');
  const bridge = Function('return `' + bridgeSource.match(/= `([\s\S]*?)`;/)[1] + '`')();
  new Function(bridge);
  const dispatch = bridge.slice(bridge.indexOf('    notify(snapshot(pin));'), bridge.indexOf('  function schedule()'));
  const phases = [];
  let previewLoading = true;
  let imageReady = false;
  const dispatchContext = { pin: url, schedule() {}, notify: () => phases.push('detail'), snapshot: () => ({}), window: {
    PinWebDetailApiEnabled: true,
    PinWebDetailApi: { raw: () => ({}), read: () => ({ imageStageReady: imageReady }),
      settleInteractions: () => phases.push('settled'), scheduleRelated: () => phases.push('related') },
    PinWebPostApi: { previewRead: (_pin, readOnly) => { if (!readOnly) phases.push('preview'); return { loading: previewLoading }; } }
  } };
  vm.runInNewContext('function dispatch() {' + dispatch + '; dispatch();', dispatchContext);
  assert.deepEqual(phases, ['detail', 'preview', 'related'], 'Verified Pin starts preview and related reads before image completion');
  imageReady = true; phases.length = 0;
  vm.runInNewContext('dispatch();', dispatchContext);
  assert.deepEqual(phases, ['detail', 'preview', 'related'], 'Loading preview does not hold recommendations');
  previewLoading = false; phases.length = 0;
  imageReady = false;
  vm.runInNewContext('dispatch();', dispatchContext);
  assert.deepEqual(phases, ['detail', 'preview', 'related', 'settled', 'related']);
  dispatchContext.window.PinWebDetailApi.raw = () => null; phases.length = 0;
  vm.runInNewContext('dispatch();', dispatchContext);
  assert.deepEqual(phases, ['detail'], 'Missing or stale detail must not start secondary requests');
  const snapshotBody = bridge.match(/function apiSnapshot\(pin\) \{([\s\S]*?)\n  function snapshot\(pin\)/)[1];
  const pendingContext = { window: {}, session: 4, schedule() {} };
  vm.runInNewContext('function apiSnapshot(pin) {' + snapshotBody, pendingContext);
  assert.equal(pendingContext.apiSnapshot(url).kind, 'apiPending');
  assert.equal(pendingContext.apiSnapshot(url).retryable, false);
  assert.match(bridge, /if \(window.PinWebDetailApiEnabled === true\) return apiSnapshot\(pin\)/);
  window.PinWebDetailApiEnabled = false;
  const disabled = { window, location: { hostname: 'www.pinterest.com', origin: 'https://www.pinterest.com' } };
  vm.runInNewContext(script, disabled);
  assert.equal(window.PinWebDetailApi.read(url), null);
  console.log('detail API mapping, pagination, stale guards, failure retry, unsupported media and no DOM fallback OK');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
