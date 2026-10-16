const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.argv[2] || 'typescript');
const runtime = require('./product-coordination-harness.cjs').runtime(ts);
const { PinmonyNetworkBridgeCoordinator } = runtime.loadFile('entry/src/main/ets/app/PinmonyNetworkBridgeCoordinator.ets');
let active = 0, suspended = false;
const scripts = [];
const coordinator = new PinmonyNetworkBridgeCoordinator({
  nativeNetworkContext: () => ({ authenticated: true, epoch: 1, page: 'https://www.pinterest.com/sample/board/' }),
  businessSuspended: () => suspended,
  controller: () => ({ onActive() { active++; }, onInactive() { throw Error('hidden session must remain active'); },
    runJavaScript(script) { scripts.push(script); return Promise.resolve('transport-present'); } })
});
coordinator.bindNativeNetwork();
assert.equal(active, 1);
assert(scripts[0].includes('setForeground(true)'));
assert(scripts[0].includes('PinmonyBoardDemand'));
suspended = true;
coordinator.bindNativeNetwork();
assert(scripts[1].includes('setForeground(false)'), 'real background still disables business requests');
const page = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyPublishPage.ets', 'utf8');
assert(!page.includes('.bindSheet('));
assert(page.includes("$r('sys.symbol.arrow_right')"));
assert(page.includes('this.websiteSheet()'));
assert(page.includes('HdsNavDestinationTitleMode.MINI'));
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const visibleStart = index.indexOf('  private publishPageVisible()');
assert(visibleStart >= 0);
const visibleMethod = index.slice(visibleStart, index.indexOf('\n  private ', visibleStart + 1));
const visibilityContext = {};
const sectionStart = index.indexOf('  private boardSectionReady()');
assert(sectionStart >= 0);
const sectionMethod = index.slice(sectionStart, index.indexOf('\n  private ', sectionStart + 1));
require('./product-coordination-harness.cjs').run(ts, ts.transpileModule(
  'class PhotoVisibility {' + visibleMethod + sectionMethod + '} globalThis.PhotoVisibility = PhotoVisibility;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, visibilityContext);
const visibility = new visibilityContext.PhotoVisibility();
visibility.profileStore = { publishPicking: false, publishFlow: undefined };
assert.equal(visibility.publishPageVisible(), false, 'cancelled flow retains parent');
visibility.profileStore.publishFlow = { kind: 'photo', phase: 'photo', pins: [], error: '' };
assert.equal(visibility.publishPageVisible(), false, 'initial flow cannot open app page before system selection');
visibility.profileStore.publishPicking = true;
visibility.profileStore.publishFlow.phase = 'select';
visibility.profileStore.publishFlow.pins = [{ id: 'local' }];
assert.equal(visibility.publishPageVisible(), false, 'partial transfer cannot reveal photo page');
visibility.profileStore.publishPicking = false;
assert.equal(visibility.publishPageVisible(), true, 'completed photo selection opens app page');
visibility.profileStore.publishFlow = { kind: 'website', phase: 'website', pins: [], error: '' };
assert.equal(visibility.publishPageVisible(), true, 'website navigation remains immediate');
const boardPage = 'https://www.pinterest.com/sample/board/';
Object.assign(visibility, { boardSectionVisible: true, authStatus: 'authenticated', businessSuspended: false,
  boardStore: { presentationOnly: true, boardDetail: { ready: true, session: 1, pageKey: boardPage, editable: true } },
  currentBoardUrl: () => boardPage, controller: { getUrl: () => boardPage }, boardUrlFromAddress: value => value });
assert.equal(visibility.boardSectionReady(), false, 'retained visual snapshot cannot submit');
visibility.boardStore.presentationOnly = false;
visibility.controller.getUrl = () => 'https://www.pinterest.com/sample/';
assert.equal(visibility.boardSectionReady(), false, 'profile preparation document cannot submit');
visibility.controller.getUrl = () => boardPage;
visibility.boardStore.boardDetail.loading = true;
assert.equal(visibility.boardSectionReady(), false, 'wait for board read completion');
visibility.boardStore.boardDetail.loading = false;
assert.equal(visibility.boardSectionReady(), true, 'current ready board enables creation');
visibility.businessSuspended = true;
assert.equal(visibility.boardSectionReady(), false, 'background cannot submit');
assert(index.includes("this.profileStore.publishFlow.phase !== 'create'"));
const create = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets', 'utf8');
assert(create.includes('height: SheetSize.MEDIUM'));
assert(create.includes('HdsNavigationTitleMode.MODAL'));
assert(create.includes('detents: [SheetSize.MEDIUM]'));
assert(create.includes("Button('创建图板').width('100%')"));
const section = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardSectionPage.ets', 'utf8');
assert(section.includes('height: SheetSize.MEDIUM'));
assert(section.includes('HdsNavigationTitleMode.MODAL'));
assert(section.includes('detents: [SheetSize.MEDIUM]'));
assert(!section.includes('Toggle('));
console.log('Publish background and active hidden network binding checks passed');
