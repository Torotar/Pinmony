import { PinmonyNetworkJob, PinmonyNetworkContext, PinmonyNetworkReply } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
// Business request construction and response validation belong to the profile feature.
// The injected transport retains credentials, request cancellation and admission policy.
type PinmonyProfileAvatarStatusRequest = (job: PinmonyNetworkJob, context: () => PinmonyNetworkContext) => Promise<PinmonyNetworkReply>;
interface ProfileAvatarStatusData { tracking_id: string; }
interface ProfileAvatarStatusOptions { url: string; data: ProfileAvatarStatusData; }
interface ProfileAvatarStatusEnvelope { options: ProfileAvatarStatusOptions; context: Record<string, string>; }
interface ProfileAvatarStatusResponse { resource_response: ProfileAvatarStatusResource; }
interface ProfileAvatarStatusResource { status: string; code: number; endpoint_name: string; data: Record<string, number>; }

export async function readProfileAvatarStatus(tracking: string, page: string, session: () => PinmonyBusinessSessionContext,
      owner: () => boolean, id: string, request: PinmonyProfileAvatarStatusRequest): Promise<number> {
    const state: PinmonyBusinessSessionContext = session();
    const captured: PinmonyBusinessSessionContext = { authenticated: state.authenticated, accountId: state.accountId,
      generation: state.generation, origin: state.origin, userAgent: state.userAgent };
    if (!owner() || !/^[A-Za-z0-9_-]{1,200}$/.test(tracking) ||
        !/^native_profile_avatar_\d+$/.test(id) || !/^https:\/\/(?:www|uk)\.pinterest\.com$/.test(captured.origin) ||
        !page.startsWith(captured.origin + '/') || !/^[A-Za-z0-9_]+\/$/.test(page.slice(captured.origin.length + 1))) throw new Error('avatar-status');
    const options: ProfileAvatarStatusOptions = { url: '/v3/images/upload/status/', data: { tracking_id: tracking } };
    const envelope: ProfileAvatarStatusEnvelope = { options: options, context: {} };
    const form: string = 'source_url=' + encodeURIComponent(page.slice(captured.origin.length)) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const job: PinmonyNetworkJob = { id: id + '_status', epoch: captured.generation, page: page,
      url: captured.origin + '/resource/ApiResource/get/?' + form, method: 'GET', body: '',
      headers: { 'X-Requested-With': 'XMLHttpRequest', 'X-Pinterest-Pws-Handler': 'www/index.js' } };
    const context = (): PinmonyNetworkContext => { const actual: PinmonyBusinessSessionContext = session(); return {
      authenticated: owner() && actual.authenticated && actual.accountId === captured.accountId &&
        actual.generation === captured.generation && actual.origin === captured.origin,
      epoch: actual.generation, page: page, userAgent: actual.userAgent }; };
    const reply: PinmonyNetworkReply = await request(job, context);
    if (!context().authenticated || reply.error || reply.status !== 200) throw new Error('avatar-status');
    const body: ProfileAvatarStatusResponse = JSON.parse(reply.body) as ProfileAvatarStatusResponse;
    const r: ProfileAvatarStatusResource = body.resource_response;
    const status: number | undefined = r?.data?.[tracking];
    if (!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== 'v3_get_image_upload_status' ||
        !Number.isInteger(status) || status! < 0 || status! > 5) throw new Error('avatar-status');
    return status!;
  }
