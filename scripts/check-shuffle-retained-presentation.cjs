const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const tree = ts.createSourceFile('page.ts', source.replace(/\bstruct\b/g, 'class'), 99, true);
const wanted = ['onPinChanged', 'commitPinPresentation', 'displayedDetail', 'resetEntryMotion'];
const methods = [];
function visit(node) {
  if (ts.isMethodDeclaration(node) && wanted.includes(node.name.getText(tree))) methods.push(node.getText(tree));
  ts.forEachChild(node, visit);
}
visit(tree);
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + methods.join('\n') + '} Host;',
  {compilerOptions:{target:99}}).outputText);
const parent = {pinUrl:'collage', imageUrl:'cover', shuffle:{id:'scene'}};
const child = {pinUrl:'child', imageUrl:'cutout'};
function fixture() {
  const jobs = new Map();
  const host = new Host();
  let resets = 0;
  Object.assign(host, {currentDetail:parent, activePin:parent.pinUrl, heroVisible:true,
    entryPhoto:{pinUrl:parent.pinUrl}, entryResumed:false, entryMotionComplete:true,
    entryOpacity:1, entryBackdropProgress:1, entryPhotoHidden:false, decodedHeroSource:{key:'retained'},
    uiCommits:{post:(key, job)=>jobs.set(key,job)}, viewerOwner:()=>'',
    restoreScrollPosition:()=>resets++, startSearchLabel(){}, syncDetailFlow(){},
    updateDetailLayout(){}, auditRecommendationGate(){}, queuePhotoFitAudit(){}});
  return {host, jobs, resets:()=>resets, flush:()=>{
    const pending=[...jobs.values()]; jobs.clear(); pending.forEach(job=>job());
  }};
}
// ArkUI updates watched props separately: currentDetail can arrive before its
// retained parent and before the entryPhoto/entryResumed props in the same render.
const opening = fixture();
opening.host.currentDetail = child;
opening.host.onPinChanged();
opening.host.shuffleParentDetail = parent;
opening.host.onPinChanged();
opening.host.entryPhoto = undefined;
opening.flush();
assert.equal(opening.host.entryOpacity,1,'loading/entry must keep the retained collage drawn');
assert.equal(opening.host.entryMotionComplete,true,'child reads cannot restart parent entry');
assert.equal(opening.host.decodedHeroSource.key,'retained','retained cover is not discarded');
assert.equal(opening.resets(),0,'child reads cannot reset the collage scroll');
// Full child detail is a real presentation change. Return props still must be
// consumed together, so it resumes the collage without a homepage entry flight.
opening.host.shuffleFullDetail = true;
opening.host.onPinChanged(); opening.flush();
assert.equal(opening.host.activePin,'child');
opening.host.currentDetail = parent;
opening.host.onPinChanged();
opening.host.shuffleFullDetail = false;
opening.host.entryPhoto = {pinUrl:'collage'};
opening.host.entryResumed = true;
opening.flush();
assert.equal(opening.host.entryOpacity,1,'return cannot leave a transparent HDS destination');
assert.equal(opening.host.entryMotionComplete,true,'return must not fly in again from home');
opening.host.entryMotionComplete = false;
opening.host.entryOpacity = 0;
opening.host.onPinChanged(); opening.flush();
assert.equal(opening.host.entryMotionComplete,true,'same retained Pin also consumes the resume flag');
assert.equal(opening.host.entryOpacity,1,'same retained Pin cannot keep an earlier hidden state');
const rapid = fixture();
rapid.host.currentDetail = child; rapid.host.onPinChanged();
rapid.host.currentDetail = {pinUrl:'latest'}; rapid.host.onPinChanged();
rapid.host.entryPhoto = undefined; rapid.flush();
assert.equal(rapid.host.activePin,'latest','only the final prop batch may change presentation');
assert.equal(rapid.resets(),1,'superseded intermediate snapshots never restore scroll');
const disposed = fixture();
disposed.host.currentDetail = child; disposed.host.onPinChanged();
disposed.host.heroVisible = false; disposed.flush();
assert.equal(disposed.host.activePin,'collage','unmounted pages cannot commit pending presentation');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
const indexTree = ts.createSourceFile('index.ts',index.replace(/\bstruct\b/g,'class'),99,true);
let openMethod='';
function findOpen(node) {
  if(ts.isMethodDeclaration(node) && node.name.getText(indexTree)==='openShufflePin') openMethod=node.getText(indexTree);
  ts.forEachChild(node,findOpen);
}
findOpen(indexTree); assert(openMethod);
const Owner=vm.runInNewContext(ts.transpileModule('class Owner {'+openMethod+'} Owner;', {compilerOptions:{target:99}}).outputText);
const owner=new Owner(); let opens=0, caches=0;
const artwork={id:'one',pinId:'202',tappable:true,alpha:1,imageUrl:'photo'};
const collage={pinUrl:'https://www.pinterest.com/pin/101/',shuffleId:'scene',shuffle:{id:'scene',items:[artwork]}};
Object.assign(owner,{authStatus:'authenticated',businessSuspended:false,activeSheetKind:'',
  pinStore:{videoForeground:true,detailNativeReadsReady:true,detailPreparing:false,detail:collage,
    detailScrollOffset:72,detailCache:{put:()=>caches++}},detailNativeReads:{owned:()=>true},
  pinIdentity:url=>url, currentPinUrl:()=>collage.pinUrl,
  nativeBusinessSessionContext:()=>({origin:'https://www.pinterest.com'}),
  detailOpeningCoordinator:{prefetchShufflePins(){}},
  beginDetailOpening(target, origin, returning, childEntry) {
    assert.equal(this.shuffleParentDetail,collage,'install the retained parent before changing the route');
    assert.equal(this.shuffleSelectedPin,target); assert.equal(this.shuffleSelectedImage,'photo');
    assert.equal(origin,collage.pinUrl); assert.equal(returning,false); assert.equal(childEntry,true);
    opens++;
  }});
owner.openShufflePin('missing'); assert.equal(opens,0);
owner.openShufflePin('one'); assert.equal(opens,1); assert.equal(caches,1);
owner.authStatus='anonymous'; owner.openShufflePin('one'); assert.equal(opens,1,'session gate remains authoritative');
console.log('Shuffle retained presentation: prop ordering, visible loading/reverse backdrop, decoded cover, scroll, full detail, rapid replacement and disposal passed');
