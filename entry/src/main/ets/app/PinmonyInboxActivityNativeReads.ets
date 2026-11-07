import { PinmonyI18n } from 'common_foundation';
import { PinmonyInboxItem } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';

interface PinmonyActivityUser { id: string; username: string; full_name?: string; image_large_url?: string; }
interface PinmonyActivityRelationship { relationship_type: number; followed_by_me: boolean; last_action_time: string; user: PinmonyActivityUser; }
interface PinmonyActivityResource { status: string; code?: number; endpoint_name: string; error?: Object; data: Object; }
interface PinmonyActivityBody { resource_response: PinmonyActivityResource; }
interface PinmonyActivityOptions { url: string; data: Record<string,number>; field_sets?: string[]; }
interface PinmonyActivityEnvelope { options: PinmonyActivityOptions; context: Record<string,string>; }
export interface PinmonyInboxActivityPorts {
  session: () => PinmonyBusinessSessionContext;
  network: () => PinmonyNativeNetwork;
  current: () => boolean;
  changed: () => void;
  feedback: (message: string) => void;
}

// Website inbox relationship contract; no automatic write replay or DOM fallback.
export class PinmonyInboxActivityNativeReads {
  rows: PinmonyInboxItem[] = [];
  loading: boolean = false;
  ready: boolean = false;
  error: string = '';
  private revision: number = 0;
  private sequence: number = 0;
  private readonly jobs: Map<string,string> = new Map<string,string>();
  private readonly ports: PinmonyInboxActivityPorts;
  constructor(ports: PinmonyInboxActivityPorts) { this.ports = ports; }
  private state(row: PinmonyInboxItem,busy: boolean,followed: boolean,uncertain: boolean): PinmonyInboxItem {
    return {id:row.id,title:row.title,subtitle:row.subtitle,imageUrl:row.imageUrl,profileUrl:row.profileUrl,
      usernames:row.usernames,enabled:row.enabled,updatedAt:row.updatedAt,activityUserId:row.activityUserId,
      activityBusy:busy,activityFollowed:followed,activityUncertain:uncertain};
  }
  pause(): void {
    this.revision++;
    this.jobs.forEach((id: string): void => this.ports.network().cancel(id)); this.jobs.clear();
    this.loading = false;
    this.rows = this.rows.map((row: PinmonyInboxItem): PinmonyInboxItem => this.state(row,false,!!row.activityFollowed,!!row.activityUncertain || !!row.activityBusy));
  }
  reset(): void { this.pause(); this.rows = []; this.ready = false; this.error = ''; }
  private async request(target: string, current: () => boolean): Promise<PinmonyActivityResource> {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const id: string = 'native_inbox_activity_' + (++this.sequence).toString();
    const data: Record<string,number> = {}; if(!target)data['page_size'] = 20;
    const options: PinmonyActivityOptions = {url: target ? '/v3/users/' + target + '/follow/' : '/v3/social_relationships/inbox/',data:data};
    if(!target)options.field_sets = ['socialrelationship.user()','socialrelationship.relationship_type','socialrelationship.last_action_time','socialrelationship.followed_by_me','user.id','user.full_name','user.image_large_url','user.username'];
    const envelope: PinmonyActivityEnvelope = {options:options,context:{}};
    const encoded: string = 'source_url=' + encodeURIComponent('/inbox/') + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const job: PinmonyNetworkJob = {id:id,epoch:session.generation,page:session.origin + '/inbox/',
      url:session.origin + '/resource/ApiResource/' + (target ? 'update/' : 'get/?' + encoded),
      method:target ? 'POST' : 'GET',body:target ? encoded : '',headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded',
        'X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active','X-Pinterest-Source-Url':'/inbox/','X-Pinterest-Pws-Handler':'www/inbox.js'}};
    const live = (): boolean => current() && this.ports.current() && this.ports.session().authenticated &&
      this.ports.session().accountId === session.accountId && this.ports.session().generation === session.generation && this.ports.session().origin === session.origin;
    this.jobs.set(target || 'read',id);
    try {
      const reply: PinmonyNetworkReply = await this.ports.network().requestBusinessInboxActivity(job,(): PinmonyBusinessSessionContext => this.ports.session(),target,live);
      if(!live() || reply.id !== id || reply.epoch !== job.epoch || reply.page !== job.page || reply.error || reply.status !== 200 || reply.body.length > 4000000)throw new Error('activity-request');
      const resource: PinmonyActivityResource = (JSON.parse(reply.body) as PinmonyActivityBody).resource_response;
      if(resource?.status !== 'success' || resource.code !== undefined && resource.code !== 0 || resource.error ||
        resource.endpoint_name !== (target ? 'v3_follow_user_method' : 'v3_get_inbox_social_relationships'))throw new Error('activity-response');
      return resource;
    } finally { if(this.jobs.get(target || 'read') === id)this.jobs.delete(target || 'read'); }
  }
  async load(force: boolean = false): Promise<void> {
    if(!this.ports.current() || this.loading || this.jobs.size > 0 || this.ready && !force)return;
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.ports.current();
    this.loading = true; this.error = ''; this.ports.changed();
    try {
      const resource: PinmonyActivityResource = await this.request('',live);
      const data: PinmonyActivityRelationship[] = resource.data as PinmonyActivityRelationship[];
      if(!Array.isArray(data) || data.length > 2000)throw new Error('activity-format');
      const rows: PinmonyInboxItem[] = []; const seen: Set<string> = new Set<string>();
      for(const relationship of data) {
        if(relationship.relationship_type !== 8)continue;
        const user: PinmonyActivityUser = relationship.user;
        if(!user || typeof user.id !== 'string' || !/^\d{1,40}$/.test(user.id) || typeof user.username !== 'string' ||
          !/^[A-Za-z0-9_]{1,100}$/.test(user.username) || typeof relationship.followed_by_me !== 'boolean' ||
          typeof relationship.last_action_time !== 'string' || !Number.isFinite(Date.parse(relationship.last_action_time)))throw new Error('activity-row');
        if(seen.has(user.id))continue; seen.add(user.id);
        rows.push({id:'activity:' + user.id,activityUserId:user.id,title:typeof user.full_name === 'string' ? user.full_name.slice(0,500) || user.username : user.username,
          subtitle:PinmonyI18n.message('pm_activity_followed_you'),usernames:[user.username],
          imageUrl:typeof user.image_large_url === 'string' && user.image_large_url.length <= 2048 && /^https:\/\/(?:[A-Za-z0-9-]+\.)*pinimg\.com\//.test(user.image_large_url) ? user.image_large_url : '',
          profileUrl:this.ports.session().origin + '/' + user.username + '/',enabled:true,updatedAt:relationship.last_action_time,
          activityFollowed:relationship.followed_by_me,activityUncertain:false});
      }
      if(live()){this.rows = rows; this.ready = true;}
    } catch (_) { if(live())this.error = PinmonyI18n.message('pm_activity_load_error'); }
    finally { if(revision === this.revision){this.loading = false; if(live())this.ports.changed();} }
  }
  async follow(target: string): Promise<void> {
    const row: PinmonyInboxItem | undefined = this.rows.find((item: PinmonyInboxItem): boolean => item.activityUserId === target);
    if(!this.ports.current() || !row || row.activityFollowed || row.activityBusy || row.activityUncertain || this.loading)return;
    const revision: number = this.revision;
    const live = (): boolean => revision === this.revision && this.ports.current();
    this.rows = this.rows.map((item: PinmonyInboxItem): PinmonyInboxItem => item === row ? this.state(item,true,!!item.activityFollowed,!!item.activityUncertain) : item); this.ports.changed();
    try {
      const resource: PinmonyActivityResource = await this.request(target,live);
      if((resource.data as PinmonyActivityUser)?.id !== target)throw new Error('activity-target');
      if(!live())return;
      this.rows = this.rows.map((item: PinmonyInboxItem): PinmonyInboxItem => item.activityUserId === target ? this.state(item,false,true,false) : item);
      this.ports.feedback(PinmonyI18n.message('pm_activity_follow_success'));
    } catch (_) {
      if(live()) {
        this.rows = this.rows.map((item: PinmonyInboxItem): PinmonyInboxItem => item.activityUserId === target ? this.state(item,false,!!item.activityFollowed,true) : item);
        this.ports.feedback(PinmonyI18n.message('pm_activity_follow_uncertain'));
      }
    } finally { if(live())this.ports.changed(); }
  }
}
