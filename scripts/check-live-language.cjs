const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict'), vm = require('node:vm');
module.exports = function checkLiveLanguage(ts, i18n) {
  function walk(dir) { return fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.isDirectory() ? walk(path.join(dir,e.name)) : e.name.endsWith('.ets') ? [path.join(dir,e.name)] : []); }
  let checked = 0;
  const keyCases = [];
  for (const root of fs.readdirSync('.').filter(n => n === 'entry' || n.startsWith('feature_') || n === 'common_ui').map(n => n+'/src/main/ets').filter(fs.existsSync)) {
    for (const file of walk(root)) {
      if (!/components|pages/.test(file)) continue;
      const source=fs.readFileSync(file,'utf8'); if (!source.includes("@StorageLink('pinmonyLanguage')")) continue;
      const sf=ts.createSourceFile(file,source,ts.ScriptTarget.Latest,true);
      const classSource=ts.createSourceFile(file,source.replace(/\bstruct\b/g,'class'),ts.ScriptTarget.Latest,true);
      const languageHelpers=new Set();
      function collect(n){if(ts.isMethodDeclaration(n)&&n.name&&n.body?.getText(classSource).includes('this.uiLanguage'))languageHelpers.add(n.name.getText(classSource));ts.forEachChild(n,collect);}collect(classSource);
      function visit(n) {
        if (ts.isCallExpression(n) && n.expression.getText(sf)==='ForEach' && /uiText|PinmonyI18n|PinmonyNotificationCopy|optionLabel|this\.(selection|row|field|buildShareActionRow)/.test(n.arguments[1]?.getText(sf)||'')) {
          const key=n.arguments[2]?.getText(sf)||'';
          const helper=key.match(/this\.(\w+)\(/)?.[1];
          assert(key.includes('uiLanguage') || n.arguments[0].getText(sf).includes('uiLanguage') || languageHelpers.has(helper), `Localized list must invalidate on language change: ${file}:${sf.getLineAndCharacterOfPosition(n.pos).line+1}`);
          checked++;
          if (/PinmonySearchFilterSheet|PinmonyNotificationsPage/.test(file) && ts.isArrowFunction(n.arguments[2])) keyCases.push(n.arguments[2].getText(sf));
        }
        if (ts.isCallExpression(n) && n.expression.getText(sf)==='Select' && /uiText/.test(n.getText(sf))) {
          let parent=n.parent;
          while(parent && !(ts.isCallExpression(parent)&&parent.expression.getText(sf)==='ForEach')) parent=parent.parent;
          assert(parent?.arguments[0].getText(sf).includes('uiLanguage'), 'Localized Select must rebuild its options when language changes');
        }
        ts.forEachChild(n,visit);
      } visit(sf);
    }
  }
  // Execute real row identities with the same item and selection across en -> zh -> en.
  for (const key of keyCases) {
    const factory=vm.runInNewContext(ts.transpileModule('(function(){return ('+key+');})', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText);
    const host={uiLanguage:'en',store:{token:2,busy:false},searchStore:{},confirmationOpen:false};
    const identity=factory.call(host), item={id:'item',key:'comments',channel:'push',section:'section',option:'comments',label:'原文',selected:true,value:true};
    // Category identity closes over its parent group in the actual nested list.
    if (key.includes('group.key')) continue;
    const first=identity(item);host.uiLanguage='zh';const second=identity(item);host.uiLanguage='en';assert.equal(identity(item),first);assert.notEqual(first,second);assert.equal(item.selected,true);
  }
  const index=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8');
  assert(index.includes('Text(PinmonyI18n.text(labelKey, this.uiLanguage))'));
  assert(!/buildNativeTab\(this\.uiText/.test(index), 'Do not capture a translated tab caption');
  const profile=fs.readFileSync('feature_profile/src/main/ets/components/PinmonyProfilePage.ets','utf8');
  assert(!/sectionTab\('[^']+',\s*this\.uiText/.test(profile), 'Profile section builders must receive resource keys');
  assert(profile.includes('Text(PinmonyI18n.text(nameKey, this.uiLanguage))'));
  assert(profile.includes("this.profile.boards[start].id + ':' + this.uiLanguage"));
  assert(profile.includes("(pin: PinmonyCreatedPin) => pin.id + ':' + this.uiLanguage"));
  if (i18n) {
    const state={section:'saved',boards:[{id:'22',title:'插画'}]};
    const keys=['pm_created_80bfa30d','pm_saved_471dd4d7'];
    const host={uiLanguage:'en',profile:state};
    const caption=vm.runInNewContext('(function(nameKey){return PinmonyI18n.text(nameKey,this.uiLanguage);})',{PinmonyI18n:i18n});
    assert.deepEqual(keys.map(key=>caption.call(host,key)),['Created','Saved']);
    host.uiLanguage='zh';assert.deepEqual(keys.map(key=>caption.call(host,key)),['已创建','已收藏']);
    host.uiLanguage='en';assert.deepEqual(keys.map(key=>caption.call(host,key)),['Created','Saved']);
    assert.equal(host.profile,state);assert.equal(state.section,'saved');assert.equal(state.boards[0].title,'插画');
    for (const page of ['PinmonyDisplaySettingsPage','PinmonyRecommendationSettingsPage','PinmonyVisibilitySettingsPage']) {
      const source=fs.readFileSync(`feature_settings/src/main/ets/components/${page}.ets`,'utf8');
      assert(source.includes("@StorageLink('pinmonyLanguage') @Watch('syncErrorSnack')"));
      const sf=ts.createSourceFile(page,source.replace(/\bstruct\b/g, 'class'),99,true);let method;
      function find(n){if(ts.isMethodDeclaration(n)&&n.name.getText(sf)==='syncErrorSnack')method=n;ts.forEachChild(n,find);}find(sf);
      const Type=vm.runInNewContext(ts.transpileModule('class Host {'+method.getText(sf)+'} Host;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText,{PinmonyI18n:i18n,$r:name=>name,SnackBarIconType:{NORMAL:1},SnackBarOperationType:{TEXT_ONLY:1}});
      const shows=[],store={screen:'display',recommendationTab:'ai',token:1,error:i18n.message('pm_unable_to_load_please_reload_d84df6b3')};
      const host=new Type();Object.assign(host,{uiLanguage:'en',store,pageVisible:true,errorSnackKey:'',errorSnack:{show(_a,b){shows.push(b.title);}},dismissErrorSnack(){this.errorSnackKey='';},uiText(key){return i18n.text(key,this.uiLanguage);}});
      host.syncErrorSnack();host.syncErrorSnack();assert.equal(shows.length,1);
      host.uiLanguage='zh';host.syncErrorSnack();host.uiLanguage='en';host.syncErrorSnack();assert.equal(shows.length,3);assert.equal(shows[0],shows[2]);assert.notEqual(shows[0],shows[1]);assert.equal(host.store,store);
    }
  }
  console.log(`Live language: ${checked} localized lists, Select refresh, tab resource identity and retained snackbar state passed`);
};
if (require.main === module) module.exports(require(process.argv[2] || 'typescript'));
