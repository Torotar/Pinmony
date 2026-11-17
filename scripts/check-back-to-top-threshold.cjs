const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const file='common_ui/src/main/ets/components/PinmonyBackToTopButton.ets';
const source=fs.readFileSync(file,'utf8');
const plain=(source.slice(0,source.indexOf('  build()'))+'}').replace(/^import .*;\r?\n/gm,'').replace(/@\w+(?:\([^)]*\))?/g,'').replace('export struct ','export class ');
const context={exports:{},TouchType:{Down:0,Up:1,Cancel:2,Move:3}};
vm.runInNewContext(ts.transpileModule(plain,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText,context);
const button=new context.exports.PinmonyBackToTopButton();button.showButton=true;button.aboutToAppear();
for(const height of [320,600,800,1200]){
  button.updateHostArea(400,height);
  for(const offset of [0,180,height,height*2-0.1]){button.scrollOffsetVp=offset;assert.equal(button.shouldShow(),false,'below two screens: '+height+'/'+offset);}
  for(const offset of [height*2,height*2+1,height*3]){button.scrollOffsetVp=offset;assert.equal(button.shouldShow(),true,'at/above two screens');}
}
button.scrollOffsetVp=1400;button.updateHostArea(400,800);assert(!button.shouldShow());
button.updateHostArea(800,600);assert(button.shouldShow(),'rotation/resize recalculates threshold without scrolling');
button.updateHostArea(400,800);assert(!button.shouldShow(),'larger viewport hides immediately');
button.scrollOffsetVp=1600;button.tracking=true;button.updateHostArea(400,900);assert(!button.tracking,'resizing below threshold clears touch tracking');
for(const offset of [NaN,Infinity,-1]){button.scrollOffsetVp=offset;assert(!button.shouldShow());}
button.scrollOffsetVp=5000;button.updateHostArea(400,0);assert(!button.shouldShow(),'wait for actual layout');
button.updateHostArea(400,800);button.showButton=false;assert(!button.shouldShow(),'parent lifecycle gates remain authoritative');
let clicks=0;button.onBackToTop=()=>clicks++;button.suppressClickUntil=0;button.click();assert.equal(clicks,0);
button.showButton=true;button.scrollOffsetVp=1599;button.click();assert.equal(clicks,0,'hidden threshold blocks stale click');
button.scrollOffsetVp=1600;button.click();assert.equal(clicks,1);button.aboutToDisappear();button.click();assert.equal(clicks,1);
for(const surface of ['feature_home/src/main/ets/components/PinmonyHomePage.ets','feature_search/src/main/ets/components/PinmonySearchPage.ets','feature_board/src/main/ets/components/PinmonyBoardPage.ets','feature_pin/src/main/ets/components/PinmonyDetailPage.ets','common_ui/src/main/ets/components/PinmonyImageSearchView.ets']){
  const text=fs.readFileSync(surface,'utf8');assert(text.includes('scrollOffsetVp: this.backToTopOffset'),surface+' supplies live offset');
  assert(text.includes('@State private backToTopOffset: number = 0;'),surface+' offset is reactive');
  assert(!/this\.backToTopVisible\s*=.*> 180/.test(text),surface+' no fixed visibility threshold');
}
assert(source.includes('.enabled(this.shouldShow())')&&source.includes('.visibility(this.shouldShow() ?'),'render and hit gating share threshold');
console.log('Back-to-top threshold: five surfaces, two viewport boundaries, rotation/resize, initial layout, invalid offsets, stale clicks and lifecycle passed');
