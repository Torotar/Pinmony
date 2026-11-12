const fs = require('node:fs'), vm = require('node:vm');
module.exports = function loadModalStyle(ts) {
  const source = fs.readFileSync('common_ui/src/main/ets/services/PinmonyHdsTitleBar.ets', 'utf8')
    .replace(/^import .*;\r?\n/gm, '').replace('export class ', 'class ');
  return vm.runInNewContext(ts.transpileModule(source + '\nPinmonyHdsTitleBar;', {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText, {
    $r: name => name,
    BlurStrategy: { DISABLE: 0, ENABLE: 1, ADAPTIVE: 2 },
    ScrollEffectType: { GRADIENT_BLUR: 2, IMMERSIVE_GRADIENT_BLUR: 3 },
    PinmonyImmersiveLight: { effect: mode => mode === 'off' ? undefined : { mode } }
  });
};
