const fs = require('fs');
const assert = require('assert');

const common = fs.readFileSync('common_ui/src/main/ets/components/SmartImage.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinmonyDetailPage.ets', 'utf8');
const model = fs.readFileSync('feature_pin/src/main/ets/models/PinmonyDetail.ets', 'utf8');
const api = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailApiScript.ets', 'utf8');
const cache = fs.readFileSync('feature_pin/src/main/ets/services/PinmonyDetailCache.ets', 'utf8');

assert.match(common, /display\.getDefaultDisplaySync\(\)/);
assert.match(common, /RECOMMEND_WIDE_THRESHOLD_VP: number = 600/);
assert.match(common, /RECOMMEND_HORIZONTAL_PADDING_VP \* 2/);
assert.match(common, /columnGapVp \* \(columnCount - 1\)/);
assert.match(common, /170x.*236x.*474x.*564x.*736x/s);
assert.match(common, /tier\.width >= targetPx/);
assert.match(common, /validImageTier\(images, 'orig'\)/);
assert.match(common, /\.objectFit\(ImageFit\.Cover\)/);
assert.doesNotMatch(common, /\.sourceSize\(/, 'card aspect must not stretch decoded source pixels');
assert.match(common, /#F0F0F0/);
assert.match(common, /exclamationmark_triangle/);
assert.match(common, /@Prop fadeInOnLoad: boolean = true/, 'other SmartImage callers retain their reveal behavior');
const reveal = common.match(/\.opacity\((this\.phase[^\n]+)\)/)[1];
const revealOpacity = new Function('return ' + reveal);
for (const fadeInOnLoad of [true, false]) {
  for (const phase of ['loading', 'loaded', 'failed']) {
    const expected = phase === 'failed' ? 0 : phase === 'loaded' || !fadeInOnLoad ? 1 : 0;
    assert.equal(revealOpacity.call({fadeInOnLoad, phase}), expected,
      'both reveal modes hide failed native images; only recommendations paint during loading');
  }
}
assert.match(common, /duration: this\.fadeInOnLoad \? 180 : 0/, 'recommendations do not replay a fade inside the entry animation');
for (const name of ['relatedCard', 'relatedTopicModule']) {
  const body = page.match(new RegExp('private ' + name + '\\([\\s\\S]*?\\n  \\}'))[0];
  assert.match(body, /fadeInOnLoad: false/, name + ' participates in the page transition');
  assert.match(body, /loadingActive: this\.videoActive, useSharedDecode: false, viewportOnly: false/,
    'retain native cache and lifecycle admission');
}
assert.match(common, /status !== 1/, 'showing a native image does not report download-ready as decoded');
assert.match(common, /if \(this\.phase === 'failed'\) \{\s*SymbolGlyph/,
  'failed images retain visible localized error feedback');
assert.equal((page.match(/SmartImage\(\{/g) || []).length, 2, 'audit every detail recommendation image host');
assert.equal((page.match(/fadeInOnLoad: false/g) || []).length, 2, 'both recommendation hosts disable the extra fade');

assert.match(model, /images\?: PinImageSources/);
assert.match(api, /images\[size\] = \{ url: candidate\.url \}/);
assert.match(cache, /images: item\.images/);
assert.match(page, /SmartImage\(/);
assert.match(page, /this\.isRecommendReady\(\)/);
assert.match(page, /if \(!this\.isRecommendReady\(\)\)/);
assert.match(page, /if \(!this\.readsReady && !this\.displayedDetail\(\)\.interactionsSettled\)/);
assert.match(page, /recommendationSkeleton/);
assert.match(page, /RecommendAudit: gate/);
assert.match(page, /RecommendAudit: layout/);
assert.match(page, /RecommendAudit: image/);
assert.match(page, /RecommendAudit: pagination\.blocked/);

console.log('recommend image loading: dynamic columns, finite tier decoding with source aspect, Cover, placeholder and live pagination gates OK');
