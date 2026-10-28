const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomePage.ets','utf8');
const indicator=source.slice(source.indexOf('  private homeRefreshIndicator()'),source.indexOf('  private feedContent()'));
assert(indicator.includes(".height(64).justifyContent(FlexAlign.Center)"),'home indicator must occupy and center within the refresh slot');
assert(indicator.includes('this.homeTopInset() + 48 + (this.home.board ? 68 : 0)'), 'board feed refresh must clear both category bar and board summary');
const expression=indicator.match(/\.visibility\(([\s\S]*?)\)\s*\n/)[1];
const RefreshStatus={Inactive:0,Drag:1,OverDrag:2,Refresh:3,Done:4},Visibility={Visible:1,Hidden:0};
const visible=vm.runInNewContext('(function(){return '+expression+';})',{RefreshStatus,Visibility});
for(const state of [RefreshStatus.Inactive,RefreshStatus.Refresh,RefreshStatus.Done])
  assert.equal(visible.call({refreshing:false,refreshGestureState:state}),Visibility.Hidden,'idle/completed refresh cannot leave a spinner visible');
for(const state of [RefreshStatus.Drag,RefreshStatus.OverDrag])
  assert.equal(visible.call({refreshing:false,refreshGestureState:state}),Visibility.Visible);
assert.equal(visible.call({refreshing:true,refreshGestureState:RefreshStatus.Refresh}),Visibility.Visible);
assert(source.includes('.onStateChange((state: RefreshStatus) => { this.refreshGestureState = state; })'));
console.log('Home refresh: pull, threshold, active refresh, finish and inactive visibility passed');
for(const [path,name,field,inset] of [
  ['feature_search/src/main/ets/components/PinmonySearchPage.ets','searchRefreshIndicator','searchRefreshState','searchFeedInset'],
  ['feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','inboxRefreshIndicator','inboxRefreshState','inboxTopInset'],
  ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets','profileRefreshIndicator','profileRefreshState','hubContentInset']
]){
  const text=fs.readFileSync(path,'utf8'),start=text.indexOf('  private '+name+'()');
  const block=text.slice(start,text.indexOf('\n  }',start));
  assert(block.includes('.height(64).justifyContent(FlexAlign.Center)'),'indicator must center within the refresh slot instead of resting at its lower edge');
  const expr=block.match(/\.visibility\(([\s\S]*?)\)\s*\n/)[1];
  const check=vm.runInNewContext('(function(){return '+expr+';})',{RefreshStatus,Visibility});
  for(const state of [0,3,4])assert.equal(check.call({refreshing:false,[field]:state}),Visibility.Hidden);
  for(const state of [1,2])assert.equal(check.call({refreshing:false,[field]:state}),Visibility.Visible);
  assert.equal(check.call({refreshing:true,[field]:3}),Visibility.Visible);
  assert(block.includes('.offset({ y: this.'+inset+'() })'),'refresh indicator avoids its own page header');
  assert(text.includes('builder: this.'+name)&&text.includes('this.'+field+' = state'));
}
console.log('Search and inbox refresh: header clearance and pull/finish visibility passed');
