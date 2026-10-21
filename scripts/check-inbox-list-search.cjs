const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_inbox/src/main/ets/components/PinmonyInboxListPage.ets', 'utf8');
const methods = source.slice(source.indexOf('  private query()'), source.indexOf('  private error()'));
const navigation = source.slice(source.indexOf('  private selectSection('), source.indexOf('  @Builder'));
const searchNavigation = source.slice(source.indexOf('  private openSearch('), source.indexOf('  private query()'));
const js = ts.transpileModule(`class Filter { ${methods} ${navigation} ${searchNavigation} } exports.Filter = Filter;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText;
const context = { exports: {} }; vm.runInNewContext(js, context);
const filter = new context.exports.Filter();
filter.snapshot = {
  items: [{ id: 'one', title: 'Display name', subtitle: 'unrelated text', usernames: ['Alice'] },
    { id: 'group', title: 'Group', subtitle: 'Alice in body', usernames: ['Bob', 'CAROL'] }],
  contacts: [{ id: 'contact', title: 'Display name', subtitle: '@alice' }]
};
filter.section = 'messages'; filter.messageQuery = ' @aLi '; filter.contactQuery = 'missing';
assert.equal(filter.rows().map(row => row.id).join(), 'one');
filter.messageQuery = 'car'; assert.equal(filter.rows()[0].id, 'group');
filter.messageQuery = 'Display name'; assert.equal(filter.rows().length, 0);
assert.equal(filter.rows(false).length, 2, 'search query never filters the parent list');
filter.messageQuery = 'unrelated text'; assert.equal(filter.rows().length, 0);
filter.messageQuery = ''; assert.equal(filter.rows().length, 2);
filter.section = 'contacts'; assert.equal(filter.rows().length, 0);
filter.contactQuery = '@ALICE'; assert.equal(filter.rows()[0].id, 'contact');
filter.contactQuery = '  '; assert.equal(filter.rows().length, 1);
filter.snapshot.contacts = []; assert.equal(filter.rows().length, 0);
let resets = 0;
filter.scroller = { scrollTo() { resets++; } };
filter.onSection = section => { filter.section = section; };
filter.section = 'messages';
filter.swipeSection(-80, 10); assert.equal(filter.section, 'contacts');
filter.swipeSection(-80, 10); assert.equal(resets, 1, 'no wrapping past contacts');
filter.swipeSection(80, 10); assert.equal(filter.section, 'messages');
filter.swipeSection(80, 10); assert.equal(resets, 2, 'no wrapping before messages');
filter.swipeSection(-30, 0); filter.swipeSection(-80, 100);
assert.equal(filter.section, 'messages', 'short and predominantly vertical drags keep selection');
const routes = ['inbox-list']; let closed = 0;
filter.paths = { pushPath(path) { routes.push(path.name); }, pop() { routes.pop(); } };
filter.onSearchClosed = () => { closed++; };
filter.openSearch(); filter.openSearch();
assert.equal(routes.join(), 'inbox-list,inbox-search', 'open creates one separate search destination');
filter.closeSearch(); filter.closeSearch();
assert.equal(routes.join(), 'inbox-list', 'search back retains the parent list');
assert.equal(closed, 1);
assert(source.includes("icon: $r('app.media.inbox_search_outline')"));
assert(source.includes("selectedIndex: this.section === 'contacts' ? 1 : 0"));
assert(source.includes('.navDestination(this.destination)'), 'register the HDS destination builder directly');
assert(source.includes('.mode(NavigationMode.Stack)'), 'secondary list uses stack navigation');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const mount = index.slice(index.indexOf('            PinmonyInboxListPage({'), index.indexOf('          if (!(PIN_NATIVE_PROFILE_READS_ENABLED', index.indexOf('            PinmonyInboxListPage({')));
assert(mount.includes(".width('100%').height('100%')"), 'list must fill the bottom-aligned overlay host');
console.log('PASS inbox list: username-only filtering, groups, case/@/whitespace, independent segment queries and empty lists');
