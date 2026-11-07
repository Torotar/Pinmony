const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const start = source.indexOf('  private boardTitleMenu(');
const method = source.slice(start, source.indexOf('\n  private ', start + 1)).replace('private ', '');
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + method + '} Host;', {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText, { $r: value => value, SymbolGlyphModifier: class { fontSize() { return this; } fontColor() { return this; } } });
const host = new Host();
Object.assign(host, { uiText: key => key, isDiscoveryBoard: () => false });
for (const editable of [undefined, false, true]) {
  host.snapshot = { ready: false, editable };
  const menu = host.boardTitleMenu();
  assert(menu.some(item => item.content.icon === 'app.media.lucide_ellipsis'));
  assert(!menu.some(item => item.content.icon instanceof Object));
  assert(menu.every(item => !item.content.isEnabled));
}
host.snapshot = { ready: true, editable: true };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'));
host.snapshot = { ready: true, editable: false };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'non-editable alone does not imply another user');
host.snapshot = { ready: true, editable: false, canFollow: false };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'own saved collection never shows follow');
host.snapshot = { ready: true, editable: true, canFollow: true };
assert(host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'own board cannot show follow even with conflicting eligibility');
host.snapshot = { ready: true, editable: false, canFollow: true };
assert(!host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'));
host.snapshot = { ready: true, editable: false, canFollow: false, followBusy: true };
assert(!host.boardTitleMenu().some(item => item.content.icon === 'app.media.lucide_ellipsis'), 'pending follow retains its disabled control');
console.log('Board title: loading never infers follow permission; owned board keeps options; confirmed visitor behavior preserved');
const loadingStart=source.indexOf('  private initialBoardLoading('),loadingEnd=source.indexOf('\n  private ',loadingStart+1);
const Loading=vm.runInNewContext(ts.transpileModule('class Loading {'+source.slice(loadingStart,loadingEnd)+'} Loading;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const loading=new Loading();Object.assign(loading,{phase:()=>'',isDiscoveryBoard:()=>true,snapshot:{loading:true,ready:false}});
assert.equal(loading.initialBoardLoading(),true,'discovery initial read uses the centered overlay');
for(const snapshot of [{loading:false,ready:true},{loading:false,ready:false,error:'failed'},{loading:true,ready:false,postOperationLoading:true},{loading:true,ready:true,refreshing:true}]){loading.snapshot=snapshot;assert.equal(loading.initialBoardLoading(),false);}
loading.snapshot={loading:true,ready:false};loading.phase=()=> 'section';assert.equal(loading.initialBoardLoading(),false);
loading.phase=()=>'';loading.isDiscoveryBoard=()=>false;assert.equal(loading.initialBoardLoading(),true,'ordinary board entry uses the centered overlay');
loading.snapshot={loading:true,ready:true};assert.equal(loading.initialBoardLoading(),true,'metadata readiness must not move the spinner before the initial feed finishes');
loading.boardRefreshActive=true;assert.equal(loading.initialBoardLoading(),false,'gesture refresh stays below the title');loading.boardRefreshActive=false;
assert(source.includes('!this.initialBoardLoading() && !this.snapshot.postOperationLoading'),'initial discovery loading is not duplicated beneath the header');
assert.match(source,/else if \(this.initialBoardLoading\(\)\) \{\s*Stack\(\{ alignContent: Alignment.Center \}\) \{\s*LoadingProgress\(\)[\s\S]*?\.width\('100%'\)\.height\('100%'\)/,'indicator uses a full-page non-scrolling overlay');
const maskStart=source.indexOf('  private discoveryLoadingMask('),maskEnd=source.indexOf('\n  private ',maskStart+1);
const Mask=vm.runInNewContext(ts.transpileModule('class Mask {'+source.slice(maskStart,maskEnd)+'} Mask;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const mask=new Mask();mask.isDiscoveryBoard=()=>true;mask.initialBoardLoading=()=>loading.initialBoardLoading();
loading.snapshot={loading:true,ready:false};assert.equal(mask.discoveryLoadingMask(),true);
loading.snapshot={loading:false,ready:true};assert.equal(mask.discoveryLoadingMask(),false,'success removes mask');
loading.snapshot={loading:false,ready:false,error:'unavailable'};assert.equal(mask.discoveryLoadingMask(),false,'failure does not cover retry');
loading.snapshot={loading:true,refreshing:true};assert.equal(mask.discoveryLoadingMask(),false,'refresh keeps its own indicator');
loading.snapshot={loading:true};mask.isDiscoveryBoard=()=>false;assert.equal(mask.discoveryLoadingMask(),false,'ordinary board unchanged');
assert(source.includes(".backgroundColor(this.discoveryLoadingMask() ? '#66808080' : Color.Transparent)"));
assert(source.includes('.hitTestBehavior(this.discoveryLoadingMask() ? HitTestMode.Block : HitTestMode.None)'));
assert(source.includes("this.snapshot.postOperationLoading || this.discoveryLoadingMask() ? 'no-hide-descendants' : 'auto'"));
for (const ready of [false, true]) {
  host.snapshot = { pageKey: 'https://www.pinterest.com/example/pins/', ready, editable: false, canFollow: true };
  assert.equal(host.boardTitleMenu().length, 0, 'all Pins collection has no title actions even during loading');
}
