const assert = require('node:assert/strict');
const fs = require('node:fs');
const source = fs.readFileSync('entry/src/main/ets/components/PinmonyLoginPage.ets', 'utf8');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const events = [];
let current = true, loading = true;
const view = {
  controller: {}, isCurrent: () => current,
  onLoadingChanged: value => { loading = value; events.push('loading:' + value); },
  captureEnvironment: () => events.push('capture'),
  lifecycle: { pageBegin: url => events.push(url), pageEnd: () => events.push('end') }
};
function callback(name) {
  const match = source.match(new RegExp('\\.' + name + '\\(\\((?:event)?\\) => \\{ ([^\\n]+) \\}\\)'));
  assert.ok(match, name);
  return Function('view', 'event', match[1]);
}
const begin = callback('onPageBegin'), end = callback('onPageEnd');
assert.match(index, /@State private loginDocumentLoading: boolean = true/);
assert.match(index, /this\.loginPageVisible = true;\s+this\.loginDocumentLoading = true;/);
assert.match(index, /loading: this\.loginDocumentLoading,\s+onLoadingChanged: \(loading: boolean\): void => \{ this\.loginDocumentLoading = loading; \}/);
begin(view, { url: 'https://www.pinterest.com/login/' });
assert.equal(loading, true, 'slow login navigation keeps loading animation');
end(view);
assert.equal(loading, false, 'finished login document reveals form');
begin(view, { url: 'https://accounts.google.com/' });
assert.equal(loading, true, 'subsequent full document navigation shows animation again');
const count = events.length;
current = false;
end(view); begin(view, { url: 'https://www.pinterest.com/login/' });
assert.equal(events.length, count, 'released login controller cannot alter new loading state');
const guard = source.match(/if \((view\.visible && !view\.authenticated && view\.loading)\)/);
assert.ok(guard);
const visible = Function('view', 'return ' + guard[1]);
for (const viewVisible of [false, true]) for (const authenticated of [false, true]) for (const pending of [false, true]) {
  assert.equal(visible({ visible: viewVisible, authenticated, loading: pending }), viewVisible && !authenticated && pending);
}
assert.match(source, /LoadingProgress\(\)\.width\(36\)\.height\(36\)\.color\(\$r\('app\.color\.accent'\)\)/);
assert.match(source, /Stack\(\{ alignContent: Alignment\.Center \}\)/);
assert.match(source, /backgroundColor\(\$r\('app\.color\.page_background'\)\)/);
assert.match(source, /hitTestBehavior\(HitTestMode\.Block\)/);
console.log('Login startup loading checks passed: initial wait, completion, navigation, stale callbacks, visibility and theme.');
