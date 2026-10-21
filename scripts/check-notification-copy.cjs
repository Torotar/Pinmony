const assert=require('node:assert/strict'),fs=require('node:fs'),ts=require(process.argv[2]);
const {createArktsLoader}=require('./arkts-module-loader.cjs');
const resources=Object.fromEntries(['base','en_US'].map(locale=>[locale,Object.fromEntries(JSON.parse(fs.readFileSync(`common_foundation/src/main/resources/${locale}/element/string.json`,'utf8')).string.map(r=>[r.name,r.value]))]));
const loader=createArktsLoader(ts,{common_foundation:{PinmonyI18n:{text:(key,language)=>resources[language==='en'?'en_US':'base'][key]??key}}});
const {PinmonyNotificationCopy:copy}=loader.loadFile('feature_settings/src/main/ets/models/PinmonyNotificationCopy.ets');
const source=fs.readFileSync('feature_settings/src/main/ets/models/PinmonyNotificationCopy.ets','utf8');
const map=JSON.parse(source.match(/const CATEGORY_COPY[^=]*= (\{[\s\S]*?\});/)[1]);
for(const option of Object.keys(map)){
 const category={key:option,label:'网站中文标题',description:'网站中文说明',channels:[{channel:'push',option,value:true}]};
 for(const method of ['category','description']){const en=copy[method](category,'en'),zh=copy[method](category,'zh');assert(!/[\u3400-\u9fff]/.test(en),option+' '+method);assert(!en.startsWith('pm_'));assert(/[\u3400-\u9fff]/.test(zh));}
}
for(const key of ['pins-you-created','pins-you-saved','social','recommendations','others','permissions','permissions-biz'])assert(!/[\u3400-\u9fff]/.test(copy.group({key,label:'网站中文标题',categories:[]},'en')));
const global={key:'global',label:'如何接收通知',description:'重要通知',channels:[]};assert.equal(copy.category(global,'en'),'How you get notifications');assert(!/[\u3400-\u9fff]/.test(copy.description(global,'en')));
const unknown={key:'custom',label:'用户原文',description:'未知网站文案',channels:[]};assert.equal(copy.category(unknown,'en'),'用户原文');assert.equal(copy.description(unknown,'en'),'未知网站文案');
const page=fs.readFileSync('feature_settings/src/main/ets/components/PinmonyNotificationsPage.ets','utf8');assert(!page.includes("this.uiText('pm_notify_how')"));
console.log('Notification copy: all 25 titles/descriptions, group/global titles, language reversal and unknown website text boundary passed');

// Screenshot regression: actual keys and channel fields observed in the notification HAR.
const shuffles={key:'shuffles_activity',label:'Shuffles 动态',description:'获取关于 Shuffles 动态的更新',summary:'',channels:[{label:'电子邮件',channel:'email',section:'settings_email_v2',option:'shuffles_activity',value:true}]};
assert.equal(copy.description(shuffles,'en'),'Get updates about activity on Shuffles');
assert.equal(copy.description(shuffles,'zh'),'获取关于 Shuffles 动态的更新');
const delivery={key:'permissions',label:'如何接收通知',categories:[{key:'global',label:'如何接收通知',description:'Pinterest 会持续向你发送关于你帐户的重要更新',summary:'',channels:[{label:'推送',channel:'push',section:'settings_push_everything',option:'NO_PUSH',value:true}]}]};
assert.equal(copy.group(delivery,'en'),'How you get notifications');
assert.equal(copy.category(delivery.categories[0],'en'),'How you get notifications');
assert.equal(copy.description(delivery.categories[0],'en'),'Pinterest will still send you important updates about your account');
assert.equal(copy.channel(delivery.categories[0].channels[0],'en'),'Push');
console.log('Screenshot regression: Shuffles expanded description and delivery group/category/description/channel passed');
