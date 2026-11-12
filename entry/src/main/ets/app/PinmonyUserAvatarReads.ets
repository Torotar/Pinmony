import { PinmonyAvatarColorSource, PinmonyAvatarColorIdentity, PinmonyAvatarColorListener } from 'common_ui';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';
import { PinmonyBusinessNetwork as PinmonyNativeNetwork } from './PinmonyBusinessNetwork';
import { PinmonyRuntimeLog } from 'common_foundation';
export interface PinmonyUserAvatarReadPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  page: () => string;
  viewerProfile: () => string;
  foreground: () => boolean;
}
interface PinmonyAvatarProfileOptions { username: string; field_set_key: string; }
interface PinmonyAvatarProfileEnvelope { options: PinmonyAvatarProfileOptions; context: Record<string,string>; }
interface PinmonyAvatarUserResponse {
  resource_response?: PinmonyAvatarUserResource;
  client_context?: PinmonyAvatarClientContext;
}
interface PinmonyAvatarClientContext { is_authenticated?: boolean; user?: PinmonyAvatarReadUser; }
interface PinmonyAvatarUserResource { status?: string; code?: number; error?: Object; data?: PinmonyAvatarReadUser; }
interface PinmonyAvatarReadUser { id?: string; type?: string; username?: string; avatar_color_index?: number; }
interface PinmonyAvatarCacheEntry { id: string; color: number; until: number; }
interface PinmonyAvatarWaiter { id: string; changed: PinmonyAvatarColorListener; }
interface PinmonyAvatarReadTask {
  key: string; profile: string; username: string; page: string; owner: string;
  jobId: string; timer: number; running: boolean; done: boolean;
  waiters: Set<PinmonyAvatarWaiter>;
}
export class PinmonyUserAvatarReads {
  private readonly ports: PinmonyUserAvatarReadPorts;
  private owner: string = '';
  private sequence: number = 0;
  private active: number = 0;
  private readonly cache: Map<string,PinmonyAvatarCacheEntry> = new Map<string,PinmonyAvatarCacheEntry>();
  private readonly tasks: Map<string,PinmonyAvatarReadTask> = new Map<string,PinmonyAvatarReadTask>();
  constructor(ports: PinmonyUserAvatarReadPorts) { this.ports = ports; }
  install(): void {
    PinmonyAvatarColorSource.connect((identity: PinmonyAvatarColorIdentity, changed: PinmonyAvatarColorListener): (() => void) => this.read(identity,changed));
  }
  private ownerKey(session: PinmonyBusinessSessionContext): string {
    return session.authenticated && session.accountId ? session.origin + '|' + session.accountId + '|' + session.generation.toString() : '';
  }
  sessionChanged(): void {
    const owner: string = this.ownerKey(this.ports.session());
    if (owner === this.owner) return;
    this.reset(); this.owner = owner; this.resume();
  }
  reset(): void {
    this.owner = ''; this.cache.clear(); this.pause();
  }
  pause(): void {
    this.tasks.forEach((task: PinmonyAvatarReadTask): void => this.finish(task,undefined));
    PinmonyAvatarColorSource.invalidate();
  }
  resume(): void { PinmonyAvatarColorSource.invalidate(true); }
  dispose(): void { this.reset(); PinmonyAvatarColorSource.connect(undefined); }
  private read(identity: PinmonyAvatarColorIdentity, changed: PinmonyAvatarColorListener): () => void {
    const session: PinmonyBusinessSessionContext = this.ports.session(), owner: string = this.ownerKey(session);
    if (!owner || !this.ports.foreground()) return (): void => {};
    if (owner !== this.owner) { this.owner = owner; this.cache.clear(); this.tasks.forEach((task: PinmonyAvatarReadTask): void => this.finish(task,undefined)); }
    const profile: string = identity.profileUrl || (/^[A-Za-z0-9_]+$/.test(identity.username) ? session.origin + '/' + identity.username + '/' : '');
    const route: RegExpMatchArray | null = profile.match(/^https:\/\/(www|uk)\.pinterest\.com\/([A-Za-z0-9_]+)\/$/);
    if (!route || profile.slice(0,profile.indexOf('/',8)) !== session.origin ||
      ['pin','settings','inbox','messages','search','login','signup','business','ideas','today','news_hub','notifications','updates'].includes(route[2].toLowerCase()) ||
      identity.userId && !/^\d{1,40}$/.test(identity.userId)) return (): void => {};
    const key: string = profile.toLowerCase(), cached: PinmonyAvatarCacheEntry | undefined = this.cache.get(key);
    if (cached && cached.until > Date.now() && (!identity.userId || cached.id === identity.userId)) {
      changed(cached.color); return (): void => {};
    }
    const waiter: PinmonyAvatarWaiter = {id:identity.userId,changed:changed};
    let task: PinmonyAvatarReadTask | undefined = this.tasks.get(key);
    if (!task) {
      if (this.tasks.size >= 64) return (): void => {};
      const page: string = this.ports.page();
      if (!page.startsWith(session.origin + '/')) return (): void => {};
      task = {key:key,profile:profile,username:route[2],page:page,owner:owner,
        jobId:'native_avatar_' + (++this.sequence).toString(),timer:-1,running:false,done:false,waiters:new Set<PinmonyAvatarWaiter>()};
      this.tasks.set(key,task);
    }
    const lease: PinmonyAvatarReadTask = task; lease.waiters.add(waiter); this.pump();
    return (): void => { lease.waiters.delete(waiter); if (!lease.waiters.size) { this.finish(lease,undefined); this.pump(); } };
  }
  private current(task: PinmonyAvatarReadTask): boolean {
    return !task.done && this.tasks.get(task.key) === task && this.ports.foreground() &&
      task.owner === this.owner && task.owner === this.ownerKey(this.ports.session()) && this.ports.page() === task.page;
  }
  private pump(): void {
    if (!this.ports.foreground()) return;
    this.tasks.forEach((task: PinmonyAvatarReadTask): void => {
      if (this.active >= 3 || task.running || task.done) return;
      if (!this.current(task)) { this.finish(task,undefined); return; }
      task.running = true; this.active++;
      task.timer = setTimeout((): void => { this.finish(task,undefined); this.pump(); },5000);
      this.perform(task).then((): void => this.pump()).catch((): void => { this.finish(task,undefined); this.pump(); });
    });
  }
  private async perform(task: PinmonyAvatarReadTask): Promise<void> {
    const session: PinmonyBusinessSessionContext = this.ports.session(), path: string = '/' + task.username + '/';
    const envelope: PinmonyAvatarProfileEnvelope = {options:{username:task.username,field_set_key:'profile'},context:{}};
    const job: PinmonyNetworkJob = {id:task.jobId,epoch:session.generation,page:task.page,
      url:session.origin + '/resource/UserResource/get/?source_url=' + encodeURIComponent(path) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      method:'GET',body:'',headers:{'Accept':'application/json','X-Pinterest-AppState':'active','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':'www/index.js','X-Pinterest-Source-Url':path}};
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessUserAvatarRead(job,(): PinmonyBusinessSessionContext => this.ports.session(),task.profile,(): boolean => this.current(task));
      if (!this.current(task)) { this.finish(task,undefined); return; }
      if (reply.error || reply.status !== 200 || reply.body.length > 2000000 || reply.url !== job.url) throw new Error('response');
      const response: PinmonyAvatarUserResponse = JSON.parse(reply.body) as PinmonyAvatarUserResponse;
      const resource: PinmonyAvatarUserResource | undefined = response.resource_response, user: PinmonyAvatarReadUser | undefined = resource?.data;
      const viewer: PinmonyAvatarReadUser | undefined = response.client_context?.user;
      const viewerRoute: RegExpMatchArray | null = this.ports.viewerProfile().match(/^https:\/\/(?:www|uk)\.pinterest\.com\/([A-Za-z0-9_]+)\/$/);
      if (resource?.status !== 'success' || resource.error || resource.code !== undefined && resource.code !== 0 ||
        !user || user.type !== 'user' || !/^\d{1,40}$/.test(user.id || '') || user.username?.toLowerCase() !== task.username.toLowerCase() ||
        response.client_context?.is_authenticated === false || viewer?.id !== undefined && !/^\d{1,40}$/.test(viewer.id) ||
        viewer?.username && (!viewerRoute || viewer.username.toLowerCase() !== viewerRoute[1].toLowerCase())) throw new Error('identity');
      const color: number = Number.isInteger(user.avatar_color_index) && user.avatar_color_index! >= 1 && user.avatar_color_index! <= 10 ? user.avatar_color_index! : 0;
      this.finish(task,{id:user.id!,color:color,until:Date.now() + (color ? 600000 : 30000)});
    } catch (_) { this.finish(task,undefined); }
  }
  private finish(task: PinmonyAvatarReadTask, entry: PinmonyAvatarCacheEntry | undefined): void {
    if (task.done) return;
    const publish: boolean = this.current(task);
    task.done = true; if (task.timer >= 0) clearTimeout(task.timer);
    if (task.running) { this.active = Math.max(0,this.active - 1); this.ports.network().cancel(task.jobId); }
    if (this.tasks.get(task.key) === task) this.tasks.delete(task.key);
    if (publish && entry) {
      this.cache.delete(task.key); this.cache.set(task.key,entry);
      while(this.cache.size > 256) this.cache.delete(this.cache.keys().next().value!);
    }
    PinmonyRuntimeLog.info('AvatarColorTrace: stage=' + (publish && entry ? 'resolved' : 'discarded') + ' colored=' + (!!entry?.color).toString());
    task.waiters.forEach((waiter: PinmonyAvatarWaiter): void => {
      waiter.changed(publish && entry && (!waiter.id || waiter.id === entry.id) ? entry.color : 0);
    });
    task.waiters.clear();
  }
}
