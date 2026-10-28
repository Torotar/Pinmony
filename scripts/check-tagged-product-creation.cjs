const assert = require('node:assert/strict');
const ts = require(process.argv[2] || 'typescript');
const {createArktsLoader} = require('./arkts-module-loader.cjs');
const loader = createArktsLoader(ts, {
  common_foundation: {PinmonyRuntimeLog: {info() {}, warn() {}}},
  common_network: {PIN_BUSINESS_PIN_READ_ENABLED: true}, common_session: {}, feature_profile: {},
  '@kit.RemoteCommunicationKit': {rcp: {}}, '@kit.BasicServicesKit': {}, '@kit.ArkTS': {util: {}}, '@kit.ImageKit': {image: {}}
});
const {PinmonyPublishNativeFlow: Flow} = loader.loadFile('entry/src/main/ets/app/PinmonyPublishNativeFlow.ets');
const {PinmonyNativeNetwork: Network, acceptsNetworkJob} = loader.loadFile('common_network/src/main/ets/PinmonyNativeNetwork.ets');
const origin = 'https://www.pinterest.com', page = origin + '/sample/', viewer = {id:'42', username:'sample', type:'user'};
const session = {authenticated:true, accountId:'synthetic-account', generation:1, origin, userAgent:'synthetic'};
const flush = () => new Promise(setImmediate);
const reply = (request, data, endpoint) => request.resolve({status:200,error:'',body:JSON.stringify({resource_response:{status:'success',code:0,endpoint_name:endpoint,data},client_context:{user:viewer}})});
async function fixture() {
  const requests = [], store = {publishFlowToken:1, publishFlow:{token:1,page,profile:page,kind:'photo',phase:'products',pins:[],boards:[],selectedIds:[],completed:0,busy:false,loading:true,error:'',feedback:'',hasMore:false,uncertain:false}};
  const network = Object.create(Network.prototype);
  network.cancel = () => {};
  network.request = async (job, current) => {
    assert(acceptsNetworkJob(job,current()),'production transport must accept each generated job');
    const form = new URLSearchParams(job.method === 'GET' ? new URL(job.url).search : job.body);
    return new Promise(resolve => requests.push({job,options:JSON.parse(form.get('data')).options,resolve}));
  };
  const flow = new Flow({store:()=>store,session:()=>session,network:()=>network,active:()=>true,foreground:()=>true,page:()=>page,done:()=>assert.fail('a product does not publish the main Pin')});
  const opening = flow.open();reply(requests.at(-1),viewer);await flush();
  reply(requests.at(-1),{id:'42',comments_disabled:1,shopping_rec_disabled:false},'v3_get_user_settings');assert(await opening);
  let pending = flow.action('findProduct','https://retailer.test/product',false);
  reply(requests.at(-1),{landing_url:'https://retailer.test/product',title:'Product',images:['https://retailer.test/photo.jpg']},'v3_find_products');await pending;
  assert.equal(store.publishFlow.phase,'productImages');assert(!store.publishFlow.productCreated);
  return {flow,store,requests};
}
async function main() {
  const f = await fixture();let pending = f.flow.action('confirmProductImage','',false);
  assert.equal(f.requests.at(-1).options.url,'/v3/visual_links/boards/tagged/');
  const board = {id:'100',type:'board',privacy:'protected',owner:viewer,access:['write']};
  reply(f.requests.at(-1),board,'create_products_tagged_board');await flush();
  assert.deepEqual(f.requests.at(-1).options,{board_id:'100',image_url:'https://retailer.test/photo.jpg',link:'https://retailer.test/product',method:'scraped',scrape_metric:{source:'www_url_scrape'}});
  reply(f.requests.at(-1),{id:'200',type:'pin',board,pinner:viewer,images:{orig:{url:'https://i.pinimg.com/originals/'+'a'.repeat(32)+'.jpg',width:640,height:480}}},'v3_create_pin_handler');await pending;
  assert(f.store.publishFlow.productCreated);assert.equal(f.store.publishFlow.completed,0);assert.equal(f.store.publishFlow.selectedProducts[0].id,'200');
  await f.flow.action('removeProduct','200',false);assert(f.store.publishFlow.productCreated,'removing a tag does not delete the product board Pin');
  const failed = await fixture();pending = failed.flow.action('confirmProductImage','',false);
  reply(failed.requests.at(-1),{...board,owner:{id:'99'}},'create_products_tagged_board');await pending;
  assert(!failed.store.publishFlow.productCreated);assert(failed.store.publishFlow.uncertain);
  const count = failed.requests.length;await failed.flow.action('confirmProductImage','',false);assert.equal(failed.requests.length,count,'unknown creation cannot be replayed');
  console.log('Tagged product creation: actual transport, protected board ownership, confirmed refresh marker, independent main publish count and no replay passed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
