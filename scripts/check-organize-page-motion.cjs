const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyOrganizePage.ets','utf8');
function method(name){const start=source.indexOf('  private '+name+'(');assert(start>=0,name);const end=source.indexOf('\n  }',start)+4;return source.slice(start,end);}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['syncPhase','back','act'].map(method).join('\n')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const calls=[],h=Object.assign(new Host(),{active:true,secret:false,standaloneBoard:false,onAction:(...args)=>calls.push(args)});
const state=phase=>({phase,selectedIds:['1'],boards:[{id:'10',name:'Board'}],loading:false,busy:false,error:'',feedback:'',hasMore:false,uncertain:false});
h.state=state('select');h.syncPhase();const selection=h.retainedSelection;
h.state.selectedIds.push('2');assert.deepEqual(Array.from(selection.selectedIds),['1'],'retained layer is isolated from mutable incoming state');
h.state=state('boards');h.syncPhase();const boards=h.retainedBoards;
assert.equal(h.retainedSelection,selection);h.state=state('create');h.syncPhase();assert.equal(h.retainedBoards,boards);assert.equal(h.retainedSelection,selection);
h.back();assert.equal(calls.at(-1)[0],'boards','create back reveals the existing board picker');
h.state=state('boards');h.back();assert.equal(calls.at(-1)[0],'back','picker back follows the existing selection return');
h.active=false;const count=calls.length;h.act('moreBoards');h.back();assert.equal(calls.length,count,'covered layers cannot submit actions');
h.active=true;h.state.busy=true;h.back();assert.equal(calls.length,count,'in-flight writes remain protected');
h.state.busy=false;h.state.uncertain=true;h.back();assert.equal(calls.at(-1)[0],'close','unknown writes preserve the established close path');
assert.equal((source.match(/\.transition\(ORGANIZE_PAGE_TRANSITION\)/g)||[]).length,2,'picker and create have independent enter/exit layers');
assert(source.includes("this.retainedBoards!, active: this.state.phase === 'boards'"));
assert(source.includes("active: this.state.phase === 'select'"));
assert(source.includes(".hitTestBehavior($$.active ? HitTestMode.Default : HitTestMode.None)"));
assert(source.includes(".accessibilityLevel($$.active ? 'auto' : 'no-hide-descendants')"));
assert(source.includes('.bindToScrollable([this.contentScroller])'));
assert(source.includes('systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode)'));
assert(!source.includes("(this.state.phase === 'boards') || this.immersiveLightMode"),'picker controls no longer suppress shared material');
console.log('Organize page motion: retained selection/picker, independent create layer, back/busy/uncertain gates and covered interaction passed');const Layout=vm.runInNewContext(ts.transpileModule('class Layout {'+['contentColumns','columnSlots','contentColumnsTemplate'].map(method).join('\n')+'} Layout;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const layout=new Layout();for(const width of [320,360,600,768,1024,1366,1920,360]){layout.contentWidth=width;const columns=layout.contentColumns();assert(columns>=3);assert.equal(layout.columnSlots().length,columns);assert.equal(layout.contentColumnsTemplate().split(' ').length,columns);assert((width-32-(columns-1)*12)/columns>0);}
console.log('Organize responsive selection: portrait, wide windows and return to portrait passed');

const boardSource=fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets','utf8');
for (const [label,ui,columnMethod,slotsMethod] of [
  ['profile',source,'contentColumns','columnSlots'],
  ['board',boardSource,'selectionColumns','selectionSlots']
]) {
  function extract(name) {
    const start=ui.indexOf('  private '+name+'(');assert(start>=0,name);
    return ui.slice(start,ui.indexOf('\n  }',start)+4);
  }
  const Selection=vm.runInNewContext(ts.transpileModule('class Selection {'+
    [columnMethod,slotsMethod,'rows','selectedPins'].map(extract).join('\n')+'} Selection;',
    {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
  const selection=new Selection();
  const pins=Array.from({length:29},(_,id)=>({id:String(id)}));
  selection.pins=pins;selection.selectionPins=()=>selection.pins;
  for(const width of [320,360,600,768,1024,1366,1920,360]) {
    selection.contentWidth=width;
    const columns=selection[columnMethod]();
    if(width>=600)assert(columns>3,label+' wide selection uses more than three columns');
    assert((width-32-(columns-1)*12)/columns<140,label+' cards remain compact');
    for(const count of [0,1,2,3,7,29]) {
      selection.pins=pins.slice(0,count);
      const seen=[];
      for(const start of selection.rows())for(const slot of selection[slotsMethod]())if(start+slot<count)seen.push(start+slot);
      assert.deepEqual(seen,Array.from({length:count},(_,id)=>id),label+' no skipped or duplicate Pins');
    }
  }
  selection.pins=pins;
  for(const ids of [[],['8','2','6'],['8','6'],['8','6','2'],['99','2'],pins.map(pin=>pin.id)]) {
    selection.selectedIds=ids;selection.state={selectedIds:ids};
    assert.deepEqual(Array.from(selection.selectedPins(),pin=>pin.id),ids.filter(id=>pins.some(pin=>pin.id===id)),label+' preview follows selection order');
    assert.deepEqual(pins.map(pin=>pin.id),Array.from({length:29},(_,id)=>String(id)),'feed order stays intact');
  }
  assert(ui.includes('ForEach(this.'+slotsMethod+'(), (column: number) => {'),label+' computed columns drive rendered cards');
  assert(ui.includes('ForEach(this.selectedPins(),'),label+' preview uses ordered Pins');
  assert(/const width: number = Number\(area.width\);\s*if \([^\n]+\) this.contentWidth = width;/.test(ui),label+' measured width drives responsive columns');
}
console.log('Organize selection: both entry points, compact rendered columns, full/partial rows, ordered previews, deselect/reselect and missing IDs passed');
