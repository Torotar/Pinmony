const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { createArktsLoader } = require('./arkts-module-loader.cjs');
const read = file => fs.readFileSync(file, 'utf8');

function checkArabic(ts) {
  const disk = new Map();
  let system = 'ar-SA', failFlush = false, failLayout = false, colorMode = 1;
  function boot() {
    const memory = new Map(), pending = new Map(disk), layout = [], configurations = [];
    const loader = createArktsLoader(ts, {
      '@kit.LocalizationKit': { i18n: { System: { getSystemLanguage: () => system } }, resourceManager: {ColorMode:{DARK:0,LIGHT:1}} },
      '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
        getSync: (key, fallback) => pending.has(key) ? pending.get(key) : fallback,
        putSync: (key, value) => pending.set(key, value),
        flushSync: () => {if(failFlush) throw Error('disk'); for(const [k,v] of pending) disk.set(k,v);}
      }) } }, '@kit.AbilityKit': {}
    }, { AppStorage: {get:key=>memory.get(key),setOrCreate:(key,value)=>memory.set(key,value)}, Intl, console });
    const api = loader.loadFile('common_foundation/src/main/ets/services/PinmonyI18n.ets').PinmonyI18n;
    const context = {getApplicationContext:()=>({setLanguage:locale=>{if(failLayout)throw Error('layout');layout.push(locale);}}), resourceManager:{
      getConfigurationSync:()=>({colorMode}),
      getOverrideResourceManager:config=>{
        let current = {...config};
        return {updateOverrideConfiguration:next=>{current={...next};configurations.push(current);},
          getStringByNameSync:key=>{
            const locale = {'zh-CN':'zh_CN','zh-TW':'zh_TW','en-US':'en_US','en-GB':'en_GB','ja-JP':'ja','ko-KR':'ko','ru-RU':'ru','pt-BR':'pt_BR',ar:'ar'}[current.locale];
            const row=JSON.parse(read(`common_foundation/src/main/resources/${locale}/element/string.json`)).string.find(row=>row.name===key);
            if(!row)throw Error(key);return row.value;
          }};
      }} };
    api.initialize(context);
    assert.equal(layout.length,0,'Do not set application language before loadContent');
    api.attachLayoutContext(context);
    return {api,memory,layout,configurations,context};
  }
  let f=boot();
  assert.equal(f.memory.get('pinmonyLanguage'),'ar');assert.deepEqual(f.layout,['ar']);
  for(const locale of ['ar','ar-SA','ar_EG','ar-AE','ar-MA','ar-DZ']) {
    assert.equal(f.api.resolve('account',locale),'ar');
    f.api.syncAccountLanguage(locale);assert.equal(f.memory.get('pinmonyLanguage'),'ar');
  }
  assert.equal(f.api.translationAcceptLanguage(),'ar');
  assert(f.api.isRtl());assert(!f.api.isRtl('en'));assert(!f.api.isRtl('zh'));
  const website='مرحبا Pinterest @user https://example.com/?q=1 {0}';
  assert.equal(f.api.text(website),website);assert.equal(f.api.render(website),website);
  const token=f.api.message('pm_retry_b8784c8d');
  for(const language of ['ar','en','zh','ar']) {
    f.api.select(language);
    assert.equal(f.memory.get('pinmonyLanguage'),language);
    assert.equal(f.api.render(token),{ar:'إعادة المحاولة',en:'Retry',zh:'重试'}[language]);
  }
  assert.equal(f.api.format('pm_inbox_unread_message_count',[12],'ar'),'الرسائل غير المقروءة: \u2068'+new Intl.NumberFormat('ar',{useGrouping:false}).format(12)+'\u2069');
  const englishRow=JSON.parse(read('common_foundation/src/main/resources/en_US/element/string.json')).string.find(row=>row.value==='Search {0}');
  assert(f.api.format(englishRow.name,[website],'ar').includes('\u2068'+website+'\u2069'));
  assert.equal(f.api.number(123,'ar'),new Intl.NumberFormat('ar',{useGrouping:false}).format(123));
  assert.equal(f.api.numericInput('٢٠٢٦/١١/۱۴'),'2026/11/14');
  assert.equal(f.api.numericInput('12a'),'12a','Keep invalid characters for the existing validator');
  f.api.select('ar');system='en-US';f=boot();assert.equal(f.memory.get('pinmonyLanguage'),'ar');
  f.api.syncAccountLanguage('zh-CN');assert.equal(f.memory.get('pinmonyLanguage'),'ar','Manual selection wins');
  f.api.select('account');assert.equal(f.memory.get('pinmonyLanguage'),'zh');
  f.api.syncAccountLanguage('ar-EG');assert.equal(f.memory.get('pinmonyLanguage'),'ar');
  f.api.clearAccountLanguage();assert.equal(f.memory.get('pinmonyLanguage'),'en');
  f.api.select('ar');failFlush=true;assert.throws(()=>f.api.select('en'),/language-storage-write/);failFlush=false;
  assert.equal(f.memory.get('pinmonyLanguage'),'ar','Failed persistence leaves live language and direction intact');
  failLayout=true;f.api.select('en');failLayout=false;f.api.syncSystemLanguage();assert.equal(f.layout.at(-1),'en-US','Failed layout update can retry');
  f.api.select('ar');f.api.syncResourceColorMode(f.context);
  assert.equal(f.configurations.length,9);assert(f.configurations.some(config=>config.locale==='ar'&&config.colorMode===1));
  assert.equal(f.api.text('pm_retry_b8784c8d'),'إعادة المحاولة');
  for (const mode of [0,1]) {
    colorMode=mode;f.api.syncResourceColorMode(f.context);
    assert(f.configurations.slice(-9).every(config=>config.colorMode===mode));
    assert.equal(f.api.text('pm_birthdate_year','ar'),'السنة');
  }
  const accountSource=read('feature_settings/src/main/ets/components/PinmonyAccountPage.ets');
  assert.equal((accountSource.match(/"pm_birthdate_year"/g)||[]).length,2,'Visible and accessible birth year labels use the full year resource');
  assert(!accountSource.includes('pm_y_62ef900a'),'Time abbreviations must not label the birth-year input');

  // Read the actual layout expressions and verify the retained tree can change language
  // in either direction. Overlapping avatars must overlap the preceding avatar, and
  // reply indentation must follow the avatar side, without changing the total inset.
  const layouts=[
    ['feature_pin/src/main/ets/components/PinmonyCommentsSheet.ets',42,0,2],
    ['feature_pin/src/main/ets/components/PinmonyEditPinSheet.ets',0,28,1],
    ['feature_settings/src/main/ets/components/PinmonyAboutPage.ets',78,18,5],
    ['feature_inbox/src/main/ets/components/PinmonyBoardInvitationList.ets',8,0,1],
    ['feature_inbox/src/main/ets/components/PinmonyInboxPage.ets',8,0,2],
    ['feature_profile/src/main/ets/components/PinmonyPublishPhotoEditor.ets',0,12,1]
  ];
  for (const [file,left,right,count] of layouts) {
    const expressions=[...read(file).matchAll(/\.(?:margin|padding)\((\{[^{}\n]*PinmonyI18n\.isRtl[^{}\n]*\})\)/g)].map(match=>match[1]);
    let checked=0;
    for (const expression of expressions) {
      const host={uiLanguage:'en'};
      const evaluate=()=>vm.runInNewContext('(function(){return ('+expression+');}).call(host)',{host,index:1,PinmonyI18n:f.api});
      const original=evaluate();if(original.left!==left||original.right!==right)continue;
      for(const language of ['ar','en','zh','ar']) {
        host.uiLanguage=language;const actual=evaluate();
        assert.equal(actual.left,language==='ar'?right:left,file);
        assert.equal(actual.right,language==='ar'?left:right,file);
      }
      checked++;
    }
    assert.equal(checked,count,file+' directional inset coverage');
  }
  for(const [file,expected] of [
    ['feature_board/src/main/ets/components/PinmonyBoardPage.ets',[-16,-12,-12,-12]],
    ['feature_profile/src/main/ets/components/PinmonyProfilePage.ets',[-6]]
  ]) {
    const expressions=[...read(file).matchAll(/\.margin\(\{ start: LengthMetrics\.vp\((index > 0 \? -\d+ : 0)\) \}\)/g)];
    assert.deepEqual(expressions.map(match=>vm.runInNewContext(match[1],{index:1})),expected);
    assert(expressions.every(match=>vm.runInNewContext(match[1],{index:0})===0),'First avatar has no overlap');
  }
  assert(read('common_ui/src/main/ets/components/PinmonyOptionsNavigation.ets').includes('.direction(PinmonyI18n.isRtl(this.uiLanguage) ? Direction.Rtl : Direction.Ltr)'));

  // Execute the real form, timestamp and slider methods with retained data.
  function view(file, methods, host, globals = {}) {
    const source=read(file).replace(/\bstruct\s+/g,'class ');
    const ast=ts.createSourceFile('view.ts',source,ts.ScriptTarget.Latest,true);const found=[];
    function walk(n){if(ts.isMethodDeclaration(n)&&methods.includes(n.name?.getText(ast)))found.push(n.getText(ast).replace(/^private\s+/,''));ts.forEachChild(n,walk);}walk(ast);
    assert.equal(found.length,methods.length,file);
    const Constructor=vm.runInNewContext(ts.transpileModule('class View{'+found.join('\n')+'}; View',{compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:f.api,Intl,Date,...globals});
    return Object.assign(new Constructor(),host);
  }
  const activityNow=Date.parse('2026-11-14T04:52:42Z');
  class SegmentItems extends Array {constructor(items){super(...items);}}
  const inboxListSource=read('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets');
  assert(inboxListSource.includes('ForEach([this.uiLanguage], (_language: string) => {'));
  assert(!inboxListSource.includes('@State private segments: SegmentButtonV2Items'),'ObservedV2 items cannot be decorated with V1 State');
  assert(inboxListSource.includes("@StorageLink('pinmonyLanguage') @Watch('syncLabels')"));
  const list=view('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets',['text','syncLabels'],{
    uiLanguage:'zh',segments:new SegmentItems([{text:'旧消息'},{text:'旧联系人'}]),
    section:'contacts',messageQuery:'retained-message',contactQuery:'retained-contact'
  },{SegmentButtonV2Items:SegmentItems});
  for(const language of ['zh','en','ar','zh','ar']) {
    const previous=list.segments;list.uiLanguage=language;list.syncLabels();
    assert.notEqual(list.segments,previous,'Replace segment state so both API branches receive refreshed labels');
    assert.equal(list.segments[0].text,f.api.text('pm_messages_4da199fa',language));
    assert.equal(list.segments[1].text,f.api.text('pm_contacts_3303b569',language));
    assert.equal(list.section,'contacts');assert.equal(list.messageQuery,'retained-message');assert.equal(list.contactQuery,'retained-contact');
  }
  const rootInboxSource=read('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets');
  for(const [key,section] of [['pm_messages_4da199fa','messages'],['pm_contacts_3303b569','contacts']]) {
    assert(rootInboxSource.includes(`this.listTitle(this.uiText("${key}"), '${section}')`),
      'Fixed section headings must not prefer raw snapshot labels');
  }
  class ActivityDate extends Date {static now(){return activityNow;}}
  const activityItem={updatedAt:''};
  const activity=view('feature_inbox/src/main/ets/components/PinmonyInboxActivityRow.ets',['timeLabel','text'],{
    uiLanguage:'ar',item:activityItem
  },{Date:ActivityDate});
  for(const language of ['ar','en','zh','ar']) {
    activity.uiLanguage=language;
    for(const [minutes,key,count] of [
      [0,'pm_activity_now'],[1,'pm_activity_minutes',1],[59,'pm_activity_minutes',59],
      [60,'pm_activity_hours',1],[1439,'pm_activity_hours',23],
      [1440,'pm_activity_days',1],[4320,'pm_activity_days',3]
    ]) {
      activityItem.updatedAt=new Date(activityNow-minutes*60000).toISOString();
      assert.equal(activity.timeLabel(),count===undefined?f.api.text(key,language):f.api.format(key,[count],language),
        'Retained activity time follows the current locale, numbers and bidi isolation: '+language+'/'+minutes);
    }
    activityItem.updatedAt='invalid';assert.equal(activity.timeLabel(),'');
    activityItem.updatedAt=new Date(activityNow+60000).toISOString();assert.equal(activity.timeLabel(),f.api.text('pm_activity_now',language));
  }
  const slider=view('feature_search/src/main/ets/components/PinmonySearchFilterSheet.ets',['price','priceHandleOffset'],{
    uiLanguage:'ar',trackWidth:200,searchStore:{searchProductLower:0,searchProductUpper:100,searchProductMin:'20',searchProductMax:'80'}});
  assert.equal(slider.priceHandleOffset(false),160);assert.equal(slider.priceHandleOffset(true),40);
  slider.uiLanguage='en';assert.equal(slider.priceHandleOffset(false),40);assert.equal(slider.priceHandleOffset(true),160);
  const sections=[];
  const inbox=view('feature_inbox/src/main/ets/components/PinmonyInboxPage.ets',['swipeSection'],{uiLanguage:'ar',snapshot:{section:'updates'},selectSection:section=>sections.push(section)});
  inbox.swipeSection(100,0);assert.deepEqual(sections,['messages']);
  inbox.snapshot.section='messages';inbox.swipeSection(-100,0);assert.deepEqual(sections,['messages','updates']);
  inbox.swipeSection(-10,0);inbox.swipeSection(-100,150);inbox.conversationSwipeActive=true;inbox.swipeSection(-100,0);assert.equal(sections.length,2);
  const chat=view('feature_inbox/src/main/ets/components/PinmonyInboxFlowPage.ets',['messageTime'],{uiLanguage:'ar',uiText:key=>f.api.text(key,'ar')});
  const stamp=chat.messageTime('2020-03-04T12:34:00Z');assert.equal(stamp,new Intl.DateTimeFormat('ar',{year:'numeric',month:'numeric',day:'numeric'}).format(new Date('2020-03-04T12:34:00Z'))+' '+new Intl.DateTimeFormat('ar',{hour:'numeric',minute:'2-digit'}).format(new Date('2020-03-04T12:34:00Z')));assert(!/[年月日]/.test(stamp));assert.equal(chat.messageTime('invalid'),'');
  const NotificationCopy=createArktsLoader(ts,{'common_foundation':{PinmonyI18n:f.api}}).loadFile('feature_settings/src/main/ets/models/PinmonyNotificationCopy.ets').PinmonyNotificationCopy;
  const category={key:'comments',label:'Original',channels:[{channel:'push',value:true},{channel:'email',value:false}]};
  assert(NotificationCopy.summary(category,'ar').includes('، '));
  assert.equal(NotificationCopy.category({key:'unknown',label:website,channels:[]},'ar'),website);
  const entry=read('entry/src/main/ets/entryability/EntryAbility.ets');
  assert(entry.indexOf('this.contentLoaded = true;')<entry.indexOf('PinmonyI18n.attachLayoutContext(this.context)'));
  const rows=JSON.parse(read('common_foundation/src/main/resources/ar/element/string.json')).string;
  assert(rows.length>1500);for(const row of rows){assert(!/[\u3400-\u9fff]/.test(row.value),row.name);}
  // Execute the actual coverage gate against synthetic catalogs without writing
  // fixtures into the app. Distinct English sentences must fail even when they
  // differ from en_US; placeholders and standalone brand names remain valid.
  for(const [replacement,expectedError] of [
    ['Try the request again','Latin-only application copy'],
    ['重试','Chinese in Arabic resource'],['Pinmony','']
  ]) {
    const catalog=JSON.parse(read('common_foundation/src/main/resources/ar/element/string.json'));
    catalog.string.find(row=>row.name==='pm_retry_b8784c8d').value=replacement;
    const fakeFs=Object.create(fs);
    fakeFs.readFileSync=(file,...options)=>String(file).replace(/\\/g,'/').endsWith('/ar/element/string.json')?JSON.stringify(catalog):fs.readFileSync(file,...options);
    const run=()=>vm.runInNewContext(read('scripts/check-language-coverage.cjs'),{
      require:name=>name==='node:fs'?fakeFs:require(name),__dirname:require('node:path').resolve('scripts'),console:{log(){}}
    });
    if(expectedError)assert.throws(run,new RegExp(expectedError+'.*: pm_retry_b8784c8d'));else run();
  }
  assert(read('entry/src/main/ets/pages/Index.ets').includes('.direction(PinmonyI18n.isRtl(this.uiLanguage) ? Direction.Rtl : Direction.Ltr)'));
  console.log('Arabic: locale variants, account/manual persistence, live switching, RTL configuration retry, resource color mode, bidi isolation, Arabic digits, timestamps, slider and website text boundaries passed');
}
module.exports=checkArabic;
if(require.main===module)checkArabic(require(process.argv[2]||'typescript'));
