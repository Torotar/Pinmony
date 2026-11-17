const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function load(file) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, { exports, require: name => name === 'common_ui' ? carousel : {}, console });
  return exports;
}
const carousel = load('common_ui/src/main/ets/models/PinmonyCardCarousel.ets');
const home = Object.create(load('entry/src/main/ets/app/PinmonyHomeNativeReads.ets').PinmonyHomeNativeReads.prototype);
home.origin = 'https://www.pinterest.com'; home.ports = { saved: () => false };
const search = Object.create(load('entry/src/main/ets/app/PinmonySearchNativeReads.ets').PinmonySearchNativeReads.prototype);
search.origin = home.origin;
const board = Object.create(load('entry/src/main/ets/app/PinmonyBoardNativeReads.ets').PinmonyBoardNativeReads.prototype);
board.origin = home.origin;
const profile = Object.create(load('entry/src/main/ets/app/PinmonyProfileNativeReads.ets').PinmonyProfileNativeReads.prototype);
profile.origin = home.origin;
const personal = Object.create(load('entry/src/main/ets/app/PinmonyProfileSearchNativeReads.ets').PinmonyProfileSearchNativeReads.prototype);
const related = load('feature_pin/src/main/ets/services/PinmonyRelatedPresentation.ets').readRelatedPresentation;
const normalize = load('feature_home/src/main/ets/services/PinmonyHomeCache.ets').normalizeHomeCacheRecord;
const image = { url: 'https://i.pinimg.com/474x/synthetic.jpg', width: 474, height: 700 };
for (const count of [0, 1, 3, 4, 5, 8, 10, 12, 15, 16, 19, 20]) {
  const raw = { id: '101', type: 'pin', title: 'Synthetic', images: { '474x': image },
    carousel_data: { carousel_slots: Array.from({ length: count }, () => ({})) } };
  const mapped = [home.mapPins([raw])[0], search.map(raw), board.mapPin(raw), profile.pin(raw),
    related(JSON.stringify({ resource_response: { status: 'success', data: [raw] } }), home.origin + '/pin/102/').pins[0]];
  for (const pin of mapped) assert.equal(pin.mediaCount, count);
  assert.equal(personal.pin(raw).mediaCount, count);
  const cached = normalize({ snapshot: { kind: 'state', pageKey: home.origin + '/', dataSource: 'api',
    selectedTab: 'All', tabs: [{ id: 'all', label: 'All', selected: true, enabled: true }], pins: [mapped[0]] } }, home.origin + '/');
  assert.equal(cached.snapshot.pins[0].mediaCount, count > 1 ? count : undefined);
}
for (const malformed of [undefined, null, {}, { carousel_slots: '1234' }, { carousel_slots: {} }]) {
  const raw = { id: '101', type: 'pin', images: { '474x': image }, carousel_data: malformed };
  for (const pin of [home.mapPins([raw])[0], search.map(raw), board.mapPin(raw), profile.pin(raw), personal.pin(raw)]) assert.equal(pin.mediaCount, 0);
}
const badge = fs.readFileSync('common_ui/src/main/ets/components/PinmonyPinCountBadge.ets', 'utf8');
assert.match(badge, /Number.isInteger\(this.mediaCount\) && this.mediaCount > 1/);
assert.doesNotMatch(badge, /alignStart|Alignment.TopEnd/);
assert.match(badge, /PinmonyCardMediaBadge\(\{ caption: this.mediaCount.toString\(\) \}\)/);
const sharedBadge = fs.readFileSync('common_ui/src/main/ets/components/PinmonyCardMediaBadge.ets', 'utf8');
assert.match(sharedBadge, /align\(Alignment.TopStart\)/);
const detail = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
assert.match(detail, /overlay\(this.pinCountBadge\(pin.mediaCount \|\| 0\), \{ align: Alignment.TopStart \}\)/);
assert.match(detail, /PinmonyPinCountBadge\(\{ mediaCount: mediaCount \}\)/);
assert.match(sharedBadge, /hitTestBehavior\(HitTestMode.None\)/);
for (const file of ['feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets',
  'feature_search/src/main/ets/components/PinmonySearchPage.ets', 'feature_board/src/main/ets/components/PinmonyBoardPage.ets',
  'feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'feature_pin/src/main/ets/components/PinmonyDetailPage.ets',
  'feature_profile/src/main/ets/components/PinmonyProfileSearchPage.ets', 'feature_profile/src/main/ets/components/PinmonyOrganizePage.ets']) {
  assert.match(fs.readFileSync(file, 'utf8'), /PinmonyPinCountBadge\(\{ mediaCount:/);
}
console.log('Pin count: six real native mappers, malformed/single/multiple media, home cache, non-interactive badge and seven card surfaces passed');

for (const file of ['feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets', 'feature_search/src/main/ets/components/PinmonySearchPage.ets', 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'feature_pin/src/main/ets/components/PinmonyDetailPage.ets']) {
  const source = fs.readFileSync(file, 'utf8');
  for (const line of source.split('\n').filter(line => line.includes('.overlay(this.pinCountBadge('))) assert.match(line, /align: Alignment.TopStart/);
}
