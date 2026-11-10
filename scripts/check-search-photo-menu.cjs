const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'utf8');
const start = source.indexOf('  private async photoMenu()');
const end = source.indexOf("  @StorageProp('systemDarkMode')", start);
class Content { constructor(context, builder, options) { this.options = options; } }
const events = [];
const Host = vm.runInNewContext(ts.transpileModule('class Host {' + source.slice(start, end) + '} Host;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText,
{ ComponentContent: Content, wrapBuilder: x => x, buildPhotoMenu() {},
  PinmonySearchPhotoMenuMaterial: { options: (_mode, options) => options },
  PinmonyRuntimeLog: { info: s => events.push(s), warn: s => events.push(s) } });
(async () => {
  const host = new Host(); let opens = 0, closes = 0, uploads = 0, histories = 0, disappear, finishClose, rejectClose = false;
  Object.assign(host, { active: true, interactionReady: true, photoMenuOpen: false, photoBusy: false,
    photoMenuSelection: -1, photoMenuClosing: false, photoMenuEpoch: 0,
    startPhotoSearch: async () => { uploads++; }, openPhotoHistory: () => { histories++; },
    getUIContext: () => ({ getPromptAction: () => ({
      openMenu: async (content, anchor, options) => { opens++; assert.equal(anchor.id, 'pinmony-photo-search-menu'); disappear = options.onDisappear; },
      closeMenu: () => { closes++; if (rejectClose) return Promise.reject(Error('already dismissed'));
        return new Promise(resolve => { finishClose = () => { disappear(); resolve(); }; }); }
    }) }) });
  await host.photoMenu();
  host.photoMenuContent.options.select(1); host.photoMenuContent.options.select(0);
  assert.equal(closes, 0, 'MenuItem dismissal must not race another closeMenu call');
  assert.equal(histories, 0, 'navigation waits for menu disappearance');
  disappear(); disappear(); assert.equal(histories, 1, 'selection runs exactly once');
  await host.photoMenu(); host.selectPhotoMenu(0); disappear(); await Promise.resolve(); assert.equal(uploads, 1);
  await host.photoMenu(); host.selectPhotoMenu(1); host.active = false; disappear(); assert.equal(histories, 1);
  host.active = true; await host.photoMenu();
  const staleDisappear = disappear, close = host.dismissPhotoMenu();
  await host.dismissPhotoMenu(); assert.equal(closes, 1, 'concurrent dismiss calls share one platform close');
  const priorOpens = opens; await host.photoMenu(); assert.equal(opens, priorOpens, 'cannot reopen while closing');
  finishClose(); await close; assert.equal(host.photoMenuOpen, false);
  await host.photoMenu(); host.selectPhotoMenu(1); staleDisappear();
  assert.equal(host.photoMenuOpen, true, 'old disappearance cannot close the new menu');
  disappear(); assert.equal(histories, 2);
  await host.photoMenu(); host.selectPhotoMenu(1); rejectClose = true;
  await host.dismissPhotoMenu(); disappear(); assert.equal(histories, 2, 'programmatic dismissal cancels pending selection');
  assert.equal(host.photoMenuClosing, false); assert.equal(host.photoMenuOpen, false);
  host.startPhotoSearch = async () => { throw Error('synthetic upload error'); };
  await host.photoMenu(); host.selectPhotoMenu(0); disappear(); await Promise.resolve(); await Promise.resolve();
  assert(events.includes('PhotoMenu: selection failed action=upload'), 'callback rejection is observed');
  assert(source.includes(".id('pinmony-photo-search-menu')"));
  console.log('Photo menu: automatic dismissal precedes navigation, one selection/close, stale and inactive callbacks, failed close and upload rejection passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
