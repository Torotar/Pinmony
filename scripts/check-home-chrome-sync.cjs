const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const root=process.argv[3]||'.';
const parentSource=fs.readFileSync(root+'/feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
const paneSource=fs.readFileSync(root+'/feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets','utf8');
function host(source,names,globals={}){
 const ast=ts.createSourceFile('host.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true),methods=[];
 function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(ast)))methods.push(n.getText(ast));ts.forEachChild(n,visit);}visit(ast);
 assert.equal(methods.length,names.length);
 return vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,globals);
}
assert(!parentSource.match(/private updatePaneChrome\([\s\S]*?\n  \}/)[0].includes('animateTo('),'scroll-driven chrome commits must not open a page-wide animation transaction');
const Parent=host(parentSource,['paneChromeOpacity','paneBackdropOpacity','categoryBackdropOpacity','categoryBackdropAnimation','updatePaneChrome','syncPagerChrome'],{Curve:{EaseOut:'out'}});
const Pane=host(paneSource,['notifyChromeChanged','setHomeChromeCollapsed','updateHomeChrome'],{ScrollState:{Scroll:1}});
const p=new Parent(),pane=new Pane();let commits=0,y=100;
const states=new Map([['board',false]]),set=states.set.bind(states);
states.set=(key,value)=>{commits++;return set(key,value);};
Object.assign(p,{chromeState:{backdrop:{opacity:0,moving:false}},pagerBindingKey:'',pagerBindingRevision:0,pagerChromeIndex:-1,paneChrome:states,selectedId:'board',homeChromeCollapsed:false,pagerPosition:-1,paneKey:id=>id,pageTabs:()=>[{id:'board'}],snapshotFor:()=>({board:{},pins:[{}]}),getUIContext:()=>{throw Error('page-wide animation would capture the moving feed');}});
Object.assign(pane,{homeChromeCollapsed:false,feedActive:true,restoringScroll:false,refreshing:false,home:{board:{},refreshing:false},chromeScrollDistance:0,feedScroller:{offset:()=>({yOffset:y})},onChromeChanged:collapsed=>p.updatePaneChrome('board',collapsed)});
pane.updateHomeChrome(19,1);assert.equal(commits,0,'preserve 20vp gesture threshold');
pane.updateHomeChrome(1,1);assert.equal(commits,1);assert.equal(p.paneChromeOpacity('board'),0);assert.equal(p.categoryBackdropOpacity(),0);
pane.updateHomeChrome(25,1);assert.equal(commits,1,'same target does not restart animation');
pane.updateHomeChrome(-20,1);assert.equal(commits,2);assert.equal(p.paneChromeOpacity('board'),1);assert.equal(p.categoryBackdropOpacity(),1);
pane.updateHomeChrome(20,1);y=0;pane.updateHomeChrome(0,0);assert.equal(commits,4,'return to top restores both targets');
pane.restoringScroll=true;y=100;pane.updateHomeChrome(30,1);assert.equal(commits,4,'restoration cannot trigger the animation');
assert.equal(p.categoryBackdropAnimation().duration,180);assert.equal(p.categoryBackdropAnimation().curve,'out');
for(const position of [0,.1,.5,.99,1]){p.pagerPosition=position;assert.equal(p.categoryBackdropAnimation().duration,0,'horizontal progress must not receive a second easing animation');}
p.pagerPosition=-1;p.updatePaneChrome('other',true);assert.equal(p.homeChromeCollapsed,false,'hidden pane cannot change selected chrome');
assert.equal(p.paneChromeOpacity('other'),0,'retain independent collapsed state');
assert.match(parentSource, /\.opacity\(this\.state\.opacity\)\s*\.animation\(\{ duration: this\.state\.moving \? 0 : 180, curve: Curve\.EaseOut \}\)/);
assert(summaryAnimationCount()===2,'summary foreground and reveal animate locally with matching timing');
function summaryAnimationCount(){return (paneSource.slice(paneSource.lastIndexOf('if (this.home.board && this.canShowFeed())')).match(/\.animation\(\{ duration: 180, curve: Curve.EaseOut \}\)/g)||[]).length;}
assert(parentSource.includes('chromeOpacity: this.paneChromeOpacity(tab.id)'));
assert(parentSource.includes('this.updatePaneChrome(tab.id, collapsed);'));
assert(paneSource.includes('.opacity(this.chromeOpacity)'));
assert(paneSource.includes(".width('100%').height(68 * this.chromeOpacity)"),'opaque summary surface is clipped with the same progress');
const summary=paneSource.slice(paneSource.lastIndexOf('if (this.home.board && this.canShowFeed())'));
assert(summary.indexOf('.opacity(this.chromeOpacity)') < summary.indexOf(".backgroundColor($r('app.color.page_background'))"),'only summary foreground fades; its background must stay opaque');
assert(summary.includes(".height(68)\n            .flexShrink(0)\n            .opacity(this.chromeOpacity)"),'inner summary keeps fixed layout while the outer reveal clips it');
assert(!paneSource.includes("@Watch('notifyChromeChanged')"),'notification must not leave the animation transaction through a deferred watch');
assert(!paneSource.includes('animateTo('),'pane must not capture the moving feed in an explicit animation');
const feed=paneSource.slice(paneSource.indexOf('  private feedContent('),paneSource.indexOf('\n  build()'));
assert(!feed.includes('this.chromeOpacity'),'chrome motion must not change feed geometry');
console.log('Home chrome sync: scoped 180ms EaseOut attributes, unanimated feed, shared targets, horizontal tracking, collapse/expand/top, threshold, duplicate and restoration guards passed');
