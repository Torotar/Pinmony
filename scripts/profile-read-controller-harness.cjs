const {runtime}=require('./return-coordinator-harness.cjs');
function create(ts,globals={}){const r=runtime(ts,globals);return r.compile('feature_profile/src/main/ets/controllers/PinmonyProfileReadController.ets',()=>({...r.foundation,PinmonyRuntimeLog:{info(){},warn(){}}}));}
function bind(native,ts,globals={}){const {PinmonyProfileReadController}=create(ts,globals);native.profileReadController=new PinmonyProfileReadController(native.profileStore,{
 authenticated:()=>native.authStatus==='authenticated',foreground:()=>!native.businessSuspended,document:()=>native.controller.getUrl(),addressKey:a=>native.pageHistory.key(a),
 profileAddress:a=>native.profileUrlFromAddress(a),currentProfile:()=>native.currentProfileUrl(),rootOnly:()=>!!native.nativeRootOnly,interacted:()=>!!native.rootContentInteracted,
 backTarget:()=>native.nativeBackTarget,apiEnabled:()=>true,activeTab:()=>native.activeTab,pendingTab:()=>native.pendingWebTab,rootAddress:()=>native.rootTabAddresses.get(3)||'',
 selectProfile:()=>{native.currentWebTab=3;native.activeTab=3;native.tabsController.changeIndex(3)},confirmPending:()=>native.pendingWebTab=-1,recordAddress:a=>native.rootTabAddresses.set(3,a),
 clearProfile:preserve=>native.clearProfile(preserve),prepareRead:()=>native.prepareRootPageRead(3),requestRead:()=>native.requestRootPage(3),runScript:script=>native.controller.runJavaScript(script)
 });}
module.exports={create,bind};
