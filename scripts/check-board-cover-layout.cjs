const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const page = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardPage.ets', 'utf8');
const content = fs.readFileSync('feature_board/src/main/ets/components/PinmonyBoardCoverContent.ets', 'utf8');
function host(source, name) {
  const start = source.indexOf(`  private ${name}(`);
  assert(start >= 0, name);
  const end = source.indexOf('\n  }', start);
  const code = ts.transpileModule(`class Host { ${source.slice(start, end + 4)} } Host;`, {
    compilerOptions: { target: ts.ScriptTarget.ES2021 }
  }).outputText;
  return new (vm.runInNewContext(code))();
}
const outer = host(page, 'coverContentHeight');
const pinsOuter = host(page, 'coverPinsHeight');
const preview = host(content, 'previewWidthLimit');
const editor = host(page, 'editColumns');
const layout = host(content, 'coverLayoutColumns');
for (const [width, height, expected] of [[360,800,1],[599,400,1],[600,400,2],
  [800,600,2],[865,577,2],[1024,768,2],[768,1024,1],[1024,1024,1],
  [1366,1024,2],[1920,1080,2],[360,800,1]]) {
  Object.assign(editor,{snapshot:{editable:true},editViewportWidth:width,editViewportHeight:height});
  layout.splitLayout = editor.editColumns() > 4;
  layout.cover = {adjusting:false};
  assert.equal(layout.coverLayoutColumns(),expected,`${width}x${height}: match the edit page landscape boundary`);
  const availableWidth = width - 32;
  const columnWidth = expected === 2 ? (availableWidth - 20) / 2 : availableWidth;
  const candidateColumns = expected === 2 ? 3 : 2;
  const candidateWidth = (columnWidth - 12 * (candidateColumns - 1)) / candidateColumns;
  assert(candidateWidth > 0);
  assert(Math.abs(candidateWidth*candidateColumns+12*(candidateColumns-1)-columnWidth)<1e-8,'Pins and gutters fill the candidate area');
  outer.editViewportHeight = height; outer.titleContentInset = () => 104;
  preview.contentHeightLimit = outer.coverContentHeight(); preview.captionHeight = 40;
  const frameWidth = Math.min(columnWidth,preview.previewWidthLimit());
  assert(height - (104 + 18 + frameWidth * 3 / 5 + 16 + 40) >= 40 - 1e-6,
    'left preview retains the bottom clearance after changing column width');
  layout.cover.adjusting = true;
  assert.equal(layout.coverLayoutColumns(),1,'adjustment-only flow has no empty candidate column');
}
for (const [width, height] of [[360, 800], [600, 400], [865, 577], [768, 1024],
  [1024, 768], [1366, 1024], [1920, 1080], [360, 800]]) {
  for (const title of [80, 104]) for (const caption of [20, 40, 60]) {
    outer.editViewportHeight = height;
    outer.titleContentInset = () => title;
    preview.contentHeightLimit = outer.coverContentHeight();
    preview.captionHeight = caption;
    const frameWidth = Math.min(width - 32, preview.previewWidthLimit());
    const frameHeight = frameWidth * 3 / 5;
    assert(frameWidth > 0);
    assert(Math.abs(frameWidth / frameHeight - 5 / 3) < 1e-9, 'retain the saved crop aspect ratio');
    const usedHeight = title + 18 + frameHeight + 16 + caption;
    assert(height - usedHeight >= 40 - 1e-6, `${width}x${height} reserves bottom space including caption`);
    if (width === 360) assert.equal(frameWidth, width - 32, 'phone portrait keeps full content width');
  }
}
for (const height of [0, -1, NaN, Infinity]) {
  preview.contentHeightLimit = height;
  assert.equal(preview.previewWidthLimit(), undefined, 'unmeasured viewport retains normal sizing');
}
preview.contentHeightLimit = 40;
preview.captionHeight = 60;
assert(preview.previewWidthLimit() > 0, 'very short windows keep a valid scrollable preview');
assert.match(page, /contentHeightLimit: this\.coverContentHeight\(\)/, 'pass the measured page height to both cover modes');
assert.match(page, /splitLayout: this\.editColumns\(\) > 4/, 'reuse existing measured window adaptation');
assert.match(content, /GridRow\(\{columns:this\.coverLayoutColumns\(\),gutter:\{x:20,y:16\}\}\)/);
assert(content.indexOf('GridCol({span:1}) { this.coverPreview() }') <
  content.lastIndexOf('this.coverCandidates()'), 'fixed preview precedes the independently scrolling candidates');
assert.match(content, /WaterFlow\(\{scroller:this\.coverLayoutColumns\(\) === 2 \? this\.pinsScroller : undefined,footer:this\.candidateFooter\}\)/,
  'candidate WaterFlow owns the independent scroll controller and pagination footer');
assert(content.indexOf("Text(this.copy('pm_board_cover_pins'))")<content.indexOf('WaterFlow({scroller:'),
  'fixed heading stays outside the scrolling masonry');
assert.match(content,/\.height\(this\.candidateHeight\(\)\)/,'masonry has bounded viewport height');
assert.match(content, /nestedScroll\(\{scrollForward:NestedScrollMode\.SELF_FIRST,scrollBackward:NestedScrollMode\.SELF_FIRST\}\)/,
  'candidate edges hand the gesture to the local refresh container');
assert.match(content, /Refresh\(\{refreshing:this\.cover\.refreshing === true\}\)/, 'candidate refresh uses the request lifecycle');
assert.match(page,/maxPullDownDistance\(this.snapshot.flow\?\.cover \? 0 : undefined\)/,'only candidate list pulls down on the cover page');
assert(content.indexOf("Text(this.copy('pm_board_cover_pins'))") < content.indexOf('Refresh({refreshing:'), 'heading stays outside the refresh movement');
assert.match(content, /onAction\('coverRefresh',''\)/, 'pull refresh reloads the candidate feed rather than the board root');
assert.match(content, /pullToRefresh\(!this\.locked && !this\.cover\.loading && this\.cover\.status !== 'uncertain'\)/, 'busy, loading and uncertain states cannot refresh');
assert.match(content, /minHeight:Math.min\(120,this.candidateHeight\(\) \?\? 120\).*edgeEffect\(EdgeEffect.Spring,\{alwaysEnabled:true\}\)/, 'empty and short lists remain pullable without overflowing short windows');
assert.match(page, /cover.loading && !this.snapshot.flow.cover.refreshing &&/, 'empty refresh uses only the list indicator rather than a second full-page spinner');
assert.match(page, /Scroll\(this\.splitCoverScrolling\(\) \? this\.coverHostScroller : this\.contentScroll\(\)\)/,
  'outer host and candidates never share a bound controller');
assert.match(page, /\.scrollable\(this\.splitCoverScrolling\(\) \? ScrollDirection\.None : ScrollDirection\.Vertical\)/,
  'whole-page scrolling is disabled only in split cover selection');
assert.match(page, /pinsScroller: this\.contentScroll\(\)/, 'HDS and scroll restoration retain the actual candidate controller');
assert.match(content, /this\.onPinsScroll\(this\.pinsScroller\.currentOffset\(\)\.yOffset\)/,
  'independent list reports the offset used for restoration');
const tracking = host(page,'coverPinsScrolled');
tracking.scrollOffsets=new Map();tracking.scrollScope=()=>'cover';tracking.splitCoverScrolling=()=>true;
tracking.coverPinsScrolled(240);assert.equal(tracking.scrollOffsets.get('cover'),240);assert(tracking.headerScrolled);
tracking.restoringScroll=true;tracking.coverPinsScrolled(0);assert.equal(tracking.scrollOffsets.get('cover'),240);
tracking.restoringScroll=false;tracking.splitCoverScrolling=()=>false;tracking.coverPinsScrolled(0);
assert.equal(tracking.scrollOffsets.get('cover'),240,'portrait and restore events cannot overwrite the candidate offset');
const scrolling = host(page,'splitCoverScrolling');
for(const [cover,columns,expected] of [[undefined,12,false],[{adjusting:false},12,true],
  [{adjusting:false},8,true],[{adjusting:false},4,false],[{adjusting:true},12,false]]) {
  scrolling.snapshot={flow:{cover}};scrolling.editColumns=()=>columns;
  assert.equal(scrolling.splitCoverScrolling(),expected,'only landscape cover selection isolates the list');
}
assert.match(content,/FlowItem\(\) \{ this\.candidate\(pin\) \}\.width\('100%'\)/,'each Pin is a masonry item');
assert.match(content,/\(pin: PinmonyBoardPin\): string => pin.id\)/,'selection and language cannot recreate image nodes');
const candidateImages = content.slice(content.indexOf('  private candidate('),content.indexOf('  private candidateFooter('));
assert.match(candidateImages, /\.width\('100%'\)\.aspectRatio\(pin\.imageWidth\/pin\.imageHeight\)/,
  'candidate images fill their column width at their natural aspect ratio');
assert.match(candidateImages,/border\(\{width:3,color:/,'selection changes color without changing image geometry');
const columns=host(content,'candidateColumns'),viewport=host(content,'candidateHeight');
for(const count of [1,2]) {
  columns.coverLayoutColumns=()=>count;viewport.coverLayoutColumns=()=>count;
  viewport.pinsHeightLimit=420;viewport.pinsTitleHeight=28;
  assert.equal(columns.candidateColumns(),count===2?3:2);
  assert.equal(viewport.candidateHeight(),count===2?376:undefined);
}
viewport.coverLayoutColumns=()=>2;viewport.pinsTitleHeight=56;
assert.equal(viewport.candidateHeight(),348,'language/font-dependent heading height reduces the list viewport');
for(const height of [320,400,577,768,1024])for(const title of [80,104])for(const heading of [28,56]) {
  Object.assign(pinsOuter,{editViewportHeight:height,titleContentInset:()=>title});
  Object.assign(viewport,{pinsHeightLimit:pinsOuter.coverPinsHeight(),pinsTitleHeight:heading});
  assert.equal(title+18+heading+16+viewport.candidateHeight(),height,'right candidate viewport reaches the page bottom');
  Object.assign(outer,{editViewportHeight:height,titleContentInset:()=>title});
  assert.equal(pinsOuter.coverPinsHeight()-outer.coverContentHeight(),40,'preview alone retains its bottom clearance');
}
viewport.pinsHeightLimit=0;
assert.equal(viewport.candidateHeight(),1,'unmeasured viewport remains bounded');
assert.match(page,/pinsHeightLimit: this.coverPinsHeight\(\)/,'candidate viewport receives its own measured height');
assert.match(page,/bottom: this.splitCoverScrolling\(\) \? 0 :/,'split list has no outer bottom spacer');
assert.match(content,/padding\(\{bottom:this.coverLayoutColumns\(\) === 2 \? 0 : 24\}\)/,'split masonry has no extra bottom padding');
assert(!candidateImages.includes('maxHeight'), 'candidate height caps must not shrink portrait images away from their column edges');
assert(!content.includes("width('31%')"), 'remove the former three-column percentage layout');
assert.match(content, /constraintSize\(\{ maxWidth: this\.previewWidthLimit\(\) \}\)\.align\(Alignment\.Center\)/);
assert.match(content, /this\.captionHeight = height/, 'reserve actual caption height after language/font changes');
const coverPreview = content.slice(content.indexOf('  private coverPreview()'), content.indexOf('  private candidate('));
const emptyPreview = coverPreview.slice(coverPreview.indexOf('} else {'), coverPreview.indexOf("if(this.cover.status === 'saving'"));
assert.match(emptyPreview, /Stack\(\)\s*\{\}/, 'no selected Pin renders an empty cover surface');
assert.match(emptyPreview, /aspectRatio\(5\/3\)\.borderRadius\(20\)/, 'placeholder matches the cover frame');
assert.match(emptyPreview, /backgroundColor\(\$r\('app.color.surface_muted'\)\)/, 'placeholder uses the shared theme gray');
assert.match(emptyPreview, /maxWidth: this\.previewWidthLimit\(\)/, 'placeholder respects the viewport height limit');
assert(!/gesture\(|onClick\(|pm_board_cover_drag|PinmonyCdnImage/.test(emptyPreview), 'empty cover has no image, crop gesture, action or drag instruction');
assert.match(content, /this\.resizePreview\(Number\(area\.width\)\)/, 'crop gesture scale uses the constrained frame size');
assert.match(content, /if\(!this\.cover\.adjusting\)/, 'candidate refresh remains mounted for empty results');
console.log('Board cover layout passed: landscape three-column masonry, fixed heading, independent list, stable selection keys, portrait fallback, adjustment-only mode, bottom spacing, caption changes, rotation and 5:3 drag frame.');
