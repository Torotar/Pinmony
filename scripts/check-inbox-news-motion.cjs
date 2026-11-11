const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace(/\r\n/g, '\n');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0, name);
  const end = source.indexOf('\n  private ', start + 1);
  const out = {};
  vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} exports.Host=Host;', {
    compilerOptions: {target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS}
  }).outputText, {exports: out});
  return out.Host.prototype[name];
}
const present = method('inboxNewsPresentation'), interactive = method('inboxNewsInteractive');
const slide = method('inboxNewsPinSlide');
const news = {screen: 'news', newsScrollOffset: 420};
const host = {inboxStore: {inboxFlow: news}, activeTab: 2, authStatus: 'authenticated',
  businessSuspended: false, pinStore: {}, nativeBoardVisible: () => false,
  profileStore: {origins: []}, activeSheetKind: ''};
assert.equal(present.call(host), news);
assert.equal(interactive.call(host), true);
host.inboxNewsSearchParent = news; host.inboxStore.inboxFlow = undefined; host.activeTab = 1;
assert.equal(present.call(host), news, 'search keeps the same notification instance data');
assert.equal(interactive.call(host), false);
host.inboxNewsSearchParent = undefined; host.inboxStore.retainedChat = news;
host.pinStore.detailOpeningPin = '/pin/1/';
assert.equal(present.call(host), news, 'Pin opening retains notification scroll and parent');
assert.equal(slide.call(host), true);
host.homeEntryPhoto = {pinUrl: '/pin/1/', x: 10, y: 80, width: 160, height: 220};
assert.equal(slide.call(host), false, 'measured notification card uses the existing image flight');
host.homeEntryPhoto.returnPageOnly = true;
assert.equal(slide.call(host), false, 'offscreen return must keep the motion owner mounted until its close callback');
host.homeEntryPhoto = {width: 1, height: 1, returnPageOnly: true};
assert.equal(slide.call(host), true, 'unmeasured source uses the page slide fallback');
host.inboxStore.inboxFlow = news; host.activeTab = 2;
assert.equal(interactive.call(host), false);
host.pinStore = {};
for (const patch of [{pinStore: {detail: {}}}, {businessSuspended: true}, {activeSheetKind: 'menu'},
  {profileStore: {origins: ['profile']}}, {nativeBoardVisible: () => true}, {authStatus: 'checking'}]) {
  assert.equal(interactive.call({...host, ...patch}), false, JSON.stringify(patch));
}
assert.equal(interactive.call(host), true);
assert.equal(present.call(host).newsScrollOffset, 420);
host.inboxStore.retainedChat = {screen: 'chat'};
assert.equal(slide.call(host), false, 'normal Pin photo geometry is unaffected');
const effects = {translate: value => ({animation: options => ({value, options})}),
  asymmetric: (enter, leave) => ({enter, leave})};
for (const name of ['NATIVE_PAGE_TRANSITION', 'BOARD_PAGE_TRANSITION']) {
  const start = source.indexOf('const ' + name + ':');
  const declaration = source.slice(start, source.indexOf('\n);', start) + 3);
  const out = {};
  vm.runInNewContext(ts.transpileModule(declaration + '\nexports.effect=' + name + ';', {
    compilerOptions: {target: ts.ScriptTarget.ES2021}
  }).outputText, {exports: out, TransitionEffect: effects, Curve: {EaseOut: 'easeOut'}});
  assert.deepEqual(out.effect.enter, out.effect.leave, 'entry and back must match');
  assert.equal(out.effect.enter.value.x, '100%');
}
const newsLayer = source.indexOf('if (this.inboxNewsPresentation()) {');
const searchLayer = source.indexOf('if (this.inboxNewsSearchParent && this.activeTab === 1) {', newsLayer);
const otherFlow = source.indexOf("if (this.inboxStore.inboxFlow && this.inboxStore.inboxFlow.screen !== 'news'", searchLayer);
assert(newsLayer > 0 && searchLayer > newsLayer && otherFlow > searchLayer);
assert.match(source.slice(newsLayer, searchLayer), /accessibilityLevel\(this.inboxNewsInteractive\(\) \? 'auto' : 'no-hide-descendants'\)/);
assert.match(source.slice(newsLayer, searchLayer), /hitTestBehavior\(this.inboxNewsInteractive\(\) \? HitTestMode.Default : HitTestMode.None\)/);
assert.match(source, /if \(!this.inboxNewsSearchParent\) \{ this.buildSearchRootContent\(\) \}/, 'search has one presentation');
assert.match(source, /this.inboxStore.listSection \|\| this.inboxNewsSearchParent\) return false/);
assert.match(source, /entryPhoto: !this.inboxNewsPinSlide\(\)/);
assert.match(source, /transition\(!this.inboxNewsPinSlide\(\)/);
const capture = method('capturePinEntryPhoto');
let measured = '';
const geometry = {authStatus: 'authenticated', businessSuspended: false,
  getUIContext: () => ({px2vp: px => px / 2,
    getComponentUtils: () => ({getRectangleById: id => {
      measured = id; return {size: {width: 320, height: 440}, windowOffset: {x: 20, y: 160}};
    }})})};
capture.call(geometry, '/pin/7/', 'fixture.jpg', 'pinmony-news-photo-pin:7', 474, 700);
assert.equal(measured, 'pinmony-news-photo-pin:7');
assert.equal(geometry.homeEntryPhoto.x, 10);
assert.equal(geometry.homeEntryPhoto.y, 80);
assert.equal(geometry.homeEntryPhoto.width, 160);
assert.equal(geometry.homeEntryPhoto.height, 220);
assert.equal(geometry.homeEntryPhoto.imageHeight, 700);
assert.equal(geometry.homeEntryPhoto.returnPageOnly, undefined);
assert.match(source, /capturePinEntryPhoto\(card.target,card.image,'pinmony-news-photo-' \+ card.id,card.imageWidth,card.imageHeight\)/);
const cardView = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxNewsPage.ets', 'utf8');
assert.match(cardView, /\.id\('pinmony-news-photo-' \+ card.id\)/);
assert.match(source, /getRectangleById\(this.homeEntryCardId\)/, 'return measures the retained source again');
const searchView = fs.readFileSync('entry/src/main/ets/components/PinmonySearchRootContent.ets', 'utf8');
assert.match(source, /preparingDetailReturn: this.preservingSearchForPin\(\)/);
assert.match(searchView, /view.preparingDetailReturn \|\|/);
const visibility=searchView.match(/\.visibility\(([^\r\n]+)\)/);assert(visibility);
const visible=new Function('view','Visibility','return '+visibility[1]+';');
const Visibility={Visible:'visible',Hidden:'hidden'};
for(const [search,preparing,covered,expected] of [[false,false,false,'hidden'],[true,false,false,'visible'],
 [false,true,false,'visible'],[false,false,true,'visible'],[true,true,true,'visible']]) {
 assert.equal(visible({nativeSearchPageVisible:()=>search,preparingDetailReturn:preparing,profileCovered:covered},Visibility),expected,
  'search stays mounted through Pin return and profile cover');
}
assert.match(searchView,/hitTestBehavior\(view.nativeSearchPageVisible\(\) \? HitTestMode.Default : HitTestMode.None\)/);
console.log('Notification motion: stable parent identity/scroll, covered input guards, layer order, Pin slide and paired timing passed');
