const fs = require('node:fs'), assert = require('node:assert/strict');
const files = [
  'entry/src/main/ets/pages/Index.ets',
  'common_ui/src/main/ets/components/PinmonyImageSearchView.ets',
  'feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets',
  'feature_search/src/main/ets/components/PinmonySearchPage.ets',
  'feature_board/src/main/ets/components/PinmonyBoardPage.ets',
  'feature_board/src/main/ets/components/PinmonyBoardSectionPage.ets',
  'feature_profile/src/main/ets/components/PinmonyProfilePage.ets',
  'feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets',
  'feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets',
  'feature_settings/src/main/ets/components/PinmonyVisibilitySettingsPage.ets'
];
for (const file of files) {
  const source = fs.readFileSync(file,'utf8');
  assert.match(source,/import[^;]*\bLengthMetrics\b[^;]*from '@kit.ArkUI'/,file);
  assert.match(source,/\.bindSheet\([^\n]*\{\s*radius: LengthMetrics\.vp\(32\)/,file);
  assert(!/radius: \{ topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 \}/.test(source),file);
  assert(!source.includes('radius=four-corners-32vp'), 'trace must describe the actual uniform LengthMetrics radius: '+file);
}
assert.equal((fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets','utf8').match(/radius: LengthMetrics\.vp\(32\)/g)||[]).length,2,'both inbox menus are covered');
// Scan every active module so a new sheet cannot escape the targeted list.
for(const root of fs.readdirSync('.').filter(name=>name==='entry'||name.startsWith('common_')||name.startsWith('feature_'))) {
  function scan(dir) {
    for(const entry of fs.readdirSync(dir,{withFileTypes:true})) {
      const file=dir+'/'+entry.name;
      if(entry.isDirectory())scan(file);
      else if(file.endsWith('.ets')) {
        const source=fs.readFileSync(file,'utf8');
        assert(!/radius:\s*\{\s*topLeft:\s*32,\s*topRight:\s*32,\s*bottomLeft:\s*32,\s*bottomRight:\s*32\s*\}/.test(source),file);
        for(const binding of source.matchAll(/\.bindSheet\([^\n]*\{\s*([^\n]*)/g))
          assert.match(binding[1],/^radius:\s*LengthMetrics\.vp\(32\)/,'every sheet supplies a typed radius: '+file);
      }
    }
  }
  if(fs.existsSync(root+'/src/main/ets'))scan(root+'/src/main/ets');
}
console.log('Sheet radius compatibility: all eighteen bindings supply a typed radius; active modules passed');
