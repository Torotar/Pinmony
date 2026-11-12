const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const file = 'feature_profile/src/main/ets/components/PinmonyProfilePage.ets';
const source = fs.readFileSync(file, 'utf8');
const ast = ts.createSourceFile('profile.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);
function method(name) {
  let found;
  function visit(node) {
    if (ts.isMethodDeclaration(node) && node.name.getText(ast) === name) found = node;
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert(found, `Missing profile method: ${name}`);
  return found;
}
const button = method('hubStateButton');
const versionBranch = button.body.statements[0];
assert(ts.isIfStatement(versionBranch));
assert.equal(versionBranch.expression.getText(ast), "deviceInfo.apiAvailable('26.0.0')");
const native = versionBranch.thenStatement.getText(ast);
const fallback = versionBranch.elseStatement.getText(ast);
assert(!native.includes(".backgroundColor(this.hubSelected(kind) ? $r('app.color.detail_save_accent') : $r('app.color.surface_muted'))"),
  'Native material filters must not also paint the opaque selected/fallback background during pager updates');
const material = native.match(/\.systemMaterial\(([\s\S]*?)\)\s*\.shadow\(/);
const shadow = native.match(/\.shadow\(([\s\S]*?)\)\s*\.accessibilityText\(/);
assert(material && shadow, 'Read the actual material and shadow expressions from the button');
assert(!material[1].includes('!this.hubSelected'), 'Selecting a filter must not disable immersive material');
assert(!shadow[1].includes('!this.hubSelected'), 'Selecting a filter must retain its material shadow');
assert(!/systemMaterial|uiMaterial\.|ColorMetrics/.test(fallback), 'API 24/25 keep the original Toggle path');
assert(fallback.includes('Toggle({type:ToggleType.Button,isOn:this.hubSelected(kind)})'));
assert(fallback.includes(".selectedColor($r('app.color.detail_save_accent'))"));
for (const branch of [native, fallback]) {
  assert(branch.includes('.accessibilitySelected(this.hubSelected(kind))'));
  assert(branch.includes('.enabled(this.interactionReady && !this.profile.suggestionWriting)'));
  assert(branch.includes("this.hubSelected(kind) ? Color.White : $r('app.color.primary_text')"));
}
const clickMatches = [...button.getText(ast).matchAll(/\.onClick\((\(\) => \{[\s\S]*?\n      \})\)/g)];
assert.equal(clickMatches.length, 2, 'Exercise both native and fallback click handlers');
const surfaces = [];
function collectSurfaces(node) {
  if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) &&
      node.expression.name.text === 'systemMaterial' && node.arguments[0]?.getText(ast).includes('this.hubControlMaterial(')) {
    let preceding = node.expression.expression;
    let background;
    while (ts.isCallExpression(preceding) && ts.isPropertyAccessExpression(preceding.expression)) {
      if (preceding.expression.name.text === 'backgroundColor') {
        background = preceding.arguments[0].getText(ast); break;
      }
      preceding = preceding.expression.expression;
    }
    assert(background, 'Every actual material control explicitly defines its fallback background');
    surfaces.push({ material: node.arguments[0].getText(ast), background });
  }
  ts.forEachChild(node, collectSurfaces);
}
collectSurfaces(ast);
assert.equal(surfaces.length, 5, 'Inspect actual filter, layout, sort, search and publish modifier chains');
const kinds = ['favorite', 'created', 'groups', 'secret', 'following', 'collage-drafts', 'collage-created'];
function boot(api, supported = true, failColor = false, rgb = [230, 0, 35]) {
  let probes = 0, colors = 0;
  const empty = Symbol('empty');
const code = 'class Host {' + ['hubSelected', 'hubStateMaterialColor', 'hubMaterialEnabled', 'hubControlBackground', 'hubControlMaterial'].map(n => method(n).getText(ast)).join('\n') +
    `\nrender(kind) { if (${versionBranch.expression.getText(ast)}) return { material: ${material[1]}, shadow: ${shadow[1]} }; return undefined; }\n` +
    '\nrenderSurfaces(kind) { return [' + surfaces.map(surface => '{material:' + surface.material + ',background:' + surface.background + '}').join(',') + ']; }\n' +
    clickMatches.map((match, index) => `click${index}(kind) { return (${match[1]})(); }`).join('\n') + '\n} Host;';
  const Host = vm.runInNewContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
    deviceInfo: { apiAvailable: version => { assert.equal(version, '26.0.0'); return api >= 26; } },
    uiMaterial: { Material: { empty }, ImmersiveStyle: { THICK: 3, REGULAR: 2, ULTRA_THIN: 0 },
      isImmersiveMaterialSupported() { probes++; assert(api >= 26); return supported; },
      ImmersiveMaterial: class { constructor(options) { Object.assign(this, options); } } },
    $r: key => key, Color: { Transparent: 'transparent' },
    ColorMetrics: {
      resourceColor(key) { colors++; assert.equal(key, 'app.color.detail_save_accent'); if (failColor) throw Error('color unavailable'); return { red: rgb[0], green: rgb[1], blue: rgb[2] }; },
      rgba: (r, g, b, a) => ({ color: `rgba(${r},${g},${b},${a})` })
    }
  });
  const host = new Host();
  Object.assign(host, { immersiveLightMode: 'immersive', hdsDarkMode: false, favoriteFilter: false, createdFilter: false,
    hubControlMaterials: new Map(), hubMaterialConfiguration: '',
    boardFilter: '', collageDrafts: false, collageCreated: false, interactionReady: true, profile: { suggestionWriting: false },
    getUIContext: () => ({ vp2px: value => value * 3 }),
    requests: 0, requestHub() { this.requests++; } });
  return { host, empty, probes: () => probes, colors: () => colors };
}
for (const api of [24, 25]) {
  const h = boot(api);
  assert.equal(h.host.hubControlMaterial('publish'),undefined,'legacy runtime never accesses native material APIs');
  for (const kind of kinds) for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
    h.host.immersiveLightMode = mode;
    assert.equal(h.host.render(kind), undefined);
  }
  assert.equal(h.probes(), 0); assert.equal(h.colors(), 0);
  assert.equal(h.host.hubControlBackground('ordinary-background'), 'ordinary-background', 'Older APIs retain ordinary colors without probing unsupported material APIs');
  assert.equal(h.probes(), 0);
}
for (const dark of [false, true]) {
  const rgb = dark ? [255, 70, 100] : [230, 0, 35];
  for (const mode of ['gentle', 'immersive', 'exquisite']) for (const kind of kinds) {
    const h = boot(26, true, false, rgb), host = h.host;
    host.immersiveLightMode = mode; host.hdsDarkMode = dark;
    for (const surface of host.renderSurfaces(kind)) {
      assert.equal(surface.background, 'transparent', 'Active material must own the background on every actual header control');
      assert.notEqual(surface.material, h.empty);
    }
    const before = host.render(kind);
    assert.equal(before.material.materialColor, undefined);
    host.click0(kind);
    assert.equal(host.hubSelected(kind), true);
    const selected = host.render(kind);
    for (const surface of host.renderSurfaces(kind)) assert.equal(surface.background, 'transparent', 'Selecting a filter keeps the backing transparent; accent tint belongs to materialColor');
    assert.notEqual(selected.material, h.empty, `${kind}: selected material stays enabled`);
    assert.equal(selected.material.materialColor, `rgba(${rgb.join(',')},0.9)`);
    assert.equal(selected.material.style, mode === 'gentle' ? 3 : 2);
    assert.equal(selected.material.colorInvert, false);
    assert.equal(selected.material.interactive, true);
    assert.equal(selected.material.applyShadow, false);
    assert.equal(selected.material.lightEffect.color, 'app.color.immersive_interaction_light');
    for (const surface of host.renderSurfaces(kind)) {
      assert.equal(surface.material.lightEffect.color, 'app.color.immersive_interaction_light',
        'All profile header controls share the theme-aware soft red interaction light');
    }
    assert.equal(selected.shadow.radius, 18);
    assert.equal(selected.shadow.offsetY, 3);
    assert.equal(selected.shadow.color, dark ? '#33000000' : '#14000000');
    host.immersiveLightMode = 'off';
    const off = host.render(kind);
    assert.equal(off.material, h.empty); assert.equal(off.shadow.radius, 18);
    const offSurfaces = host.renderSurfaces(kind);
    assert.equal(offSurfaces[0].background, 'app.color.detail_save_accent', 'Material off keeps selected accent background');
    assert.equal(offSurfaces[1].background, 'app.color.surface_muted');
    assert.equal(offSurfaces[2].background, 'app.color.surface_muted');
    assert.equal(offSurfaces[3].background, 'transparent', 'Ordinary search retains its original transparent background');
    assert.equal(offSurfaces[4].background, 'app.color.input_surface');
    host.immersiveLightMode = mode;
    assert.notEqual(host.render(kind).material, h.empty, 'Changing mode restores material on retained selection');
    host.click0(kind);
    assert.equal(host.hubSelected(kind), false);
    assert.equal(host.render(kind).material.materialColor, undefined, 'Deselection removes the accent tint');
    for (const surface of host.renderSurfaces(kind)) assert.equal(surface.background, 'transparent');
    assert.equal(host.requests, 2);
  }
}
for (const kind of kinds) {
  const h = boot(26, false);
  h.host.click0(kind);
  assert.equal(h.host.render(kind).material, h.empty);
  assert.equal(h.host.render(kind).shadow.radius, 18);
  assert.equal(h.host.renderSurfaces(kind)[0].background, 'app.color.detail_save_accent', 'Unsupported material keeps selected fallback color');
  h.host.click0(kind);
  assert.equal(h.host.renderSurfaces(kind)[0].background, 'app.color.surface_muted', 'Unsupported material keeps ordinary fallback color');
  assert.equal(h.colors(), 0, 'Unsupported devices do not resolve tint');
}
const failed = boot(26, true, true);
failed.host.click0('favorite');
assert.equal(failed.host.render('favorite').material.materialColor, 'app.color.detail_save_accent');
for(const mode of ['gentle','immersive','exquisite'])for(const dark of [false,true]) {
  const {host}=boot(26);host.immersiveLightMode=mode;host.hdsDarkMode=dark;
  const controls=['layout','sort','search','publish',...kinds.map(kind=>'filter-'+kind)];
  const materialFor=control=>host.hubControlMaterial(control,control.startsWith('filter-')?control.slice(7):'');
  const retained=controls.map(materialFor);
  assert.equal(new Set(retained).size,controls.length,'interactive controls own separate material objects');
  for(let frame=0;frame<120;frame++) {
    host.hubPagerPosition=frame/60;host.hubTab=['pins','boards','collages'][Math.min(2,Math.floor(frame/40))];
    host.uiLanguage=frame%2?'zh':'en';host.profile.contentLoading=frame%3===0;
    controls.forEach((control,index)=>assert.equal(materialFor(control),retained[index],control+': pager/language/loading updates retain material identity'));
    for(const surface of host.renderSurfaces('favorite'))assert.equal(surface.background,'transparent','Every pager frame retains transparent backing instead of repainting gray');
  }
  assert.equal(retained[2].style,mode==='gentle'?3:0,'search keeps its thin material');
  host.click0('favorite');const selected=materialFor('filter-favorite');
  assert.notEqual(selected,retained[4]);assert.equal(materialFor('filter-favorite'),selected);
  assert.equal(materialFor('publish'),retained[3],'filter selection does not replace publish material');
  host.click0('favorite');assert.equal(materialFor('filter-favorite'),retained[4],'deselection reuses the normal material');
  const oldPublish=materialFor('publish');host.hdsDarkMode=!dark;
  assert.notEqual(materialFor('publish'),oldPublish,'theme changes refresh material tint');
  host.immersiveLightMode='off';host.hubControlMaterial('publish');assert.equal(host.hubControlMaterials.size,0);
  host.immersiveLightMode=mode;assert.notEqual(materialFor('publish'),oldPublish,'reenabling light creates a valid new material');
  assert(host.hubControlMaterials.size<=controls.length*2,'cache stays bounded by controls and their two visual states');
}
for (const index of [0, 1]) {
  for (const kind of kinds) {
    const { host } = boot(26);
    host.interactionReady = false; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 0);
    host.interactionReady = true; host.profile.suggestionWriting = true; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 0);
    host.profile.suggestionWriting = false; host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), true); assert.equal(host.requests, 1);
    host[`click${index}`](kind);
    assert.equal(host.hubSelected(kind), false); assert.equal(host.requests, 2);
  }
}
const pins = boot(26).host;
pins.click0('favorite'); pins.click0('created');
assert(pins.favoriteFilter && pins.createdFilter, 'Favorite and created filters may be combined');
for (const kind of ['groups', 'secret', 'following']) {
  pins.click0(kind); assert.equal(pins.boardFilter, kind);
}
pins.click0('collage-drafts'); pins.click0('collage-created');
assert(pins.collageCreated && !pins.collageDrafts, 'Collage modes remain mutually exclusive');
const filters = method('hubFilters').getText(ast);
for (const kind of kinds) assert(filters.includes(`,'${kind}')`), `Missing filter entry: ${kind}`);
console.log('Profile filter material passed: five actual header modifier chains with transparent material backing, seven kinds, selected/unselected tint, four modes, theme colors, off/reset, capability fallback, API 24/25 gates, click guards and filter combinations.');

const dragFilterStrip = source.slice(source.indexOf('private hubFilters(tab: string)'), source.indexOf('private hubSearchContent()'));
assert(dragFilterStrip.includes('.scrollable(ScrollDirection.Horizontal)'));
assert(dragFilterStrip.includes('.enableScrollInteraction(true)'), 'Overflow filter rows accept horizontal touch scrolling');
assert(dragFilterStrip.includes('.scrollable(ScrollDirection.Horizontal)'), 'Filter strip scrolls horizontally');
assert(dragFilterStrip.includes('.width(\'100%\')'), 'Filter viewport stays within the available page width');
for (const kind of ['favorite','created','groups','secret','following','collage-created','collage-drafts']) {
  assert(dragFilterStrip.includes("'" + kind + "'"), `Shared scrollable strip retains ${kind}`);
}
assert(dragFilterStrip.includes('.edgeEffect(EdgeEffect.None)'), 'Filter rows must not rebound during horizontal drag');
for (const kind of ['collage-created', 'collage-drafts', 'favorite', 'groups']) assert(dragFilterStrip.includes("'" + kind + "'"));
console.log('Profile filter strip: horizontal touch scrolling and rebound disabled for collage, Pin and board filters passed');

const searchHostCode = 'class SearchHost {' + ['canUseHubSearchControls', 'openHubSearch', 'openHubPublish',
  'hubTitlePosition', 'hubTitleSearchOpacity', 'hubTitleBottomHeight'].map(n => method(n).getText(ast)).join('\n') + '} SearchHost;';
const SearchHost = vm.runInNewContext(ts.transpileModule(searchHostCode, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText);
const searchHost = new SearchHost();
Object.assign(searchHost, { interactionReady: true, profile: { suggestionWriting: false }, hubTab: 'pins',
  hubPagerPosition: -1, hubChromeOffset: 0, searches: 0, publishes: 0, offsets: {},
  hubPaneChromeOffset(tab) { return this.offsets[tab] || 0; },
  hubHeaderBackgroundOpacity() { return 1 - this.hubChromeOffset / 112; },
  onSearch() { this.searches++; }, onPublish() { this.publishes++; } });
function assertSearchAction(allowed, label) {
  const before = [searchHost.searches, searchHost.publishes];
  assert.equal(searchHost.canUseHubSearchControls(), allowed, label);
  searchHost.openHubSearch(); searchHost.openHubPublish();
  assert.equal(searchHost.searches, before[0] + Number(allowed), label + ': search callback');
  assert.equal(searchHost.publishes, before[1] + Number(allowed), label + ': publish callback');
}
for (const tab of ['pins', 'boards', 'collages']) {
  searchHost.hubTab = tab;
  assertSearchAction(tab !== 'collages', tab + ': idle visible controls');
  for (const position of [0, 0.5, 1, 1.5, 1.99, 2]) {
    searchHost.hubPagerPosition = position;
    assertSearchAction(false, tab + ': switching at ' + position);
  }
  searchHost.hubPagerPosition = -1;
  searchHost.hubChromeOffset = 28; searchHost.offsets[tab] = 28;
  assertSearchAction(false, tab + ': partly collapsed');
  searchHost.hubChromeOffset = 112; searchHost.offsets[tab] = 112;
  assertSearchAction(false, tab + ': collapsed');
  searchHost.hubChromeOffset = 0; searchHost.offsets = {};
  searchHost.interactionReady = false; assertSearchAction(false, tab + ': covered page');
  searchHost.interactionReady = true; searchHost.profile.suggestionWriting = true;
  assertSearchAction(false, tab + ': writing'); searchHost.profile.suggestionWriting = false;
  assertSearchAction(tab !== 'collages', tab + ': restored');
}
const searchBuilder = method('hubSearch').getText(ast);
assert.equal((searchBuilder.match(/\.enabled\(this.canUseHubSearchControls\(\)\)/g) || []).length, 4,
  'API 26 and API 24/25 search and publish buttons share the visibility gate');
for (const action of ['openHubSearch', 'openHubPublish']) {
  assert.equal((searchBuilder.match(new RegExp('this\\.' + action + '\\(\\)', 'g')) || []).length, 2);
}
assert(!/this\.onSearch|this\.onPublish/.test(searchBuilder), 'No unguarded hidden search/publish callbacks');
const titleBottom = method('hubCustomTitleBottom').getText(ast);
assert(titleBottom.includes('.visibility(this.hubTitleSearchOpacity() > 0 ? Visibility.Visible : Visibility.Hidden)'));
assert(titleBottom.includes('.hitTestBehavior(this.canUseHubSearchControls() ? HitTestMode.Default : HitTestMode.None)'));
assert(titleBottom.includes(".accessibilityLevel(this.canUseHubSearchControls() ? 'auto' : 'no-hide-descendants')"));
console.log('Profile search isolation passed: hidden collage row, both callbacks, three tabs, pager frames, collapse, covered/writing and return states.');
