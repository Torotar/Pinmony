const fs = require('fs');
const assert = require('assert');

const common = fs.readFileSync('common_ui/src/main/ets/components/SmartImage.ets', 'utf8');
const page = fs.readFileSync('feature_pin/src/main/ets/components/PinWebDetailPage.ets', 'utf8');
const model = fs.readFileSync('feature_pin/src/main/ets/models/PinWebDetail.ets', 'utf8');
const api = fs.readFileSync('feature_pin/src/main/ets/services/PinWebDetailApiScript.ets', 'utf8');
const cache = fs.readFileSync('feature_pin/src/main/ets/services/PinWebDetailCache.ets', 'utf8');

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
assert.match(common, /\.opacity\(this\.phase === 'loaded' \? 1 : 0\)/);

assert.match(model, /images\?: PinImageSources/);
assert.match(api, /images\[size\] = \{ url: candidate\.url \}/);
assert.match(cache, /images: item\.images/);
assert.match(page, /SmartImage\(/);
assert.match(page, /this\.isRecommendReady\(\)/);
assert.match(page, /if \(!this\.isRecommendReady\(\)\)/);
assert.match(page, /if \(!this\.detail\.interactionsSettled\)/);
assert.match(page, /recommendationSkeleton/);
assert.match(page, /RecommendAudit: gate/);
assert.match(page, /RecommendAudit: layout/);
assert.match(page, /RecommendAudit: image/);
assert.match(page, /RecommendAudit: pagination\.blocked/);

console.log('recommend image loading: dynamic columns, finite tier decoding with source aspect, Cover, placeholder and live pagination gates OK');
