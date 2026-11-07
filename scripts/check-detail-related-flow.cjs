const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const text = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const source = text.slice(text.indexOf('interface PinmonyDetailFlowRow'), text.indexOf('@Component\nexport struct PinmonyDetailPage'));
const js = ts.transpileModule(source + '\nexport { PinmonyDetailFlowSource };', { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 } }).outputText;
const loaded = {}; vm.runInNewContext(js, { exports: loaded, DataOperationType: {ADD:'add',DELETE:'delete'} });
const flow = new loaded.PinmonyDetailFlowSource();
const events = [];
flow.registerDataChangeListener({ onDataAdd: i => events.push(['add', i]), onDataDelete: i => events.push(['delete', i]), onDataChange: i => events.push(['change', i]), onDataReloaded: () => events.push(['reload']) });
const row = (key, fingerprint = '') => ({ key, fingerprint, kind: key });
flow.update([row('header'), row('a', 'one'), row('footer')]); events.length = 0;
flow.update([row('header'), row('a', 'one'), row('b', 'two'), row('footer')]);
assert.deepEqual(events, [['add', 2]], 'pagination adds only the new card'); events.length = 0;
flow.update([row('header'), row('a', 'updated'), row('b', 'two'), row('footer')]);
assert.deepEqual(events, [['change', 1]], 'same card identity receives changed content'); events.length = 0;
flow.update([row('header'), row('a', 'updated'), row('footer')]);
assert.deepEqual(events, [['delete', 2]], 'removal retains the other nodes'); events.length = 0;
flow.update([row('new-header'), row('footer')]); assert.deepEqual(events, [['reload']]);
assert.match(text, /WaterFlow\(\{ scroller: this\.detailScroller, sections: this\.detailSections \}\)[\s\S]*?LazyForEach\(this\.detailRows/);
assert.match(text, /\.cachedCount\(12, true\)/, 'mutable sections retain the native offscreen image cache window');
// The header is an eager FlowItem. Only recommendations/footer belong to the
// lazy source; async action/collage updates must not recycle that subtree.
const syncStart=text.indexOf('  private syncDetailFlow()'),syncEnd=text.indexOf('\n  private readonly detailPathStack',syncStart);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+text.slice(syncStart,syncEnd)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const host=new Host(),retained=new loaded.PinmonyDetailFlowSource(),notifications=[];
retained.registerDataChangeListener({onDataAdd:i=>notifications.push(['add',i]),onDataDelete:i=>notifications.push(['delete',i]),onDataChange:i=>notifications.push(['change',i]),onDataReloaded:()=>notifications.push(['reload'])});
let detail={pinUrl:'https://www.pinterest.com/pin/11/',actions:[{kind:'save',label:'Save',selected:false}],related:[]};
Object.assign(host,{displayedDetail:()=>detail,isRecommendReady:()=>true,recommendColumnCount:()=>2,detailRows:retained,detailFlowShape:'0:2',detailSections:{length:()=>3,splice:()=>{}} });
host.syncDetailFlow();notifications.length=0;
detail={...detail,actions:[{kind:'save',label:'My long board name',selected:true}]};host.syncDetailFlow();
assert.deepEqual(notifications,[],'save success does not recycle the eager header');notifications.length=0;
host.syncDetailFlow();assert.deepEqual(notifications,[],'same save state does not rebuild the header');
detail={...detail,actions:[{kind:'save',label:'Save',selected:false}]};host.syncDetailFlow();
assert.deepEqual(notifications,[],'confirmed undo does not recycle the eager header');
assert.match(text, /\.bindToScrollable\(this\.imageLayer === 'search' \? \[\] : \[this\.detailScroller\]\)/);
const content = text.slice(text.indexOf('  private detailContent()'), text.indexOf('  private videoRetryNotice()'));
const footer = text.slice(text.indexOf('  private detailFooter()'), text.indexOf('  private heroImage()'));
const destination = text.slice(text.indexOf('  private detailDestination('), text.indexOf('\n  build()', text.indexOf('  private detailDestination(')));
assert.match(content, /\.padding\(\{ left: 18, right: 18 \}\)/, 'the viewport has no fixed bottom inset');
assert(!/padding\(\{ bottom:/.test(footer), 'the footer does not add a gesture-area spacer');
assert.match(destination, /this\.imageLayer === 'search' \?[\s\S]*?LayoutSafeAreaEdge\.TOP, LayoutSafeAreaEdge\.BOTTOM/, 'detail extends to the bottom while photo search keeps its own layout');
console.log('Detail related flow: incremental append, change, removal, stable keys and shared scroller passed');


notifications.length=0;
detail={...detail,shuffleId:'77'};host.syncDetailFlow();
assert.deepEqual(notifications,[],'late collage identity updates outside the lazy source');notifications.length=0;
detail={...detail,shuffleLoading:true};host.syncDetailFlow();
assert.deepEqual(notifications,[],'collage loading does not invalidate the eager header');notifications.length=0;
detail={...detail,shuffleLoading:false,shuffle:{id:'77',items:[{id:'child',pinId:'22',isTappable:true}]}};host.syncDetailFlow();
assert.deepEqual(notifications,[],'resolved collage updates observable header props without recycling');notifications.length=0;
host.syncDetailFlow();assert.deepEqual(notifications,[],'unchanged collage retains header');
detail={...detail,related:[{id:'23',pinUrl:'pin/23'}],relatedLoading:true};host.syncDetailFlow();
assert.deepEqual(notifications,[['add',0]],'lazy indices exclude the eager header');
assert.equal(retained.totalCount(),2,'one recommendation plus footer, header remains outside lazy source');
const lazyStart=content.indexOf('LazyForEach(this.detailRows');
assert(lazyStart>0);
assert.match(content.slice(0,lazyStart),/FlowItem\(\)[\s\S]*this\.detailHeader\(\)/,'eager header is the first WaterFlow item');
assert(!content.slice(lazyStart).includes('this.detailHeader()'),'lazy recycling cannot dispose the media header');
assert(!text.slice(syncStart,syncEnd).includes('JSON.parse'),'header updates do not deep-clone collage masks or related pins');
let sections=[];
host.detailSections={length:()=>sections.length,splice:(_start,_count,next)=>{sections=next;}};
host.detailFlowShape='';host.syncDetailFlow();
assert.deepEqual(Array.from(sections,section=>section.itemsCount),[1,1,1],'sections count eager header, lazy recommendations and footer exactly once');
notifications.length=0;detail={...detail,related:[...detail.related,{id:'24',pinUrl:'pin/24'}]};host.syncDetailFlow();
assert.deepEqual(notifications,[['add',1]],'append preserves existing recommendation nodes');
assert.deepEqual(Array.from(sections,section=>section.itemsCount),[1,2,1]);
notifications.length=0;detail={...detail,related:[{id:'23',pinUrl:'pin/23',title:'updated'},detail.related[1]]};host.syncDetailFlow();
assert.deepEqual(notifications,[['change',0]],'changed recommendation still refreshes the correct lazy index');
notifications.length=0;detail={...detail,pinUrl:'https://www.pinterest.com/pin/99/',related:[]};host.syncDetailFlow();
assert.equal(retained.totalCount(),1,'switching Pin removes stale recommendation rows');
assert.equal(retained.getData(0).key,'footer:'+detail.pinUrl);
assert.deepEqual(Array.from(sections,section=>section.itemsCount),[1,1],'empty content keeps header and footer sections');
let ready=false;host.isRecommendReady=()=>ready;
detail={...detail,related:[{id:'30',pinUrl:'pin/30'}],shuffleLoading:true};
host.syncDetailFlow();assert.equal(retained.totalCount(),1,'loading recommendations do not enter the lazy source');
ready=true;host.syncDetailFlow();assert.equal(retained.totalCount(),2,'ready recommendations are inserted after the retained header');
notifications.length=0;detail={...detail,shuffleLoading:false,shuffleError:'fixture error',relatedError:'fixture retry'};host.syncDetailFlow();
assert.deepEqual(notifications,[],'error feedback updates observable header/footer without rebuilding list rows');
ready=false;host.syncDetailFlow();assert.equal(retained.totalCount(),1,'readiness reset clears stale cards and retains footer');
console.log('Detail retained header: collage/save updates, recommendation indices, section counts and Pin switch passed');

// Each callback must observe exactly the mutation it reports, including retained suffixes.
const batch = new loaded.PinmonyDetailFlowSource();
batch.update([row('a'), row('footer', 'old')]);
const snapshots = [];
batch.registerDataChangeListener({
  onDataAdd: i => snapshots.push(['add', i, Array.from({length: batch.totalCount()}, (_, n) => batch.getData(n).key)]),
  onDataDelete: i => snapshots.push(['delete', i, Array.from({length: batch.totalCount()}, (_, n) => batch.getData(n).key)]),
  onDataChange: i => snapshots.push(['change', i, batch.getData(i).fingerprint]),
  onDataReloaded: () => snapshots.push(['reload'])
});
batch.update([row('a'), row('b'), row('c'), row('footer', 'new')]);
assert.deepEqual(snapshots, [['add',1,['a','b','footer']],['add',2,['a','b','c','footer']],['change',3,'new']]);
snapshots.length = 0;
batch.update([row('a'), row('footer', 'last')]);
assert.deepEqual(snapshots, [['delete',2,['a','b','footer']],['delete',1,['a','footer']],['change',1,'last']]);
ready = true;
detail={...detail,related:[{id:'30',pinUrl:'pin/30'},{id:'30',pinUrl:'pin/30'},{id:'30',pinUrl:'pin/30',kind:'topic'}]};
host.syncDetailFlow();
assert.equal(retained.totalCount(),3,'duplicate pins collapse while distinct content kinds retain their own node');
assert.notEqual(retained.getData(0).key,retained.getData(1).key);
assert.deepEqual(Array.from(sections,section=>section.itemsCount),[1,2,1]);
console.log('Detail batch notification snapshots, suffix refresh and typed deduplication passed');
const traces=[];
const audited=new loaded.PinmonyDetailFlowSource(message=>traces.push(message));
const secretRow=row('private-content-key');
audited.update([secretRow]);
for(let i=0;i<20;i++)assert.equal(audited.renderKey(secretRow,0),secretRow.key);
assert.equal(traces.filter(line=>line.includes('phase=key')).length,16,'render diagnostics have a per-update budget');
assert(traces.every(line=>!line.includes(secretRow.key)),'diagnostics contain no content identifiers');
const traceCount=traces.length;audited.update([row(secretRow.key)]);
assert.equal(traces.length,traceCount,'unchanged snapshots do not reset trace budget');
audited.update([row('replacement')]);audited.renderKey(secretRow,0);
assert(traces.at(-1).includes('matches=false'),'stale key requests are identifiable without changing the key');
console.log('Detail trace: stable keys, generation, bounded output and content privacy passed');
// Model the framework's lifetime-wide notification-family contract. Providing
// both methods does not mean they may be alternated on one LazyForEach.
const lifecycleSource=new loaded.PinmonyDetailFlowSource();
const currentKeys=()=>Array.from({length:lifecycleSource.totalCount()},(_,i)=>lifecycleSource.renderKey(lifecycleSource.getData(i),i));
function guardedListener() {
  let family='',mirror=currentKeys();const calls=[];
  function enter(next) {
    if(family&&family!==next)throw Error('onDatasetChange cannot be used with other interface');
    family=next;
  }
  function verify(kind) {assert.deepEqual(mirror,currentKeys(),'each '+kind+' observes its own matching snapshot');calls.push(kind);}
  return {calls,listener:{
    onDatasetChange:()=>enter('dataset'),
    onDataAdd:i=>{enter('legacy');mirror.splice(i,0,lifecycleSource.getData(i).key);verify('add');},
    onDataDelete:i=>{enter('legacy');mirror.splice(i,1);verify('delete');},
    onDataChange:i=>{enter('legacy');mirror[i]=lifecycleSource.getData(i).key;verify('change');},
    onDataReloaded:()=>{enter('legacy');mirror=currentKeys();verify('reload');}
  }};
}
const observers=[guardedListener(),guardedListener()];
observers.forEach(observer=>lifecycleSource.registerDataChangeListener(observer.listener));
lifecycleSource.update([row('footer')]); // legacy notification before first multi-card page
const pageRows=Array.from({length:8},(_,i)=>row('card-'+i));
lifecycleSource.update([...pageRows,row('footer')]); // previously switched family and crashed
lifecycleSource.update([...pageRows.map((item,i)=>row(item.key,i===2?'changed':'')),row('footer')]);
lifecycleSource.update([...pageRows,row('next-a'),row('next-b'),row('footer')]);
lifecycleSource.update([...pageRows,row('footer')]);
lifecycleSource.update([row('card-7'),row('card-0'),row('footer')]);
lifecycleSource.update([]);
lifecycleSource.update([row('footer-new-pin')]);
lifecycleSource.update([...pageRows,row('footer-new-pin')]);
for(const observer of observers)for(const kind of ['add','delete','change','reload'])assert(observer.calls.includes(kind));
const count=observers[0].calls.length;lifecycleSource.update([...pageRows,row('footer-new-pin')]);
assert.equal(observers[0].calls.length,count,'same content does not notify');
lifecycleSource.unregisterDataChangeListener(observers[1].listener);
const detachedCount=observers[1].calls.length;lifecycleSource.update([row('footer-new-pin')]);
assert.equal(observers[1].calls.length,detachedCount,'detached observer remains silent');
assert.throws(()=>observers[0].listener.onDatasetChange([]),/cannot be used with other interface/,'guard rejects the original mixed-family sequence');
assert(!/listener\.onDatasetChange\(/.test(source),'detail source uses only one family for its full lifetime');
console.log('Detail notification lifetime: first page, pagination, changes, removal, reorder, clear, new Pin and multiple listeners passed');
