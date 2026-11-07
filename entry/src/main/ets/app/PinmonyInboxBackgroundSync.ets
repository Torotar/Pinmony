import { notificationManager } from '@kit.NotificationKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonyI18n, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyInboxBackgroundLifecycle } from './PinmonyInboxBackgroundLifecycle';
import { PinmonyInboxUnreadNativeReads, PIN_INBOX_MESSAGES_POLL_MS } from './PinmonyInboxUnreadNativeReads';
import { PinmonyInboxNoticeConversation } from './PinmonyInboxMessageNotice';
export const PIN_INBOX_BACKGROUND_MESSAGES_POLL_MS: number = 3000;

export interface PinmonyInboxBackgroundSyncPorts {
  session: () => PinmonyBusinessSessionContext;
  store: () => PinmonyInboxStore;
  observed: (rows: PinmonyInboxNoticeConversation[]) => void;
  stopped: () => void;
}

// One system-granted transient task per real background transition.
// Expiry releases the task; it is never renewed while the app stays hidden.
export class PinmonyInboxBackgroundSync {
  private readonly ports: PinmonyInboxBackgroundSyncPorts;
  private readonly network: PinmonyNativeNetwork = new PinmonyNativeNetwork();
  private readonly reader: PinmonyInboxUnreadNativeReads;
  private readonly lifecycle: (background: boolean) => void = (background: boolean): void => {
    if(background)this.start(); else this.stop();
  };
  private installed: boolean = false;
  private running: boolean = false;
  private revision: number = 0;
  private checking: boolean = false;
  private lastTick: number = 0;
  private timer: number = -1;
  private suspendRequest: number = -1;
  private suspendUntil: number = 0;
  private suspendTimer: number = -1;
  private suspendGeneration: number = 0;
  private account: PinmonyBusinessSessionContext | undefined = undefined;
  constructor(ports: PinmonyInboxBackgroundSyncPorts) {
    this.ports = ports;
    this.network.setForeground(false);
    this.reader = new PinmonyInboxUnreadNativeReads({
      // This owner's interval and single-flight guard schedule reads. A second
      // throttle after async permission lookup can skip ticks due to clock jitter.
      messagesPollMs: 0,
      session: (): PinmonyBusinessSessionContext => this.ports.session(),
      active: (): boolean => this.active(), store: (): PinmonyInboxStore => this.ports.store(),
      network: (): PinmonyNativeNetwork => this.network,
      messagesObserved: (rows: PinmonyInboxNoticeConversation[]): void => {
        if(this.active())this.ports.observed(rows);
      }
    });
  }
  install(): void {
    if(this.installed)return;
    this.installed = true;
    PinmonyInboxBackgroundLifecycle.bind(this.lifecycle);
    if(PinmonyInboxBackgroundLifecycle.isBackground())this.start();
  }
  dispose(): void {
    this.installed = false;
    PinmonyInboxBackgroundLifecycle.unbind(this.lifecycle);
    this.stop();
  }
  private eligible(): boolean {
    const actual: PinmonyBusinessSessionContext = this.ports.session();
    return this.installed && this.running && this.suspendRequest >= 0 && Date.now() < this.suspendUntil &&
      PinmonyInboxBackgroundLifecycle.isBackground() && actual.authenticated && !!actual.accountId &&
      actual.accountId === this.account?.accountId && actual.generation === this.account?.generation &&
      actual.origin === this.account?.origin;
  }
  active(): boolean {
    const elapsed: number = Date.now() - this.lastTick;
    // This bounds response freshness, not the lifetime of background checking.
    return this.eligible() && elapsed >= 0 && elapsed < PIN_INBOX_MESSAGES_POLL_MS * 3;
  }
  private start(): void {
    if(!this.installed || this.running)return;
    const session: PinmonyBusinessSessionContext = this.ports.session();
    if(!session.authenticated || !session.accountId)return;
    // Synchronous: the request must be made inside the ability's onBackground
    // callback, before waiting on permission or network promises.
    let taskId: number = -1;
    let expired: boolean = false;
    const suspendGeneration: number = ++this.suspendGeneration;
    try {
      const info: backgroundTaskManager.DelaySuspendInfo = backgroundTaskManager.requestSuspendDelay(
        PinmonyI18n.message('pm_new_message_3fc957bf'), (): void => {
          expired = true;
          if(taskId >= 0 && this.suspendRequest === taskId && this.suspendGeneration === suspendGeneration)this.stop();
        });
      taskId = info.requestId;
      if(!Number.isSafeInteger(taskId) || taskId < 0)return;
      this.suspendRequest = taskId;
      if(expired || !Number.isFinite(info.actualDelayTime) || info.actualDelayTime <= 0) { this.releaseSuspendDelay(); return; }
      this.suspendUntil = Date.now() + info.actualDelayTime;
      this.suspendTimer = setTimeout((): void => {
        if(this.suspendRequest === taskId && this.suspendGeneration === suspendGeneration)this.stop();
      }, info.actualDelayTime);
      PinmonyRuntimeLog.info('InboxBackgroundTrace: transient-granted durationMs=' + info.actualDelayTime.toString());
    } catch (_) {
      this.releaseSuspendDelay();
      PinmonyRuntimeLog.warn('InboxBackgroundTrace: transient-unavailable');
      return;
    }
    this.account = session;
    this.revision++; this.running = true; this.lastTick = Date.now();
    this.timer = setInterval((): void => { this.tick().catch((): void => {}); }, PIN_INBOX_BACKGROUND_MESSAGES_POLL_MS);
    this.tick().catch((): void => {});
    PinmonyRuntimeLog.info('InboxBackgroundTrace: checking-started');
  }
  private async tick(): Promise<void> {
    if(!this.eligible()) { this.stop(); return; }
    const now: number = Date.now();
    if(now < this.lastTick || now - this.lastTick >= PIN_INBOX_MESSAGES_POLL_MS * 3) {
      // Timers may resume much later after suspension. Discard old work once;
      // the normal interval resumes without replaying every missed poll.
      this.revision++; this.checking = false;
      this.reader.pause(); this.ports.stopped();
      PinmonyRuntimeLog.info('InboxBackgroundTrace: scheduling-gap');
    }
    this.lastTick = now;
    if(this.checking)return;
    this.checking = true;
    const revision: number = this.revision;
    // Never launch an authorization dialog while the app is hidden.
    try {
      const allowed: boolean = await notificationManager.isNotificationEnabled();
      if(revision !== this.revision)return;
      if(!allowed || !this.eligible()) { this.stop(); return; }
      if(!this.active())return;
      // Private read-only owner; ordinary page reads and all writes stay suspended.
      this.network.setForeground(true);
      await this.reader.pollMessages();
    } catch (_) {
      // A transient platform lookup failure must not disable this background
      // session permanently. Retry on the existing interval, never in a loop.
      if(revision === this.revision && this.eligible()) {
        this.reader.pause(); this.network.setForeground(false); this.ports.stopped();
        PinmonyRuntimeLog.warn('InboxBackgroundTrace: check-unavailable');
      }
    } finally {
      if(revision === this.revision)this.checking = false;
    }
  }
  private releaseSuspendDelay(): void {
    const taskId: number = this.suspendRequest;
    this.suspendGeneration++;
    this.suspendRequest = -1; this.suspendUntil = 0;
    if(this.suspendTimer >= 0)clearTimeout(this.suspendTimer);
    this.suspendTimer = -1;
    if(taskId >= 0) {
      try { backgroundTaskManager.cancelSuspendDelay(taskId); }
      catch (_) { PinmonyRuntimeLog.warn('InboxBackgroundTrace: transient-release-unavailable'); }
    }
  }
  stop(): void {
    const wasRunning: boolean = this.running;
    this.running = false; this.checking = false; this.lastTick = 0; this.revision++;
    if(this.timer >= 0)clearInterval(this.timer);
    this.timer = -1;
    this.releaseSuspendDelay();
    this.reader.pause(); this.network.setForeground(false);
    this.account = undefined;
    if(wasRunning) {
      this.ports.stopped();
      PinmonyRuntimeLog.info('InboxBackgroundTrace: checking-stopped');
    }
  }
}
