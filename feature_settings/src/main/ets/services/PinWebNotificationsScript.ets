export const PIN_NOTIFICATIONS_READ_SCRIPT: string = `
(function(){
  var page = location.href, token = window.PinWebNotificationsToken = (window.PinWebNotificationsToken || 0) + 1;
  window.PinWebNotificationsResult = null;
  var query = new URLSearchParams({source_url:location.pathname,data:JSON.stringify({options:{url:'/v3/settings/notifications/'},context:{}})});
  fetch('/resource/ApiResource/get/?'+query,{credentials:'same-origin',headers:{Accept:'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js'}})
    .then(function(r){if(!r.ok) throw new Error('HTTP '+r.status);return r.json();})
    .then(function(body){var r=body.resource_response;
      if(!r || r.status!=='success' || r.code!==undefined && r.code!==0 || r.error || r.endpoint_name!=='v3_get_settings_all_notifications' || !Array.isArray(r.data)) throw new Error('通知设置响应无效');
      var groups=r.data.slice(0,40).map(function(g){
        if(g.type!=='notification_settings_group' || typeof g.label!=='string' || !Array.isArray(g.subcategories)) throw new Error('通知分组格式无效');
        return {key:String(g.key).slice(0,100),label:g.label.slice(0,200),categories:g.subcategories.slice(0,60).map(function(c){
          if(typeof c.label!=='string' || !Array.isArray(c.channel_options)) throw new Error('通知选项格式无效');
          return {key:String(c.key).slice(0,100),label:c.label.slice(0,200),description:String(c.description||'').slice(0,500),summary:String(c.channel_options_label||'').slice(0,500),channels:c.channel_options.slice(0,10).map(function(o){if(typeof o.label!=='string'||typeof o.value!=='boolean')throw new Error('通知渠道格式无效');return {label:o.label.slice(0,100),value:o.value};})};
        })};
      });
      if(location.href===page && token===window.PinWebNotificationsToken)window.PinWebNotificationsResult={groups:groups,error:''};
    }).catch(function(){if(location.href===page && token===window.PinWebNotificationsToken)window.PinWebNotificationsResult={groups:[],error:'通知设置读取失败，请重试'};});
})();`;
