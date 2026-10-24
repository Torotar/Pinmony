import { PinmonyI18n } from 'common_foundation';
import { PinmonySearchResult } from 'feature_search';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
interface FollowOptions { url: string; }
interface FollowEnvelope { options: FollowOptions; context: Record<string, string>; }
interface FollowData { id: string; type: string; followed_by_me: boolean; }
interface FollowResource { status: string; code: number; endpoint_name: string; data: FollowData | null; }
interface FollowUser { id: string; }
interface FollowContext { user?: FollowUser; }
interface FollowResponse { resource_response?: FollowResource; client_context?: FollowContext; }
interface ConfirmedFollow { following: boolean; expires: number; account: string; generation: number; origin: string; }
export interface PinmonyBoardFollowNativeWritesPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  changed: () => void;
  feedback: (message: string) => void;
  confirmed: (id: string, following: boolean) => void;
}
let followSequence: number = 0;
// Reuses the captured own-profile following contract without navigating the WebView.
export class PinmonyBoardFollowNativeWrites {
  private readonly ports: PinmonyBoardFollowNativeWritesPorts;
  private readonly unknown: Map<string, boolean> = new Map();
  private readonly confirmedStates: Map<string, ConfirmedFollow> = new Map();
  private job: string = '';
  private board: string = '';
  private release: (() => void) | undefined = undefined;
  constructor(ports: PinmonyBoardFollowNativeWritesPorts) { this.ports = ports; }
  pending(): boolean { return !!this.job; }
  busy(id: string): boolean { return !!this.job && this.board === id; }
  locked(id: string): boolean { return this.unknown.has(id); }
  reconcile(id: string, following: boolean): void {
    if (!this.busy(id) && this.unknown.get(id) === following) this.unknown.delete(id);
  }
  readFollowing(id: string, following: boolean | undefined): boolean | undefined {
    const confirmed: ConfirmedFollow | undefined = this.confirmedStates.get(id);
    if (!confirmed) return following;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if (!session.authenticated || session.accountId !== confirmed.account || session.generation !== confirmed.generation ||
      session.origin !== confirmed.origin || Date.now() >= confirmed.expires || following === confirmed.following) {
      this.confirmedStates.delete(id); return following;
    }
    return confirmed.following;
  }
  pause(): void {
    if (this.job) this.ports.network().cancel(this.job);
    this.job = ''; this.board = ''; this.release?.(); this.release = undefined;
  }
  reset(): void { this.pause(); this.unknown.clear(); this.confirmedStates.clear(); }
  async submit(item: PinmonySearchResult, viewer: string, owner: () => boolean): Promise<void> {
    const session: PinmonyBusinessSessionContext = this.ports.session(), profile: string = item.targetUrl;
    const id: string = item.boardId || '';
    if (!owner() || this.job || this.locked(id) || item.kind !== 'board' || typeof item.following !== 'boolean' ||
        !/^\d{1,40}$/.test(id) || !/^\d{1,40}$/.test(viewer) || !session.authenticated ||
        !profile.startsWith(session.origin + '/') || !/^\/[A-Za-z0-9_]+\/[^/?#]+\/$/.test(profile.slice(session.origin.length))) return;
    const desired: boolean = !item.following, source: string = profile.slice(session.origin.length);
    const envelope: FollowEnvelope = {options:{url:'/v3/boards/' + id + '/follow/'},context:{}};
    const job: PinmonyNetworkJob = {id:'native_board_follow_' + (++followSequence).toString(),
      epoch:session.generation,page:profile,url:session.origin + '/resource/ApiResource/' + (desired ? 'update' : 'delete') + '/',
      method:'POST',body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','X-Pinterest-AppState':'active','Content-Type':'application/x-www-form-urlencoded',
        'X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/[username]/[slug].js','X-Pinterest-Source-Url':source}};
    if (session.appVersion) job.headers['X-App-Version'] = session.appVersion;
    this.job = job.id; this.board = id; this.unknown.set(id, desired); this.ports.changed();
    const current = (): boolean => {
      const actual: PinmonyBusinessSessionContext = this.ports.session();
      return this.job === job.id && owner() && actual.authenticated &&
        actual.accountId === session.accountId && actual.generation === session.generation && actual.origin === session.origin;
    };
    const stopped: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => { this.release = (): void => resolve(undefined); });
    try {
      const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessBoardFollow(job,
        (): PinmonyBusinessSessionContext => this.ports.session(),profile,id,viewer,current),stopped]);
      if (!current()) return;
      if (!reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 2000000) throw new Error('unknown');
      const response: FollowResponse = JSON.parse(reply.body) as FollowResponse, r: FollowResource | undefined = response.resource_response;
      if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0) {
        this.unknown.delete(id); this.ports.feedback(PinmonyI18n.message("pm_the_website_rejected_this_board_follow_action_you_can_retry_768968ce")); return;
      }
      if (!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== (desired ? 'v3_follow_board' : 'v3_unfollow_board') ||
          response.client_context?.user && response.client_context.user.id !== viewer ||
          (desired ? !r.data || r.data.id !== id || r.data.type !== 'board' || r.data.followed_by_me !== true : r.data !== null)) throw new Error('unknown');
      this.unknown.delete(id);
      this.confirmedStates.delete(id);
      if (this.confirmedStates.size >= 100) this.confirmedStates.clear();
      this.confirmedStates.set(id,{following:desired,expires:Date.now() + 15000,account:session.accountId,generation:session.generation,origin:session.origin});
      this.ports.confirmed(id,desired); this.ports.feedback(desired ? PinmonyI18n.message("pm_board_followed_99719d35") : PinmonyI18n.message("pm_board_unfollowed_b3151db9"));
    } catch (_) { if (current()) this.ports.feedback(PinmonyI18n.message("pm_board_follow_result_not_confirmed_refresh_to_check_before_submit_b77726df")); }
    finally { if (this.job === job.id) { this.job = ''; this.board = ''; this.release = undefined; this.ports.changed(); } }
  }
}
