const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function method(source,name){const start=source.indexOf('  private '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n  private ',start+1));}
const root=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8'),flow=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets','utf8');
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['selectSection','swipeSection'].map(n=>method(root,n)).join('\n')+method(flow,'messageAvatarSize')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const h=new Host(),calls=[];Object.assign(h,{snapshot:{section:'updates',dataSource:'api'},interactionReady:true,onSection:s=>calls.push(s)});
h.swipeSection(-90,10);assert.deepEqual(calls,['messages']);h.snapshot.section='messages';h.swipeSection(90,10);assert.deepEqual(calls,['messages','updates']);
for(const [x,y] of [[10,0],[-90,100],[-90,0]]){h.swipeSection(x,y);}assert.equal(calls.length,2,'small, vertical and edge swipes do not switch');
h.refreshing=true;h.swipeSection(90,0);h.refreshing=false;h.interactionReady=false;h.swipeSection(90,0);assert.equal(calls.length,2);
for(const item of [{text:'text'},{text:'❤️'},{image:'image'},{profile:{}},{board:{}},{deleted:true}])assert.equal(h.messageAvatarSize(item),44);
assert(flow.includes('type: TextStyleMode.NORMAL, label: this.uiText("pm_next_acfc4e74")'));assert(flow.includes("Checkbox().select(this.snapshot.selectedIds.includes(user.id))"));assert(flow.includes(".selectedColor($r('app.color.accent'))"));assert(flow.includes(".hitTestBehavior(HitTestMode.None)"));assert(!flow.includes("? '✓' : '○'"));assert(flow.includes('icon: $r(\'app.media.lucide_ellipsis\'), label: this.uiText("pm_message_settings_'));
console.log('Inbox swipe/avatars: both directions, distance/vertical/edge/refresh guards, uniform message avatars and title icons passed');
