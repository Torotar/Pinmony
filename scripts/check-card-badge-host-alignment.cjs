const fs = require('node:fs'), assert = require('node:assert/strict');
const files = [
  "common_ui/src/main/ets/components/PinmonyPinCountBadge.ets",
  "common_ui/src/main/ets/components/PinmonyVideoCard.ets",
  "feature_home/src/main/ets/components/PinmonyHomeFeedPane.ets",
  "feature_search/src/main/ets/components/PinmonySearchPage.ets",
  "feature_board/src/main/ets/components/PinmonyBoardPage.ets",
  "feature_profile/src/main/ets/components/PinmonyProfilePage.ets",
  "feature_profile/src/main/ets/components/PinmonyProfileSearchPage.ets",
  "feature_profile/src/main/ets/components/PinmonyOrganizePage.ets",
  "feature_pin/src/main/ets/components/PinmonyDetailPage.ets"
];
function calls(source){const out=[];const re=/Pinmony(?:PinCount|CardMedia)Badge\(/g;let match;while((match=re.exec(source))){let depth=1,i=re.lastIndex,quote='';for(;i<source.length&&depth;i++){let c=source[i];if(quote){if(c==='\\'){i++;continue;}if(c===quote)quote='';continue;}if(c==='"'||c==="'"||c==='`'){quote=c;continue;}if(c==='(')depth++;if(c===')')depth--;}if(depth)throw Error('unclosed component');out.push({start:match.index,end:i});re.lastIndex=i;}return out;}
let checked = 0;
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  const found = calls(source);
  assert(found.length > 0, file + ': no badge invocations');
  for (const call of found) {
    assert.match(source.slice(call.end), /^\s*\.align\(Alignment.TopStart\)\.hitTestBehavior\(HitTestMode.None\)/,
      file + ': badge host must explicitly override parent Stack alignment and allow card clicks');
    checked++;
  }
}
const board = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const organize = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyOrganizePage.ets', 'utf8');
function checkImageOverlay(source, builder, overlay, owner) {
  const body = source.slice(source.indexOf(builder));
  const image = body.slice(body.indexOf('Image(pin.imageUrl)'), body.indexOf('if (', body.indexOf('Image(pin.imageUrl)')));
  assert(image.includes(overlay), owner + ': badge must be attached to the actual image with a top-left overlay');
  assert.doesNotMatch(image, /Pinmony(?:PinCount|CardMedia)Badge\(/, owner + ': no badge sibling inheriting BottomEnd');
  assert.match(body, /Stack\(\{ alignContent: Alignment.BottomEnd \}\)/, owner + ': preserve original bottom-right action parent');
}
const layouts = [
  [board, 'private card(pin:', '.overlay(this.cardMediaBadge(pin), { align: Alignment.TopStart })', 'board'],
  [organize, 'private thumb(pin:', '.overlay(this.pinCountBadge(pin.mediaCount || 0), { align: Alignment.TopStart })', 'organize']
];
for (const args of layouts) checkImageOverlay(...args);
assert.match(board, /private cardMediaBadge\(pin: PinmonyBoardPin\) \{\s*Stack\(\{ alignContent: Alignment.TopStart \}\)/);
assert.match(board, /\.borderRadius\(17\)\.margin\(6\)/, 'board selection remains unchanged');
assert.match(board, /\}\.width\(36\)\.height\(36\)\.margin\(8\)/, 'board ideas save remains unchanged');
assert.match(organize, /\.borderRadius\(15\)\.margin\(6\)/, 'organize selection remains unchanged');
assert.match(board, /if \(this.selectingPins\(\) && this.selectedIds.includes\(pin.id\)\)/);
assert.match(organize, /if \(this.selected\(pin\)\)/);
// The previous failing version already had TopStart on every custom-component call.
// Reject its actual parent layout even when those superficial style checks pass.
for (const [source, builder, overlay, owner] of layouts) {
  const previous = source.replace(overlay, 'PinmonyPinCountBadge({ mediaCount: 7 }).align(Alignment.TopStart).hitTestBehavior(HitTestMode.None)');
  assert.throws(() => checkImageOverlay(previous, builder, overlay, owner), /actual image/, owner + ': detect previous failing sibling despite TopStart call');
  assert.throws(() => checkImageOverlay(source.replace(overlay, overlay.replace('TopStart', 'BottomEnd')), builder, overlay, owner), /actual image/, owner + ': reject wrong overlay corner');
}
console.log('Badge hosts: ' + checked + ' invocations across ' + files.length + ' sources explicitly position top-left and pass touches; bottom-right selectors preserved; old omission detected');
