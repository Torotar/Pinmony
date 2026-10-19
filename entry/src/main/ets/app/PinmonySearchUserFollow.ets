import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchResult } from 'feature_search';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
interface FollowOptions { url: string; data?: Record<string, string>; }
interface FollowEnvelope { options: FollowOptions; context: Record<string, string>; }
interface FollowData { id: string; type: string; username: string; }
interface FollowResource { status: string; code: number; endpoint_name: string; data: FollowData | null; }
interface FollowUser { id: string; }
interface FollowContext { user?: FollowUser; }
interface FollowResponse { resource_response?: FollowResource; client_context?: FollowContext; }
export interface PinmonySearchUserFollowPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  changed: () => void;
  feedback: (message: string) => void;
  confirmed: (id: string, following: boolean) => void;
}
let followSequence: number = 0;
// Captured target-profile ApiResource contract; never navigate the hidden WebView.
export class PinmonySearchUserFollow {
  private readonly ports: PinmonySearchUserFollowPorts;
  private readonly unknown: Map<string, boolean> = new Map();
  private job: string = '';
  private targetId: string = '';
  private release: (() => void) | undefined = undefined;
  constructor(ports: PinmonySearchUserFollowPorts) { this.ports = ports; }
  pending(): boolean { return !!this.job; }
  busy(id: string): boolean { return !!this.job && this.targetId === id; }
  locked(id: string): boolean { return this.unknown.has(id); }
  reconcile(id: string, following: boolean): void {
    if (!this.busy(id) && this.unknown.get(id) === following) this.unknown.delete(id);
  }
  pause(): void {
    if (this.job) this.ports.network().cancel(this.job);
    this.job = ''; this.targetId = ''; this.release?.(); this.release = undefined;
  }
  reset(): void { this.pause(); this.unknown.clear(); }
  async submit(item: PinmonySearchResult, viewer: string, owner: () => boolean): Promise<void> {
    const session: PinmonyBusinessSessionContext = this.ports.session(), profile: string = item.targetUrl;
    const id: string = item.userId || '';
    if (!owner() || this.job || this.locked(id) || item.kind !== 'user' || typeof item.following !== 'boolean' ||
        item.blocked === true || id === viewer || !/^\d{1,40}$/.test(id) || !/^\d{1,40}$/.test(viewer) || !session.authenticated ||
        !profile.startsWith(session.origin + '/') || !/^\/[A-Za-z0-9_]+\/$/.test(profile.slice(session.origin.length))) return;
    const desired: boolean = !item.following, source: string = profile.slice(session.origin.length);
    const envelope: FollowEnvelope = {options:{url:'/v3/users/' + id + '/follow/'},context:{}};
    if (desired) envelope.options.data = {};
    const job: PinmonyNetworkJob = {id:'native_search_user_follow_' + (++followSequence).toString(),
      epoch:session.generation,page:profile,url:session.origin + '/resource/ApiResource/' + (desired ? 'update' : 'delete') + '/',
      method:'POST',body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','X-Pinterest-AppState':'active','Content-Type':'application/x-www-form-urlencoded',
        'X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/[username].js','X-Pinterest-Source-Url':source}};
    if (session.appVersion) job.headers['X-App-Version'] = session.appVersion;
    this.job = job.id; this.targetId = id; this.unknown.set(id, desired); this.ports.changed();
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session();
      return this.job === job.id && owner() && actual.authenticated &&
        actual.accountId === session.accountId && actual.generation === session.generation && actual.origin === session.origin;
    };
    const stopped: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => { this.release = (): void => resolve(undefined); });
    try {
      const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessSearchUserFollow(job,
        (): PinmonyBusinessSessionContext => this.ports.session(),profile,id,viewer,current),stopped]);
      if (!current()) return;
      if (!reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 2000000) throw new Error('unknown');
      const response: FollowResponse = JSON.parse(reply.body) as FollowResponse, r: FollowResource | undefined = response.resource_response;
      if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0) {
        this.unknown.delete(id); this.ports.feedback(PinmonyI18n.message("pm_the_website_rejected_this_follow_action_you_can_retry_d6d60818")); return;
      }
      if (!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== (desired ? 'v3_follow_user_method' : 'v3_unfollow_user_method') ||
          response.client_context?.user && response.client_context.user.id !== viewer ||
          (!r.data || r.data.id !== id || r.data.type !== 'user' || r.data.username !== profile.slice(session.origin.length).split('/')[1])) throw new Error('unknown');
      this.unknown.delete(id); this.ports.confirmed(id,desired); this.ports.feedback(desired ? '已关注用户' : PinmonyI18n.message("pm_profile_unfollowed_ecb7bb9d"));
    } catch (_) { if (current()) this.ports.feedback(PinmonyI18n.message("pm_profile_follow_result_not_confirmed_refresh_to_check_before_subm_1218b98b")); }
    finally { if (this.job === job.id) { this.job = ''; this.targetId = ''; this.release = undefined; this.ports.changed(); } }
  }
}
