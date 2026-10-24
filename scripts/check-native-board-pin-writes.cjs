const { withLocalMessages } = require('./local-message-test-fixture.cjs');
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
function load(file, deps = () => ({})) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021}}).outputText,
    {exports, require: withLocalMessages(deps), setTimeout, clearTimeout, console});
  return exports;
}
const logs = [], log = {PinmonyRuntimeLog: {info: s => logs.push(s)}};
const writesModule = load('entry/src/main/ets/app/PinmonyBoardPinNativeWrites.ets', name => name === 'common_foundation' ? log : {});
const Writer = writesModule.PinmonyBoardPinNativeWrites;
const {PinmonyNativeNetwork: Network, acceptsNetworkJob} = load('common_network/src/main/ets/PinmonyNativeNetwork.ets', name => name === 'common_session' ? {PinmonySessionCredentials: class {}} : {});
const origin = 'https://www.pinterest.com', page = origin + '/sample/board/';
const pin = id => ({id: String(id), pinUrl: origin + '/pin/' + id + '/', imageUrl: 'https://i.pinimg.com/synthetic.jpg', imageWidth: 100, imageHeight: 200, title: 'Synthetic'});
const rawPin = id => ({type: 'pin', id: String(id), images: {'736x': {url: 'https://i.pinimg.com/synthetic.jpg', width: 100, height: 200}}, board: {id: '100'}, pinner: {id: '42'}, is_repin: true});
const resource = (data, endpoint = '', extra = {}) => JSON.stringify({resource_response: {status: 'success', code: 0, endpoint_name: endpoint, data}, client_context: {user: {id: '42'}}, ...extra});
const flush = () => new Promise(setImmediate);
function fixture(move = false) {
  let session = {authenticated: true, accountId: 'synthetic-cache', generation: 1, origin, userAgent: 'synthetic'};
  let identity = {page, boardId: '100', viewerId: '42', intent: 1, canContribute: true, loadedIds: ['1', '2', '3'], selectedIds: move ? ['1', '2', '3'] : [], sources: [{id: '7', tracking_params: 'synthetic-tracking'}]};
  let state = {phase: move ? 'targets' : 'ideas', loading: false, busy: false, uncertain: false, error: '', description: '', privacy: 'public', recommend: false, invites: false, requests: false,
    pins: [pin(7)], targets: [{id: '200', enabled: true, title: 'Target', imageUrl: ''}, {id: '201', enabled: false, title: 'Read only', imageUrl: ''}], saved: [], hasMore: false};
  const requests = [], cancelled = [], snapshots = [], commits = [];
  const writer = new Writer({state: () => state, page: () => identity?.page || page, identity: () => identity, session: () => session,
    network: () => ({cancel: id => cancelled.push(id), requestBusinessBoardPinWrite(job, s, board, viewer, loaded, targets, recommended, current) {
      assert(current()); return new Promise(resolve => requests.push({job, board, viewer, loaded, targets, recommended, current,
        resolve: (body, status = 200, error = '') => resolve({body, status, error})}));
    }}), changed: next => {state = next; snapshots.push(next)}, confirmed: (action, ids, copy) => commits.push({action, ids, copy})});
  return {writer, state: () => state, identity: () => identity, session: () => session, requests, cancelled, snapshots, commits,
    setIdentity: next => identity = next, setSession: next => session = next, setState: next => state = next};
}
async function main() {
  const save = fixture(), original = save.state(); let pending = save.writer.submit('save', '7');
  assert(save.state().busy); assert.equal(original.busy, false); assert.equal(save.state().saved.length, 0);
  await save.writer.submit('save', '7'); assert.equal(save.requests.length, 1);
  const form = new URLSearchParams(save.requests[0].job.body), options = JSON.parse(form.get('data')).options;
  assert.equal(form.get('source_url'), '/sample/board/_tools/more-ideas/?ideas_referrer=23');
  assert.deepEqual(options, {pin_id: '7', board_id: '100', user_id: '42', clientTrackingParams: 'synthetic-tracking'});
  save.requests[0].resolve(resource(rawPin(77), 'v3_repin_handler')); await pending;
  assert.deepEqual(Array.from(save.state().saved), ['7']); assert.equal(save.state().busy, false); assert.equal(save.commits.length, 1);
  pending = save.writer.submit('save', '7'); assert.equal(save.requests.length, 2);
  const deletion = JSON.parse(new URLSearchParams(save.requests[1].job.body).get('data')).options;assert.equal(deletion.id,'77');assert.equal(deletion.client_tracking_params,'synthetic-tracking');assert(save.requests[1].job.url.endsWith('/PinResource/delete/'));
  save.requests[1].resolve(resource(null,'v3_delete_pin_handler'));await pending;assert.equal(save.state().saved.length,0);assert.equal(save.commits[1].action,'unsave');assert.equal(save.commits[1].copy,'77');
  const move = fixture(true); pending = move.writer.submit('move', '200'); await move.writer.submit('move', '200');
  assert.equal(move.requests.length, 1); const moveForm = new URLSearchParams(move.requests[0].job.body);
  assert.equal(moveForm.get('source_url'), '/board/100/organize/repin/');
  assert.deepEqual(JSON.parse(moveForm.get('data')).options, {url: '/v3/pins/bulk/move/', data: {board_id: '200', pin_ids: ['1', '2', '3']}});
  move.requests[0].resolve(resource(null, 'v3_move_pins')); await pending;
  assert.equal(move.commits[0].action, 'move'); assert.deepEqual(Array.from(move.commits[0].ids), ['1', '2', '3']);
  function sectionFixture(target = 'section:100:300', ids = ['1']) {
    const f = fixture(true); f.setIdentity({...f.identity(), selectedIds: ids});
    f.state().targets.push({id: target, enabled: true, title: 'Section', imageUrl: ''}); return f;
  }
  const section = sectionFixture(); pending = section.writer.submit('move', 'section:100:300');
  await section.writer.submit('move', 'section:100:300'); assert.equal(section.requests.length, 1);
  const sectionJob = section.requests[0].job, sectionOptions = JSON.parse(new URLSearchParams(sectionJob.body).get('data')).options;
  assert.deepEqual(sectionOptions, {url:'/v3/board/sections/300/',data:{pins:['1'],fields:[
    'boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()',
    'boardsection.slug','boardsection.title','boardsection.type']}});
  section.requests[0].resolve(resource({id:'300',type:'board_section',board:{id:'100'}},'v3_post_board_section')); await pending;
  assert.equal(section.commits[0].action,'moveSection');
  const cross=fixture(true);cross.state().targetBoardId='200';cross.state().targetSections=[{id:'300',title:'Section',images:[]}];
  pending=cross.writer.submit('move','section:200:300');await cross.writer.submit('move','section:200:300');assert.equal(cross.requests.length,1);
  const crossJob=cross.requests[0].job,crossForm=new URLSearchParams(crossJob.body);
  assert.equal(crossForm.get('source_url'),'/sample/board/_tools/organize/?organization_feed=False');
  assert.deepEqual(JSON.parse(crossForm.get('data')).options,{url:'/v3/pins/bulk/move/',data:{board_id:'200',section_id:'300',pin_ids:['1','2','3']}});
  assert(cross.requests[0].targets.includes('section:200:300'));assert.equal(cross.state().targetBoardId,'200','busy retains target context');
  cross.requests[0].resolve(resource(null,'v3_move_pins'));await pending;assert.equal(cross.commits[0].action,'move');
  for(const configure of [f=>f.state().targetSections=[],f=>f.state().targetBoardId='201',f=>f.state().targets[0].enabled=false]) {
    const f=fixture(true);f.state().targetBoardId='200';f.state().targetSections=[{id:'300',title:'Section',images:[]}];configure(f);
    await f.writer.submit('move','section:200:300');assert.equal(f.requests.length,0,'unverified section ownership cannot write');
  }
  for (const [target, ids] of [['section:200:300',['1']], ['section:100:300',['1','2']]]) {
    const f = sectionFixture(target,ids); await f.writer.submit('move',target); assert.equal(f.requests.length,0);
  }
  for (const [data, endpoint] of [
    [{id:'301',type:'board_section',board:{id:'100'}},'v3_post_board_section'],
    [{id:'300',type:'board_section',board:{id:'200'}},'v3_post_board_section'],
    [{id:'300',type:'board',board:{id:'100'}},'v3_post_board_section'],
    [{id:'300',type:'board_section',board:{id:'100'}},'v3_move_pins']]) {
    const f=sectionFixture(), p=f.writer.submit('move','section:100:300'); f.requests[0].resolve(resource(data,endpoint)); await p;
    assert(f.state().uncertain); assert.equal(f.commits.length,0);
    await f.writer.submit('move','section:100:300'); assert.equal(f.requests.length,1);
  }
  for(const change of [f => f.state().busy = true, f => f.state().loading = true, f => f.state().uncertain = true,
    f => f.state().error = 'read-error', f => f.setIdentity({...f.identity(), canContribute: false}), f => f.setSession({...f.session(), authenticated: false})]) {
    const f = fixture(); change(f); await f.writer.submit('save', '7'); assert.equal(f.requests.length, 0);
  }
  for(const ids of [[], ['1', '1'], ['99'], Array.from({length: 501}, (_, i) => String(i))]) {
    const f = fixture(true); f.identity().selectedIds = ids; await f.writer.submit('move', '200'); assert.equal(f.requests.length, 0);
  }
  for(const target of ['100', '201', '999']) {const f = fixture(true); await f.writer.submit('move', target); assert.equal(f.requests.length, 0)}
  const wrongPin = fixture(); await wrongPin.writer.submit('save', '8'); assert.equal(wrongPin.requests.length, 0);
  for(const body of ['invalid', resource(rawPin(77), 'other'), resource({...rawPin(77), board: {id: '999'}}, 'v3_repin_handler'),
    resource({...rawPin(77), pinner: {id: '99'}}, 'v3_repin_handler'), resource({...rawPin(77), is_repin: false}, 'v3_repin_handler'),
    resource(rawPin(77), 'v3_repin_handler', {client_context: {user: {id: '99'}}})]) {
    const f = fixture(); const p = f.writer.submit('save', '7'); f.requests[0].resolve(body); await p;
    assert(f.state().uncertain); assert.equal(f.state().saved.length, 0); assert.equal(f.commits.length, 0);
    await f.writer.submit('save', '7'); assert.equal(f.requests.length, 1);
  }
  for(const result of [{body: resource(null, 'v3_move_pins'), error: 'network-unavailable'},
    {body: resource(null, 'v3_move_pins'), status: 503}, {body: resource({}, 'v3_move_pins')}]) {
    const f = fixture(true), p = f.writer.submit('move', '200'); f.requests[0].resolve(result.body, result.status || 200, result.error || ''); await p;
    assert(f.state().uncertain); assert.equal(f.state().busy, false); assert.equal(f.commits.length, 0);
  }
  const pause = fixture(); pending = pause.writer.submit('save', '7'); pause.setIdentity(undefined); pause.writer.pause();
  assert(pause.state().uncertain, 'background marks uncertainty even when active identity is unavailable'); assert.equal(pause.state().busy, false);
  assert(pause.cancelled.includes(pause.requests[0].job.id)); pause.requests[0].resolve(resource(rawPin(77), 'v3_repin_handler')); await pending; assert.equal(pause.commits.length, 0);
  for(const change of [f => f.setIdentity({...f.identity(), page: origin + '/other/board/'}), f => f.setIdentity({...f.identity(), intent: 2}),
    f => f.setIdentity({...f.identity(), viewerId: '99'}), f => f.setSession({...f.session(), accountId: 'other', generation: 2})]) {
    const f = fixture(), p = f.writer.submit('save', '7'); change(f); f.requests[0].resolve(resource(rawPin(77), 'v3_repin_handler')); await p; assert.equal(f.commits.length, 0);
  }
  const create = fixture(true), input = JSON.stringify({name:'New board',secret:true});
  pending = create.writer.submit('createTarget',input);await create.writer.submit('createTarget',input);assert.equal(create.requests.length,1);
  const createJob=create.requests[0].job,createForm=new URLSearchParams(createJob.body);assert.equal(createForm.get('source_url'),'/board/create/');assert.equal(createJob.headers['X-Pinterest-Pws-Handler'],'www/board/create.js');assert.deepEqual(JSON.parse(createForm.get('data')).options,{name:'New board',privacy:'secret'});
  create.requests[0].resolve(resource({id:'250',type:'board',name:'New board',privacy:'secret',owner:{id:'42'}},'v3_create_board'));await pending;
  assert.equal(create.state().phase,'targets');assert.equal(create.state().targets[0].id,'250');assert(create.state().targets[0].enabled);assert(!create.state().uncertain);assert.equal(create.commits[0].action,'createTarget');
  pending=create.writer.submit('move','250');assert.equal(create.requests.length,2);assert.equal(JSON.parse(new URLSearchParams(create.requests[1].job.body).get('data')).options.data.board_id,'250');create.requests[1].resolve(resource(null,'v3_move_pins'));await pending;
  const lost=fixture(true);pending=lost.writer.submit('createTarget',input);lost.requests[0].resolve('',503,'lost');await pending;assert(lost.state().uncertain);lost.setState({...lost.state(),uncertain:false,error:''});await lost.writer.submit('createTarget',input);assert.equal(lost.requests.length,1,'reopening cannot repeat unknown board creation');
  const wrong=fixture(true);pending=wrong.writer.submit('createTarget',input);wrong.requests[0].resolve(resource({id:'250',type:'board',name:'New board',privacy:'secret',owner:{id:'99'}},'v3_create_board'));await pending;assert(wrong.state().uncertain);assert(!wrong.state().targets.some(t=>t.id==='250'));
  const net = new Network(); let sent = 0, context, session = save.session(), owner = true;
  net.request = async (job, current) => {context = current; const permitted = acceptsNetworkJob(job, current()); if(permitted)sent++; return {error: permitted ? '' : 'rejected'}};
  const transport = job => net.requestBusinessBoardPinWrite(job, () => session, '100', '42', ['1', '2', '3'], ['200'], ['7'], () => owner);
  assert.equal((await transport(createJob)).error,'','create-target request passes exact native gate');
  const invalidCreate={...createJob,headers:{...createJob.headers,'X-Pinterest-Pws-Handler':'www/other.js'}};assert.equal((await transport(invalidCreate)).error,'rejected');
  const saveJob = save.requests[0].job, moveJob = move.requests[0].job;
  assert.equal((await transport(saveJob)).error, ''); assert.equal((await transport(moveJob)).error, ''); const deleteJob=save.requests[1].job;
  const undoTransport=(job,copies=['77'],route='')=>net.requestBusinessBoardPinWrite(job,()=>session,'100','42',[],[],['7'],()=>owner,copies,route);
  assert.equal((await undoTransport(deleteJob)).error,'');assert.equal((await undoTransport(deleteJob,[])).error,'rejected');
  const sectionRoute='/sample/board/section/_tools/more-ideas/?ideas_referrer=24';const sectionForm=new URLSearchParams(deleteJob.body);sectionForm.set('source_url',sectionRoute);const sectionDelete={...deleteJob,body:sectionForm.toString(),headers:{...deleteJob.headers,'X-Pinterest-Pws-Handler':'www/[username]/[slug]/[section_slug]/_tools/more-ideas.js'}};
  assert.equal((await undoTransport(sectionDelete,['77'],sectionRoute)).error,'');assert.equal((await undoTransport(sectionDelete,['7'],sectionRoute)).error,'rejected');
  const before = sent;
  function mutate(job, change) {const q = new URLSearchParams(job.body), e = JSON.parse(q.get('data')); change(e); q.set('data', JSON.stringify(e)); return {...job, body: q.toString()}}
  const crossTransport=(job,targets=['200','section:200:300'])=>net.requestBusinessBoardPinWrite(job,()=>session,'100','42',['1','2','3'],targets,[],()=>owner);
  assert.equal((await crossTransport(crossJob)).error,'');
  for(const targets of [['200'],['section:200:300'],['200','section:201:300']])assert.equal((await crossTransport(crossJob,targets)).error,'rejected');
  for(const job of [mutate(crossJob,e=>e.options.data.section_id='301'),mutate(crossJob,e=>e.options.data.pin_ids=['99']),
    mutate(crossJob,e=>e.options.data.extra=true)])assert.equal((await crossTransport(job)).error,'rejected');
  const sectionTransport=(job,targets=['section:100:300'])=>net.requestBusinessBoardPinWrite(job,()=>session,'100','42',['1'],targets,[],()=>owner);
  assert.equal((await sectionTransport(sectionJob)).error,'');
  assert.equal((await sectionTransport(sectionJob,[])).error,'rejected');
  for(const job of [mutate(sectionJob,e=>e.options.data.pins=['2']),
    mutate(sectionJob,e=>e.options.data.pins=['1','1']),mutate(sectionJob,e=>e.options.data.fields=[]),
    mutate(sectionJob,e=>e.options.url='/v3/board/sections/301/')]) assert.equal((await sectionTransport(job)).error,'rejected');
  for(const job of [{...saveJob, method: 'GET'}, {...saveJob, id: 'bridge'}, {...saveJob, page: origin + '/sample/pins/'},
    {...saveJob, body: saveJob.body + '&extra=true'}, {...saveJob, url: origin + '/resource/PinResource/delete/'},
    mutate(saveJob, e => e.options.pin_id = '999'), mutate(saveJob, e => e.options.board_id = '999'), mutate(saveJob, e => e.options.user_id = '99'),
    mutate(saveJob, e => e.options.clientTrackingParams = 'a'.repeat(16385)), mutate(saveJob, e => e.options.extra = true), mutate(saveJob, e => e.context = ''),
    {...saveJob, headers: {...saveJob.headers, 'X-Pinterest-Pws-Handler': 'www/index.js'}}, mutate(moveJob, e => e.options.data.board_id = '201'),
    mutate(moveJob, e => e.options.data.board_id = '100'), mutate(moveJob, e => e.options.data.pin_ids = ['99']),
    mutate(moveJob, e => e.options.data.pin_ids = ['1', '1']), mutate(moveJob, e => e.options.data.pin_ids = []),
    mutate(moveJob, e => e.options.data.section_id = '123'), mutate(moveJob, e => e.options.url = '/v3/boards/100/archive/')]) assert((await transport(job)).error);
  assert.equal(sent, before + 2); session = {...session, origin: 'https://uk.pinterest.com'};
  assert.equal((await transport({...saveJob, page: saveJob.page.replace(origin, session.origin), url: saveJob.url.replace(origin, session.origin)})).error, '');
  owner = false; assert.equal(context().authenticated, false);

  // Actual native reader: source recommendations, target permissions, local commit and fresh read ownership.
  const collaborators = load('entry/src/main/ets/app/PinmonyBoardCollaboratorsNativeWrites.ets', name => name === 'common_foundation' ? log : {});
  const {PinmonyBoardNativeReads: Reader} = load('entry/src/main/ets/app/PinmonyBoardNativeReads.ets', name => name === './PinmonyBoardFollowNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardFollowNativeWrites.ets') : name === './PinmonyBoardSectionNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardSectionNativeWrites.ets') : name === './PinmonyBoardContentNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardContentNativeWrites.ets', n => n === 'common_foundation' ? {PinmonyRuntimeLog:{info(){}}} : {}) : name === './PinmonyBoardManagementNativeWrites' ? load('entry/src/main/ets/app/PinmonyBoardManagementNativeWrites.ets', name => name === 'common_foundation' ? log : {}) : name === './PinmonyBoardPinNativeWrites' ? writesModule :
    name === './PinmonyBoardCollaboratorsNativeWrites' ? collaborators : name === 'common_network' ? {PIN_BUSINESS_PIN_READ_ENABLED: true} : name === 'common_foundation' ? log : {});
  const store = {boardDetail: {kind: 'state', session: 0, pageKey: page, title: 'Board', pins: [], ready: false}, collaboratorsToken: 0};
  const requests = [], cancelled = []; let invalidations = 0, active = true, singleMovePage = '';
  const send = (job, ...args) => {const current = args.findLast(value=>typeof value==='function'); assert(current()); return new Promise(resolve => requests.push({job, current, resolve: body => resolve({body, status: 200, error: ''})}))};
  const reader = new Reader({store: () => store, session: () => save.session(), active: () => active, network: () => ({cancel: id => cancelled.push(id),
    requestBusinessBoardRead: send, requestBusinessBoardAuxRead: send, requestBusinessBoardPinWrite: send}), document: () => {throw Error('Web document gate')},
    documentEpoch: () => {throw Error('Web epoch')}, prepareDocument: () => {throw Error('navigation')}, runScript: () => {throw Error('Web write')},
    jsonText: s => s, install() {}, bridge() {}, committed() {}, openPin() {}, invalidateProfile: () => invalidations++, movePage: () => singleMovePage, clearMovePage: () => singleMovePage = ''});
  const board = {type: 'board', id: '100', url: '/sample/board/', name: 'Board', privacy: 'public', owner: {id: '42', username: 'sample'}, pin_count: 3, section_count: 0};
  const action = (action, value) => reader.handle('flow', JSON.stringify({action, value}));
  pending = reader.demand(); requests[0].resolve(resource(board)); await flush(); requests[1].resolve(JSON.stringify({resource_response: {status:'success', code:0, data:[rawPin(1), rawPin(2), rawPin(3)], bookmark:'next'}, client_context:{user:{id:'42'}}})); await pending;
  pending = action('ideas'); requests[2].resolve(resource([{...rawPin(7),tracking_params:'native-tracking'}])); await pending;
  pending = action('save', '7'); assert(store.boardDetail.flow.busy); await action('close'); assert.equal(store.boardDetail.flow.phase, 'ideas');
  await reader.more(); assert.equal(requests.length, 4); requests[3].resolve(resource(rawPin(77), 'v3_repin_handler')); assert.equal(await pending, true);
  assert.equal(store.boardDetail.flow.saved[0], '7'); assert.equal(store.boardDetail.pins[0].id, '77'); assert.equal(invalidations, 1);
  assert.equal(store.boardDetail.nativeAccountGeneration, 1); requests[4].resolve(resource({...board,pin_count:4})); await flush(); requests[5].resolve(resource([rawPin(77),rawPin(1),rawPin(2),rawPin(3)])); await flush();
  await action('close'); await action('select'); pending = action('targets', ['1','2','3']);
  requests[6].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']},{type:'board',id:'201',name:'Archived',access:['write'],archived_by_me:true}])); await pending;
  const beforeDisabled = requests.length; await action('move','201'); assert.equal(requests.length,beforeDisabled);
  // An older main page read exists when the confirmed move arrives.
  // Recreate a cursor through explicit refresh, then start paging before opening the targets.
  await action('close'); pending=reader.refresh();requests[7].resolve(resource(board));await flush();requests[8].resolve(JSON.stringify({resource_response:{status:'success',code:0,data:[rawPin(1),rawPin(2),rawPin(3)],bookmark:'next'},client_context:{user:{id:'42'}}}));await pending;
  const oldMore=reader.more(), late=requests[9];await action('select');pending=action('targets',['1','2','3']);requests[10].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']} ]));await pending;
  pending=action('move','200');await reader.refresh();assert.equal(requests.length,12);requests[11].resolve(resource(null,'v3_move_pins'));await pending;
  assert.equal(store.boardDetail.flow.phase,'');assert.equal(store.boardDetail.pins.length,0);assert(cancelled.includes(late.job.id));assert.equal(invalidations,2);
  late.resolve(resource([rawPin(1),rawPin(2),rawPin(3)]));await oldMore;assert.equal(store.boardDetail.pins.length,0,'late feed cannot restore moved Pins');
  requests[12].resolve(resource({...board,pin_count:0}));await flush();requests[13].resolve(resource([]));await flush();assert.equal(store.boardDetail.pins.length,0);
  assert.equal(requests.filter(r=>r.job.method==='POST').length,2,'read revalidation never replays writes');
  pending=action('ideas');requests[14].resolve(resource([rawPin(8)]));await pending;pending=action('save','8');active=false;reader.pause();assert(store.boardDetail.flow.uncertain);assert.equal(store.boardDetail.flow.busy,false);
  requests[15].resolve(resource(rawPin(88),'v3_repin_handler'));await pending;assert.equal(store.boardDetail.flow.saved.length,0);
  active=true;await reader.demand();await action('save','8');assert.equal(requests.length,16,'resume cannot repeat an unknown save');
  const recovery=action('close');assert.equal(requests.length,17);requests[16].resolve(resource({...board,pin_count:0}));await flush();requests[17].resolve(resource([]));await recovery;
  // Single-card target back returns to the board; bulk target back retains the selection step.
  pending=reader.refresh();requests[18].resolve(resource(board));await flush();requests[19].resolve(resource([rawPin(1)]));await pending;
  singleMovePage=page;pending=action('targets',['1']);requests[20].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']}]));await pending;
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');const begin=index.indexOf('  private backFromBoard('),end=index.indexOf('\n  private ',begin+1);assert(begin>=0);
  const Back=vm.runInNewContext(ts.transpileModule('class Back {'+index.slice(begin,end)+'} Back;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PIN_NATIVE_BOARD_READS_ENABLED:true});
  const back=new Back();back.boardStore=store;back.boardNativeReads=reader;back.boardOperation=(method,id)=>reader.handle(method,id);
  back.backFromBoard();await flush();assert.equal(store.boardDetail.flow.phase,'');assert.equal(singleMovePage,'');
  await action('select');pending=action('targets',['1']);requests[21].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']}]));await pending;
  back.backFromBoard();await flush();assert.equal(store.boardDetail.flow.phase,'select');
  singleMovePage=page;pending=action('targets',['1']);requests[22].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']}]));await pending;
  pending=action('move','200');back.backFromBoard();assert.equal(store.boardDetail.flow.phase,'targets');assert.equal(singleMovePage,page,'busy system back cannot close the flow');
  requests[23].resolve(resource(null,'v3_move_pins'));await pending;assert.equal(singleMovePage,'','confirmed single move clears its navigation marker');
  requests[24].resolve(resource({...board,pin_count:0}));await flush();requests[25].resolve(resource([]));await flush();
  assert.equal(logs.some(s=>s.includes('sample/board')||s.includes('native-tracking')),false);

  const cs={boardDetail:{kind:'state',session:0,pageKey:page,title:'Board',pins:[],ready:false},collaboratorsToken:0}, cr=[];
  const sendCreate=(job,...args)=>{assert(args.findLast(value=>typeof value==='function')());return new Promise(resolve=>cr.push({job,resolve:body=>resolve({body,status:200,error:''})}))};
  const nr=new Reader({store:()=>cs,session:()=>save.session(),active:()=>true,network:()=>({cancel(){},requestBusinessBoardRead:sendCreate,requestBusinessBoardAuxRead:sendCreate,requestBusinessBoardSectionRead:sendCreate,requestBusinessBoardPinWrite:sendCreate}),install(){},bridge(){},committed(){},openPin(){},invalidateProfile(){}});
  let work=nr.demand();cr[0].resolve(resource(board));await flush();cr[1].resolve(resource([rawPin(1)]));await work;
  work=nr.handle('flow',JSON.stringify({action:'targets',value:['1']}));cr[2].resolve(resource([]));await work;
  work=nr.handle('flow',JSON.stringify({action:'createTarget',value:input}));assert(cs.boardDetail.flow.busy);cr[3].resolve(resource({id:'250',type:'board',name:'New board',privacy:'secret',owner:{id:'42'}},'v3_create_board'));await work;
  assert.equal(cs.boardDetail.flow.phase,'targets');assert.equal(cs.boardDetail.flow.targets[0].id,'250');assert.equal(cs.boardDetail.pins.length,1,'creating a destination never removes source Pins');
  work=nr.handle('flow',JSON.stringify({action:'move',value:'250'}));assert.equal(JSON.parse(new URLSearchParams(cr[4].job.body).get('data')).options.data.pin_ids[0],'1');cr[4].resolve(resource(null,'v3_move_pins'));await work;assert.equal(cs.boardDetail.pins.length,0);
  cr[5].resolve(resource({...board,pin_count:0}));await flush();cr[6].resolve(resource([]));await flush();
  work=nr.refresh();cr[7].resolve(resource(board));await flush();cr[8].resolve(resource([rawPin(1)]));await work;
  work=nr.handle('flow',JSON.stringify({action:'targets',value:['1']}));cr[9].resolve(resource([{type:'board',id:'200',name:'Target',access:['write']}]));await work;
  work=nr.handle('flow',JSON.stringify({action:'sectionTargetOpen',value:'200'}));
  const readSectionJob=cr[10].job;assert.equal(cs.boardDetail.flow.targetBoardId,'200');
  assert.equal((await net.requestBusinessBoardSectionRead(readSectionJob,()=>save.session(),'200','100','',()=>true)).error,'');
  cr[10].resolve(resource([{id:'300',type:'board_section',title:'Section',board:{id:'200'}}],'get_all_boards_sections'));await work;
  assert.equal(cs.boardDetail.flow.targetSections[0].id,'300');
  const targetBack=new Back();targetBack.boardStore=cs;targetBack.boardNativeReads=nr;targetBack.boardOperation=(method,id)=>nr.handle(method,id);
  targetBack.backFromBoard();await flush();assert.equal(cs.boardDetail.flow.phase,'targets');assert.equal(cs.boardDetail.flow.targetBoardId,undefined);
  work=nr.handle('flow',JSON.stringify({action:'sectionTargetOpen',value:'200'}));cr[11].resolve(resource([{id:'300',type:'board_section',title:'Section',board:{id:'200'}}],'get_all_boards_sections'));await work;
  work=nr.handle('flow',JSON.stringify({action:'move',value:'section:200:300'}));assert.equal(cr.length,13);
  cr[12].resolve(resource(null,'v3_move_pins'));await work;assert.equal(cs.boardDetail.pins.length,0);
  cr[13].resolve(resource({...board,pin_count:0}));await flush();cr[14].resolve(resource([]));await flush();
  // Real Web adapter adopts native busy and completed flows, with both legacy submit entrypoints disabled.
  const script = load('feature_board/src/main/ets/services/PinmonyBoardApiScript.ets').PIN_BOARD_API_SCRIPT;
  const location={hostname:'www.pinterest.com',origin,pathname:'/sample/board/',href:page};let fetches=0;const states=[];
  const window={PinmonyNativeBoardReadsEnabled:true,PinmonyNativeBoardAuxReadsEnabled:true,PinmonyNativeBoardPinWritesEnabled:true,PinmonyBoardApiEnabled:true,
    PinmonyNativeNetworkEnabled:true,PinmonyNetwork:{isReady:()=>true,documentEpoch:()=>7},PinmonyShareBridge:{boardState:raw=>states.push(JSON.parse(raw))},addEventListener(){},setInterval(){}};window.top=window;
  const ctx={window,location,URL,AbortController,console,setTimeout,clearTimeout,fetch(){fetches++;throw Error('duplicate Web POST')}};
  vm.runInNewContext(script,ctx);vm.runInNewContext(reader.installScript(),ctx);
  let version=store.boardDetail.nativeVersion+1;const flow={...save.state(),phase:'ideas',busy:true};
  const adopt = f => window.PinmonyBoardApi.installNative(page,board,'42',{...store.boardDetail,nativeVersion:version++,flow:f},'',{flowOwned:true,sourcePins:[{id:'7'}],selectedIds:[],targetBookmark:''});
  assert(adopt(flow));assert.equal(window.PinmonyBoardApi.flow(states.at(-1).session,page,JSON.stringify({action:'save',value:'7'})),false);
  assert(adopt({...flow,busy:false}));assert.equal(states.at(-1).flow.busy,false);assert.equal(window.PinmonyBoardApi.flow(states.at(-1).session,page,JSON.stringify({action:'move',value:'200'})),false);assert.equal(fetches,0);
  assert(fs.readFileSync('entry/src/main/ets/app/PinmonyScriptRegistry.ets','utf8').includes('window.PinmonyNativeBoardPinWritesEnabled'));
  console.log('Native board save/move passed: tracking/copy ownership, bulk targets, strict POST policy, busy/unknown/cancel, native local commits, late feed rejection, read-only revalidation and zero Web submit.');
}
const watchdog=setTimeout(()=>{console.error('native board Pin write test did not complete');process.exit(1)},15000);
main().then(()=>clearTimeout(watchdog)).catch(error=>{clearTimeout(watchdog);console.error(error);process.exitCode=1});
