const fs = require('node:fs'), assert = require('node:assert/strict'), path = require('node:path');
const contracts = require('./feature-store-access-contracts.json');
const buildMode = process.argv[2] || 'debug';
assert(['debug', 'release'].includes(buildMode), 'Build mode must be debug or release');
const base = 'entry/build/default/cache/default/default@CompileArkTS/esmodule/' + buildMode + '/';
const indexPath = 'entry/src/main/ets/pages/Index';
const homePath = 'feature_home/src/main/ets/controllers/PinmonyHomeController';
const searchPath = 'feature_search/src/main/ets/controllers/PinmonySearchController';
function currentCompiled(relative) {
  const compiled = path.join(base, relative + '.ts'), source = relative + '.ets';
  assert(fs.existsSync(compiled), 'Build entry HAP before checking ' + relative);
  assert(fs.statSync(compiled).mtimeMs >= fs.statSync(source).mtimeMs, 'Compiled output is older than source: ' + relative);
  return fs.readFileSync(compiled, 'utf8');
}
const profileActions = currentCompiled('feature_profile/src/main/ets/controllers/PinmonyProfileActionsController').replace(/this\.store\./g, 'this.profileStore.');
const profileRead = currentCompiled('feature_profile/src/main/ets/controllers/PinmonyProfileReadController').replace(/this\.store\./g, 'this.profileStore.');
const panels = currentCompiled('feature_pin/src/main/ets/controllers/PinmonyPostPanelsController').replace(/this\.store\./g, 'this.pinStore.');
const board = currentCompiled('feature_board/src/main/ets/controllers/PinmonyBoardStateController');
const invitation = currentCompiled('feature_inbox/src/main/ets/controllers/PinmonyBoardInvitationController').replace(/this\.store\./g, 'this.inboxStore.');
const publish = currentCompiled('feature_profile/src/main/ets/controllers/PinmonyPublishController').replace(/this\.store\./g, 'this.profileStore.');
const settings = currentCompiled('feature_settings/src/main/ets/controllers/PinmonySettingsController');
const inboxActions = currentCompiled('feature_inbox/src/main/ets/controllers/PinmonyInboxActionsController');
const sheets = [['pin','PinmonyShareSheet'],['pin','PinmonyMoreSheet'],['search','PinmonySearchFilterSheet']].map(([feature,name])=>currentCompiled('feature_'+feature+'/src/main/ets/components/'+name)).join('\n');
const product = ['RootContext','Navigation','Session','PhotoMenu','DetailOpening','BusinessResults','WebLifecycle','NetworkBridge','FailureRecovery','BottomBar'].map(name=>currentCompiled('entry/src/main/ets/app/Pinmony'+name+'Coordinator')).join('\n');
const rootViews = ['Home','Search','Inbox','Profile'].map(name=>currentCompiled('entry/src/main/ets/components/Pinmony'+name+'RootContent')).join('\n');
const index = currentCompiled(indexPath), search = currentCompiled(searchPath), home = currentCompiled(homePath);
assert(!index.includes('this.immersiveLightEnabled'), 'ArkUI must not reference a stripped getter');
assert.match(index, /HdsTabs.barBackgroundColor\(this\.immersiveLightMode !== 'off'/);
for (const [name, state] of Object.entries(contracts)) {
  assert(!new RegExp('\\bthis\\.' + name + '\\b').test(index), 'Compiled ArkUI references a missing page field: ' + name);
  const owner = state.store === 'searchStore' ? index + '\n' + search : state.store === 'homeStore' ? index + '\n' + home : state.store === 'profileStore' ? index + '\n' + publish + '\n' + profileRead + '\n' + profileActions : state.store === 'inboxStore' ? index + '\n' + invitation : state.store === 'pinStore' ? index + '\n' + panels : index;
  assert((owner+'\n'+product+'\n'+sheets).includes('this.' + state.store + '.' + state.field) ||
    rootViews.includes('view.' + state.store + '.' + state.field), 'Missing compiled Store access: ' + name);
}
assert.match(index, /this\.profileStore\.profileCache\.clear\(\)/);
assert.match(index, /this\.boardStateController = new PinmonyBoardStateController\(this\.boardStore,/);
assert(index.indexOf('this.__boardStore =') < index.indexOf('this.boardStateController ='), 'Board Store initializes before controller');
assert.match(board, /this\.store = store/);
assert.match(index, /this\.profileActionsController = new PinmonyProfileActionsController\(this\.profileStore,/);
assert(index.indexOf('this.__profileStore =') < index.indexOf('this.profileReadController ='));
assert.match(index, /this\.postPanelsController = new PinmonyPostPanelsController\(this\.pinStore,/);
assert(index.indexOf('this.__pinStore =') < index.indexOf('this.postPanelsController ='));
assert.match(index, /this\.__searchStore = new ObservedPropertyObjectPU\(new PinmonySearchStore\(\)/);
assert.match(index, /this\.searchController = new PinmonySearchController\(this\.searchStore,/);
assert.equal((index.match(/new PinmonySearchStore\(\)/g) || []).length, 1);
assert.match(search, /this\.searchStore = searchStore/);
assert.match(search, /this\.searchStore\.searchCache/);
assert(index.indexOf('this.__searchStore =') < index.indexOf('this.searchController ='), 'Observed Store initializes before controller binding');
assert.match(index, /this\.__homeStore = new ObservedPropertyObjectPU\(new PinmonyHomeStore\(\)/);
assert.match(index, /this\.homeController = new PinmonyHomeController\(this\.homeStore,/);
assert.equal((index.match(/new PinmonyHomeStore\(\)/g) || []).length, 1);
assert(index.indexOf('this.__homeStore =') < index.indexOf('this.homeController ='));
assert.match(home, /this\.homeStore = homeStore/);
for(const [controller,store,compiled] of [['settingsController','settingsStore',settings],['inboxActionsController','inboxStore',inboxActions]]) {
  assert(index.includes('this.'+controller+' = new '),'controller emitted '+controller);
  assert(index.indexOf('this.__'+store+' =')<index.indexOf('this.'+controller+' ='),'Store initializes before '+controller);
  assert.match(compiled,/this\.store = store/);
}
assert.match(settings,/this\.store\.writeUncertain/);
for(const name of ['RootContext','Navigation','Session','PhotoMenu','DetailOpening','BusinessResults','NetworkBridge','FailureRecovery','BottomBar']) {
  const field=name[0].toLowerCase()+name.slice(1)+'Coordinator';
  assert(index.includes('this.'+field+' = new Pinmony'+name+'Coordinator('));
  for(const store of ['home','pin','board','search','profile','inbox','settings']) assert(index.indexOf('this.__'+store+'Store =') < index.indexOf('this.'+field+' ='),'Stores initialize before '+field);
}
assert(sheets.includes('new SynchedPropertyNesedObjectPU(params.pinStore'));
assert(sheets.includes('new SynchedPropertyNesedObjectPU(params.searchStore'));
console.log('Current Hvigor output: initialized feature Stores, shared search binding, migrated business access and login cleanup passed');
