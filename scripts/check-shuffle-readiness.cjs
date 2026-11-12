const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const queue=require('./ui-commit-harness.cjs').createUiCommitHarness(ts);
const text=fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets','utf8');
const ast=ts.createSourceFile('page.ts',text.replace(/\bstruct\b/g,'class'),99,true);
const names=['shufflePhotoUrl','shuffleImageReady','commitShuffleImageReady','shuffleViewerItemMounted'];const methods=[];
function visit(n){if(ts.isMethodDeclaration(n)&&names.includes(n.name.getText(ast)))methods.push(n.getText(ast));ts.forEachChild(n,visit);}visit(ast);
assert.equal(methods.length,names.length);
const Host=vm.runInNewContext(ts.transpileModule('class Host{'+methods.join('\n')+'} Host;',{compilerOptions:{target:99}}).outputText,{Curve:{EaseOut:'ease-out'}});
function fixture(count=100){
  const host=new Host();
  Object.assign(host,{heroVisible:true,shuffleItems:Array.from({length:count},(_,i)=>({id:String(i),imageUrl:'thumb-'+i,cutoutUrl:'photo-'+i})),
    shuffleIndex:0,shuffleSelectedImage:'photo-0',shuffleBackdrop:'backdrop',shuffleReadyBackdrop:'',
    shuffleReadyImages:[],shuffleViewerPresented:false,uiCommits:new queue.Queue(),
    pin:'parent',displayedDetail(){return {pinUrl:this.pin,imageUrl:'backdrop'};}});
  return host;
}
const large=fixture();
const fast=fixture();
fast.contentError='not-found';
fast.shuffleImageReady('photo:photo-0');queue.flush();
assert.equal(fast.shuffleViewerPresented,true,'selected artwork opens without waiting for backdrop, thumbnail or Pin metadata');
assert.deepEqual(Array.from({length:100},(_,i)=>i).filter(i=>fast.shuffleViewerItemMounted(i)),[0,1]);
fast.shuffleIndex=50;
assert.deepEqual(Array.from({length:100},(_,i)=>i).filter(i=>fast.shuffleViewerItemMounted(i)),[49,50,51],'only current and adjacent image/card nodes load');
fast.shuffleIndex=99;
assert.deepEqual(Array.from({length:100},(_,i)=>i).filter(i=>fast.shuffleViewerItemMounted(i)),[98,99]);
assert.equal(fast.shuffleViewerItemMounted(-1),false);assert.equal(fast.shuffleViewerItemMounted(100),false);
const awaitingPhoto=fixture(1);
awaitingPhoto.shuffleImageReady('backdrop','backdrop');awaitingPhoto.shuffleImageReady('card:thumb-0');queue.flush();
assert.equal(awaitingPhoto.shuffleViewerPresented,false,'background and thumbnail cannot reveal a missing main photo');
awaitingPhoto.shuffleImageReady('photo:photo-0');queue.flush();
assert.equal(awaitingPhoto.shuffleViewerPresented,true,'main photo independently releases the entry');
const lateBackground=fixture(1);const fades=[];
lateBackground.shuffleBackdropOpacity=1;lateBackground.shuffleBackdropImageOpacity=0;
lateBackground.getUIContext=()=>({animateTo:(options,change)=>{fades.push(options);change();}});
lateBackground.shuffleImageReady('backdrop','backdrop');queue.flush();
assert.equal(fades.length,1,'background arriving after opening fades in');
assert.equal(lateBackground.shuffleBackdropImageOpacity,1);
lateBackground.shuffleImageReady('backdrop','backdrop');queue.flush();
assert.equal(fades.length,1,'duplicate render completion cannot restart background fade');
assert.match(text,/if \(this.shuffleViewerItemMounted\(index\)\)/,'image and card subtree use bounded mounting');
for(const item of large.shuffleItems){large.shuffleImageReady('photo:'+item.cutoutUrl);large.shuffleImageReady('card:'+item.imageUrl);}
queue.flush();assert.equal(large.shuffleViewerPresented,true,'late backdrop cannot block a ready selected photo');
large.shuffleImageReady('backdrop','backdrop');queue.flush();
assert.equal(large.shuffleViewerPresented,true,'100-item collage cannot evict selected readiness before backdrop completes');
assert.equal(large.shuffleReadyImages.length,200,'cache contains only the two current sources per collage item');
large.shuffleViewerPresented=false;large.shuffleIndex=99;large.shuffleSelectedImage='photo-99';
large.shuffleImageReady('photo:photo-99');queue.flush();
assert.equal(large.shuffleViewerPresented,true,'cached sibling photo/card readiness remains available');
for(const order of [['backdrop','photo','card'],['card','backdrop','photo'],['photo','card','backdrop']]){
  const ordered=fixture(200);
  for(const phase of order){
    if(phase==='backdrop') ordered.shuffleImageReady('backdrop','backdrop');
    else for(const item of ordered.shuffleItems) ordered.shuffleImageReady(phase+':'+(phase==='photo'?item.cutoutUrl:item.imageUrl));
    queue.flush();
  }
  assert.equal(ordered.shuffleViewerPresented,true,'maximum-size collage settles in '+order.join('/'));
  assert.equal(ordered.shuffleReadyImages.length,400,'readiness remains bounded by current items');
  ordered.shuffleViewerPresented=false;ordered.shuffleReadyBackdrop='';
  ordered.shuffleImageReady('backdrop','backdrop');queue.flush();
  assert.equal(ordered.shuffleViewerPresented,true,'reopening reuses valid decoded photo/card after fresh backdrop completion');
}
const transient=fixture();
transient.pin='temporary-child';transient.shuffleSelectedImage='';
transient.shuffleImageReady('photo:photo-0');transient.shuffleImageReady('card:thumb-0');transient.shuffleImageReady('backdrop','backdrop');
transient.pin='parent';transient.shuffleSelectedImage='photo-0';queue.flush();
assert.equal(transient.shuffleViewerPresented,true,'same-render parent/selection synchronization cannot lose one-shot decode callbacks');
const stale=fixture(1);
stale.shuffleImageReady('photo:removed');stale.shuffleImageReady('card:removed');stale.shuffleImageReady('backdrop','old');queue.flush();
assert.equal(stale.shuffleReadyImages.length,0,'unrelated sources never enter the readiness cache');
stale.shuffleImageReady('backdrop','backdrop');stale.shuffleBackdrop='new';queue.flush();
assert.equal(stale.shuffleReadyBackdrop,'','old background completion cannot unlock a replaced source');
const cancelled=fixture(1);cancelled.shuffleImageReady('photo:photo-0');cancelled.heroVisible=false;queue.flush();
assert.equal(cancelled.shuffleReadyImages.length,0,'hidden/disposed callback cannot commit');
const replaced=fixture(1);replaced.shuffleImageReady('photo:photo-0');replaced.shuffleItems=[{imageUrl:'different'}];queue.flush();
assert.equal(replaced.shuffleReadyImages.length,0,'removed collage item completion cannot commit');
const disposed=fixture(1);disposed.shuffleImageReady('photo:photo-0');disposed.uiCommits.dispose();queue.flush();
assert.equal(disposed.shuffleReadyImages.length,0,'disposed queue rejects one-shot late completions');
// Image errors deliberately settle readiness through the existing onError path;
// business failure is then visible in the selected card instead of a blocked spinner.
assert.match(text,/\.onError\(\(\) => this.shuffleImageReady\('photo:'/);
assert.match(text,/\.onError\(\(\) => this.shuffleImageReady\('card:'/);
assert.match(text,/item.id === this.shuffleItems\[this.shuffleIndex\]\?\.id && this.contentError/);
console.log('Shuffle readiness: 100 items, late backdrop, cached siblings, prop synchronization, replaced source, hidden callbacks and existing error presentation passed');
