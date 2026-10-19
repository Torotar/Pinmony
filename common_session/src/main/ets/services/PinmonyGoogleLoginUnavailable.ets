export const GOOGLE_LOGIN_UNAVAILABLE_EVENT: string = 'PinmonyLogin: google-unavailable';

export function isGoogleLoginTarget(url: string): boolean {
  return /^https:\/\/accounts\.google\.com(?:\/|[?#]|$)/i.test(url);
}

// This is the Google-hosted button frame observed on the Pinterest login page.
// Stop activation before Google's handlers. Never inspect fields or start authentication.
export const PIN_GOOGLE_LOGIN_UNAVAILABLE_SCRIPT: string = `
(function () {
  if (location.protocol !== 'https:' || location.hostname !== 'accounts.google.com' ||
      window === window.top || !/^\\/gsi\\//.test(location.pathname)) return;
  var last = -1000;
  function block(event) {
    if (/^key/.test(event.type) && event.key !== 'Enter' && event.key !== ' ' && event.key !== 'Spacebar') return;
    event.preventDefault(); event.stopImmediatePropagation();
    if (/^(pointerdown|mousedown|touchstart|click|keydown)$/.test(event.type) && Date.now() - last >= 500) {
      last = Date.now();
      try { console.info('PinmonyLogin: google-unavailable'); } catch (_) {}
    }
  }
  ['pointerdown','pointerup','mousedown','mouseup','touchstart','touchend','click','keydown','keyup'].forEach(function (name) {
    window.addEventListener(name, block, { capture: true, passive: false });
  });
})();`;
