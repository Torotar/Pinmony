const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function methods(file, names, globals = {}) {
  const source = fs.readFileSync(file, 'utf8');
  const bodies = names.map(name => {
    const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
    assert(start >= 0, name);
    const tail = source.slice(start); const end = tail.slice(1).search(/\n  (?:private |@|on\w+\??:)/) + 1;
    return tail.slice(0, end);
  });
  return vm.runInNewContext(ts.transpileModule('class Subject {' + bodies.join('\n') + '} Subject;', {
    compilerOptions: {target:ts.ScriptTarget.ES2021}
  }).outputText, globals);
}
const Home = methods('feature_home/src/main/ets/components/PinmonyHomePage.ets',
  ['loadNextPageAtEnd','resumePendingEnd']);
const page = new Home(); let loads = 0, atEnd = true;
Object.assign(page, {home:{dataSource:'api',pins:[{}],endReached:false},feedActive:true,paginationReady:false,
  loading:false,refreshing:false,pendingTabId:'',actionsReady:false,paginationTrace(){},
  feedScroller:{isAtEnd:()=>atEnd},onLoadMore:()=>loads++});
page.loadNextPageAtEnd(); assert.equal(loads,0); assert.equal(page.pendingEnd,true);
page.paginationReady=true; page.resumePendingEnd(); assert.equal(loads,1,'read readiness is independent of write actions');
page.resumePendingEnd(); assert.equal(loads,1,'pending edge resumes once');
page.home.sourceError='category error';page.home.categorySourceFailure=true;page.loadNextPageAtEnd();assert.equal(loads,2);
page.home.loadingMore=true;page.loadNextPageAtEnd();page.home.loadingMore=false;page.resumePendingEnd();assert.equal(loads,2,'busy edges cannot produce automatic failure retry loops');
page.loading=true;page.loadNextPageAtEnd();page.loading=false;atEnd=false;page.resumePendingEnd();assert.equal(loads,2,'scrolling away cancels the pending edge');
page.home.endReached=true;page.loadNextPageAtEnd();assert.equal(loads,2);
const Index = methods('entry/src/main/ets/pages/Index.ets',['updateLoginPresentation','authWebVisible'], {
  isPinterestAuthRoute:url=>/^https:\/\/(?:www|uk)\.pinterest\.com\/(?:login|signup|auth|challenge)\//.test(url)
});
const host = new Index();Object.assign(host,{nativeLoginEnabled:true,loginHostMounted:true,authStatus:'unauthenticated',loadFailed:false});
for(const url of ['https://www.pinterest.com/login/','https://accounts.google.com/signin/']) {
  host.updateLoginPresentation(url);assert.equal(host.authWebVisible(),true);
}
for(const url of ['about:blank','https://www.google.com/accounts/intermediate','javascript:void(0)']) {
  host.updateLoginPresentation(url);assert.equal(host.authWebVisible(),true,'intermediate URLs cannot hide the login controls');
}
const loginSource=fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets','utf8');
const override=loginSource.match(/\.onOverrideUrlLoading\((\(request: WebResourceRequest\) => \{[\s\S]*?)\n            \}\)/)[1]+'\n}';
let navigations=0;
const handle=vm.runInNewContext(ts.transpileModule('const handle='+override+';handle;',{
  compilerOptions:{target:ts.ScriptTarget.ES2021}
}).outputText,{rejectGoogleLoginNavigation:(_view,url,main)=>main&&url.startsWith('https://accounts.google.com/'),view:{isCurrent:()=>true,controller:{},authenticated:false,lifecycle:{overrideUrl(){navigations++;return false;}}}});
assert.equal(handle({isMainFrame:()=>false,getRequestUrl:()=> 'https://accounts.google.com/gsi/iframe'}),false);
assert.equal(navigations,0);
assert.equal(handle({isMainFrame:()=>true,getRequestUrl:()=> 'https://accounts.google.com/signin/'}),true);
assert.equal(navigations,0,'top-level Google navigation cannot reach the login coordinator');
assert.equal(handle({isMainFrame:()=>true,getRequestUrl:()=> 'https://www.pinterest.com/login/'}),false);
assert.equal(navigations,1,'Pinterest password navigation is unchanged');
host.updateLoginPresentation('https://www.pinterest.com/');assert.equal(host.authWebVisible(),false,'hide before native evidence arrives, without declaring authentication');
assert.equal(host.authStatus,'unauthenticated');host.updateLoginPresentation('https://www.pinterest.com/challenge/');assert.equal(host.authWebVisible(),true);
host.authStatus='authenticated';assert.equal(host.authWebVisible(),false);
console.log('Home/login presentation: deferred edge, read gate, category errors, no loops, scroll-away and login navigation mask passed');
