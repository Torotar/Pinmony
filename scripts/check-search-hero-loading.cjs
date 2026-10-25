const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
function method(name) {
  const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
  assert(start >= 0, name);
  const rest = source.slice(start);
  return rest.slice(0, rest.slice(1).search(/\n  (?:private |@Builder)/) + 1);
}
let statusCount = 0;
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  ['performSearchAction', 'buildRootStatus', 'nativeBoardVisible'].map(method).join('\n') + '} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
  {PIN_NATIVE_BOARD_READS_ENABLED:true, PinmonyStatusPage(){statusCount++;}});
async function main() {
  const host = new Host(), events = [], target = 'https://www.pinterest.com/sample/board/';
  Object.assign(host, {
    searchStore:{search:{pageKey:'https://www.pinterest.com/search/',heroes:[{id:'hero',enabled:true,targetUrl:target}]},searchCache:{put(){}}},
    boardStore:{}, pinStore:{}, loadFailed:false, nativeRootOnly:true,
    boardUrlFromAddress:url=>url, nativeDisplayAddress:()=>host.navigationAddress || '',
    extractPinUrl:()=>'', shouldKeepSearchRootMounted:()=>true, nativeSearchPageVisible:()=>false,
    uiText:key=>key, rootStatusError:()=>'', rootStatusLoading:()=>true, nativeRootTabsVisible:()=>false,
    bottomBarCoordinator:{syncBottomBarForPageDepth(){
      assert.equal(host.nativeBoardVisible(),true,'Board loading cover is ready before hiding tabs');
      assert.equal(host.boardStore.pendingBoardUrl,target);events.push('hide-tabs');
    }}, syncFloatingTabsMotion(){events.push('schedule-tabs');},clearRootTabGuard(){},
    pageHistory:{visit(){events.push('route');}},boardNativeReads:{demand(){events.push('request');}}
  });
  host.buildRootStatus(1);assert.equal(statusCount,1,'Ordinary root loading remains available');
  await host.performSearchAction('hero','hero');
  assert.deepEqual(events,['hide-tabs','schedule-tabs','route','request']);
  host.buildRootStatus(1);assert.equal(statusCount,1,'Opening board must suppress search loading');
  host.boardStore.pendingBoardUrl='';host.boardStore.boardDetail.loading=false;
  host.buildRootStatus(1);assert.equal(statusCount,1,'Ready board still owns the screen');
  host.boardStore.boardDetail=undefined;host.boardStore.presentationPage='';host.navigationAddress='';
  host.buildRootStatus(1);assert.equal(statusCount,2,'Leaving board restores root status eligibility');
  console.log('Search hero: board cover, immediate tab hide, single loading owner and return passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
