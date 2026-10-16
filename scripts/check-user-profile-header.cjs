const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require(process.argv[2]||'typescript');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
function method(name){const start=source.indexOf('  private '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n  private ',start+1)).replace(/@Builder/g,'');}
const Host=vm.runInNewContext(ts.transpileModule('class Host {'+['requestProfileBack','profileCoverHeight','profileTitleOptions','onProfileChanged'].map(method).join('\n')+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{$r:x=>x});
const h=new Host(),events=[];Object.assign(h,{profile:{profileUrl:'profile',isOwn:false,coverUrl:'https://i.pinimg.com/synthetic.jpg'},contentWidth:360,onBack:()=>events.push('back'),onShare:()=>events.push('share'),scroller:{scrollTo(){}},activeProfile:'profile'});
assert.equal(h.profileCoverHeight(),187.20000000000002);h.profile.isOwn=true;assert.equal(h.profileCoverHeight(),0);h.profile.isOwn=false;
const title=h.profileTitleOptions();assert.equal(title.content.menu.value.length,1);assert.equal(title.content.menu.value[0].content.label,'分享个人资料');title.content.menu.value[0].content.action();assert.deepEqual(events,['share']);
title.content.backIcon.action();h.requestProfileBack();assert.deepEqual(events,['share','back'],'one return gesture cannot pop twice');
h.profile.profileUrl='parent';h.onProfileChanged();h.requestProfileBack();assert.equal(events.length,3,'new profile permits next return');
assert(source.includes('.maxFontSize(18).minFontSize(12)'));assert(source.includes('.padding({ left: 64, right: 72 })'));
console.log('Visitor profile: cover bounds, share-only title, adaptive title constraints and duplicate return guard passed');
