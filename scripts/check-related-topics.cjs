const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function load(file,deps={}){const exports={};vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,{exports,require:require('./local-message-test-fixture.cjs').withLocalMessages(name=>deps[name]||{PinmonyI18n:{message:k=>k}}),URL});return exports;}
const root='feature_pin/src/main/ets/';
const {readRelatedPresentation,relatedTopicSearchUrl}=load(root+'services/PinmonyRelatedPresentation.ets');
const parent='https://www.pinterest.com/pin/100/';
const image={url:'https://i.pinimg.com/synthetic.jpg',width:474,height:600};
const pin=id=>({id,type:'pin',images:{'474x':image}});
const topic=(id,title='Topic')=>({id,type:'explorearticle',title:{format:title},cover_images:[{'474x':image}],action:{url:'/search/pins/?q=design&rs=synthetic'}});
const story=(id='module')=>({id,type:'story',story_type:'BUBBLE_ONE_COL',title:{format:'Ideas you might love',args:[]},objects:[topic('a'),topic('b')]});
const body=(data,bookmark='next')=>JSON.stringify({resource_response:{status:'success',data,bookmark}});
const mapped=readRelatedPresentation(body([pin('1'),story(),pin('2')]),parent);
assert.deepEqual(Array.from(mapped.pins,p=>p.id),['api:1','story:module','api:2']);
assert.equal(mapped.pins[1].topics.length,2);
assert.equal(mapped.pins[1].topics[0].targetUrl,'https://www.pinterest.com/search/pins/?q=design');
assert.equal(readRelatedPresentation(body([story()]),parent).pins.length,1,'module-only response is valid');
for(const target of ['https://evil.invalid/search/pins/?q=a','//evil.invalid/search/pins/?q=a','javascript:alert(1)','/search/pins/?q=a&q=b','/search/pins/?q=%zz','/search/pins/?q=%00','/search/boards/?q=a'])assert.equal(relatedTopicSearchUrl(target,parent),'');
assert.equal(relatedTopicSearchUrl('/search/pins/?q=%E6%8F%92%E7%94%BB',parent),'https://www.pinterest.com/search/pins/?q=%E6%8F%92%E7%94%BB');
const broken=story();broken.objects=[{...topic('bad'),cover_images:[]},topic('ok'),{...topic('evil'),action:{url:'https://evil.invalid/'}}];
assert.equal(readRelatedPresentation(body([broken]),parent).pins[0].topics.length,1);
assert.equal(readRelatedPresentation(body([story(),story()]),parent).pins.length,1);
const reads=fs.readFileSync('entry/src/main/ets/app/PinmonyDetailNativeReads.ets','utf8');
const mergeStart=reads.indexOf('      mapped.pins.forEach('),mergeEnd=reads.indexOf('      this.related = merged;',mergeStart);
const mergeContext={merged:mapped.pins.slice(),mapped:readRelatedPresentation(body([story(),story('second'),pin('2'),pin('3')]),parent)};
vm.runInNewContext(ts.transpileModule(reads.slice(mergeStart,mergeEnd),{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,mergeContext);
assert.deepEqual(Array.from(mergeContext.merged,p=>p.id),['api:1','story:module','api:2','story:second','api:3'],'pagination retains distinct modules and deduplicates repeated modules/Pins');
const {PinmonyDetailCache}=load(root+'services/PinmonyDetailCache.ets');
const cache=new PinmonyDetailCache();cache.put('100',{pinUrl:parent,actions:[],related:mapped.pins},12);
assert.equal(cache.get('100').detail.related[1].topics[0].targetUrl,mapped.pins[1].topics[0].targetUrl);
assert.equal(cache.get('100').detail.related[1].id,'story:module');
const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const start=index.indexOf('  private openDetailRelatedTopic('),end=index.indexOf('\n  private ',start+1);
const context={relatedTopicSearchUrl,PIN_NATIVE_SEARCH_READS_ENABLED:true,PinmonyRuntimeLog:{info(){}}};
vm.runInNewContext(ts.transpileModule('class Navigate {'+index.slice(start,end)+'} globalThis.Navigate=Navigate;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,context);
const calls=[],nav=new context.Navigate();
Object.assign(nav,{authStatus:'authenticated',activeTab:0,topicSearchReturns:[],nativeBusinessSessionContext:()=>({authenticated:true,accountId:'synthetic',generation:1}),pinStore:{videoForeground:true,detailPin:parent,detail:{pinUrl:parent,related:mapped.pins},detailCache:{put:()=>calls.push('cache')}},pinIdentity:()=> '100',pageHistory:{visit:()=>calls.push('history')},clearDetail:()=>calls.push('clear'),tabsController:{changeIndex:()=>calls.push('tab')},searchNativeReads:{navigate:url=>calls.push(url)}});
nav.openDetailRelatedTopic('story:module','missing',parent);assert.equal(calls.length,0);
nav.openDetailRelatedTopic('story:module','a',parent.replace('100','101'));assert.equal(calls.length,0);
nav.openDetailRelatedTopic('story:module','a',parent);assert.deepEqual(calls,['cache','history','clear','tab','https://www.pinterest.com/search/pins/?q=design']);
nav.businessSuspended=true;nav.openDetailRelatedTopic('story:module','a',parent);assert.equal(calls.length,5);
assert.equal(nav.topicSearchReturns[0].pin,parent);
assert.equal(nav.topicSearchReturns[0].tab,0);
const returnStart=index.indexOf('  private restoreTopicSearchParent('),returnEnd=index.indexOf('\n  private ',returnStart+1);
vm.runInNewContext(ts.transpileModule('class ReturnTopic {'+index.slice(returnStart,returnEnd)+'} globalThis.ReturnTopic=ReturnTopic;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,context);
function returning(overrides={}) {
  const events=[],host=new context.ReturnTopic();
  Object.assign(host,{topicSearchReturns:nav.topicSearchReturns.slice(),nativeBusinessSessionContext:nav.nativeBusinessSessionContext,
    currentSearchPageKey:()=>nav.topicSearchReturns[0].page,searchNativeReads:{pause:()=>events.push('pause')},searchDiscoveryNativeReads:{pause(){}},searchStore:{},
    clearSearch:()=>events.push('clear-search'),tabsController:{changeIndex:tab=>events.push(tab)},pageHistory:{cancelBack(){}},backOnePage:(fallback,target)=>{events.push(target);return true;},...overrides});
  return {host,events};
}
const restored=returning();assert.equal(restored.host.restoreTopicSearchParent(),true);
assert.deepEqual(restored.events,['pause','clear-search',0,parent]);assert.equal(restored.host.topicSearchReturns.length,0);
assert.equal(restored.host.restoreTopicSearchParent(),false,'context is consumed once');
for(const overrides of [{nativeBusinessSessionContext:()=>({authenticated:true,accountId:'another',generation:1})},
  {nativeBusinessSessionContext:()=>({authenticated:true,accountId:'synthetic',generation:2})},
  {currentSearchPageKey:()=> 'https://www.pinterest.com/search/pins/?q=unrelated'}]) {
  const changed=returning(overrides);assert.equal(changed.host.restoreTopicSearchParent(),false);assert.equal(changed.events.length,0);assert.equal(changed.host.topicSearchReturns.length,0);
}
const backStart=index.indexOf('  private backFromSearch('),backEnd=index.indexOf('\n  private ',backStart+1),back=index.slice(backStart,backEnd);
assert(back.indexOf('restoreTopicSearchParent()')<back.indexOf('searchOpenHistory()'),'origin return precedes search landing/history');
const nested=returning();nested.host.topicSearchReturns.push({...nav.topicSearchReturns[0],pin:parent.replace('100','200'),tab:1});
assert.equal(nested.host.restoreTopicSearchParent(),true);assert.equal(nested.events.at(-1),parent.replace('100','200'));
assert.equal(nested.host.topicSearchReturns.length,1,'nested theme navigation preserves outer source');
const tabStart=index.indexOf('  private selectNativeRootTab('),tabEnd=index.indexOf('\n  private ',tabStart+1);
vm.runInNewContext(ts.transpileModule('class TabContext {'+index.slice(tabStart,tabEnd)+'} globalThis.TabContext=TabContext;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,context);
const tab=new context.TabContext();Object.assign(tab,{topicSearchReturns:nav.topicSearchReturns.slice(),navigationCoordinator:{selectNativeRootTab(){}}});
tab.selectNativeRootTab(1);assert.equal(tab.topicSearchReturns.length,1);tab.selectNativeRootTab(0);assert.equal(tab.topicSearchReturns.length,0);
console.log('Related topics: ordered module mapping, bounded images, safe query, cache and native navigation passed');
