const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 'utf8');
function method(name) {
  const start = source.indexOf('  private ' + name + '(');
  assert(start >= 0);
  return source.slice(start, source.indexOf('\n  private ', start + 1));
}
const Host = vm.runInNewContext(ts.transpileModule('class Host {' +
  method('updateHubChrome') + method('setHubChromeCollapsed') + '} Host;',
  {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,
  {ScrollState:{Scroll:1},Curve:{EaseOut:1}});
const h = new Host();
Object.assign(h,{modern:()=>true,interactionReady:true,refreshing:false,loading:false,sortVisible:false,
  hubChromeScrollDistance:0,hubChromeCollapsed:false,getUIContext:()=>({animateTo:(options,fn)=>{assert.equal(options.duration,180);fn();}})});
h.updateHubChrome(12,1,100); assert.equal(h.hubChromeCollapsed,false);
h.updateHubChrome(9,1,109); assert.equal(h.hubChromeCollapsed,true);
h.updateHubChrome(-12,1,97); assert.equal(h.hubChromeCollapsed,true);
h.updateHubChrome(-9,1,88); assert.equal(h.hubChromeCollapsed,false);
h.updateHubChrome(30,2,118); assert.equal(h.hubChromeCollapsed,false,'inertia does not toggle chrome');
h.updateHubChrome(30,1,148); assert.equal(h.hubChromeCollapsed,true);
h.updateHubChrome(0,2,0); assert.equal(h.hubChromeCollapsed,false,'top always expands');
h.refreshing=true;h.updateHubChrome(30,1,100);assert.equal(h.hubChromeCollapsed,false);
h.refreshing=false;h.updateHubChrome(12,1,100);h.updateHubChrome(-12,1,88);
assert.equal(h.hubChromeCollapsed,false,'direction changes reset accumulation');
console.log('Profile chrome: 20vp directional threshold, 180ms animation, top expansion, inertia and refresh guards passed');
