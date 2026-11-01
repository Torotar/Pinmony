const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm');
const root=fs.readFileSync('entry/src/main/ets/components/PinmonyProfileRootContent.ets','utf8');
const status=root.slice(root.indexOf('function PinmonyBuildProfileStatus'));
const expression=status.match(/if \((view\.profileStore\.[^\n]+)\) \{/)[1];
const loading=vm.runInNewContext('(view)=>'+expression);
for(const [busy,error,expected]of [[false,'',true],[true,'',true],[true,'old-error',true],[false,'load-failed',false]])assert.equal(loading({profileStore:{profileLoading:busy,profileError:error}}),expected);
assert(status.indexOf('Button(')>status.indexOf('} else {'),'retry is error-only');
const source=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
const condition=source.split('\n').find(l=>l.includes('if(')&&l.includes('!this.automaticPhotoPaging()')&&l.includes('contentHasMore')).trim().slice(3,-3);
const canShow=vm.runInNewContext('(function(){return '+condition+';})');
for(const busy of ['loading','contentLoading']){const view={loading:false,profile:{contentLoading:false,contentHasMore:true,contentLoadingMore:false},modern:()=>true,automaticPhotoPaging:()=>false};if(busy==='loading')view.loading=true;else view.profile.contentLoading=true;assert.equal(canShow.call(view),false,'no paging button during primary loading');}
assert(source.includes('else if (!this.loading && !this.profile.contentLoading && this.profile.contentLoadingMore)'));
console.log('Profile loading states: pending identity stays loading, genuine error retries, primary loading suppresses paging controls');
