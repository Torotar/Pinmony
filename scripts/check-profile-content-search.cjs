const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(path) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: name => name === 'common_foundation' ? { PinmonyI18n: { message: key => key } } : {}, setTimeout, clearTimeout });
  return exports;
}
const Reader = load('entry/src/main/ets/app/PinmonyProfileSearchNativeReads.ets').PinmonyProfileSearchNativeReads;
const { PinmonyNativeNetwork: Network, acceptsNetworkJob } = load('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const tick = () => new Promise(setImmediate);
const response = (data, bookmark) => ({ status: 200, body: JSON.stringify({ resource_response: { status: 'success', data, bookmark } }) });
const pin = id => ({ id, images: { '236x': { url: 'https://i.pinimg.com/fixture.jpg' } }, title: 'Fixture' });
function fixture() {
  const store = {}, requests = [], cancelled = [];
  const session = { authenticated: true, accountId: 'fixture-account', generation: 1, origin: 'https://www.pinterest.com', userAgent: '' };
  const reader = new Reader({ store: () => store, session: () => session, active: () => true,
    network: () => ({ cancel: id => cancelled.push(id), requestBusinessProfileSearchDelete: (job, session, query, live) => new Promise(resolve => requests.push({ job, query, live, resolve })), requestBusinessProfileSearchRead: (job, s, live) => new Promise(resolve => requests.push({ job, live, resolve })) }) });
  return { store, reader, session, requests, cancelled };
}
async function main() {
  const f = fixture(); f.reader.open();
  assert.equal(f.requests.length, 1);
  const opts = JSON.parse(new URL(f.requests[0].job.url).searchParams.get('data')).options;
  assert.equal(opts.personal_search_only, true); assert.equal(opts.pin_scope, 'my_content'); assert.equal(opts.autocomplete_request_surface, 1);
  f.requests[0].resolve(response({ items: [{ type: 'recent_query', query: 'global' }, { type: 'recent_personal_searches', query: 'mine' }] })); await tick();
  assert.deepEqual(Array.from(f.store.contentSearch.suggestions, x => x.query), ['mine']);
  f.reader.submit('first'); const stale = f.requests.at(-1);
  f.reader.submit('second'); const current = f.requests.at(-1);
  assert(f.cancelled.includes(stale.job.id)); assert.equal(stale.live(), false);
  stale.resolve(response({ results: [pin('11')] }, '-end-')); await tick(); assert.equal(f.store.contentSearch.pins.length, 0);
  current.resolve(response({ results: [pin('12'), pin('12')] }, 'cursor-a')); await tick();
  assert.equal(f.store.contentSearch.pins.length, 1);
  const more = f.reader.more(); const page = f.requests.at(-1);
  const pageOptions = JSON.parse(new URL(page.job.url).searchParams.get('data')).options;
  assert.equal(pageOptions.scope, 'my_pins'); assert.deepEqual(pageOptions.bookmarks, ['cursor-a']);
  page.resolve(response({ results: [pin('12'), pin('13')] }, 'cursor-a')); await more;
  assert.equal(f.store.contentSearch.pins.length, 2); assert.equal(f.store.contentSearch.ended, true);
  const count = f.requests.length; await f.reader.more(); assert.equal(f.requests.length, count);
  f.reader.input('typing'); f.reader.input(''); assert.equal(f.store.contentSearch.query, '');
  const history = f.requests.at(-1); f.reader.close(); history.resolve(response({ items: [] })); await tick();
  assert.equal(f.store.searchVisible, false); assert.equal(f.store.contentSearch, undefined);
  const failure = fixture(); failure.reader.open(); failure.requests[0].resolve(response({ items: [] })); await tick();
  failure.reader.submit('fixture'); failure.requests.at(-1).resolve(response({ results: [pin('1')] }, 'next')); await tick();
  const failedPage = failure.reader.more(); failure.requests.at(-1).resolve({ status: 503, body: '' }); await failedPage;
  assert.equal(failure.store.contentSearch.pins.length, 1); assert(failure.store.contentSearch.error);
  failure.reader.retry(); assert.deepEqual(JSON.parse(new URL(failure.requests.at(-1).job.url).searchParams.get('data')).options.bookmarks, ['next']);
  const locked = fixture(); locked.reader.open(); locked.session.generation++; assert.equal(locked.requests[0].live(), false); locked.reader.close();
  const account = fixture(); account.reader.open(); account.session.accountId = 'other'; assert.equal(account.requests[0].live(), false); account.reader.close();

  const resumed = fixture(); resumed.reader.open(); const beforePause = resumed.requests[0];
  resumed.reader.pause(); resumed.reader.resume(); assert.equal(resumed.requests.length, 2); assert.equal(beforePause.live(), false);
  resumed.requests[1].resolve(response({ items: [] })); await tick(); assert.equal(resumed.store.contentSearch.loading, false); resumed.reader.close();
  async function historyFixture() {
    const f = fixture(); f.reader.open(); f.requests[0].resolve(response({ items: [{ type: 'recent_personal_searches', query: 'mine' }, { type: 'recent_personal_searches', query: 'other' }] })); await tick(); return f;
  }
  const deleted = await historyFixture();
  const deletion = deleted.reader.deleteHistory('mine'); const deleteJob = deleted.requests.at(-1).job;
  assert.equal(deleted.store.contentSearch.suggestions.length, 2, 'click does not imply success');
  assert.equal(deleted.store.contentSearch.suggestions[0].deleting, true);
  await deleted.reader.deleteHistory('mine'); await deleted.reader.deleteHistory('other'); assert.equal(deleted.requests.length, 2, 'single pending write');
  const deleteOptions = JSON.parse(new URLSearchParams(deleteJob.body).get('data')).options;
  assert.equal(deleteOptions.data.vertical, 'PERSONAL'); assert.equal(deleteOptions.data.query, 'mine');
  deleted.requests.at(-1).resolve({ status: 200, body: JSON.stringify({ resource_response: { status: 'success', code: 0, endpoint_name: 'v3_recent_search_delete', data: null } }) }); await deletion;
  assert.deepEqual(Array.from(deleted.store.contentSearch.suggestions, x => x.query), ['other']); assert.equal(deleted.store.contentSearch.suggestions[0].deletable, true);
  const uncertain = await historyFixture(); const unknownDelete = uncertain.reader.deleteHistory('mine');
  uncertain.requests.at(-1).resolve({ status: 200, body: JSON.stringify({ resource_response: { status: 'success', code: 0, endpoint_name: 'wrong_endpoint' } }) }); await unknownDelete;
  assert.equal(uncertain.store.contentSearch.suggestions.length, 2); assert.equal(uncertain.store.contentSearch.suggestions[0].deletable, false); assert(uncertain.store.contentSearch.error);
  const beforeUnknownRetry = uncertain.requests.length; await uncertain.reader.deleteHistory('mine'); assert.equal(uncertain.requests.length, beforeUnknownRetry, 'unknown write is not replayed');
  const staleDeleteFixture = await historyFixture(); const staleDelete = staleDeleteFixture.reader.deleteHistory('mine'), pendingDelete = staleDeleteFixture.requests.at(-1);
  staleDeleteFixture.reader.input(''); assert.equal(pendingDelete.live(), false); pendingDelete.resolve({ status: 200, body: JSON.stringify({ resource_response: { status: 'success', code: 0, endpoint_name: 'v3_recent_search_delete' } }) }); await staleDelete;
  assert.equal(staleDeleteFixture.store.contentSearch.loading, true, 'stale delete does not replace current read');
  const notSent = await historyFixture(); const notSentDelete = notSent.reader.deleteHistory('mine'); notSent.requests.at(-1).resolve({ status: 0, error: 'request-unavailable', body: '' }); await notSentDelete;
  assert.equal(notSent.store.contentSearch.suggestions[0].deletable, true);
  const rejected = await historyFixture(); const rejectedDelete = rejected.reader.deleteHistory('mine'); rejected.requests.at(-1).resolve({ status: 200, body: JSON.stringify({ resource_response: { status: 'failure', code: 1 } }) }); await rejectedDelete;
  assert.equal(rejected.store.contentSearch.suggestions[0].deletable, true);
  const network = Object.create(Network.prototype);
  network.request = async (job, context) => acceptsNetworkJob(job, context());
  const validSuggestion = f.requests[0].job, validResult = current.job;
  async function allowed(job) { return network.requestBusinessProfileSearchRead(job, () => f.session, () => true); }
  assert.equal(await allowed(validSuggestion), true); assert.equal(await allowed(validResult), true);
  assert.equal(await allowed({ ...validResult, method: 'POST' }), false);
  assert.equal(await allowed({ ...validResult, epoch: 9 }), false);
  assert.equal(await allowed({ ...validResult, url: validResult.url.replace('www.pinterest.com', 'outside.example') }), false);
  function changeOptions(job, patch) {
    const url = new URL(job.url), data = JSON.parse(url.searchParams.get('data')); Object.assign(data.options, patch);
    url.searchParams.set('data', JSON.stringify(data)); return { ...job, url: url.toString() };
  }
  assert.equal(await allowed(changeOptions(validResult, { scope: 'pins' })), false);
  assert.equal(await allowed(changeOptions(validSuggestion, { personal_search_only: false })), false);
  assert.equal(await allowed(changeOptions(validSuggestion, { pin_scope: 'pins' })), false);
  assert.equal(await network.requestBusinessProfileSearchRead(validResult, () => f.session, () => false), false);
  async function allowedDelete(job, query = 'mine', live = () => true) { return network.requestBusinessProfileSearchDelete(job, () => deleted.session, query, live); }
  assert.equal(await allowedDelete(deleteJob), true);
  assert.equal(await allowedDelete({ ...deleteJob, method: 'GET' }), false);
  assert.equal(await allowedDelete({ ...deleteJob, page: deleted.session.origin + '/search/' }), false);
  assert.equal(await allowedDelete(deleteJob, 'unlisted'), false); assert.equal(await allowedDelete(deleteJob, 'mine', () => false), false);
  const otherVertical = new URLSearchParams(deleteJob.body); const changedDelete = JSON.parse(otherVertical.get('data')); changedDelete.options.data.vertical = 'PIN'; otherVertical.set('data', JSON.stringify(changedDelete));
  assert.equal(await allowedDelete({ ...deleteJob, body: otherVertical.toString() }), false);
  for (const f of [deleted, uncertain, staleDeleteFixture, notSent, rejected]) f.reader.close();
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  const pageSource = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfileSearchPage.ets', 'utf8');
  const root = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
  assert(root.indexOf('if (this.onSearch)') < root.indexOf('if (this.onPublish)'));
  assert(pageSource.includes('CancelButtonStyle.INPUT')); assert(pageSource.includes('.hideBackButton(false)'));
  assert(pageSource.includes('.navDestination(this.destination)')); assert(index.includes('this.profileStore.searchVisible || !!this.inboxStore.listSection'));
  assert(!pageSource.includes('打开应用程序')); assert(index.includes('this.profileSearchReads.close(); this.inboxMenuNative.pause()'));
  assert(pageSource.includes('.align(Alignment.TopStart)')); assert(pageSource.includes('.justifyContent(FlexAlign.Start)'));
  assert(pageSource.includes('onDeleteHistory(item.query)')); assert(pageSource.includes("SymbolGlyph($r('sys.symbol.xmark'))"));
  assert(pageSource.includes(".width(44).height(44).borderRadius(22)")); assert(!pageSource.includes("Button(this.text('pm_profile_search_your_pins'))"));
  failure.reader.close();
  console.log('PASS personal search: history scope, stale/cancel/account guards, clear, dedupe, pagination/retry, network allowlist, title/back/safe-area wiring');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
