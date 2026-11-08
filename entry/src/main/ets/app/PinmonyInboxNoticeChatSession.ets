import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork } from 'common_network';
import { PinmonyInboxMessagesNativeReads } from './PinmonyInboxMessagesNativeReads';
import { PIN_INBOX_CHAT_POLL_MS } from './PinmonyInboxUnreadNativeReads';

export interface PinmonyInboxNoticeChatPorts {
  session: () => PinmonyBusinessSessionContext;
  active: () => boolean;
  username: () => string;
  network: () => PinmonyNativeNetwork;
  feedback: (text: string) => void;
}
// A separate store/reader preserves every source page, including an already open chat.
export class PinmonyInboxNoticeChatSession {
  readonly store: PinmonyInboxStore = new PinmonyInboxStore();
  readonly key: string;
  readonly conversation: string;
  private readonly reader: PinmonyInboxMessagesNativeReads;
  private readonly ports: PinmonyInboxNoticeChatPorts;
  private readonly account: PinmonyBusinessSessionContext;
  private lastPoll: number = 0;
  constructor(key: string, conversation: string, ports: PinmonyInboxNoticeChatPorts) {
    this.key = key; this.conversation = conversation; this.ports = ports; this.account = ports.session();
    this.reader = new PinmonyInboxMessagesNativeReads({
      requestPrefix:key + '_',store:(): PinmonyInboxStore => this.store,
      session:(): PinmonyBusinessSessionContext => this.ports.session(),
      page:(): string => this.account.origin + '/inbox/',
      active:(): boolean => this.current(), username:(): string => this.ports.username(),
      network:(): PinmonyNativeNetwork => this.ports.network(), feedback:(text: string): void => this.ports.feedback(text),
      settled:(): void => {}
    });
  }
  private current(): boolean {
    const session: PinmonyBusinessSessionContext = this.ports.session();
    return this.ports.active() && session.authenticated && session.accountId === this.account.accountId &&
      session.generation === this.account.generation && session.origin === this.account.origin;
  }
  open(): Promise<boolean> { return this.reader.openNoticeConversation(this.conversation); }
  action(action: string, value: string): Promise<boolean> { return this.reader.action(action,value); }
  poll(): void {
    if(!this.current() || Date.now() - this.lastPoll < PIN_INBOX_CHAT_POLL_MS)return;
    this.lastPoll = Date.now(); this.reader.poll();
  }
  pause(): void { this.reader.pause(); }
  resume(): void { if(this.current())this.reader.demand(); }
  reset(): void { this.reader.reset(); }
}
