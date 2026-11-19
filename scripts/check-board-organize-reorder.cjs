const assert = require('node:assert/strict');
const fs = require('node:fs');
const { runtime } = require('./product-coordination-harness.cjs');
const ts = require(process.argv[2] || 'typescript');
const loader = runtime(ts);
const { PinmonyBoardNativeReads } = loader.loadFile('entry/src/main/ets/app/PinmonyBoardNativeReads.ets');
const { PinmonyBoardNetwork } = loader.loadFile('feature_board/src/main/ets/services/PinmonyBoardNetwork.ets');
const { acceptsNetworkJob } = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const origin = 'https://uk.pinterest.com', page = origin + '/sample/board/';
const reply = (kind, viewer = '42', code = 0) => ({ status: 200, body: JSON.stringify({ client_context: { user: { id: viewer } }, resource_response: {
  status: 'success', code, data: null, endpoint_name: kind === 'pin' ? 'v3_board_reorder_pin_handler' : 'v3_reorder_section' } }) });
function fixture() {
  let session = { authenticated: true, accountId: 'synthetic', generation: 1, origin, userAgent: 'synthetic' };
  const jobs = [], cancelled = [];
  const transport = { request(job, context) {
    assert(acceptsNetworkJob(job, context()));
    return new Promise(resolve => jobs.push({ job, context, resolve }));
  } };
  const network = new PinmonyBoardNetwork(transport);
  network.cancel = id => cancelled.push(id);
  const reader = Object.create(PinmonyBoardNativeReads.prototype);
  const flow = { ...reader.emptyFlow(), phase: 'select', busy: false };
  Object.assign(reader, { page, origin, generation: 1, account: 'synthetic', viewer: '42', verified: true, ready: true,
    board: { id: '100', owner: { id: '42' } }, flow, revision: 3, flowEpoch: 4, version: 5, sequence: 0,
    sectionsReady: true, pins: ['11','12','13','14'].map(id => ({ id })), sections: ['21','22','23'].map(id => ({ id })),
    requests: new Set(), sectionRequests: new Set(), flowRequests: new Set(), collabRequests: new Set(),
    store: { boardDetail: { pageKey: page, nativeVersion: 5, flow } },
    ports: { active: () => true, session: () => session, network: () => network, committed() {}, install() {} },
    installScript: () => '', cursor: 'synthetic-next', refreshCalls: 0, async refresh() { this.refreshCalls++; } });
  for (const field of ['follow','section','content','management','pin','collaborator']) reader[field + 'Writes'] = { pause() {}, busy: () => false };
  reader.apply();
  const send = (kind, moved, target, revision = reader.version) => reader.handle('flow', JSON.stringify({ action: 'organizerReorder', value: JSON.stringify({ kind, moved, target, revision }) }));
  return { reader, jobs, cancelled, flow, send, switchSession: () => session = { ...session, generation: 2 } };
}
const data = row => {
  assert.equal(row.job.url, origin + '/resource/ApiResource/create/');
  assert.equal(row.job.method, 'POST');
  const form = new URLSearchParams(row.job.body);
  assert.equal(form.get('source_url'), '/sample/board/');
  assert.equal(row.job.headers['X-Pinterest-Pws-Handler'], 'www/[username]/[slug].js');
  return JSON.parse(form.get('data')).options;
};
const order = (f, kind) => Array.from(kind === 'pin' ? f.reader.pins : f.reader.sections, x => x.id);
async function main() {
  const f = fixture();
  const pending = f.send('pin', '13', '11');
  assert(f.flow.busy);
  assert.deepEqual(order(f,'pin'), ['11','12','13','14']);
  assert.deepEqual(data(f.jobs[0]), { url: '/v3/boards/100/reorder_pin/', data: { pin: '13', after_pin: '11' } });
  await f.send('pin', '14', '11');
  assert.equal(f.jobs.length, 1);
  f.jobs[0].resolve(reply('pin')); await pending;
  assert.deepEqual(order(f,'pin'), ['13','11','12','14']);
  assert.deepEqual(Array.from(f.reader.store.boardDetail.pins, x => x.id), ['13','11','12','14']);
  const second = f.send('pin','14','11');
  assert.deepEqual(data(f.jobs[1]).data, { pin: '14', before_pin: '13', after_pin: '11' });
  f.jobs[1].resolve(reply('pin')); await second;
  assert.deepEqual(order(f,'pin'), ['13','14','11','12']);
  const section = f.send('section','21','23');
  assert.deepEqual(data(f.jobs[2]), { url: '/v3/board/sections/21/reorder/', data: { section_before: '23' } });
  f.jobs[2].resolve(reply('section')); await section;
  assert.deepEqual(order(f,'section'), ['22','23','21']);
  for (const [kind,moved,target,ver] of [['pin','13','21'], ['pin','11','11'],['pin','11','12',1],['pin','unknown','12']]) await f.send(kind,moved,target,ver);
  assert.equal(f.jobs.length,3);
  await f.reader.auxiliaryAction({ action: 'close' });
  const returned = f.reader.store.boardDetail;
  assert.equal(returned.flow.phase, '');
  assert.deepEqual(Array.from(returned.pins, x => x.id), ['13','14','11','12']);
  assert.deepEqual(Array.from(returned.sections, x => x.id), ['22','23','21']);
  assert.equal(f.reader.refreshCalls, 0, 'closing preserves the confirmed order instead of doing an immediate read');
  await f.reader.more();
  assert.equal(f.reader.refreshCalls, 1, 'next page revalidates instead of appending with the stale cursor');
  const denied = fixture(); denied.reader.board.owner.id = '99';
  await denied.send('pin','13','11'); assert.equal(denied.jobs.length,0);
  const withinSection = fixture(); withinSection.flow.sectionId = '21';
  await withinSection.send('pin','13','11'); assert.equal(withinSection.jobs.length,0);
  const failure = fixture(), failed = failure.send('pin','13','11');
  failure.jobs[0].resolve(reply('pin','99')); await failed;
  assert(failure.flow.uncertain && !failure.flow.busy);
  assert.deepEqual(order(failure,'pin'), ['11','12','13','14']);
  await failure.send('pin','13','11'); assert.equal(failure.jobs.length,1);
  await failure.reader.auxiliaryAction({ action: 'close' });
  assert.equal(failure.reader.refreshCalls, 1, 'uncertain writes still trigger a read on close');
  const stale = fixture(), delayed = stale.send('pin','13','11');
  stale.switchSession(); assert.equal(stale.jobs[0].context().authenticated,false);
  stale.reader.pause(); assert.deepEqual(stale.cancelled,[stale.jobs[0].job.id]);
  stale.jobs[0].resolve(reply('pin')); await delayed;
  assert.deepEqual(order(stale,'pin'), ['11','12','13','14']);
  const view = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
  assert.match(view,/organizerReorderEnabled\('pin'\)\) \{ this.organizerHandle\('pin', pin.id\)/);
  const sectionView = view.slice(view.indexOf('private organizerSection('), view.indexOf('private organizeSelection('));
  assert.match(sectionView, /Text\(section\.title\)[\s\S]*?Text\(section\.pinCount/);
  assert.match(sectionView,/act\('section', section.id\)/);
  assert.match(view, /ForEach\(this\.organizerLaneIndexes\(\), \(lane: number\) => \{[\s\S]*?ForEach\(this\.organizerPinsByLane\[lane\]/);
  assert.match(view, /private snapshotChanged\(\): void \{\s*this\.updateOrganizerPinColumns\(\)/);
  const laneMethods = view.slice(view.indexOf('  private updateOrganizerPinColumns('), view.indexOf('  private cardMediaBadge(')).replace(/\s*@Builder\s*$/, '');
  const Lanes = require('node:vm').runInNewContext(ts.transpileModule(`class Lanes { ${laneMethods} } Lanes;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText);
  const lanes = new Lanes();
  let list = ['11','12','13','14'].map(id => ({ id, imageWidth: 100, imageHeight: 100 }));
  Object.assign(lanes, { selectingPins: () => true, selectionPins: () => list, selectionColumns: () => 3, contentWidth: 360 });
  const laneIds = () => Array.from(lanes.organizerPinsByLane, lane => Array.from(lane, pin => pin.id));
  lanes.updateOrganizerPinColumns();
  assert.deepEqual(laneIds(), [['11','14'], ['12'], ['13']]);
  list = Array.from(returned.pins, pin => ({ ...pin, imageWidth: 100, imageHeight: 100 }));
  lanes.updateOrganizerPinColumns();
  assert.deepEqual(laneIds(), [['13','12'], ['14'], ['11']]);
  assert(!view.includes('organizerTileColumns'));
  assert.match(view, /GridCol\(\) \{ this\.organizerSection\(section\) \}[\s\S]*?ForEach\(this\.organizerLaneIndexes\(\)/);
  assert.match(view, /const count: number = this\.selectionColumns\(\)/);
  assert.match(view, /priorityGesture\(PanGesture[\s\S]*?this\.updateOrganizerDrop\(finger\.globalX, finger\.globalY/);
  assert.match(view, /\.translate\(this\.organizerTranslation\('pin', pin\.id,[\s\S]*?this\.organizerPreviewOffsets\)\)\s*\}\.[^\n]*\.id\(this\.organizerCardId/);
  assert.match(view, /organizerHandlePressed[\s\S]*?recognizer instanceof PanRecognizer && recognizer\.isBuiltIn\(\) \? GestureJudgeResult\.REJECT/);
  const methods = view.slice(view.indexOf('  private updateOrganizerDrop('), view.indexOf('  private finishOrganizerDrag()'));
  const Preview = require('node:vm').runInNewContext(ts.transpileModule(`class Preview { ${methods} } Preview;`,
    { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, { Curve: { EaseOut: 0 } });
  const preview = new Preview(), animations = [];
  const slots = { '11': { x: 0, y: 0 }, '12': { x: 100, y: 0 }, '13': { x: 0, y: 160 } };
  Object.assign(preview, { organizerDragId: '11', organizerDragKind: 'pin', organizerDropId: '', organizerDragX: 30, organizerDragY: 20,
    organizerPreviewOffsets: new Map(), snapshot: { pins: Object.keys(slots).map(id => ({ id })) }, organizerCardId: (_kind, id) => id,
    organizerScrollId: () => 'host', selectedIds: [], titleContentInset: () => 0,
    getUIContext: () => ({ px2vp: n => n, vp2px: n => n, animateTo: (options, apply) => { animations.push(options.duration); apply(); },
      getComponentUtils: () => ({ getRectangleById: id => id === 'host' ? { size: { width: 300, height: 400 }, windowOffset: { x: 0, y: 0 } } :
        { size: { width: 80, height: 80 }, windowOffset: slots[id] } }) }) });
  const translation = (id, kind = 'pin') => { const { x, y } = preview.organizerTranslation(kind, id, preview.organizerDragKind, preview.organizerDragId, preview.organizerDragX, preview.organizerDragY, preview.organizerPreviewOffsets); return [x, y]; };
  preview.setOrganizerDrop('13');
  assert.deepEqual(translation('11'), [30, 20]);
  assert.deepEqual(translation('12'), [-100, 0]);
  assert.deepEqual(translation('13'), [100, -160]);
  assert.deepEqual(translation('13', 'section'), [0, 0]);
  assert.deepEqual(preview.snapshot.pins.map(pin => pin.id), ['11', '12', '13']);
  preview.setOrganizerDrop('');
  assert.deepEqual(translation('12'), [0, 0]);
  preview.organizerDragId = '13';
  preview.setOrganizerDrop('11');
  assert.deepEqual(translation('11'), [100, 0]);
  assert.deepEqual(translation('12'), [-100, 160]);
  assert.deepEqual(animations, [160, 160, 160]);
  preview.updateOrganizerDrop(96, 30, false);
  assert.equal(preview.organizerDropId, '12', 'nearby gutter resolves to same-type slot');
  assert.equal(animations.length, 3, 'release validation does not animate');
  preview.updateOrganizerDrop(250, 100, false);
  assert.equal(preview.organizerDropId, '', 'distant empty area does not reorder');
  const organizerContent = view.slice(view.indexOf('private organizeContent('), view.indexOf('private showSectionRefreshIndicator('));
  assert.match(organizerContent, /Stack\(\{ alignContent: Alignment.Bottom \}\)/);
  assert.match(organizerContent, /padding\(\{ left: 16, right: 16,[^\n]*bottom: !targetSheet && this\.phase\(\) === 'select' \? 132 \+ this\.boardActionBarHeight\(true\) - 56 : 24/);
  assert.match(organizerContent, /\}\.width\('100%'\)\.height\('100%'\)\s*if \(!targetSheet && this\.phase\(\) === 'select'\) \{ this\.boardActionTabs\(true\) \}/);
  assert(!organizerContent.includes('.flexShrink(0)'));
  assert.match(sectionView, /boardSectionPreviewImages\(section\)\.slice\(0, 2\)/);
  console.log('Board organizer: HAR fields, regional transport, confirmed order, permissions, stale/cancelled writes and separate section metadata passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
