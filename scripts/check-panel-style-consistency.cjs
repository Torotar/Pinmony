const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const PinmonyHdsTitleBar = require('./modal-style-test-fixture.cjs')(ts);
const read = file => fs.readFileSync(file, 'utf8');
const consumers = [
  ['common_ui/src/main/ets/components/PinmonyModalNavigation.ets', 'private titleOptions()'],
  ['common_ui/src/main/ets/components/PinmonyOptionsNavigation.ets', 'private titleOptions()'],
  ['feature_pin/src/main/ets/components/PinmonyShareSheet.ets', 'private closeTitleOptions()'],
  ['feature_pin/src/main/ets/components/PinmonySaveSheet.ets', 'private titleOptions()'],
  ['feature_board/src/main/ets/components/PinmonyBoardSectionPage.ets', null],
  ['feature_profile/src/main/ets/components/PinmonyPublishBoardPage.ets', null]
];
for (const [file, method] of consumers) {
  const source = read(file);
  assert(source.includes('.titleMode(HdsNavigationTitleMode.MODAL)'), file);
  let body;
  if (method) {
    const start = source.indexOf('  ' + method), end = source.indexOf('\n  build()', start);
    body = source.slice(start, end);
  } else {
    const start = source.indexOf('.titleMode(HdsNavigationTitleMode.MODAL)');
    const optionsStart = source.indexOf('{ avoidLayoutSafeArea:', start);
    const optionsEnd = source.indexOf(', this.hdsDarkMode))', optionsStart);
    assert(optionsStart > start && optionsEnd > optionsStart, file);
    body = 'titleOptions() { return ' + source.slice(optionsStart, optionsEnd) + '; }';
    const form = source.slice(source.indexOf('private ' + (file.includes('BoardSection') ? 'sectionForm()' : 'createForm()')), start);
    assert(form.includes('top: 12, bottom: 28') && !form.includes('top: 68'), file + ': no manual title spacer');
    assert(source.includes('.scrollBarMargin({start:LengthMetrics.vp(0)})'), file + ': native component safe area owns title spacing');
  }
  const Host = vm.runInNewContext(ts.transpileModule('class Host {' + body + '} Host;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, { PinmonyHdsTitleBar, $r: name => name,
    SymbolGlyphModifier: class { fontColor() { return this; } }, IconStyleMode: { SMALL: 1 },
    PinmonyI18n: { text: (key, language) => language + ':' + key }
  });
  for (const mode of ['off', 'gentle', 'immersive', 'exquisite']) for (const language of ['zh', 'en']) {
    let closed = 0;
    const host = new Host();
    Object.assign(host, {materialMode:mode,immersiveLightMode:mode,uiLanguage:language,titleText:language + ':title',
      creating:false,result:{busy:false},state:{busy:false},busy:false,closeEnabled:true,
      uiText:key=>language + ':' + key,onClose:()=>closed++,requestClose:()=>closed++,requestCreateClose:()=>closed++});
    const options = method && method.includes('closeTitle') ? host.closeTitleOptions() : host.titleOptions();
    assert.equal(options.avoidLayoutSafeArea, false, file);
    assert.equal(options.enableComponentSafeArea, true, file);
    assert.equal(JSON.stringify(options.style), JSON.stringify(PinmonyHdsTitleBar.modalStyle(mode)), file + ': shared complete style');
    assert.equal(options.style.scrollEffectOpts.enableScrollEffect, false);
    assert.equal(options.style.originalStyle.backgroundStyle.backgroundColor, 'app.color.page_background');
    assert.equal(options.style.originalStyle.backgroundStyle.blurRadius, 0);
    assert.equal(options.style.systemMaterialEffect === undefined, mode === 'off');
    const close = options.content.menu.value[0].content;
    assert.equal(close.type, 1, file + ': uniform SMALL close');
    assert.equal(close.icon,undefined,file + ': official MODAL default close, no replacement glyph');
    assert.equal(close.label, language + ':pm_close_3fd47edc'); close.action(); assert.equal(closed, 1);
    // Normalization must preserve content, callback identity, safe areas and current theme resolution.
    const resolved = PinmonyHdsTitleBar.resolve({}, options, false);
    assert.equal(resolved.content, options.content); assert.equal(resolved.content.menu.value[0].content.action, close.action);
  }
  if (file.includes('SaveSheet')) {
    const host = new Host();let closed=0;Object.assign(host,{result:{busy:true},uiText:key=>key,onClose:()=>closed++});
    const close=host.titleOptions().content.menu.value[0].content; assert.equal(close.isEnabled,false);close.action();assert.equal(closed,0);
  }
}
// Every active MODAL implementation must use the shared policy. Enumerate every Sheet host too.
let sheets = 0, modalTitles = 0;
function scan(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) scan(file);
    else if (file.endsWith('.ets')) {
      const source = read(file), modalCount = (source.match(/HdsNavigationTitleMode\.MODAL/g)||[]).length;
      modalTitles += modalCount;
      if (modalCount) assert.equal((source.match(/PinmonyHdsTitleBar\.modalStyle\(/g)||[]).length, modalCount, file);
      for (const binding of source.matchAll(/\.bindSheet\(/g)) {
        sheets++;
        assert(source.slice(binding.index,binding.index+220).includes('PinmonyImmersiveLight.sheetOptions('),file + ': shared mask policy');
        const options = source.slice(binding.index, binding.index + 1400);
        assert.match(options, /radius:\s*LengthMetrics\.vp\(32\)/, file);
        assert.match(options, /backgroundColor:\s*\$r\('app.color.page_background'\)/, file);
        assert.match(options, /preferType:\s*this\.(?:nativeSheetWindowWidth|sheetWindowWidthVp) >= 600 \? SheetType.CENTER/, file);
      }
    }
  }
}
for (const root of fs.readdirSync('.').filter(name=>name==='entry'||name.startsWith('feature_')||name.startsWith('common_'))) {
  const dir = root + '/src/main/ets'; if (fs.existsSync(dir)) scan(dir);
}
assert.equal(sheets,19);assert.equal(modalTitles,consumers.length);
// Returned styles are independent, and resource colors are re-resolved on each theme change.
const one=PinmonyHdsTitleBar.modalStyle('off'),two=PinmonyHdsTitleBar.modalStyle('off');
one.originalStyle.backgroundStyle.blurRadius=99;assert.equal(two.originalStyle.backgroundStyle.blurRadius,0);
let color=0;const context={getHostContext:()=>({resourceManager:{getColorSync:()=>color}})};
const options={content:{title:{mainTitle:'retained'}},style:{originalStyle:{backgroundStyle:{backgroundColor:{id:7}}}}};
for(color of [0xffffff,0x111111,0xffffff]) assert.equal(PinmonyHdsTitleBar.resolve(context,options,true).style.originalStyle.backgroundStyle.backgroundColor,color);
console.log('Panel style consistency: 19 hosts, six real title builders, four material modes, zh/en close, save busy gate, form safe areas and theme re-resolution passed; device geometry excluded.');
