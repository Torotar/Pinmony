const fs = require('node:fs');
const assert = require('node:assert/strict');

// Full-screen roots and secondary hosts must not reserve an empty split pane.
for (const [file, expected] of [
  ['feature_home/src/main/ets/components/PinmonyHomePage.ets', 1],
  ['feature_search/src/main/ets/components/PinmonySearchPage.ets', 2],
  ['feature_inbox/src/main/ets/components/PinmonyInboxPage.ets', 1],
  ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets', 3],
  ...['PinmonyBoardSectionPage', 'PinmonyBoardPage', 'PinmonyBoardCollaboratorsPage']
    .map(name => [`feature_board/src/main/ets/components/${name}.ets`, 1]),
  ...['PinmonyPublishPhotoEditor', 'PinmonyPublishPage', 'PinmonyProfilePanelPage',
    'PinmonyOrganizePage', 'PinmonyBoardOrderPage']
    .map(name => [`feature_profile/src/main/ets/components/${name}.ets`, 1]),
  ['feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets', 2],
  ...['PinmonyInboxNewsPage', 'PinmonyInboxFlowPage']
    .map(name => [`feature_inbox/src/main/ets/components/${name}.ets`, 1]),
  ['feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 1],
  ...['PinmonyVisibilitySettingsPage', 'PinmonySettingsPage', 'PinmonyRecommendationSettingsPage',
    'PinmonyDisplaySettingsPage', 'PinmonyBoardRecoveryPage', 'PinmonyAccountPage']
    .map(name => [`feature_settings/src/main/ets/components/${name}.ets`, 1])
]) {
  const source = fs.readFileSync(file, 'utf8');
  const starts = [...source.matchAll(/^\s*HdsNavigation\(/gm)];
  assert.equal(starts.length, expected, `${file}: audit new navigation hosts`);
  for (const match of starts) {
    const open = source.indexOf('{', match.index);
    let depth = 1, end = open + 1;
    for (; end < source.length && depth; end++) {
      if (source[end] === '{') depth++;
      if (source[end] === '}') depth--;
    }
    assert.equal(depth, 0, `${file}: navigation body`);
    assert.match(source.slice(end), /^\s*\.mode\(NavigationMode\.Stack\)/,
      `${file}: full-width content needs explicit stack mode`);
  }
}
console.log('Navigation width passed: four roots and full-screen board, detail, publish, profile, inbox and settings hosts.');
