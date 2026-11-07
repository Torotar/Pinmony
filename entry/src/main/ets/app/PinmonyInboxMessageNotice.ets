import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent, Want } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { PinmonyInboxNoticeAvatar } from './PinmonyInboxNoticeAvatar';
import { PinmonyInboxNoticeTap } from './PinmonyInboxNoticeTap';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';

interface PinmonyNoticeUser { id: string; username?: string; full_name?: string; image_small_url?: string; image_medium_url?: string; image_large_url?: string; }
interface PinmonyNoticeMessage {
  id: string; created_at?: string; text?: string; sender?: PinmonyNoticeUser; deleted_by?: Object;
  pin?: Object; board?: Object; user?: Object;
}
export interface PinmonyInboxNoticeConversation {
  id: string; unread?: boolean | number; name?: string; users?: PinmonyNoticeUser[]; last_message?: PinmonyNoticeMessage;
}
interface PinmonyNoticeSeen { id: string; time: number; recent: string[]; }
export interface PinmonyInboxMessageNoticePorts {
  openChat?: (conversation: string) => boolean;
  session: () => PinmonyBusinessSessionContext;
  active: () => boolean;
  username: () => string;
  visibleConversation: () => string;
  context: () => common.UIAbilityContext;
}

// Receives only already validated foreground reads. No polling, credentials or persistence.
export class PinmonyInboxMessageNotice {
  private readonly avatar: PinmonyInboxNoticeAvatar = new PinmonyInboxNoticeAvatar();
  private tapToken: string = '';
  private tapConversation: string = '';
  private tapIdentity: string = '';
  private pendingTap: boolean = false;
  private pendingConversation: string = '';
  private pendingIdentity: string = '';
  private delivery: number = 0;
  private readonly ports: PinmonyInboxMessageNoticePorts;
  private readonly seen: Map<string, PinmonyNoticeSeen> = new Map<string, PinmonyNoticeSeen>();
  private identity: string = '';
  private baseline: boolean = false;
  private baselineAt: number = 0;
  private revision: number = 0;
  private permissionAttempted: boolean = false;
  private queue: Promise<void> = Promise.resolve();
  private readonly noticeId: number = 7201;
  constructor(ports: PinmonyInboxMessageNoticePorts) {
    this.ports = ports;
    PinmonyInboxNoticeTap.bind((token: string): void => {
      if(token === this.tapToken && token.length > 0) {
        this.pendingTap = true; this.pendingConversation = this.tapConversation; this.pendingIdentity = this.tapIdentity;
        this.tapToken = ''; this.avatar.cancel(); this.delivery++;
        this.consumeTap();
      }
    });
  }
  static handleWant(want: Want): void {
    PinmonyInboxNoticeTap.receive(want);
  }
  consumeTap(): void {
    if(!this.pendingTap || !this.ports.active())return;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    const identity: string = session.accountId + '|' + session.generation.toString() + '|' + session.origin;
    if(!session.authenticated || identity !== this.pendingIdentity) { this.pendingTap = false; this.pendingConversation = ''; this.pendingIdentity = ''; return; }
    if(this.ports.openChat?.(this.pendingConversation)) {
      this.pendingTap = false; this.pendingConversation = ''; this.pendingIdentity = '';
    }
  }
  pause(): void { this.revision++; this.avatar.cancel(); }
  private clean(value: string | undefined): string { return typeof value === 'string' ? value.trim() : ''; }

  reset(): void {
    this.avatar.cancel(); this.delivery++; this.pendingTap = false; this.pendingConversation = ''; this.pendingIdentity = '';
    this.tapToken = ''; this.tapConversation = ''; this.tapIdentity = '';
    this.revision++; this.identity = ''; this.baseline = false; this.baselineAt = 0; this.seen.clear();
    // Serialized with publishing so an old account cannot cancel a new account's notice.
    this.queue = this.queue.then(async (): Promise<void> => {
      try { await notificationManager.cancel(this.noticeId); } catch (_) { /* No active notification. */ }
    }).catch((): void => {});
  }
  private current(identity: string, revision: number): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return this.ports.active() && session.authenticated && revision === this.revision &&
      identity === session.accountId + '|' + session.generation.toString() + '|' + session.origin;
  }
  observe(rows: PinmonyInboxNoticeConversation[]): void {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(!this.ports.active() || !session.authenticated || !session.accountId)return;
    const identity: string = session.accountId + '|' + session.generation.toString() + '|' + session.origin;
    if(identity !== this.identity) { this.reset(); this.identity = identity; }
    const first: boolean = !this.baseline;
    const revision: number = this.revision;
    const username: string = this.ports.username().toLowerCase();
    for(const row of rows) {
      if(!row)continue;
      const message: PinmonyNoticeMessage | undefined = row.last_message;
      if(!row || typeof row.id !== 'string' || !/^\d{1,40}$/.test(row.id) || !message ||
        typeof message.id !== 'string' || !/^\d{1,40}$/.test(message.id))continue;
      const time: number = Date.parse(this.clean(message.created_at));
      if(!Number.isFinite(time) || time > Date.now() + 60000)continue;
      const previous: PinmonyNoticeSeen | undefined = this.seen.get(row.id);
      if(previous && (previous.recent.includes(message.id) || time < previous.time))continue;
      if(!previous && this.seen.size >= 4000)continue;
      this.seen.set(row.id, {id:message.id, time:time, recent:previous ? previous.recent.concat(message.id).slice(-16) : [message.id]});
      const sender: PinmonyNoticeUser | undefined = message.sender;
      if(!sender || typeof sender.id !== 'string' || !/^\d{1,40}$/.test(sender.id))continue;
      const known: PinmonyNoticeUser | undefined = Array.isArray(row.users) ? row.users.find((user: PinmonyNoticeUser): boolean => !!user && user.id === sender.id) : undefined;
      const own: boolean = sender.id === session.accountId || !!username &&
        (this.clean(sender.username).toLowerCase() === username || this.clean(known?.username).toLowerCase() === username);
      if(first || !previous && time < this.baselineAt || own || message.deleted_by ||
        !(row.unread === true || typeof row.unread === 'number' && row.unread > 0) ||
        row.id === this.ports.visibleConversation())continue;
      const title: string = (this.clean(sender.full_name) || this.clean(known?.full_name) || this.clean(sender.username) || this.clean(known?.username)).slice(0,200);
      if(!title)continue;
      // Resolve app-owned fallback text when actually publishing, using the current language.
      const text: string = typeof message.text === 'string' ? message.text.trim().slice(0,1000) : '';
      const fallback: string = message.user ? 'pm_sent_a_profile_e003c0d2' : message.board ? 'pm_sent_a_board_8870ec6d' :
        message.pin ? 'pm_sent_a_pin_b874b586' : 'pm_new_message_3fc957bf';
      const avatarUrl: string = this.clean(sender.image_small_url) || this.clean(known?.image_small_url) ||
        this.clean(sender.image_medium_url) || this.clean(known?.image_medium_url) || this.clean(sender.image_large_url) || this.clean(known?.image_large_url);
      this.queue = this.queue.then((): Promise<void> => this.publish(identity,revision,row.id,title,text,fallback,time,avatarUrl)).catch((): void => {
        PinmonyRuntimeLog.warn('InboxNoticeTrace: delivery failed');
      });
    }
    if(first)this.baselineAt = Date.now();
    this.baseline = true;
  }
  private async publish(identity: string, revision: number, conversation: string, title: string, text: string, fallback: string, time: number, avatarUrl: string): Promise<void> {
    try {
      if(!this.current(identity,revision) || conversation === this.ports.visibleConversation())return;
      const context: common.UIAbilityContext = this.ports.context();
      let enabled: boolean = await notificationManager.isNotificationEnabled();
      if(!this.current(identity,revision))return;
      if(!enabled && !this.permissionAttempted) {
        this.permissionAttempted = true;
        try { await notificationManager.requestEnableNotification(context); } catch (_) { /* Respect denial. */ }
        enabled = await notificationManager.isNotificationEnabled();
      }
      if(!enabled || !this.current(identity,revision))return;
      const token: string = Date.now().toString(36) + '-' + (++this.delivery).toString(36) + '-' + Math.random().toString(36).slice(2);
      const delivery: number = this.delivery;
      const agent: WantAgent = await wantAgent.getWantAgent({
        wants:[{bundleName:context.applicationInfo.name,abilityName:'EntryAbility',parameters:{pinmonyMessageNotice:token}}],
        actionType:wantAgent.OperationType.START_ABILITY,requestCode:this.noticeId,
        actionFlags:[wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      if(!this.current(identity,revision) || conversation === this.ports.visibleConversation())return;
      const request: notificationManager.NotificationRequest = {
        id:this.noticeId, notificationSlotType:notificationManager.SlotType.SOCIAL_COMMUNICATION,
        deliveryTime:time, tapDismissed:true, wantAgent:agent,
        content:{notificationContentType:notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal:{title:title,text:text || PinmonyI18n.message(fallback)}}
      };
      await notificationManager.publish(request);
      if(!this.current(identity,revision)) {
        try { await notificationManager.cancel(this.noticeId); } catch (_) { /* Already dismissed. */ }
        return;
      }
      this.tapToken = token; this.tapConversation = conversation; this.tapIdentity = identity;
      this.updateAvatar(avatarUrl,identity,revision,delivery,request).catch((): void => {});
      PinmonyRuntimeLog.info('InboxNoticeTrace: published');
    } catch (_) { PinmonyRuntimeLog.warn('InboxNoticeTrace: delivery failed'); }
  }
  private async updateAvatar(url: string, identity: string, revision: number, delivery: number, request: notificationManager.NotificationRequest): Promise<void> {
    const current = (): boolean => this.current(identity,revision) && delivery === this.delivery;
    const pixels: image.PixelMap | undefined = await this.avatar.read(url,current);
    if(!pixels)return;
    this.queue = this.queue.then(async (): Promise<void> => {
      try {
        if(!current())return;
        request.largeIcon = pixels; request.isAlertOnce = true;
        await notificationManager.publish(request);
        if(!current())try { await notificationManager.cancel(this.noticeId); } catch (_) {}
      } catch (_) { /* Keep the delivered text notification on avatar failure. */ }
      finally { try { await pixels.release(); } catch (_) {} }
    }).catch((): void => {});
  }
}
