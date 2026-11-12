const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySocialPermissionsPage.ets', 'utf8');
const bar = page.slice(page.indexOf('private messageTabControls()'), page.indexOf('private messageChipItems()'));
for (const token of ['ChipGroup({ items: this.messageChipItems()', 'multiple: false', 'backgroundSystemMaterial: PinmonySocialMessageMaterial.create(this.immersiveLightMode, false)', 'selectedBackgroundSystemMaterial: PinmonySocialMessageMaterial.create(this.immersiveLightMode, true)', "PinmonySocialMessageMaterial.itemStyle('off', this.messageChipMetrics())", "if (deviceInfo.apiAvailable('26.0.0'))", 'this.selectMessageTab(indexes[0])']) assert(bar.includes(token), token);
assert.equal((bar.match(/this\.messageChipMetrics\(\)/g) || []).length, 2, 'both API branches use measured sizes');
assert.equal((bar.match(/height\(this\.messageChipBarHeight\(\)\)/g) || []).length, 3, 'both branches and shared host grow together');
const fallback = bar.slice(bar.indexOf('} else {'));
assert(!fallback.includes('backgroundSystemMaterial:') && !fallback.includes('selectedBackgroundSystemMaterial:'));
assert.equal((page.match(/HdsNavigation\(/g) || []).length, 1, 'only original route Navigation remains');
assert.equal((page.match(/\.titleBar\(/g) || []).length, 1, 'one actual title bar');
assert(page.includes('bottomBuilder: this.hasMessageTabs() ? { builder: (): void => { this.messageTabControls(); } } : undefined'));
assert.equal((page.match(/maskExtraHeight: 0/g) || []).length, 2, 'both title states stop mask at the real title including bottomBuilder');
const layout = page.slice(page.indexOf('private messageTabs()'), page.indexOf('private shoppingAndDownloads()'));
assert(!layout.includes('HdsNavigation') && !layout.includes('titleBar('));
for (const token of ['Scroll(this.scroller)', 'top:this.titleContentInset() + this.messageChipBarHeight() + 16', 'this.messageChoices()', 'pm_social_business_messages', 'this.swipeMessageTab(event.offsetX, event.offsetY)']) assert(layout.includes(token), token);
assert(page.includes('.bindToScrollable([this.scroller])'));
const names = ['uiText', 'pageScreen', 'title', 'titleContentInset', 'messageTabLabel', 'messageTabIds', 'messageChipItems', 'messageChipMetrics', 'messageChipBarHeight', 'hasMessageTabs', 'selectMessageTab'];
const ast = ts.createSourceFile('page.ts', page.replace(/\bstruct\b/g, 'class'), 99, true), methods = [];
function visit(node) { if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast)); ts.forEachChild(node, visit); }
visit(ast); assert.equal(methods.length, names.length);
const start = page.indexOf('{ avoidLayoutSafeArea: true', page.indexOf('}.titleBar('));
const end = page.indexOf(', this.hdsDarkMode))', start);
assert(start > 0 && end > start);
const options = page.slice(start, end);
const light = fs.readFileSync('common_ui/src/main/ets/services/PinmonyImmersiveLight.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
let texts = new Map();
const context = { PinmonyI18n: { text: key => texts.get(key) || key }, $r: key => key,
  FontWeight: { Bold: 'bold' }, Color: { Transparent: 'transparent' },
  hdsMaterial: { MaterialType: { ADAPTIVE: 'adaptive', IMMERSIVE: 'immersive' }, MaterialLevel: { SMOOTH: 'smooth', GENTLE: 'gentle', EXQUISITE: 'exquisite' }, getSystemMaterialTypes: () => ['immersive'] },
  BlurStrategy: { ENABLE: true, DISABLE: false }, ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 'gradient' } };
const Host = vm.runInNewContext(ts.transpileModule(light + '\nclass Host {' + methods.join('\n') + '\noptions() { return ' + options + '; }} Host;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, context);
const host = new Host();
host.store = { screen: 'socialMessages', social: { personal: true, business: false }, socialMessageGroup: 0, busy: false, loading: false };
host.routeScreen = ''; host.visible = true; host.active = true; host.confirming = false; host.statusBarHeightPx = 80;
let scale = 1;
const textWidth = text => Array.from(text).reduce((sum, c) => sum + (/[^\x00-\xff]/.test(c) ? 16 : 10), 0) * scale;
host.getUIContext = () => ({ px2vp: n => n / 2, getMeasureUtils: () => ({ measureTextSize: o => {
  assert.equal(o.fontSize, 'sys.float.chip_normal_font_size'); assert.equal(o.fontWeight, 'bold');
  return { width: textWidth(o.textContent) * 2, height: 20 * scale * 2 };
} }) });
for (const locale of ['base', 'zh_CN', 'zh_TW', 'en_US', 'en_GB', 'ja', 'ko', 'ru', 'pt_BR']) {
  const rows = JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
  texts = new Map(rows.map(row => [row.name, row.value])); host.uiLanguage = locale;
  for (const business of [false, true]) for (scale of [1, 1.5, 2, 3]) {
    host.store.social.business = business;
    const ids = Array.from(host.messageTabIds()); assert.deepEqual(ids, business ? [-1, 0, 1, 2, 4] : [0, 1, 2, 4]);
    const metrics = host.messageChipMetrics();
    const items = host.messageChipItems();
    for (let i = 0; i < ids.length; i++) {
      assert.equal(items[i].label.text, host.messageTabLabel(ids[i]), 'complete original localized text');
      assert(metrics.width >= textWidth(items[i].label.text) + 40, 'no viewport/default-width cap');
      assert(metrics.height >= 20 * scale + 16, 'large-font height');
      host.selectMessageTab(i); assert.equal(host.store.socialMessageGroup, ids[i]);
    }
    assert.equal(host.messageChipBarHeight(), metrics.height + 12);
    for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
      host.immersiveLightMode = mode; const o = host.options();
      assert(o.content.bottomBuilder); assert.equal(o.style.originalStyle.backgroundStyle.maskExtraHeight, 0); assert.equal(o.style.scrollEffectStyle.backgroundStyle.maskExtraHeight, 0);
      assert.equal(o.style.systemMaterialEffect?.materialType, mode === 'off' ? undefined : mode === 'gentle' ? 'adaptive' : 'immersive');
      let built = 0; host.messageTabControls = () => built++; o.content.bottomBuilder.builder(); assert.equal(built, 1);
    }
  }
}
const selected = host.store.socialMessageGroup;
for (const [owner, flag, value] of [[host, 'active', false], [host, 'visible', false], [host, 'confirming', true], [host.store, 'busy', true], [host.store, 'loading', true]]) {
  const old = owner[flag]; owner[flag] = value; host.selectMessageTab(0); assert.equal(host.store.socialMessageGroup, selected); owner[flag] = old;
}
for (const route of ['social', 'socialFriends', 'socialFollowers', 'socialFollowing', 'socialOthers', 'socialBlocked']) {
  host.routeScreen = route; assert.equal(host.hasMessageTabs(), false); assert.equal(host.options().content.bottomBuilder, undefined); assert.equal(host.options().style.originalStyle.backgroundStyle.maskExtraHeight, 0);
}
const chipSource = fs.readFileSync('feature_settings/src/main/ets/components/PinmonySocialMessageMaterial.ets', 'utf8').replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
let api = false, supported = false; const empty = {};
const ChipMaterial = vm.runInNewContext(ts.transpileModule(chipSource + '\nPinmonySocialMessageMaterial;', { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, {
 ColorMetrics: { resourceColor: key => { assert.equal(key, 'app.color.detail_save_accent'); return { red: 230, green: 0, blue: 35 }; }, rgba: (r,g,b,a) => { assert.equal(a, 0.9); return { color: 'home-selected-tint' }; } }, deviceInfo: { apiAvailable: () => api }, Color: { Transparent: 'transparent', White: 'white' }, $r: k => k,
 uiMaterial: { isImmersiveMaterialSupported: () => { assert(api); return supported; }, Material: { empty }, ImmersiveStyle: { THICK: 'thick', REGULAR: 'regular' }, ImmersiveMaterial: class { constructor(o) { Object.assign(this, o); } } }
});
for (api of [false, true]) for (supported of [false, true]) for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) {
 const active = api && supported && mode !== 'off', size = { width: 500, height: 60 }, style = ChipMaterial.itemStyle(mode, size);
 assert.equal(style.size, size); assert.equal(style.backgroundColor, active ? 'transparent' : 'app.color.input_surface'); assert.equal(style.selectedBackgroundColor, active ? 'transparent' : 'app.color.detail_save_accent');
 for (const selected of [false, true]) { const material = ChipMaterial.create(mode, selected); if (!api) assert.equal(material, undefined); else if (!active) assert.equal(material, empty); else { assert.equal(material.style, mode === 'gentle' ? 'thick' : 'regular'); assert.equal(material.materialColor, selected ? 'home-selected-tint' : undefined); } }
}
console.log('Message chip layout: one title/bottom region, all 9 locales x 2 account types x 4 font scales measured without width cap, full labels, bounded title mask and home selected tint, retained-page guards and API24/material branches passed');

const home = fs.readFileSync('feature_home/src/main/ets/components/PinmonyHomeCategoryMaterial.ets','utf8');
for (const token of ["$r('app.color.detail_save_accent')", 'ColorMetrics.rgba(accent.red, accent.green, accent.blue, 0.9).color', 'uiMaterial.ImmersiveStyle.REGULAR']) { assert(home.includes(token)); assert(chipSource.includes(token)); }
