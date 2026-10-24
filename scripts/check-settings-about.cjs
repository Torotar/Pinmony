const { rawLocalMessages } = require('./local-message-test-fixture.cjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyAboutPage.ets', 'utf8');
const methods = source.slice(source.indexOf('  private async readVersion'), source.indexOf('  @Builder'));
const sandbox = { PinmonyI18n: rawLocalMessages, bundleManager: { BundleFlag: { GET_BUNDLE_INFO_DEFAULT: 0 },
  getBundleInfoForSelfSync: () => ({ versionName: '9.8.7', versionCode: 987 }) }, PinmonyRuntimeLog: { warn() {}, info() {} } };
sandbox.PinmonyUpdateNotice = { confirm() {} };
vm.runInNewContext(ts.transpileModule('class About {' + methods + '} globalThis.About = About;',
  { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, sandbox);
const storeSource = fs.readFileSync('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets', 'utf8').replace(/^@Observed\s*$/m, '');
const storeExports = {};
const releaseExports = {};
const releaseWarnings = [], releaseLogs = [];
sandbox.PinmonyRuntimeLog.warn = message => releaseWarnings.push(message);
sandbox.PinmonyRuntimeLog.info = message => releaseLogs.push(message);
let response = { responseCode: 404 }, timeoutCallback, timerCleared = false, destroyed = 0, feedResponse;
const httpMock = { RequestMethod: { GET: 'GET' }, HttpDataType: { STRING: 0 }, HttpProtocol: { HTTP1_1: 1 }, createHttp: () => ({
  request: (url, options) => {
    assert(url === 'https://api.github.com/repos/Torotar/Pinmony/releases/latest' || url.startsWith('https://github.com/Torotar/Pinmony/releases.atom'));
    assert.equal(options.usingProxy, true);
    assert.equal(options.usingProtocol, httpMock.HttpProtocol.HTTP1_1);
    assert.equal(options.header.Cookie, undefined);
    if (url.includes('?after=')) return Promise.resolve({ responseCode: 200, result: '<feed></feed>' });
    if (url.endsWith('.atom') && !feedResponse && response.responseCode === 200) return Promise.resolve({ responseCode: 200,
      result: '<feed><entry><link href="https://github.com/Torotar/Pinmony/releases/tag/V2.2.0"/><content>Notes</content></entry></feed>' });
    return response === 'pending' ? new Promise(() => {}) : Promise.resolve(url.endsWith('.atom') && feedResponse ? feedResponse : response);
  },
  destroy: () => { destroyed++; }
}) };
vm.runInNewContext(ts.transpileModule(fs.readFileSync('feature_settings/src/main/ets/services/PinmonyRelease.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS } }).outputText,
  { exports: releaseExports, require: () => ({ PinmonyI18n: rawLocalMessages, http: httpMock, PinmonyRuntimeLog: sandbox.PinmonyRuntimeLog }),
    setTimeout: (callback, ms) => { assert.equal(ms, 12000); timeoutCallback = callback; return 1; },
    clearTimeout: () => { timerCleared = true; } });
sandbox.isNewerRelease = releaseExports.isNewerRelease;
sandbox.PinmonyReleaseFailure = releaseExports.PinmonyReleaseFailure;
Object.assign(storeExports, require('./arkts-module-loader.cjs').createArktsLoader(ts).loadFile('feature_settings/src/main/ets/stores/PinmonySettingsStore.ets'));
(async () => {
  const page = new sandbox.About(); page.uiText = source => source; page.visible = true;
  page.releaseClient = { latest: async () => undefined };
  await page.readVersion(); assert.equal(page.version, '9.8.7 (987)');
  sandbox.bundleManager.getBundleInfoForSelfSync = () => { throw Error('unavailable'); };
  await page.readVersion(); assert.equal(page.version, '版本信息暂不可用');
  page.visible = false; page.version = 'retained'; await page.readVersion(); assert.equal(page.version, 'retained');
  const messages = [], links = [];
  page.visible = true; page.getUIContext = () => ({ getPromptAction: () => ({ showToast: x => messages.push(x.message) }) });
  page.onOpenExternalLink = async url => { links.push(url); };
  await page.openLink('https://github.com/Torotar/Pinmony'); assert.equal(links.length, 1); assert.equal(page.openingLink, false);
  page.onOpenExternalLink = async () => { throw Error('unavailable'); };
  await page.openLink('https://github.com/Torotar/Pinmony/issues'); assert.equal(messages.length, 1); assert.equal(page.openingLink, false);
  page.openingLink = true; await page.openLink('ignored'); assert.equal(messages.length, 1);
  for (const [latest, installed, expected] of [['V2.1.1', '2.1.0', true], ['v2.10.0', '2.9.0', true],
    ['V2.1.0', '2.1.0', false], ['v1.9.9', '2.1.0', false], ['v3.0.0-beta', '2.1.0', false]]) {
    assert.equal(releaseExports.isNewerRelease(latest, installed), expected);
  }
  page.installedVersion = '2.1.0';
  page.releaseClient.latest = async () => ({ tag_name: 'V2.2.0', body: 'Release notes' });
  await page.checkUpdate(); assert.equal(page.hasUpdate, true); assert.equal(page.release.body, 'Release notes');
  page.releaseClient.latest = async () => { throw Error('offline'); };
  await page.checkUpdate(); assert.equal(page.updateStatus, '检查更新失败，点击重试');
  const client = new releaseExports.PinmonyReleaseClient();
  assert.equal(await client.latest(), undefined); assert(timerCleared);
  response = 'pending'; timerCleared = false;
  page.releaseClient = client;
  const checking = page.checkUpdate();
  assert.equal(page.updateStatus, '正在检查更新…');
  timeoutCallback(); await checking;
  assert.equal(page.updateStatus, '检查更新失败（连接 GitHub 超过 12 秒），点击重试');
  assert.equal(page.releaseChecking, false); assert(timerCleared); assert.equal(destroyed, 2);
  response = { responseCode: 200, result: JSON.stringify({ tag_name: 'V2.2.0',
    html_url: 'https://github.com/Torotar/Pinmony/releases/tag/V2.2.0', body: 'Notes', draft: false, prerelease: false }) };
  await page.checkUpdate(); assert.equal(page.hasUpdate, true); assert.equal(page.release.body, 'Notes');
  response = { responseCode: 403 };
  await page.checkUpdate(); assert.equal(page.updateStatus, '检查更新失败（GitHub 访问受限，HTTP 403），点击重试');
  response = { responseCode: 200, result: 'invalid-json' };
  await page.checkUpdate(); assert.equal(page.updateStatus, '检查更新失败（发布信息格式异常），点击重试');
  const feed = '<feed><entry><link href="https://github.com/Torotar/Pinmony/releases/tag/V2.2.0"/><content type="html">&lt;p&gt;修复 &amp;amp; 优化&lt;/p&gt;</content></entry>' +
    '<entry><link href="https://github.com/Torotar/Pinmony/releases/tag/v2.3.0-beta"/></entry></feed>';
  assert.equal(releaseExports.parseReleaseFeed(feed).tag_name, 'V2.2.0');
  assert.equal(releaseExports.parseReleaseFeed(feed).body, '修复 & 优化');
  assert.equal(releaseExports.parseReleaseFeed('<feed></feed>'), undefined);
  assert.throws(() => releaseExports.parseReleaseFeed('invalid'));
  response = { responseCode: 403 }; feedResponse = { responseCode: 200, result: feed };
  releaseWarnings.length = 0; releaseLogs.length = 0;
  await page.checkUpdate(); assert.equal(page.hasUpdate, true); assert.equal(page.release.tag_name, 'V2.2.0');
  assert.equal(releaseWarnings.length, 0, 'successful Atom recovery is not a final failure');
  assert(releaseLogs.some(message => message.includes('event=api-denied status=403')));
  assert(releaseLogs.some(message => message.includes('event=success source=atom')));
  assert.equal(page.updateStatus, '最新发布：V2.2.0');
  feedResponse = { responseCode: 200, result: feed.replace('</feed>', '<entry><link href="https://github.com/Torotar/Pinmony/releases/tag/v2.1.1"/><content>Older notes</content></entry></feed>') };
  await page.checkUpdate(); assert.deepEqual(Array.from(page.newerReleases, item => item.tag_name), ['V2.2.0', 'v2.1.1']);
  page.installedVersion = '2.2.0'; await page.checkUpdate();
  assert.equal(page.updateStatus, '当前已是最新版本'); assert.equal(page.hasUpdate, false); assert.equal(page.newerReleases.length, 0);
  assert(source.includes('edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })'));
  assert(source.includes('objectFit(ImageFit.Contain).objectRepeat(ImageRepeat.NoRepeat)'));
  assert(source.includes("height(96).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)"));
  assert(source.includes("alignItems(HorizontalAlign.Center).padding({ top: 28, bottom: 20 })\n        }\n        ListItem()"));
  assert(!source.includes('不使用官方开放 API'));
  const store = new storeExports.PinmonySettingsStore(); store.screen = 'about';
  assert.equal(store.back(), true); assert.equal(store.screen, 'root'); assert.equal(store.back(), false);
  console.log('About: installed version, failure/late-read handling, external link success/failure, duplicate guard and return hierarchy passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
