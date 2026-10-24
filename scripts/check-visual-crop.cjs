const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const wrapper=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyVisualSearchView.ets','utf8');
assert(wrapper.includes('PinmonyImageSearchView as PinmonyVisualSearchView'), 'detail crop delegates to the shared image-search component');
const s=fs.readFileSync('common_ui/src/main/ets/components/PinmonyImageSearchView.ets','utf8');
const a=s.indexOf('  private startDrag()'),b=s.indexOf('  @Builder',a);
const code=ts.transpileModule('class Crop {'+s.slice(a,b)+'};Crop;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
const Crop=vm.runInNewContext(code,{});
function run(corner,dx,dy){const c=new Crop();c.crop={x:.2,y:.2,w:.5,h:.5};c.photoWidth=()=>200;c.photoHeight=()=>400;c.queueSearch=()=>{};c.startDrag();c.drag({offsetX:dx,offsetY:dy},corner);return c.crop;}
assert(run(-1,-20,-40).x<.2);assert(run(-1,-20,-40).y<.2);
assert(run(-1,20,40).x>.2);assert(run(-1,20,40).y>.2);
for(const i of [0,1,2,3]){const c=run(i,-10,-20);if(i===0||i===2)assert(c.x<.2);else assert(c.x+c.w<.7);if(i<2)assert(c.y<.2);else assert(c.y+c.h<.7);}
const c=run(-1,-10000,10000);assert.equal(c.x,0);assert.equal(c.y,.5);
console.log('crop drag: left/right/up/down, all four corners and bounds passed');
