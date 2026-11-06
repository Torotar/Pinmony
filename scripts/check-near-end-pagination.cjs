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
const Home=methods('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets',['loadNearEnd','loadNextPageAtEnd']);
const page=new Home();let loads=0;Object.assign(page,{paginationTrace(){},onLoadMore:()=>loads++});

page.home={dataSource:'api',pageKey:'home',session:1,selectedTab:'all',pins:Array.from({length:40},(_,i)=>({id:String(i)}))};
Object.assign(page,{restoreDone:true,restoringScroll:false,visibleFirst:0,visibleLast:5,feedActive:true,paginationReady:true,pendingTabId:'',loading:false,refreshing:false,nearEndKey:''});
let baseline=loads;page.loadNearEnd();assert.equal(loads,baseline,'far from end does not load');
page.visibleFirst=22;page.visibleLast=27;page.loadNearEnd();assert.equal(loads,baseline+1,'two screens remaining starts pagination');
page.loadNearEnd();assert.equal(loads,baseline+1,'repeated visible callbacks cannot duplicate page');
page.home.pins.push({id:'40'});page.home.loadingMore=true;page.loadNearEnd();assert.equal(loads,baseline+1,'busy read blocks demand');
page.home.loadingMore=false;page.feedActive=false;page.loadNearEnd();assert.equal(loads,baseline+1,'hidden page cannot load');
page.feedActive=true;page.restoringScroll=true;page.loadNearEnd();assert.equal(loads,baseline+1,'restoring position cannot load');
page.restoringScroll=false;page.home.sourceError='failed';page.loadNearEnd();assert.equal(loads,baseline+1,'failed pagination waits for explicit retry');

console.log('Near-end home pagination: early loading, deduplication, busy, inactive, restore and error guards passed');
