// Manual rollback disables the native settings action; no DOM fallback or write replay.
export const PIN_LOGOUT_API_ENABLED: boolean = true;

interface LogoutData { success: boolean; }
interface LogoutResource { status: string; http_status: number; data: LogoutData; }
interface LogoutResponse { resource_response: LogoutResource; }
interface LogoutOptions { disable_auth_failure_redirect: boolean; }
interface LogoutRequestData { options: LogoutOptions; context: Record<string, string>; }

export function logoutRequestBody(): string {
  const payload: LogoutRequestData = { options: { disable_auth_failure_redirect: true }, context: {} };
  return 'source_url=' + encodeURIComponent('/settings/') + '&data=' +
    encodeURIComponent(JSON.stringify(payload));
}

export function logoutResponseSucceeded(status: number, body: string): boolean {
  if (status !== 200) return false;
  try {
    const response: LogoutResponse = JSON.parse(body) as LogoutResponse;
    return response?.resource_response?.status === 'success' &&
      response.resource_response.http_status === 200 && response.resource_response.data?.success === true;
  } catch (_) { return false; }
}
