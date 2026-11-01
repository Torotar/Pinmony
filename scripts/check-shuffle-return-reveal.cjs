const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const tree = ts.createSourceFile('page.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const names = ['shuffleThumbnailWidth', 'shuffleReturnOffset', 'revealShuffleReturn', 'onShuffleSelectionChanged'];
const methods = [];
function visit(n) {
  if (ts.isMethodDeclaration(n) && names.includes(n.name.getText(tree))) methods.push(n.getText(tree));
  ts.forEachChild(n, visit);
}
visit(tree);
assert.equal(methods.length, names.length);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;', {compilerOptions:{target:99}}).outputText,
  {Curve:{EaseInOut:'ease-in-out'},setTimeout(){}, clearTimeout(){}});
function setup({x=0,y=40,stripY=400,selected='',full=false,active=true}={}) {
  const horizontal=[],vertical=[];
  const host=new Host();
  const snapshot={pinUrl:'collage',shuffle:{items:Array.from({length:10},(_,i)=>({id:'item-'+i,tappable:true,hidden:false,alpha:1,imageUrl:'photo-'+i,imageWidth:80,imageHeight:100}))}};
  Object.assign(host,{shuffleReturnItem:'item-9',shuffleRevealedKey:'',shuffleSelectedImage:selected,shuffleFullDetail:full,videoActive:active,
    displayedDetail:()=>snapshot,titleContentInset:()=>100,traceId:1,
    shuffleStripScroller:{offset:()=>({xOffset:x}),scrollTo:opts=>horizontal.push(opts)},
    detailScroller:{offset:()=>({yOffset:y}),scrollTo:opts=>vertical.push(opts)},
    getUIContext:()=>({px2vp:n=>n/2,getComponentUtils:()=>({getRectangleById:id=>id.includes('strip')?
      {windowOffset:{y:stripY},size:{width:600,height:200}}:{windowOffset:{y:0},size:{height:1600}}})})});
  return {host,horizontal,vertical,snapshot};
}
let test=setup();test.host.revealShuffleReturn();
assert.equal(test.horizontal[0].xOffset,608,'rightmost hidden thumbnail moves only far enough to fit');
assert.equal(test.horizontal[0].animation.curve,'ease-in-out','horizontal reveal accelerates gradually from rest');
assert.equal(test.horizontal[0].animation.duration,480);assert.equal(test.vertical.length,0);
test.host.revealShuffleReturn();assert.equal(test.horizontal.length,1,'area changes cannot restart the same return');
test=setup({x:610});test.host.revealShuffleReturn();
assert.equal(test.horizontal.length,0,'fully visible returned thumbnail keeps the reading position');assert.equal(test.vertical.length,0);
test=setup({x:900});test.host.revealShuffleReturn();assert.equal(test.horizontal[0].xOffset,828,'left-clipped thumbnail scrolls back into view');
test=setup({x:610,stripY:2000});test.host.revealShuffleReturn();
assert.equal(test.vertical[0].yOffset,356);assert.equal(test.vertical[0].animation.curve,'ease-in-out','vertical reveal also starts gradually');assert.equal(test.vertical[0].animation.duration,480);
test=setup({x:610,y:400,stripY:100});test.host.revealShuffleReturn();
assert.equal(test.vertical[0].yOffset,342,'strip hidden behind the title scrolls down into view');assert.equal(test.vertical[0].animation.curve,'ease-in-out');
for(const opts of [{selected:'photo'},{full:true},{active:false}]) {
  test=setup(opts);test.host.revealShuffleReturn();assert.equal(test.horizontal.length,0);assert.equal(test.vertical.length,0);
}
test=setup();test.host.shuffleReturnItem='missing';test.host.revealShuffleReturn();assert.equal(test.horizontal.length,0);
test=setup();test.host.shuffleRevealedKey='collage:item-9';test.host.shuffleSelectedImage='photo';test.host.onShuffleSelectionChanged();
assert.equal(test.host.shuffleRevealedKey,'','reopening the same item permits a new return reveal');
assert.match(source,/color: item.id === \(this.shuffleSelectedImage \? this.shuffleItems\[this.shuffleIndex\]\?\.id : this.shuffleReturnItem\)/,
  'border tracks observable current or returned Pin identity, including a newly mounted parent');
assert.match(source,/\.border\(\{ width: 2,/,'stable border width must not resize thumbnails');
console.log('Shuffle return: persistent selected border, visible no-op, minimal animated reveal on both axes, top/bottom bounds, repeated item and inactive guards passed');
