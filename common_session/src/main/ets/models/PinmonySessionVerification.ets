export type PinmonySessionVerificationStatus = 'authenticated' | 'unauthenticated' | 'unknown';

export interface PinmonySessionVerificationResult {
  status: PinmonySessionVerificationStatus;
  profileUrl: string;
  appVersion: string;
}

interface VerificationUser { id?: string; username?: string; }
interface VerificationContext {
  is_authenticated?: boolean;
  user?: VerificationUser;
  app_version?: string;
}
interface VerificationSettings { id?: string; username?: string; type?: string; }
interface VerificationResource {
  status?: string;
  code?: number;
  error?: Object;
  endpoint_name?: string;
  data?: VerificationSettings;
}
interface VerificationResponse {
  client_context?: VerificationContext;
  resource_response?: VerificationResource;
}

// Only the captured settings response proves this read's identity. HTTP status,
// Cookie presence and a public profile response alone are never authentication.
export function parseSessionVerification(origin: string, status: number, text: string): PinmonySessionVerificationResult {
  const unknown: PinmonySessionVerificationResult = { status: 'unknown', profileUrl: '', appVersion: '' };
  if (!/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(origin) || status !== 200 || text.length > 1048576) return unknown;
  try {
    const body: VerificationResponse = JSON.parse(text) as VerificationResponse;
    const c: VerificationContext | undefined = body?.client_context;
    const r: VerificationResource | undefined = body?.resource_response;
    if (!c || !r || typeof c.is_authenticated !== 'boolean') return unknown;
    if (c.is_authenticated === false) {
      if (c.user?.id && c.user.id !== '0') return unknown;
      return { status: 'unauthenticated', profileUrl: '', appVersion: '' };
    }
    const user: VerificationUser | undefined = c.user;
    const data: VerificationSettings | undefined = r.data;
    if (r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_get_user_settings' ||
        !user || typeof user.id !== 'string' || !/^[1-9]\d{0,39}$/.test(user.id) ||
        typeof user.username !== 'string' || !/^[A-Za-z0-9_]{1,100}$/.test(user.username) ||
        !data || data.type !== 'user_settings' || data.id !== user.id || data.username !== user.username) return unknown;
    const version: string = typeof c.app_version === 'string' && /^[A-Za-z0-9._-]{1,80}$/.test(c.app_version) ? c.app_version : '';
    return { status: 'authenticated', profileUrl: origin + '/' + user.username + '/', appVersion: version };
  } catch (_) { return unknown; }
}
