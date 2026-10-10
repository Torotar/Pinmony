export type PinmonyAuthStatus = 'checking' | 'unauthenticated' | 'authenticated' | 'error';

// No password, Cookie or token crosses the bridge. Epoch belongs to the current document.
export interface PinmonyAuthMessage {
  status: string;
  pageUrl: string;
  epoch: number;
  profileUrl: string;
}

export function isPinterestAuthRoute(url: string): boolean {
  return /^https:\/\/(?:[^/]+\.)?pinterest\.com\/(?:login|signup|logout|auth|oauth)(?:\/|[?#]|$)/i.test(url);
}

export function acceptsAuthMessage(message: PinmonyAuthMessage, currentUrl: string, epoch: number): boolean {
  return !!message && (message.status === 'authenticated' || message.status === 'unauthenticated') &&
    message.epoch === epoch && /^https:\/\/(?:[^/]+\.)?pinterest\.com\//i.test(message.pageUrl) &&
    message.pageUrl.split('#')[0] === currentUrl.split('#')[0];
}
