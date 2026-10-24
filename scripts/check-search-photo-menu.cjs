const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),ts=require(process.argv[2]);
const source=fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets','utf8');
const start=source.indexOf('  private async photoMenu()');
const end=source.indexOf("  @StorageProp('systemDarkMode')",start);
class Content { constructor(context,builder,options){this.options=options;} }
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+source.slice(start,end)+'}\nHost;',
 {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{ComponentContent:Content,wrapBuilder:x=>x,buildPhotoMenu:()=>{}});
(async()=>{
 const host=new Host();let calls=0,closed=0,uploads=0,histories=0,target;
 host.active=true;host.interactionReady=true;host.photoMenuOpen=false;host.photoBusy=false;
 host.startPhotoSearch=()=>uploads++;host.openPhotoHistory=()=>histories++;
 host.getUIContext=()=>({getPromptAction:()=>({openMenu:async(content,anchor)=>{calls++;target=anchor.id;},closeMenu:async()=>{closed++;}})});
 assert(!source.includes('.bindMenu('));assert(!source.includes('showActionMenu('));assert.equal(calls,0);
 await host.photoMenu();assert.equal(calls,1);assert.equal(uploads,0);assert.equal(target,'pinmony-photo-search-menu');
 await host.selectPhotoMenu(0);assert.equal(uploads,1);assert.equal(closed,1);assert.equal(host.photoMenuOpen,false);
 await host.photoMenu();await host.selectPhotoMenu(1);assert.equal(histories,1);
 await host.photoMenu();host.active=false;await host.selectPhotoMenu(0);assert.equal(uploads,1);
 await host.photoMenu();assert.equal(calls,3);
 host.active=true;await host.photoMenu();await host.dismissPhotoMenu();assert.equal(uploads,1);assert.equal(histories,1);
 assert(source.includes("componentId: 'pinmony-photo-search-menu'"));
 console.log('Anchored photo Menu: lazy creation, HDS button target, upload/history, dismissal and inactive guards passed');
})().catch(error=>{console.error(error);process.exitCode=1;});