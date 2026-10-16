// Board sharing uses the existing resource-backed ProfilePanel contract only.
export const PIN_BOARD_SHARE_BRIDGE_SCRIPT: string = `
(function () {
  if (window !== window.top) return;
  var active = true, page = '', address = '', session = 0;
  function current(token) {
    return active && !!page && token === session && address === location.href &&
      window.PinmonyProfilePanel && window.PinmonyProfilePanel.shareCurrent(page);
  }
  function notify(state) {
    if (!active || address !== location.href || state.session !== session) return;
    try { if (window.PinmonyShareBridge && window.PinmonyShareBridge.sheetState)
      window.PinmonyShareBridge.sheetState(JSON.stringify(state)); } catch (_) {}
  }
  window.PinmonyNativeShareApiOpen = function (target) {
    if(window.PinmonyNativeSharePublishEnabled === true)return false;
    if (!active || page || !window.PinmonyBoardApi || !window.PinmonyBoardApi.shareInfo(target) ||
        !window.PinmonyProfilePanel) return false;
    page = target; address = location.href; session++;
    if (window.PinmonyProfilePanel.shareOpen(page, session, notify)) return true;
    page = ''; return false;
  };
  window.PinmonyNativeShareSearch = function (token, query) {
    return current(token) && window.PinmonyProfilePanel.shareSearch(page, token, query, notify);
  };
  window.PinmonyNativeShareAction = function (token, id) {
    return current(token) && window.PinmonyProfilePanel.shareContact(page, token, id, notify);
  };
  window.PinmonyNativeShareRefresh = function (token) {
    return current(token) && window.PinmonyProfilePanel.shareOpen(page, token, notify);
  };
  window.PinmonyNativeShareClose = function (token) {
    if (!page || token !== session) return false;
    page = ''; window.PinmonyProfilePanel && window.PinmonyProfilePanel.shareClose();
    notify({ kind: 'closed', session: session }); return true;
  };
  window.addEventListener('pagehide', function () {
    active = false; page = ''; session++;
    window.PinmonyProfilePanel && window.PinmonyProfilePanel.shareClose();
  });
  window.addEventListener('pageshow', function () { active = true; });
})();`;
