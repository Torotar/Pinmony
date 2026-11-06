const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),ts=require(process.argv[2]||'typescript');
const parentSource=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
const paneSource=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets','utf8');
function host(source,names,globals={}){
 const ast=ts.createSourceFile('host.ts',source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true),methods=[];
 function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(ast)))methods.push(n.getText(ast));ts.forEachChild(n,visit);}visit(ast);
 assert.equal(methods.length,names.length);
 return vm.runInNewContext(ts.transpileModule('class Host {'+methods.join('\n')+'} Host;',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,globals);
}
const Parent=host(parentSource,['paneChromeOpacity','paneBackdropOpacity','categoryBackdropOpacity','updatePaneChrome'],{Curve:{EaseOut:'out'}});
const Pane=host(paneSource,['notifyChromeChanged','setHomeChromeCollapsed','updateHomeChrome'],{ScrollState:{Scroll:1}});
const p=new Parent(),pane=new Pane();let animations=0,y=100;
Object.assign(p,{paneChrome:new Map([['board',false]]),selectedId:'board',homeChromeCollapsed:false,pagerPosition:-1,paneKey:id=>id,pageTabs:()=>[{id:'board'}],snapshotFor:()=>({board:{},pins:[{}]}),getUIContext:()=>({animateTo:(options,change)=>{
 assert.equal(options.duration,180);assert.equal(options.curve,'out');animations++;change();
 assert.equal(p.categoryBackdropOpacity(),p.paneChromeOpacity('board'),'both opacity targets update in the same animation transaction');
}})});
Object.assign(pane,{homeChromeCollapsed:false,feedActive:true,restoringScroll:false,refreshing:false,home:{board:{},refreshing:false},chromeScrollDistance:0,feedScroller:{offset:()=>({yOffset:y})},onChromeChanged:collapsed=>p.updatePaneChrome('board',collapsed)});
pane.updateHomeChrome(19,1);assert.equal(animations,0,'preserve 20vp gesture threshold');
pane.updateHomeChrome(1,1);assert.equal(animations,1);assert.equal(p.paneChromeOpacity('board'),0);assert.equal(p.categoryBackdropOpacity(),0);
pane.updateHomeChrome(25,1);assert.equal(animations,1,'same target does not restart animation');
pane.updateHomeChrome(-20,1);assert.equal(animations,2);assert.equal(p.paneChromeOpacity('board'),1);assert.equal(p.categoryBackdropOpacity(),1);
pane.updateHomeChrome(20,1);y=0;pane.updateHomeChrome(0,0);assert.equal(animations,4,'return to top restores both in one transaction');
pane.restoringScroll=true;y=100;pane.updateHomeChrome(30,1);assert.equal(animations,4,'restoration cannot trigger the animation');
assert(parentSource.includes('chromeOpacity: this.paneChromeOpacity(tab.id)'));
assert(parentSource.includes('this.updatePaneChrome(tab.id, collapsed);'));
assert(paneSource.includes('.opacity(this.chromeOpacity)'));
assert(paneSource.includes(".width('100%').height(68 * this.chromeOpacity)"),'opaque summary surface is clipped with the same progress');
const summary=paneSource.slice(paneSource.lastIndexOf('if (this.home.board && this.canShowFeed())'));
assert(summary.indexOf('.opacity(this.chromeOpacity)') < summary.indexOf(".backgroundColor($r('app.color.page_background'))"),'only summary foreground fades; its background must stay opaque');
assert(summary.includes(".height(68)\n            .flexShrink(0)\n            .opacity(this.chromeOpacity)"),'inner summary keeps fixed layout while the outer reveal clips it');
assert(!paneSource.includes("@Watch('notifyChromeChanged')"),'notification must not leave the animation transaction through a deferred watch');
assert(!paneSource.includes('animateTo('),'pane cannot run a separate fade animation');
console.log('Home chrome sync: one 180ms EaseOut owner, shared opacity targets, collapse/expand/top, threshold, duplicate and restoration guards passed');
