import { PinmonyI18n } from 'common_foundation';
import { PinmonyInboxStore, PinmonyInboxFlowSnapshot } from 'feature_inbox';
import { PinmonyAuxiliaryPorts, PinmonyBusinessAuxiliaryClient, PinmonyAuxiliaryNotSent, PinmonyAuxiliaryRejected } from './PinmonyBusinessAuxiliaryClient';
export interface PinmonyNewsTarget { newsId: string; notificationPinId: string; notificationMuted?: boolean; }
interface NewsData { news_ids?: string[]; should_hide?: boolean; object_ids_to_unsubscribe?: string[]; }
interface Options { url: string; data: NewsData; }
interface Resource { status: string; code: number; endpoint_name: string; data: Record<string,boolean> | null; }
interface Response { resource_response?: Resource; }
interface NewsUndo { flow: PinmonyInboxFlowSnapshot; pin: string; account: string; expires: number; }
export interface PinmonyInboxMenuNativePorts extends PinmonyAuxiliaryPorts {
  unsubscribed?: (id: string) => void;
  store: () => PinmonyInboxStore;page: () => string;active: () => boolean;find: (id: string) => PinmonyNewsTarget | undefined;confirmed: (id: string,hidden: boolean) => void;
}
export class PinmonyInboxMenuNative {
  private readonly ports: PinmonyInboxMenuNativePorts;private readonly client: PinmonyBusinessAuxiliaryClient;
  private hiddenUndo: NewsUndo | undefined = undefined;
  private revision: number = 0;private account: string = '';private pin: string = '';
  private readonly unknown: Set<string> = new Set<string>();private readonly unsubscribed: Set<string> = new Set<string>();
  constructor(ports: PinmonyInboxMenuNativePorts){this.ports = ports;this.client = new PinmonyBusinessAuxiliaryClient(ports);}
  pause(): void {this.revision++;this.client.pause();const flow = this.ports.store().inboxFlow;if(flow?.screen === 'updatesMenu' && flow.messageBusy){const next: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(flow)) as PinmonyInboxFlowSnapshot;next.messageBusy = false;next.writeUncertain = true;next.error = PinmonyI18n.message("pm_result_not_confirmed_refresh_to_check_it_will_not_be_resubmitted_e8e4eb27");this.ports.store().inboxFlow = next;}}
  async open(id: string): Promise<boolean> {
    if(!id.startsWith('news-menu:'))return false;
    const target: PinmonyNewsTarget | undefined = this.ports.find(id),account: string = this.client.key();
    if(!target || !account || !this.ports.active())return true;this.pause();
    if(this.account !== account){this.unknown.clear();this.unsubscribed.clear();this.hiddenUndo = undefined;}this.account = account;this.pin = target.notificationPinId;
    const store: PinmonyInboxStore = this.ports.store();store.flowDismissed = false;
    store.inboxFlow = {kind:'nativeFlow',nativeRead:true,nativeToken:this.revision,nativeAccountGeneration:this.ports.session().generation,pageUrl:this.ports.page(),session:store.inboxSession,
      screen:'updatesMenu',title:'更新',loading:false,error:'',users:[],messages:[],selectedIds:[],hasMore:false,newsId:target.newsId,newsHidden:false,
      canUnsubscribePin:/^\d{1,40}$/.test(this.pin),unsubscribedPin:target.notificationMuted === true || this.unsubscribed.has(this.pin),writeUncertain:this.unknown.has('pin:' + this.pin) || Array.from(this.unknown).some((v: string): boolean => v.startsWith(target.newsId + ':'))};
    return true;
  }
  async undoNews(newsId: string): Promise<string | undefined> {
    const undo: NewsUndo | undefined = this.hiddenUndo,store: PinmonyInboxStore = this.ports.store();
    if(store.inboxFlow?.messageBusy || !undo || undo.flow.newsId !== newsId || undo.account !== this.client.key() || undo.expires < Date.now() || undo.flow.pageUrl !== this.ports.page() || !this.ports.active() || store.inboxFlow && store.inboxFlow.newsId !== newsId)return undefined;
    this.pause();this.account = undo.account;this.pin = undo.pin;const next: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(undo.flow)) as PinmonyInboxFlowSnapshot;next.nativeToken = this.revision;next.messageBusy = false;next.newsUndoing = true;store.inboxFlow = next;store.flowDismissed = false;await this.action('undoNews');
    if(store.inboxFlow?.nativeToken === next.nativeToken) {
      const error: string = store.inboxFlow.error || (store.inboxFlow.newsHidden ? PinmonyI18n.message("pm_undo_result_not_confirmed_refresh_to_check_it_will_not_be_resubm_4a85600e") : '');
      store.inboxFlow = undefined;store.flowDismissed = true;return error;
    }
    return undefined;
  }
  async action(action: string): Promise<boolean> {
    const store: PinmonyInboxStore = this.ports.store(),flow: PinmonyInboxFlowSnapshot | undefined = store.inboxFlow;
    if(flow?.screen !== 'updatesMenu')return false;
    if(action === 'back'){this.pause();store.inboxFlow = undefined;store.flowDismissed = true;return true;}
    if(!['hideNews','undoNews','unsubscribePin'].includes(action))return true;
    if(!this.ports.active() || this.client.key() !== this.account || flow.pageUrl !== this.ports.page() || flow.messageBusy || flow.writeUncertain || !/^\d{1,40}$/.test(flow.newsId || ''))return true;
    if(action === 'undoNews' && !flow.newsHidden || action === 'hideNews' && flow.newsHidden || action === 'unsubscribePin' && (!flow.canUnsubscribePin || flow.unsubscribedPin))return true;
    const lock: string = action === 'unsubscribePin' ? 'pin:' + this.pin : flow.newsId + ':' + action;if(this.unknown.has(lock))return true;this.unknown.add(lock);
    const revision: number = this.revision,account: string = this.account;
    const live = (): boolean => revision === this.revision && account === this.client.key() && this.ports.active() && store.inboxFlow?.nativeToken === flow.nativeToken && flow.pageUrl === this.ports.page() && !store.flowDismissed;
    const update = (patch: Partial<PinmonyInboxFlowSnapshot>): void => {if(live()){const next: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(store.inboxFlow)) as PinmonyInboxFlowSnapshot;if(patch.messageBusy !== undefined)next.messageBusy = patch.messageBusy;if(patch.writeUncertain !== undefined)next.writeUncertain = patch.writeUncertain;if(patch.error !== undefined)next.error = patch.error;if(patch.newsHidden !== undefined)next.newsHidden = patch.newsHidden;if(patch.unsubscribedPin !== undefined)next.unsubscribedPin = patch.unsubscribedPin;store.inboxFlow = next;}};
    update({messageBusy:true,error:''});
    const unsubscribe: boolean = action === 'unsubscribePin',target: string = unsubscribe ? this.pin : flow.newsId!;
    const options: Options = {url:unsubscribe ? '/v3/settings/notifications/objects/' : '/v3/news_hub/hide/batch/',data:unsubscribe ? {object_ids_to_unsubscribe:[this.pin]} : {news_ids:[flow.newsId!],should_hide:action === 'hideNews'}};
    try {
      const p: Response = JSON.parse(await this.client.request(flow.pageUrl,'ApiResource',unsubscribe ? 'create' : 'update',options,'news',target,live)) as Response;
      const r: Resource | undefined = p.resource_response;
      if(r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)throw new PinmonyAuxiliaryRejected('rejected');
      if(!r || r.status !== 'success' || r.code !== 0 || r.endpoint_name !== (unsubscribe ? 'v3_update_object_subscriptions_for_notifications' : 'v3_hide_batch_by_news_ids') || (unsubscribe ? r.data?.[this.pin] !== false : r.data !== null))throw new Error('unconfirmed');
      if(!live())return true;this.unknown.delete(lock);
      if(unsubscribe){this.unsubscribed.add(this.pin);update({unsubscribedPin:true});if(this.ports.unsubscribed)this.ports.unsubscribed(flow.newsId!);}
      else {const hidden: boolean = action === 'hideNews';update({newsHidden:hidden});if(hidden){const saved: PinmonyInboxFlowSnapshot = JSON.parse(JSON.stringify(store.inboxFlow)) as PinmonyInboxFlowSnapshot;saved.messageBusy = false;this.hiddenUndo = {flow:saved,pin:this.pin,account:this.account,expires:Date.now() + 8000};}else this.hiddenUndo = undefined;this.ports.confirmed(flow.newsId!,hidden);}
    }catch (error){
      const retry: boolean = error instanceof PinmonyAuxiliaryNotSent || error instanceof PinmonyAuxiliaryRejected;
      if(retry && account === this.client.key())this.unknown.delete(lock);
      update({writeUncertain:!retry,error:retry ? '操作未提交成功，请重试' : PinmonyI18n.message("pm_result_not_confirmed_refresh_to_check_it_will_not_be_resubmitted_e8e4eb27")});
    }finally {update({messageBusy:false});}return true;
  }
}
