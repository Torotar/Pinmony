const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const source = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
function method(name) {
  const start = source.indexOf(`  private ${name}(`);
  assert(start >= 0, name);
  const end = source.indexOf('\n  }', start);
  assert(end > start, name);
  return source.slice(start, end + 4);
}
const code = ts.transpileModule(`class Host { ${method('editColumns')} } Host;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2021 }
}).outputText;
const host = new (vm.runInNewContext(code))();
host.snapshot = { editable: true, flow: { phase: 'edit', coverImage: 'saved-cover' } };
host.editName = 'Unsaved name';
host.editDescription = '尚未保存的描述';
host.secret = true;
host.recommend = false;
host.requests = true;
const draft = JSON.stringify(host);
for (const [width, height, columns] of [
  [0, 0, 4], [360, 800, 4], [599, 400, 4], [600, 900, 4],
  [600, 600, 4], [600, 599, 8], [768, 640, 8], [839, 600, 8],
  [840, 600, 12], [1024, 768, 12], [1366, 1024, 12], [1920, 1080, 12],
  [1024, 1366, 4], [768, 1024, 4], [360, 800, 4], [1024, 768, 12]
]) {
  host.editViewportWidth = width;
  host.editViewportHeight = height;
  const before = JSON.stringify(host);
  assert.equal(host.editColumns(), columns, `${width}x${height}`);
  assert.equal(JSON.stringify(host), before, 'resizing only derives layout; drafts and flow stay intact');
  if (columns > 4) {
    const available = width - 32;
    const unit = (available - (columns - 1) * 20) / columns;
    const cover = 4 * unit + 3 * 20;
    const fields = (columns - 4) * unit + (columns - 5) * 20;
    assert(cover > 0 && fields >= 260, 'both columns remain usable');
    assert(Math.abs(cover + 20 + fields - available) < 1e-6, 'columns fit within page padding');
  }
}
delete host.editViewportWidth;
delete host.editViewportHeight;
assert.equal(JSON.stringify(host), draft, 'portrait/landscape round trips retain all edit state');
host.snapshot.editable = false;
host.editViewportWidth = 1366;
host.editViewportHeight = 768;
assert.equal(host.editColumns(), 4, 'collaborators without edit permission have no empty cover column');
const layout = method('editContent');
assert.match(layout, /GridRow\(\{ columns: this\.editColumns\(\), gutter: \{ x: 20, y: 20 \} \}/);
assert.equal((layout.match(/this\.editCover\(\)/g) || []).length, 1);
assert.equal((layout.match(/this\.editFields\(\)/g) || []).length, 1);
assert.match(layout, /if \(this\.snapshot\.editable\)/);
assert.match(layout, /span: this\.editColumns\(\) === 4 \? 4 : this\.editColumns\(\) - 4/);
const cover = method('editCover');
assert.match(cover, /aspectRatio\(5\/3\)/);
assert.match(cover, /coverPreview\.width/);
assert.match(cover, /'coverAdjust' : 'coverOpen'/);
assert.match(cover, /this\.act\('coverOpen'\)/);
assert.match(cover, /!this\.snapshot\.flow\?\.uncertain/);
const fields = method('editFields');
for (const control of ['text: this.editName', 'text: this.editDescription', 'selected: this.secret',
  'selected: this.recommend', 'selected: this.requests', 'pm_collaborator_', 'this.confirmDelete()', 'this.confirmLeave()']) {
  assert(fields.includes(control), control);
}
assert.doesNotMatch(layout + cover + fields, /Scroll\(/, 'retain the existing whole-page Scroller');
assert.match(source, /PinmonyBoardCoverContent\([\s\S]*?\} else \{ this\.editContent\(\) \}/,
  'cover selection and adjustment retain their independent page');
assert.match(source, /\.onAreaChange\([\s\S]*?this\.editViewportWidth = width;\s*this\.editViewportHeight = height;/);
console.log('Board edit layout passed: width/orientation boundaries, resize round trips, permissions, drafts, cover actions and complete form.');
