const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function method(path,name){const ast=ts.createSourceFile('host.ts',fs.readFileSync(path,'utf8').replace(/\bstruct\b/g,'class'),99,true);let result;
 function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(ast)===name)result=n.getText(ast);ts.forEachChild(n,visit);}visit(ast);assert(result);return result;}
let locked=true;const changes=[];
const Ability=vm.runInNewContext(ts.transpileModule('class Host {'+method('entry/src/main/ets/entryability/EntryAbility.ets','updateStatusBarHeight')+'} Host;', {compilerOptions:{target:99}}).outputText,
 {AppStorage:{get:()=>locked,setOrCreate:(key,value)=>changes.push(value)}});
const ability=new Ability();ability.updateStatusBarHeight(0);assert.deepEqual(changes,[],'hidden bar preserves original detail height');
ability.updateStatusBarHeight(48);assert.deepEqual(changes,[48],'real positive inset updates remain supported');locked=false;ability.updateStatusBarHeight(0);assert.deepEqual(changes,[48,0]);
const timers=new Map();let serial=0;
const Viewer=vm.runInNewContext(ts.transpileModule('class Host {'+method('feature_pin/src/main/ets/components/PinmonyImageViewer.ets','queueReturnTransition')+'} Host;', {compilerOptions:{target:99}}).outputText,
 {setTimeout:fn=>{timers.set(++serial,fn);return serial;},clearTimeout:id=>timers.delete(id)});
const viewer=new Viewer();const destinations=[];Object.assign(viewer,{mounted:true,origin:{y:10},transitionChanged(){destinations.push(this.origin.y);}});
viewer.queueReturnTransition();viewer.origin={y:42};assert.equal(destinations.length,0);
for(const fn of timers.values())fn();timers.clear();assert.deepEqual(destinations,[42],'return reads final destination after sibling props synchronize');
viewer.queueReturnTransition();viewer.mounted=false;for(const fn of timers.values())fn();assert.deepEqual(destinations,[42]);
console.log('Viewer handoff: retained status inset, real inset updates, synchronized return destination and disposed callback passed');
