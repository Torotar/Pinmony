const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
function method(name){const start=source.indexOf('  private '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n  private ',start+1));}
const timers=[];
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method('fillInitialViewport')+method('resultsReachEnd')+method('resultsVisible')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{setTimeout:fn=>timers.push(fn),PinmonyRuntimeLog:{info(){}}});
let requests=0;
const h=new Host();Object.assign(h,{automaticLoadingEnabled:true,initialFillScheduled:false,initialFillCount:0,initialFillResultsCount:-1,resultsViewportReady:true,actionsReady:false,resultsReadsReady:true,loading:false,restoringResultsScroll:false,fillGeneration:0,snapshot:{api:true,apiBusy:false,apiEnded:false,apiContinuationPaused:true,apiError:'',query:'fixture',pageKey:'/search/pins/?q=fixture',results:[{id:'1'}]},resultsScroller:{offset:()=>({yOffset:0}),isAtEnd:()=>true},onLoadMore:()=>requests++,committedQuery:()=>true,upcomingImageUrls:[],lastPrefetchResultCount:-1});
h.fillInitialViewport();h.resultsReachEnd();h.resultsVisible(0,0);assert.equal(requests,0);assert.equal(timers.length,0,'paused continuation waits for explicit action');
h.snapshot.apiContinuationPaused=false;h.fillInitialViewport();assert.equal(timers.length,1);h.snapshot.apiContinuationPaused=true;timers.shift()();assert.equal(requests,0,'already scheduled fill rechecks the pause');
h.snapshot.apiContinuationPaused=false;h.fillInitialViewport();timers.shift()();assert.equal(requests,1,'ordinary viewport loading remains enabled');
const statusSource=source.slice(source.indexOf('  private searchStatus() {'),source.indexOf('  private searchHeader('));
const retry=statusSource.match(/actionText: this.uiText\("pm_reload_df7392cc"\), onAction: (\(\) => \{[\s\S]*?)\} \}\)/);assert(retry);const callback=retry[1]+'}';let more=0,refresh=0;const retryHost={snapshot:{apiActive:true,apiEnded:false},onLoadMore:()=>more++,onRetry:()=>refresh++};Function('return '+callback).call(retryHost)();assert.equal(more,1);assert.equal(refresh,0,'failed continuation retries its cursor');retryHost.snapshot.apiActive=false;Function('return '+callback).call(retryHost)();assert.equal(refresh,1,'initial failure keeps initial retry');
assert(source.includes('this.snapshot.results.length > 0 && this.snapshot.apiContinuationPaused'));
console.log('Filtered continuation UI: bounded automatic loading, delayed callback isolation, cursor retry and existing-results manual action passed');
