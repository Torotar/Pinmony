const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const disk = new Map(); let flushes = 0, failWrite = false, failFlush = false, failOpen = false, failRead = false, failResource = false;
function boot(system = 'zh-CN') {
  const memory = new Map(); let currentSystem = system;
  const cache = new Map(disk);
  const storage = { getSync: (k, fallback) => {if(failRead)throw Error('synthetic read');return cache.has(k) ? cache.get(k) : fallback;},
    putSync: (k, value) => { if (failWrite) throw Error('disk'); cache.set(k, value); },
    flushSync: () => { if (failFlush) throw Error('flush'); flushes++; for (const [k,v] of cache) disk.set(k,v); } };
  const loader = createArktsLoader(ts, {
    '@kit.LocalizationKit': { i18n: { System: { getSystemLanguage: () => currentSystem } } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => {if(failOpen)throw Error('synthetic open');return storage;} } }, '@kit.AbilityKit': {}
  }, { AppStorage: { get: key => memory.get(key), setOrCreate: (k,v) => memory.set(k,v) },
    PersistentStorage: { persistProp: (k,v) => { if (!memory.has(k)) memory.set(k,v); } } });
  const api = loader.loadFile('common_foundation/src/main/ets/services/PinmonyI18n.ets').PinmonyI18n;
  api.initialize({ resourceManager: { getConfigurationSync: () => ({}), getOverrideResourceManager: config => ({ getStringByNameSync: key => { if(failResource)throw Error('synthetic resource');const locale = config.locale === 'en-US' ? 'en_US' : config.locale === 'en-GB' ? 'en_GB' : config.locale === 'ja-JP' ? 'ja' : config.locale === 'ko-KR' ? 'ko' : config.locale === 'ru-RU' ? 'ru' : config.locale === 'zh-TW' ? 'zh_TW' : 'zh_CN'; const rows = JSON.parse(fs.readFileSync('common_foundation/src/main/resources/' + locale + '/element/string.json', 'utf8')).string; const row = rows.find(row => row.name === key); if (!row) throw Error('Missing resource: ' + key); return row.value; } }) } }); return { api, memory, system: value => currentSystem = value };
}
failOpen=true;assert.throws(()=>boot(),/language-storage-read-unavailable/);failOpen=false;
failRead=true;assert.throws(()=>boot(),/language-storage-read-unavailable/);failRead=false;
let f = boot();failResource=true;assert.equal(f.api.text('搜索'),'搜索');failResource=false;
 assert.equal(f.memory.get('pinmonyLanguage'), 'zh');
f.api.select('en'); assert.equal(flushes, 1); assert.equal(disk.get('language'), 'en');
f = boot('zh-CN'); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'en'); assert.equal(f.memory.get('pinmonyLanguage'), 'en');
f.system('zh-TW'); f.api.syncSystemLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'en');
f.api.select('zh'); f = boot('en-US'); assert.equal(f.memory.get('pinmonyLanguage'), 'zh');
f.api.select('system'); f = boot('en-US'); assert.equal(f.memory.get('pinmonyLanguage'), 'en');
f.system('zh-Hant'); f.api.syncSystemLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'zh');
f.system('en-GB'); f.api.select('system'); f.api.syncSystemLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'en_GB');
assert.equal(f.api.resolve('system', 'en-GB'), 'en_GB');
assert.equal(f.api.resolve('en_GB', 'zh-CN'), 'en_GB');
failWrite = true; assert.throws(() => f.api.select('en')); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'system'); failWrite = false;
failFlush = true; assert.throws(() => f.api.select('en')); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'system'); failFlush = false;
f = boot('zh-CN'); assert.equal(f.memory.get('pinmonyLanguagePreference'), 'system');
assert.equal(f.api.resolve('system', 'ja-JP'), 'ja');
assert.equal(f.api.resolve('ja', 'en-US'), 'ja');
assert.equal(f.api.resolve('system', 'ru-RU'), 'ru');
f.api.select('ru'); assert.equal(f.memory.get('pinmonyLanguage'), 'ru');
assert.equal(f.api.text('pm_retry_b8784c8d', 'ru'), 'Повторить');
f = boot('zh-CN'); assert.equal(f.memory.get('pinmonyLanguage'), 'ru');
f.api.select('system'); f.system('ru-RU'); f.api.syncSystemLanguage(); assert.equal(f.memory.get('pinmonyLanguage'), 'ru');
f.api.syncAccountLanguage('ru-RU'); assert.equal(f.memory.get('pinmonyLanguage'), 'ru');
assert.equal(f.api.resolve('system', 'ko-KR'), 'ko');
assert.equal(f.api.resolve('ko', 'en-US'), 'ko');
assert.equal(f.api.resolve('system', 'zh-TW'), 'zh_TW');
assert.equal(f.api.resolve('zh_TW', 'en-US'), 'zh_TW');
f.api.syncAccountLanguage('ja-JP'); assert.equal(f.memory.get('pinmonyLanguage'), 'ja');
f.api.syncAccountLanguage('xx-YY'); assert.equal(f.memory.get('pinmonyLanguage'), 'en');
f.api.syncAccountLanguage(''); assert.equal(f.memory.get('pinmonyLanguage'), 'en');
// Local message tokens can switch repeatedly without changing stored state.
const local = f.api.message('正在加载联系人…');
assert.equal(f.api.render(local, 'en'), 'Loading contacts…');
assert.equal(f.api.render(local, 'zh'), '正在加载联系人…');
assert(f.api.isText(local, '正在加载联系人…'));
assert(f.api.isUnconfirmed(f.api.message('保存结果未确认，请重新读取核对，勿重复提交')));
// Website/user text stays verbatim even when identical to a catalog entry.
for (const language of ['zh','en']) for (const raw of ['收藏', 'See more', '正在加载联系人…', 'xiaotingzi', '风景', 'Board {0}']) {
  assert.equal(f.api.render(raw, language), raw);
  assert.equal(f.api.optionLabel('website-action', raw, language), raw);
}
assert.equal(f.api.optionLabel('detail-download', '下载图片', 'en'), 'Download image');
assert.equal(f.api.optionLabel('home-save', '收藏', 'en'), 'Save');
assert.equal(f.api.optionLabel('home-save', '收藏', 'zh'), '收藏');
const mixed = f.api.message('已收藏至 ') + '收藏';
assert.equal(f.api.render(mixed, 'en'), 'Saved to 收藏');
assert.equal(f.api.render(mixed, 'zh'), '已收藏至 收藏');
// Website templates keep counts and user data correct across language changes.
assert.equal(f.api.format('pm_view_comment_replies', [12], 'zh'), '查看 12 条回复');
assert.equal(f.api.format('pm_view_comment_replies', [12], 'en'), 'View 12 replies');
const retainedSaved = f.api.message('pm_saved_to_b75786b2') + '风景 {0}”';
assert.equal(f.api.render(retainedSaved, 'zh'), '已收藏至 风景 {0}”');
assert.equal(f.api.render(retainedSaved, 'en'), 'Saved to 风景 {0}”');
assert.equal(f.api.format('pm_social_unblock_title', ['风景 {0}'], 'zh'), '取消屏蔽 风景 {0}？');

assert.equal(f.api.format('查看{0}全部内容', ['Board {0}'], 'en'), 'View all of Board {0}');
// Execute a real native producer so ternary/multiline status assignments are covered.
const mediaLoader = createArktsLoader(ts, {
  common_foundation: { PinmonyI18n: f.api }, '@kit.MediaKit': {},
  '@kit.BasicServicesKit': {}, '@kit.AudioKit': {}
});
const Playback = mediaLoader.loadFile('common_ui/src/main/ets/services/PinmonyVideoPlayback.ets').PinmonyVideoPlayback;
const player = new Playback(() => {});
player.fail(player.generation, 'prepare', 5400104, true);
assert.equal(f.api.render(player.state.error, 'en'), 'Video preparation timed out. Retry playback.');
assert.equal(f.api.render(player.state.error, 'zh'), '视频准备超时，请重试播放');
const about = fs.readFileSync('feature_settings/src/main/ets/components/PinmonyAboutPage.ets','utf8');
for (const line of about.split('\n').filter(line=>/this.updateStatus\s*=/.test(line))) assert(!line.includes('this.uiText('), 'Stored status must be language independent');
for (const file of ['feature_pin/src/main/ets/components/PinmonyMoreSheet.ets','feature_home/src/main/ets/components/PinmonyHomeMenuSheet.ets']) {
  const source=fs.readFileSync(file,'utf8'); assert(source.includes('PinmonyI18n.optionLabel(option.id, option.label, this.uiLanguage)'));
}

// Screenshot regression: execute the actual snapshot producers, not hand-written labels.
const nativeLoader = createArktsLoader(ts, { common_foundation: { PinmonyI18n: f.api }, common_network: {}, '@kit.ArkTS':{}, '@kit.ImageKit':{} });
const ProfileReader = nativeLoader.loadFile('entry/src/main/ets/app/PinmonyProfileNativeReads.ets').PinmonyProfileNativeReads;
const profile = Object.create(ProfileReader.prototype);
Object.assign(profile, { owned: () => true, store: {}, section: 'saved', page: 'https://www.pinterest.com/test/', origin: 'https://www.pinterest.com',
  info: { isOwn:true, followers:0, following:2, pinCount:88, userId:'1', name:'john fige', handle:'figefar', about:'寻找属于我的灵感' },
  feed: () => ({scroll:0, boards:[], pins:[], ready:false}), unorganized: {pins:[]}, busy:false });
profile.suggestions = [];
profile.attemptedSuggestions = new Set();
profile.apply();
const ps = profile.store.profile;
assert.equal(f.api.render(ps.followers, 'en'), '0 followers');
assert.equal(f.api.render(ps.following, 'en'), '2 following');
assert.equal(f.api.render(ps.actions[0].label, 'en'), 'Edit profile');
assert.equal(f.api.render(ps.actions[0].label, 'zh'), '编辑个人资料');
assert.equal(ps.about, '寻找属于我的灵感');
const date = new Date(Date.now() - 3 * 86400000).toISOString();
const board = profile.board({type:'board',id:'22',url:'/test/art/',name:'插画',pin_count:22,section_count:1,board_order_modified_at:date});
assert.equal(board.title, '插画');
assert.equal(f.api.render(board.pinCount, 'en'), '22 Pins · 1 section');
assert.equal(f.api.render(board.updated, 'en'), '3 days ago');
assert.equal(f.api.render(board.updated, 'zh'), '3 天前');
const all = profile.board({type:'story',story_type:'all_pins',id:'all',title:{text:'所有 Pin 图'},action:{url:'/users/1/pins/'},objects:[]});
assert.equal(all.title, '所有 Pin 图', 'Website all-Pins title must stay verbatim');
const InboxReader = nativeLoader.loadFile('entry/src/main/ets/app/PinmonyInboxMessagesNativeReads.ets').PinmonyInboxMessagesNativeReads;
const inbox = Object.create(InboxReader.prototype);
Object.assign(inbox, { owned:()=>true, store:{}, rows:[{title:'InspiFol',subtitle:'很好'}], contacts:[], listReady:false });
inbox.apply(); const snapshot = inbox.store.inbox;
for (const [key,expected] of [['updateLabel','Updates'],['inboxLabel','Inbox'],['composeLabel','New message'],['messagesLabel','Messages'],['contactsLabel','Contacts']]) {
  assert.equal(f.api.render(snapshot[key], 'en'), expected, key);
}
assert.equal(snapshot.items[0].subtitle, '很好');
const inboxSource = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets','utf8');
const start = inboxSource.indexOf('  private syncSegmentItems():');
const end = inboxSource.indexOf('  @State private sectionOpacity',start);
const Host = vm.runInNewContext(ts.transpileModule('class Host {'+inboxSource.slice(start,end)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText, {PinmonyI18n:f.api});
const view = new Host(); Object.assign(view,{snapshot,segmentItems:[{text:''},{text:''}],segmentUpdateLabel:'',segmentInboxLabel:'',uiLanguage:'en'});
const items = view.segmentItems; view.syncSegmentItems(); assert.equal(items[0].text,'Updates');
view.uiLanguage='zh'; view.syncSegmentItems(); assert.equal(items[0].text,'更新');
view.uiLanguage='en'; view.syncSegmentItems(); assert.equal(items[1].text,'Inbox');
assert.equal(view.segmentItems,items,'Mutate the existing ObservedV2 items so selection and control identity survive');
assert(inboxSource.includes("@Watch('syncSegmentItems')"));

const SearchReader = nativeLoader.loadFile('entry/src/main/ets/app/PinmonySearchNativeReads.ets').PinmonySearchNativeReads;
const search = Object.create(SearchReader.prototype);
for (const [scope, original, english] of [['pins','所有创意','All Pins'],['videos','视频','Videos'],['boards','图板','Board'],['users','用户','Profiles'],['buyable_pins','商品','Products']]) {
  const label = search.filterLabel(scope, original);
  assert.equal(f.api.render(label, 'en'), english);
  assert.equal(f.api.render(label, 'zh').includes('\uE000'), false);
}
assert.equal(search.filterLabel('unknown','网站自定义筛选'), '网站自定义筛选');
// The confirmed-write overlay must not replace translated labels with raw Chinese.
const ConfirmedSaves = nativeLoader.loadFile('feature_pin/src/main/ets/services/PinmonyConfirmedSaves.ets').PinmonyConfirmedSaves;
const saves = new ConfirmedSaves();
const saveActions = [{id:'native-save',kind:'save',label:f.api.message('收藏'),enabled:true,selected:false,countText:''}];
saves.confirm('11',true);
const savedAction = saves.actions('11',saveActions)[0];
assert.equal(f.api.render(savedAction.label,'en'),'Saved');
assert.equal(f.api.render(savedAction.label,'zh'),'已收藏');
assert.equal(savedAction.selected,true);
saves.confirm('11',false);
const unsavedAction = saves.actions('11',saveActions)[0];
assert.equal(f.api.render(unsavedAction.label,'en'),'Save');
assert.equal(f.api.render(unsavedAction.label,'zh'),'收藏');
assert.equal(unsavedAction.selected,false);
// Render legacy/raw publish command labels as well as freshly marked snapshots.
const publishSource = fs.readFileSync('feature_profile/src/main/ets/components/PinmonyPublishSheet.ets','utf8');
const labelStart = publishSource.indexOf('  private optionLabel(');
const labelEnd = publishSource.indexOf('  @Builder',labelStart);
const PublishView = vm.runInNewContext(ts.transpileModule('class PublishView {'+publishSource.slice(labelStart,labelEnd)+'} PublishView;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:f.api});
const publishView = new PublishView(); publishView.uiLanguage='en'; publishView.uiText = source => f.api.text(source,publishView.uiLanguage);
assert.equal(publishView.optionLabel({kind:'board',label:'图板'}),'Board');
assert.equal(publishView.optionLabel({kind:'website',label:'网站'}),'Website');
assert.equal(publishView.optionLabel({kind:'photo',label:'照片'}),'Photos');
publishView.uiLanguage='zh'; assert.equal(publishView.optionLabel({kind:'board',label:'Board'}),'图板');
assert.equal(publishView.optionLabel({kind:'unknown',label:'原文'}),'原文');
const Publish = nativeLoader.loadFile('entry/src/main/ets/app/PinmonyPublishNativeFlow.ets').PinmonyPublishNativeFlow;
(async () => {
 const publish = Object.create(Publish.prototype);
 Object.assign(publish,{store:{},pause(){},bind(){},identity:async()=>{},current:()=>true});
 assert.equal(await publish.menu(()=>true),true);
 assert.equal(f.api.render(publish.store.publishTitle,'en'),'Create');
 assert.deepEqual(Array.from(publish.store.publishOptions,o=>f.api.render(o.label,'en')),['Website','Photos','Board']);
 assert.deepEqual(Array.from(publish.store.publishOptions,o=>f.api.render(o.label,'zh')),['网站','照片','图板']);
 assert.deepEqual(Array.from(publish.store.publishOptions,o=>o.id),['native-website','native-photo','native-board']);
 console.log('Language: persistence, reversible snapshots, publish menu, fixed search types, segment refresh and website/user text boundaries passed');
})().catch(error=>{console.error(error);process.exitCode=1;});

// Validate the shipped resource sets, not a parallel test dictionary.
const resourceRows = locale => JSON.parse(fs.readFileSync('common_foundation/src/main/resources/' + locale + '/element/string.json', 'utf8')).string;
const baseRows = resourceRows('base');
const names = baseRows.map(row => row.name).sort();
assert.equal(new Set(names).size, names.length, 'Duplicate resource names');
for (const locale of ['zh_CN', 'en_US']) {
  const rows = resourceRows(locale);
  assert.deepEqual(rows.map(row => row.name).sort(), names, 'Locale key parity: ' + locale);
  const values = new Map(rows.map(row => [row.name, row.value]));
  for (const row of baseRows) assert.deepEqual((values.get(row.name).match(/\{\d+\}/g) || []).sort(), (row.value.match(/\{\d+\}/g) || []).sort(), 'Placeholder parity: ' + row.name);
}
const saveKey = baseRows.find(row => row.value === '收藏').name;
assert.equal(f.api.text(saveKey, 'en'), 'Save');
assert.equal(f.api.message('收藏'), f.api.message(saveKey), 'New tokens normalize legacy identifiers');
assert.equal(f.api.render(f.api.message(saveKey), 'zh'), '收藏');

// Device-reported omissions: execute the actual display/date methods.
function methodView(file, startName, endName) {
 const source = fs.readFileSync(file, 'utf8');
 const begin = source.indexOf('  private ' + startName);
 const end = source.indexOf(endName, begin + 1);
 assert(begin >= 0 && end > begin, startName);
 const Type = vm.runInNewContext(ts.transpileModule('class View {' + source.slice(begin, end) + '} View;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText, {PinmonyI18n:f.api});
 const view = new Type(); view.uiLanguage = 'en'; view.uiText = key => f.api.text(key, view.uiLanguage); return view;
}
const searchView = methodView('feature_search/src/main/ets/components/PinmonySearchPage.ets', 'searchPlaceholder(', '  private uiText(');
searchView.snapshot = {placeholder:'搜索'}; assert.equal(searchView.searchPlaceholder(),'Search');
searchView.snapshot.placeholder='风景灵感'; assert.equal(searchView.searchPlaceholder(),'风景灵感');
searchView.uiLanguage='zh'; searchView.snapshot.placeholder='Search'; assert.equal(searchView.searchPlaceholder(),'搜索');
assert.equal(f.api.optionLabel('home-system-share','系统分享','en'),'Share');
const accountView = methodView('feature_settings/src/main/ets/components/PinmonyAccountPage.ets','birthday(', '  private gender(');
accountView.store = {data:{birthdate:'1999-12-02'}}; assert.equal(accountView.birthday(),'12/02/1999');
accountView.uiLanguage='zh'; assert.equal(accountView.birthday(),'1999年12月02日');
const followView = methodView('entry/src/main/ets/app/PinmonyProfileNativeActions.ets','updated(', '    private boardImage(');
assert.equal(f.api.render(followView.updated(new Date(Date.now()-31*86400000).toISOString()),'en'),'1 month ago');
assert.equal(f.api.render(followView.updated(new Date(Date.now()-8*86400000).toISOString()),'en'),'1 week ago');
const shareView = methodView('feature_pin/src/main/ets/components/PinmonyShareSheet.ets','actionLabel(', '  private shareActionKey(');
assert.equal(shareView.actionLabel({id:'native-copy',label:'复制链接'}),'Copy link');
assert.equal(shareView.actionLabel({id:'website',label:'网站原文'}),'网站原文');
shareView.uiLanguage='zh'; assert.equal(shareView.actionLabel({id:'native-copy',label:'Copy link'}),'复制链接');

// Real update-client failures must localize the reason as well as the wrapper.
(async () => {
 let reply = {responseCode:200,result:'invalid-json'};
 let networkCode = 0;
 const releaseLoader = createArktsLoader(ts, {
  common_foundation:{PinmonyI18n:f.api,PinmonyRuntimeLog:{info(){},warn(){}}},
  '@kit.NetworkKit':{http:{RequestMethod:{GET:'GET'},HttpDataType:{STRING:0},HttpProtocol:{HTTP1_1:1},createHttp:()=>({
   request:async()=>{if(networkCode)throw {code:networkCode};return reply;},destroy(){}
  })}},'@kit.BasicServicesKit':{}
 });
 const {PinmonyReleaseClient} = releaseLoader.loadFile('feature_settings/src/main/ets/services/PinmonyRelease.ets');
 for(const [status,code,expected] of [[200,0,'Invalid release information'],[500,0,'HTTP 500'],[403,0,'HTTP 403'],[0,2300006,'2300006'],[0,0,'GitHub']]) {
  reply={responseCode:status,result:'invalid-json'}; networkCode=code;
  let failure;try{await new PinmonyReleaseClient().latest();}catch(error){failure=error;}
  assert(failure); const english=f.api.render(failure.feedback,'en');
  assert(english.includes(expected),english); assert(!/[\u3400-\u9fff]/.test(english),english);
  assert(/[\u3400-\u9fff]/.test(f.api.render(failure.feedback,'zh')));
 }
})().catch(error=>{console.error(error);process.exitCode=1;});

// Disabled content filters lack destinations but still need local control copy.
const disabledFeed = {snapshot:{pageKey:'https://www.pinterest.com/search/pins/?q=art'},filters:[],targets:new Map()};
search.origin='https://www.pinterest.com';
search.mapModules([{action:{type:'contenttypefiltermoduleaction',title:'筛选器',filters:[
 {type:'filteroption',display:{display_text:'所有 Pin 图'},disabled:true,is_selected:true},
 {type:'filteroption',display:{display_text:'个人资料'},is_disabled:true},
 {type:'filteroption',display:{display_text:'产品'},disabled:true}
]}}],disabledFeed);
assert.deepEqual(Array.from(disabledFeed.filters,o=>f.api.render(o.label,'en')),['All Pins','Profiles','Products']);
assert.equal(f.api.render(disabledFeed.filters[0].group,'en'),'Filters');
assert(disabledFeed.filters.every(o=>!o.enabled));assert.equal(disabledFeed.targets.size,0);
assert.equal(search.filterLabel('','网站自定义类型'),'网站自定义类型');
assert.equal(search.filterGroup('网站自定义分组'),'网站自定义分组');

const NotificationCopy = nativeLoader.loadFile('feature_settings/src/main/ets/models/PinmonyNotificationCopy.ets').PinmonyNotificationCopy;
const notificationCategory = {key:'comments',label:'评论',description:'网站中文说明',channels:[{channel:'push',option:'published_comments',label:'推送',value:true},{channel:'news',option:'published_comments',label:'应用内',value:false}]};
assert.equal(NotificationCopy.group({key:'unknown',label:'你创建的内容',categories:[notificationCategory]},'en'),'Pins you created');
assert.equal(NotificationCopy.category(notificationCategory,'en'),'Comments');
assert.equal(NotificationCopy.summary(notificationCategory,'en'),'Push on, in-app off');
assert.equal(NotificationCopy.description(notificationCategory,'en'),'Get notified when someone comments on a Pin you created');
assert.equal(NotificationCopy.category(notificationCategory,'zh'),'评论');
assert.equal(NotificationCopy.category({key:'unknown',label:'网站新类型',channels:[]},'en'),'网站新类型');
assert.deepEqual(Array.from(notificationCategory.channels,c=>c.value),[true,false]);

// Full-app producer and presentation regressions: switch without refetching data.
const HomeReader = nativeLoader.loadFile('entry/src/main/ets/app/PinmonyHomeNativeReads.ets').PinmonyHomeNativeReads;
const homeReader = Object.create(HomeReader.prototype);
Object.assign(homeReader,{board:'',store:{home:undefined},tabs:[{id:'tab:22',label:'插画',enabled:true,selected:false}]});
assert.deepEqual(Array.from(homeReader.makeTabs(),tab=>f.api.render(tab.label,'en')),['All','插画']);
// Exercise the reader with its actual source method, retaining website board names.
const homeSource=fs.readFileSync('entry/src/main/ets/app/PinmonyHomeNativeReads.ets','utf8');
assert(homeSource.includes('pm_all_ae99f297'));
assert.equal(f.api.render(search.boardCounts({pin_count:23,section_count:2}),'en'),'23 Pins · 2 sections');
assert.equal(f.api.render(search.boardCounts({pin_count:23,section_count:2}),'zh'),'23 张 Pin 图 · 2 个图板区块');
const profileLanguageView=methodView('feature_profile/src/main/ets/components/PinmonyProfilePanelPage.ets','syncFollowingLanguage(', '  private displayedSection:');
profileLanguageView.followingSegments=[{text:''},{text:''}];
profileLanguageView.syncFollowingLanguage();assert.equal(profileLanguageView.followingSegments[0].text,'Profiles');
profileLanguageView.uiLanguage='zh';profileLanguageView.syncFollowingLanguage();assert.equal(profileLanguageView.followingSegments[1].text,'图板');

require('./check-live-language.cjs')(ts, f.api);
