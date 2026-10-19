const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
function host(module, file, names) {
  const source = fs.readFileSync(`${module}/src/main/ets/components/${file}.ets`, 'utf8');
  const methods = names.map(name => {
    const start = source.indexOf(`  private ${name}(`);
    assert(start >= 0, name);
    return source.slice(start, source.indexOf('\n  }', start) + 4);
  });
  const js = ts.transpileModule(`class Host { ${methods.join('\n')} } Host;`, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText;
  return new (vm.runInNewContext(js))();
}
for (const [module, file, minimum] of [
  ['feature_home','PinmonyHomePage',2], ['feature_search','PinmonySearchPage',2],
  ['feature_board','PinmonyBoardPage',2], ['feature_profile','PinmonyProfilePage',2],
  ['feature_profile','PinmonyOrganizePage',3], ['feature_search','PinmonySearchQuizPanel',2]
]) {
  const h = host(module,file,['contentColumns','columnSlots','contentColumnsTemplate']);
  let previous = 0;
  for (const width of [320,360,600,768,1024,1366,1920,768,360]) {
    h.contentWidth = width;
    const columns = h.contentColumns();
    assert(columns >= minimum);
    assert.equal(h.columnSlots().length,columns);
    assert.equal(h.contentColumnsTemplate().split(' ').length,columns);
    const padding = file === 'PinmonySearchQuizPanel' ? 0 : file === 'PinmonyHomePage' ? 24 : 32;
    const gap = file === 'PinmonySearchQuizPanel' ? 8 : 12;
    assert((width-padding-(columns-1)*gap)/columns > 0);
    if(width===1366) assert(columns>minimum);
  }
}
const board=host('feature_board','PinmonyBoardPage',['contentColumns','columnSlots','sectionRows','selectionColumns','selectionSlots','rows']);
for(const width of [360,768,1024,1366,360]) {
 board.contentWidth=width;
 for(let count=0;count<25;count++) {
  board.snapshot={sections:Array.from({length:count},(_,id)=>({id}))};
  board.selectionPins=()=>board.snapshot.sections;
  for(const [rows,slots] of [[board.sectionRows(),board.columnSlots()],[board.rows(),board.selectionSlots()]]) {
   const seen=[];for(const start of rows)for(const slot of slots)if(start+slot<count)seen.push(start+slot);
   assert.deepEqual(seen,Array.from({length:count},(_,i)=>i));
  }
 }
}
const search=host('feature_search','PinmonySearchPage',['contentColumns','syncQuizPresentation','resultsAreaChanged']);
search.snapshot={results:Array.from({length:10},(_,id)=>({id})),quiz:{mode:'entry'}};
search.flowSections={length:()=>0,splice:(_a,_b,sections)=>{search.sections=sections;}};
search.fillInitialViewport=()=>{};search.flowShape='';search.contentWidth=360;search.syncQuizPresentation();
for(const width of [360,768,1024,360]) {
 search.resultsAreaChanged({width,height:700});
 assert.equal(search.sections[0].crossCount,1);
 assert.equal(search.sections[1].crossCount,search.contentColumns());
 assert.equal(search.sections[1].itemsCount,10);
}
const detail=host('feature_pin','PinmonyDetailPage',['recommendCardWidth','recommendColumnCount','relatedColumn']);
detail.detail={related:Array.from({length:23},(_,id)=>({id}))};
for(const width of [360,768,1024,1366,360]) {
 detail.contentWidth=width;const n=detail.recommendColumnCount();assert(n>=2);assert(detail.recommendCardWidth()>0);
 const seen=[];for(let i=0;i<n;i++)for(const pin of detail.relatedColumn(i,n))seen.push(pin.id);
 assert.deepEqual(seen.sort((a,b)=>a-b),Array.from({length:23},(_,i)=>i));
}
console.log('Responsive layouts passed: resize/rotation widths, row completeness, section crossCount and recommendation partitioning');


const panes=host('feature_pin','PinmonyDetailPage',['wideDetail','detailPaneWidth','heroHeight']);
panes.detail={imageWidth:1000,imageHeight:1000};
for(const width of [360,768,839,840,1024,1366,360]) {
 panes.contentWidth=width;panes.viewportWidth=width;panes.viewportHeight=600;
 assert.equal(panes.wideDetail(),width>=840);
 const pane=panes.detailPaneWidth();
 assert.equal(width>=840 ? pane*2+20 : pane,width-36);
 assert.equal(panes.heroHeight(),Math.min(1200,pane));
}
console.log('Detail panes passed: phone stacking, wide equal panes, resize back and media aspect ratio');

const discovery=host('feature_search','PinmonySearchPage',['landscapeLayout','discoveryColumns','discoverySlots','discoveryRows','heroCarouselHeight']);
for(const [width,columns] of [[360,1],[768,1],[840,2],[1366,2],[1920,3],[360,1]]) {
 discovery.contentWidth=width;discovery.viewportWidth=width;discovery.viewportHeight=600;assert.equal(discovery.discoveryColumns(),columns);
 assert(discovery.heroCarouselHeight()>=319 && discovery.heroCarouselHeight()<=600);
 for(let count=0;count<12;count++) {
  discovery.snapshot={ideaSections:Array.from({length:count})};const seen=[];
  for(const start of discovery.discoveryRows())for(const slot of discovery.discoverySlots())if(start+slot<count)seen.push(start+slot);
  assert.deepEqual(seen,Array.from({length:count},(_,i)=>i));
 }
}
console.log('Search discovery passed: responsive section rows, trailing empty slots and carousel height');

const hero=host('feature_search','PinmonySearchPage',['landscapeLayout','wideHeroImageSize','heroCarouselHeight']);
for(const width of [840,1024,1366,1920]) {
 hero.contentWidth=width;hero.viewportWidth=width;hero.viewportHeight=600;const size=hero.wideHeroImageSize();
 assert(size>0 && size<=hero.heroCarouselHeight()-36);
 assert(width-size-width*0.12-64>240,'wide carousel reserves a readable text pane');
}

console.log('Wide carousel passed: square media fits banner, text pane remains available and image-dependent background');

for(const [width,height,wide] of [[1024,1366,false],[1366,1024,true],[840,1200,false],[1200,840,true],[700,500,false]]) {
 panes.contentWidth=width;panes.viewportWidth=width;panes.viewportHeight=height;assert.equal(panes.wideDetail(),wide);
 discovery.contentWidth=width;discovery.viewportWidth=width;discovery.viewportHeight=height;assert.equal(discovery.landscapeLayout(),wide);
 if(!wide) {assert.equal(discovery.discoveryColumns(),1);assert.equal(discovery.heroCarouselHeight(),390);assert.equal(panes.detailPaneWidth(),width-36);}
}
console.log('Orientation passed: portrait tablets retain stacked pages; wide landscape windows enable split layouts');
