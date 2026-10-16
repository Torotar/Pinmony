const { readSourceFileSync } = require('./source-files.cjs');
const assert = require('node:assert/strict');
const path = require('node:path');
const vm = require('node:vm');
const source = readSourceFileSync(path.join(__dirname, '../entry/src/main/ets/services/PinmonyBoardApiScript.ets'), 'utf8');
const script = Function('return `' + source.match(/`([\s\S]*?)`;/)[1] + '`')();
new Function(script);
const flush = () => new Promise(resolve => setImmediate(resolve));
const board = { type: 'board', id: '123', url: '/sample/board/', name: 'Board', pin_count: 2,
  owner: { id: '700', username: 'sample', full_name: 'Sample', image_medium_url: 'https://i.pinimg.com/avatar.jpg' } };
const pin = id => ({ type: 'pin', id, board: { id: '123' }, title: '', images: {
  '474x': { url: 'https://i.pinimg.com/' + id + '.jpg', width: 474, height: 700 } } });
function harness(pathname = '/sample/board/', readyState = 'complete') {
  const requests = [], messages = [];
  let tick;
  const window = { PinmonyBoardApiEnabled: true, addEventListener() {}, setInterval(fn) { tick = fn; },
    PinmonyShareBridge: { boardState(value) { messages.push(JSON.parse(value)); } } };
  window.top = window;
  const location = { origin: 'https://www.pinterest.com', hostname: 'www.pinterest.com', pathname };
  const document = { readyState, getElementById() { throw new Error('DOM initial context must not be read'); } };
  const fetch = (url, options) => new Promise((resolve, reject) => {
    requests.push({ url, options, resolve });
    options.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
  });
  vm.runInNewContext(script, { window, location, URL, AbortController, setTimeout, clearTimeout, document, fetch });
  const respond = async (index, data, bookmark, ok = true, viewerId = '700') => {
    requests[index].resolve({ ok, json: async () => ({ resource_response: { status: 'success', data, bookmark },
      client_context: { user: { id: viewerId } }, resource: { options: { bookmarks: bookmark ? [bookmark] : [] } } }) });
    await flush();
  };
  const state = () => messages.at(-1);
  const call = (method, id) => window.PinmonyBoardApi[method](state().session, state().pageKey, id);
  return { window, location, requests, state, respond, call, tick: () => tick() };
}
async function loadBoard(h, value = board, viewerId = '700', feed = [pin('111')]) {
  await flush();
  assert.equal(h.requests.length, 1);
  assert.equal(new URL(h.requests[0].url, h.location.origin).pathname, '/resource/BoardResource/get/');
  await h.respond(0, value, '', true, viewerId);
  assert.equal(h.requests.length, 2);
  assert.equal(new URL(h.requests[1].url, h.location.origin).pathname, '/resource/BoardFeedResource/get/');
  await h.respond(1, feed, '-end-', true, viewerId);
}

(async()=>{const h=harness();await flush();await h.respond(0,{...board,section_count:1,featured_board_metadata:{board_tag:"-1",curator:{full_name:"Curator",username:"curator",image_medium_url:"https://i.pinimg.com/curator.jpg"}}},"",true,"701");assert.equal(h.requests.length,3);const sec=h.requests.findIndex(r=>r.url.includes("BoardSectionsResource")),feed=h.requests.findIndex(r=>r.url.includes("BoardFeedResource"));await h.respond(sec,[{type:"board_section",id:"456",title:"Section",pin_count:1,preview_pins:[{image_medium_url:"https://i.pinimg.com/preview.jpg"}]}]);await h.respond(feed,[{...pin("111"),title:"Pin title",pinner:{full_name:"Author"},videos:{video_list:{v720P:{duration:47000}}}}],"-end-",true,"701");assert.equal(h.state().ownerName,"Curator");assert.equal(h.state().featuredCreator,false);assert.equal(h.state().pins[0].duration,"0:47");assert.equal(h.state().pins[0].creatorName,"Author");assert.equal(h.state().sections.length,1);h.call("flow",JSON.stringify({action:"section",value:"456"}));await flush();let ix=h.requests.length-1;assert.ok(h.requests[ix].url.includes("BoardSectionPinsResource"));await h.respond(ix,[pin("222")],"next");assert.equal(h.state().flow.pins[0].id,"222");assert.equal(h.state().flow.hasMore,true);h.call("flow",JSON.stringify({action:"sectionMore"}));await flush();ix=h.requests.length-1;h.call("flow",JSON.stringify({action:"close"}));await h.respond(ix,[pin("333")],"-end-");assert.equal(h.state().flow.phase,"");assert.equal(h.state().pins[0].id,"111");h.call('flow',JSON.stringify({action:'sectionsRetry'}));await flush();await h.respond(h.requests.length-1,[]);assert.equal(h.state().sections.length,0,'successful empty section response removes the old section');
for(const tag of [undefined, null, '', '-1', 'not-a-tag', 0]) {
 const empty=harness();await flush();await empty.respond(0,{...board,section_count:0,featured_board_metadata:{board_tag:tag,curator:{full_name:'Curator'}}},'',true,'701');
 assert.equal(empty.requests.length,2,'no sections request when current content says zero sections');
 await empty.respond(1,[pin('111')],'-end-',true,'701');
 assert.equal(empty.state().sections.length,0);assert.equal(empty.state().sectionsError,'');
 assert.equal(empty.state().featuredCreator,tag===0,'curator alone must not enable a content badge');
 }
 for(const sponsored of [true, false, undefined]) {
   const expanded=harness();await flush();
   await expanded.respond(0,{...board,section_count:1,featured_board_metadata:{is_sponsored_content:sponsored,curator:{full_name:'Content provider',username:'provider',verified_identity:{verified:true}}}},'',true,'701');
   const preview={type:'pin',id:'888',title:'Preview title',image_medium_url:'https://i.pinimg.com/medium.jpg',image_medium_size_pixels:{width:236,height:420},image_large_url:'https://i.pinimg.com/large.jpg',image_large_size_pixels:{width:736,height:1310}};
   await expanded.respond(expanded.requests.findIndex(r=>r.url.includes('BoardSectionsResource')),[{type:'board_section',id:'456',title:'Content section',pin_count:2,preview_pins:[preview]}]);
   await expanded.respond(expanded.requests.findIndex(r=>r.url.includes('BoardFeedResource')),[pin('111')],'-end-');
   assert.equal(expanded.state().sponsored,sponsored===true,'sponsor label requires explicit content evidence');
   assert.equal(expanded.state().ownerVerified,true);assert.equal(expanded.state().sectionCount,1);
   const item=expanded.state().sections[0].pins[0];assert.equal(item.title,'Preview title');assert.equal(item.imageUrl,'https://i.pinimg.com/large.jpg');
   assert.equal(expanded.window.PinmonyBoardApi.open(expanded.state().session-1,expanded.state().pageKey,'888'),false);
   assert.equal(expanded.call('open','888'),true,'inline section preview opens current Pin');
   assert.equal(expanded.location.href,'https://www.pinterest.com/pin/888/');
 }
 console.log("Featured content: badges, sponsor/verification evidence, zero sections, inline preview titles/opening, duration and late close response passed");})().catch(e=>{console.error(e);process.exitCode=1;});
