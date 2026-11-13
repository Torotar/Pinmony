// Route state confirmed in the supplied switch-account HAR website modules.
// Install only for an explicit Add Account login, before the website router starts.
export const PIN_ADD_ACCOUNT_LOGIN_SCRIPT: string = `
(function () {
  if (!/^https:\\/\\/(?:www|uk)\\.pinterest\\.com$/.test(location.origin) ||
      !/^\\/login\\/?$/.test(location.pathname) || window.top !== window) return;
  try {
    var current = history.state;
    var state = current && typeof current === 'object' && !Array.isArray(current) ? Object.assign({}, current) : {};
    var previous = state.usr;
    var userState = previous && typeof previous === 'object' && !Array.isArray(previous) ? Object.assign({}, previous) : {};
    userState.switch_account = 'true';
    userState.secondary_account = 'true';
    state.usr = userState;
    history.replaceState(state, '');
  } catch (_) {}
})();
`;
