const {runtime}=require('./return-coordinator-harness.cjs');
function create(ts,globals={}){const r=runtime(ts,globals);return r.compile('feature_profile/src/main/ets/controllers/PinmonyProfileActionsController.ets',()=>r.foundation);}
function bind(native,ts,globals={}){const {PinmonyProfileActionsController}=create(ts,globals);native.profileActionsController=new PinmonyProfileActionsController(native.profileStore,{
 authenticated:()=>native.authStatus==='authenticated',foreground:()=>!native.businessSuspended,visible:()=>native.activeTab===3||native.profileStore.origins.length>0,
 document:()=>native.controller.getUrl(),currentProfile:()=>native.currentProfileUrl(),prepare:()=>native.prepareProfileInteraction(),runScript:script=>native.controller.runJavaScript(script),jsonText:raw=>native.webJsonText(raw),feedback:message=>native.showMessage(message),syncMotion:()=>native.syncFloatingTabsMotion?.(),markInteracted:()=>native.rootContentInteracted=true,saved(){}
 });}
module.exports={create,bind};
