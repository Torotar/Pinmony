const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
function method(source,name){const start=source.indexOf('  private '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n  private ',start+1));}
const root=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8'),flow=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets','utf8');
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['selectSection','swipeSection'].map(n=>method(root,n)).join('\n')+method(flow,'messageAvatarSize')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
const h=new Host(),calls=[];Object.assign(h,{snapshot:{section:'updates',dataSource:'api'},interactionReady:true,onSection:s=>calls.push(s)});
h.swipeSection(-90,10);assert.deepEqual(calls,['messages']);h.snapshot.section='messages';h.swipeSection(90,10);assert.deepEqual(calls,['messages','updates']);
h.conversationSwipeActive=true;h.swipeSection(90,0);assert.equal(calls.length,2,'swiping a conversation must not also change the inbox segment');h.conversationSwipeActive=false;
for(const [x,y] of [[10,0],[-90,100],[-90,0]]){h.swipeSection(x,y);}assert.equal(calls.length,2,'small, vertical and edge swipes do not switch');
h.refreshing=true;h.swipeSection(90,0);h.refreshing=false;h.interactionReady=false;h.swipeSection(90,0);assert.equal(calls.length,2);
for(const item of [{text:'text'},{text:'❤️'},{image:'image'},{profile:{}},{board:{}},{deleted:true}])assert.equal(h.messageAvatarSize(item),44);
assert(flow.includes("icon: new SymbolGlyphModifier($r('sys.symbol.checkmark'))"));assert(flow.includes('label: this.uiText("pm_next_acfc4e74")'));assert(flow.includes("Checkbox().select(this.snapshot.selectedIds.includes(user.id))"));assert(flow.includes(".selectedColor($r('app.color.accent'))"));assert(flow.includes(".hitTestBehavior(HitTestMode.None)"));assert(!flow.includes("? '✓' : '○'"));assert(flow.includes('icon: $r(\'app.media.lucide_ellipsis\'), label: this.uiText("pm_message_settings_'));
console.log('Inbox swipe/avatars: both directions, distance/vertical/edge/refresh guards, uniform message avatars and title icons passed');

const list=fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets','utf8');
function avatarHost(source){const start=source.indexOf('  private openItemAvatar('),end=source.indexOf('  @Builder',start);assert(start>=0&&end>start);const Type=vm.runInNewContext(ts.transpileModule('class AvatarHost {'+source.slice(start,end)+'} AvatarHost;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);return new Type();}
for(const source of [root,list]){
 const target=avatarHost(source),profiles=[],actions=[];Object.assign(target,{interactionReady:true,actionsReady:true,snapshot:{section:'messages'},onUser:url=>profiles.push(url),onAction:id=>actions.push(id)});
 const item={id:'conversation:100',enabled:true,profileUrl:'https://www.pinterest.com/synthetic_peer/'};
 for(const contact of [false,true]){target.openItemAvatar(item,contact);assert.equal(profiles.at(-1),item.profileUrl);}
 assert.equal(profiles.length,2);assert.equal(actions.length,0,'message/contact avatars must not open chat');
 target.openItemAvatar({...item,profileUrl:''},false);assert.equal(profiles.length,2);assert.equal(actions.length,0,'group or missing user identity must not guess a profile or open chat');
 target.openItemAvatar({...item,enabled:false},true);assert.equal(profiles.length,2);
 target.interactionReady=false;target.actionsReady=false;target.openItemAvatar(item,true);assert.equal(profiles.length,2,'covered/inactive list cannot open a profile');
}
assert.equal((root.match(/onClick\(\(\) => this.openItemAvatar\(item, contact\)\)/g)||[]).length,2);
assert(list.includes('.onClick(() => this.openItemAvatar(item))'));assert(list.includes(".onClick(() => this.onAction(item.id))"));assert(!list.includes("Row({ space: 14 }) {\n        PinmonyUserAvatar"),'avatar is an independent button beside the chat button');
console.log('Inbox avatar navigation: root/list/search messages and contacts route profiles, disabled/missing/group identity guards, independent chat targets passed');
