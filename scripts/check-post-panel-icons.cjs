const assert = require('node:assert/strict');
const fs = require('node:fs');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const icon = fs.readFileSync('common_ui/src/main/resources/base/media/copy_link.svg', 'utf8');
assert(index.includes("this.isCopyLinkAction(option.label)"));
assert(index.includes("$r('app.media.copy_link')"));
assert(index.includes("this.activeSheetKind === 'more' ? '选项'"));
assert(icon.includes('stroke="#fff"'));
console.log('Post panel icons: InspiFol copy-link asset and options title are wired');
