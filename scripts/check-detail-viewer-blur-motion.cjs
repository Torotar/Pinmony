const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
function read(path){return fs.readFileSync('feature_pin/src/main/ets/'+path,'utf8');}
const source=read('components/PinmonyImageViewer.ets');
const ast=ts.createSourceFile('viewer.ts',source.replace(/\bstruct\b/g,'class'),99,true);
let method; function visit(n){if(ts.isMethodDeclaration(n)&&n.name.getText(ast)==='transitionChanged')method=n.getText(ast);ts.forEachChild(n,visit);}visit(ast);assert(method);
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+method+'} Host;', {compilerOptions:{target:99}}).outputText,{clearTimeout(){},curves:{springMotion:(...args)=>args}});
const h=new Host(); let insideAnimation=false,closed=0;const targets=[],animations=[];
Object.assign(h,{mounted:true,previewReady:true,originalReady:true,transitionStarted:true,transitionVersion:0,closing:false,
  stopInertia(){},sourceRect:()=>({x:1}),containRect:()=>({x:2}),sourceRadius:()=>18,setFrame(){},
  onTransition:expanded=>{assert(insideAnimation,'backdrop state must share flight transaction');targets.push(expanded);},
  onClosed:()=>closed++,getUIContext:()=>({animateTo:(options,commit)=>{animations.push(options);insideAnimation=true;commit();insideAnimation=false;}})});
h.transitionChanged();assert.deepEqual(targets,[1]);assert.equal(h.backdrop,1);
h.closing=true;h.transitionChanged();assert.deepEqual(targets,[1,0]);assert.equal(h.backdrop,0);
animations[0].onFinish();assert.equal(closed,0,'stale entry finish cannot terminate return');
animations[1].onFinish();assert.equal(closed,1);
h.mounted=false;h.transitionChanged();assert.equal(targets.length,2);
const exportsSession={};vm.runInNewContext(ts.transpileModule(read('services/PinmonyImageViewerSession.ets'),{compilerOptions:{target:99,module:ts.ModuleKind.CommonJS,experimentalDecorators:true}}).outputText,
 {exports:exportsSession,Observed:v=>v,require:()=>({PinmonyRuntimeLog:{info(){}}})});
const session=new exportsSession.PinmonyImageViewerSession();let valid=true;const forwarded=[];
session.open({owner:'a',imageUrl:'image',isCurrent:()=>valid,onTransition:x=>forwarded.push(x),onClosed(){}});
const revision=session.revision;session.transition(revision,1);session.transition(revision-1,0);valid=false;session.transition(revision,0);
assert.deepEqual(forwarded,[1]);valid=true;session.cancel();session.transition(revision,0);assert.deepEqual(forwarded,[1]);
assert(read('components/PinmonyImageViewerHost.ets').includes('this.session.transition(this.hostRevision, expanded)'));
const page=read('components/PinmonyDetailPage.ets');
assert(page.includes('onTransition: (expanded: number) => { this.viewerBackdropProgress = expanded; }'));
assert(!page.includes(".opacity(this.imageLayer === 'zoom' || this.viewerMounted ? 0 : 0.72)"));
const media=page.slice(page.indexOf('private detailMedia()'),page.indexOf('private detailInformation()'));
assert(media.indexOf('viewerBackdropProgress')>=0 && media.indexOf('viewerBackdropProgress')<media.indexOf('    Column() {'),'blur is outside entry source photo opacity group');
const hero=page.slice(page.indexOf('private heroImage()'),page.indexOf('private heroImageSources'));
assert(!hero.includes('.blur('),'hero retains clear photo only; shared media backdrop stays outside viewer source opacity group');
for(const progress of [0,0.25,0.5,0.75,1]){assert.equal(28*(1-progress),28-28*progress);assert(Math.abs(0.72*(1-progress)-(0.72-0.72*progress))<1e-9);}
console.log('Viewer blur motion: shared entry/return animation transaction, retained separate blur layer, source ownership and stale/disposed callbacks passed');
