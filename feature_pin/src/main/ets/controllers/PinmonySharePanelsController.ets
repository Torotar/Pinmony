import { PinmonyI18n } from 'common_foundation';
import { PIN_EDIT_API_ENABLED } from '../services/PinmonyEditPinApiScript';
import { PinmonyTaskRegistry, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { ShareSheetMessage, ShareSheetOption, MoreSheetMessage, MoreSheetOption } from '../models/PinmonySheets';
import { PinmonyDetailSnapshot } from '../models/PinmonyDetail';
import { PIN_POST_API_ENABLED } from '../services/PinmonyPostApiScript';

export interface PinmonySharePanelsControllerPorts {
  nativeMenu?: () => boolean;
  nativeMoreOpen?: () => Promise<void>;
  nativeMoreAction?: (id: string) => Promise<void>;
  nativeMenuPause?: () => void;
  nativeShare?: () => boolean;
  nativeSearch?: (value: string) => void;
  nativeRefresh?: () => Promise<void>;
  nativeAction?: (id: string) => Promise<void>;
  nativePause?: () => void;
  copyText: (value: string) => Promise<void>;
  currentProfileUrl: () => string;
  profileTitle: () => string;
  dismissMoreSheet: () => void;
  sharePinUrl: (pin: string, title: string) => Promise<void>;
  traceAction: (name: string, id: string) => void;
  profileShareMode: () => boolean;
  activeSheetKind: () => string;
  setActiveSheetKind: (value: string) => void;
  showNativeSheet: () => boolean;
  setShowNativeSheet: (value: boolean) => void;
  customMenu: () => boolean;
  pendingHomeMorePin: () => string;
  clearHomeMenuPin: () => void;
  document: () => string;
  foreground: () => boolean;
  currentShareObjectUrl: () => string;
  shareObjectReady: () => boolean;
  isCurrentMorePin: (value: string) => boolean;
  closeMoreWebPanel: (session: number, pin: string) => void;
  suspendMoreForShare: () => void;
  extractPinUrl: (value: string) => string;
  showMessage: (value: string) => void;
  dismissShareSheet: () => void;
  isCopyLinkAction: (value: string) => boolean;
  showShareLinkSnack: () => void;
  showShareFeedbackSnack: () => void;
  pinIdentity: (value: string) => string;
  cancelHomeDetailMore: () => void;
  runScript: (script: string) => Promise<string>;
  webJsonText: (value: string) => string;
  rejectOfflineAction: (value: string) => boolean;
}

export class PinmonySharePanelsController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private searchToken: number = 0;
  private readonly searchTasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private lastSearchKey: string = '';
  private refreshToken: number = 0;
  private refreshing: boolean = false;
  private readonly store: PinmonyPinStore;
  private readonly ports: PinmonySharePanelsControllerPorts;
  constructor(store: PinmonyPinStore, ports: PinmonySharePanelsControllerPorts) { this.store = store; this.ports = ports; }
  pause(): void {
    if(this.ports.nativeMenu?.())this.ports.nativeMenuPause?.();
    if(this.ports.nativeShare?.())this.ports.nativePause?.();
    this.searchTasks.invalidate(); this.lastSearchKey = '';
    this.generation++; this.searchToken++; this.refreshToken++; this.refreshing = false; this.tasks.invalidate();
    if (this.ports.activeSheetKind() === 'share' && this.store.shareLoading) {
      this.store.shareLoading = false; this.store.shareError = PinmonyI18n.message("pm_share_loading_paused_please_retry_1a0f4d77");
    }
    if (this.ports.activeSheetKind() === 'more' && this.store.moreLoading) {
      this.store.moreLoading = false; this.store.moreError = PinmonyI18n.message("pm_option_loading_paused_please_retry_aedb895b");
    }
  }

  private current(session: number, pin: string, page: string, generation: number, kind: string): boolean {
    return generation === this.generation && this.ports.foreground() && page === this.ports.document() &&
      this.ports.activeSheetKind() === kind && (kind === 'share' ? session === this.store.shareSession &&
      session !== this.store.ignoredShareSession && pin === this.store.sharePin : session === this.store.moreSession &&
      session !== this.store.ignoredMoreSession && pin === this.store.morePin && this.ports.isCurrentMorePin(pin));
  }

  updateShareSheet(value: string): void {
    if(this.ports.nativeShare?.())return;
    if (!this.ports.foreground()) return;
    if (this.ports.customMenu()) return;
    try {
      const message: ShareSheetMessage = JSON.parse(value) as ShareSheetMessage;
      if (!message || !Number.isInteger(message.session) || message.session < 1 ||
          message.options && (!Array.isArray(message.options) || message.options.length > 100) ||
          message.actions && (!Array.isArray(message.actions) || message.actions.length > 100) ||
          message.contacts && (!Array.isArray(message.contacts) || message.contacts.length > 2000)) {
        return;
      }
      if ((message.kind === 'opening' || message.kind === 'state' || message.kind === 'apiPending' || message.kind === 'apiFailed') && message.pinUrl &&
          !(this.ports.profileShareMode() ? message.pinUrl === this.ports.currentShareObjectUrl() && this.ports.shareObjectReady() : this.ports.isCurrentMorePin(message.pinUrl))) return;
      if (message.kind === 'closed') {
        if (message.session === this.store.shareSession) {
          if (this.ports.activeSheetKind() === 'share') {
            this.ports.setShowNativeSheet(false);
            this.ports.setActiveSheetKind('');
          }
          this.store.shareSession = 0;
          this.store.ignoredShareSession = 0;
          this.store.shareOpenRequestedSession = 0;
          this.store.shareOptions = [];
          this.store.shareActions = [];
          this.store.shareContacts = [];
          this.store.shareOnPinDetail = false;
          this.store.shareTitle = '';
          this.store.shareSectionLabel = '';
          this.store.shareError = '';
          this.store.shareFeedback = '';
          this.store.shareLoading = false;
          if (this.store.ignoredMoreSession && this.store.morePin) {
            this.ports.closeMoreWebPanel(this.store.ignoredMoreSession, this.store.morePin);
          }
        }
        return;
      }
      if (message.kind === 'opening') {
        if (message.session < this.store.shareSession || message.session === this.store.ignoredShareSession) return;
        this.ports.suspendMoreForShare();
        if (message.session !== this.store.shareSession) this.store.shareOpenRequestedSession = 0;
        this.store.shareSession = message.session;
        this.store.sharePin = this.ports.profileShareMode() ? this.ports.currentShareObjectUrl() : this.ports.extractPinUrl(message.pinUrl || '');
        this.store.shareOptions = [];
        this.store.shareActions = [];
        this.store.shareContacts = [];
        this.store.shareOnPinDetail = !this.ports.profileShareMode() && !!this.ports.extractPinUrl(message.pinUrl || '');
        this.store.shareTitle = '';
        this.store.shareSectionLabel = '';
        this.store.shareSearchActive = false;
        this.store.shareSearchId = '';
        this.store.shareSendId = '';
        this.store.shareError = '';
        this.store.shareFeedback = '';
        this.store.shareLoading = true;
        this.ports.setActiveSheetKind('share');
        this.ports.setShowNativeSheet(true);
        const pin: string = this.store.sharePin, page: string = this.ports.document(), generation: number = this.generation;
        this.tasks.timeout((): void => {
          if (this.current(message.session, pin, page, generation, 'share')) this.scheduleShareWebOpen();
        }, 500);
        return;
      }
      if (message.kind === 'failed') {
        if (message.session === this.store.shareSession && message.session !== this.store.ignoredShareSession) {
          this.store.shareLoading = false;
          this.ports.showMessage(PinmonyI18n.message("pm_unable_to_load_pinterest_share_panel_reopen_sharing_2f7f03b8"));
          this.ports.dismissShareSheet();
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || message.session === this.store.ignoredShareSession ||
          message.session < this.store.shareSession) {
        return;
      }
      if (message.session !== this.store.shareSession) {
        this.store.shareSession = message.session;
        this.store.shareQuery = '';
        this.store.shareError = '';
        this.store.shareFeedback = '';
      }
      if (this.searchToken > 0 && this.store.shareSearchActive && message.searchActive &&
          typeof message.query === 'string' && message.query.trim() !== this.store.shareQuery.trim()) return;
      this.ports.suspendMoreForShare();
      this.store.sharePin = this.ports.profileShareMode() ? this.ports.currentShareObjectUrl() : this.ports.extractPinUrl(message.pinUrl || '');
      this.store.shareOnPinDetail = !this.ports.profileShareMode() && !!this.ports.extractPinUrl(message.pinUrl || '');
      this.store.shareTitle = message.title || '';
      this.store.shareSectionLabel = message.sectionLabel || '';
      this.store.shareOptions = (message.options || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      this.store.shareActions = (message.actions || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      const copyOptions: ShareSheetOption[] = this.store.shareOptions.concat(this.store.shareActions)
        .filter((option: ShareSheetOption) => this.ports.isCopyLinkAction(option.label));
      this.store.shareOptions = this.store.shareOptions.filter((option: ShareSheetOption) => !this.ports.isCopyLinkAction(option.label));
      if (copyOptions.length > 0) {
        this.store.shareOptions.push(copyOptions[0]);
      }
      this.store.shareActions = this.store.shareActions.filter((option: ShareSheetOption) => !this.ports.isCopyLinkAction(option.label));
      if (this.store.shareOnPinDetail) {
        this.store.shareSectionLabel = '发送给联系人';
        this.store.shareOptions = [];
        this.store.shareActions = [];
      }
      this.store.shareContacts = (message.contacts || []).filter((option: ShareSheetOption) => !!option.id && !!option.label);
      this.store.shareSearchId = message.searchId || '';
      this.store.shareSearchLabel = message.searchLabel || '';
      this.store.shareSendId = message.sendId || '';
      this.store.shareSendLabel = message.sendLabel || '';
      const enteringSearch: boolean = !this.store.shareSearchActive && !!message.searchActive;
      this.store.shareSearchActive = !!message.searchActive;
      if (enteringSearch && typeof message.query === 'string') {
        this.store.shareQuery = message.query;
      }
      this.store.shareFeedback = message.feedback || '';
      this.store.shareError = message.error || '';
      if (/Unexpected token|not valid JSON|JSON\.parse|Unexpected end of JSON/i.test(this.store.shareError)) {
        this.store.shareError = PinmonyI18n.message("pm_unable_to_load_share_data_please_retry_1f9affe6");
      }
      this.store.shareLoading = false;
      this.ports.setActiveSheetKind('share');
      this.ports.setShowNativeSheet(true);
      if (!this.store.shareSearchActive && this.store.shareOptions.length === 0 &&
          this.store.shareActions.length === 0 && !this.store.shareSearchId && this.store.shareContacts.length === 0) {
        this.store.shareError = PinmonyI18n.message("pm_share_options_temporarily_unavailable_e5eb170e");
      } else {
        this.store.shareError = message.error || '';
      }
      this.ports.showShareLinkSnack();
      this.ports.showShareFeedbackSnack();
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid share sheet state');
    }
  }


  updateMoreSheet(value: string): void {
    if(this.ports.nativeMenu?.())return;
    if (!this.ports.foreground()) return;
    if (this.ports.customMenu() || this.store.moreApiMode) return;
    try {
      const message: MoreSheetMessage = JSON.parse(value) as MoreSheetMessage;
      if (!message || !Number.isInteger(message.session) || message.session < 1 ||
          typeof message.pin !== 'string' || message.options && (!Array.isArray(message.options) || message.options.length > 100)) return;
      if (message.kind === 'closeFailed') {
        if (message.session === this.store.moreSession && message.pin === this.store.morePin &&
            this.ports.activeSheetKind() !== 'share') {
          this.ports.showMessage(PinmonyI18n.message("pm_unable_to_close_website_options_please_retry_4162f998"));
        }
        return;
      }
      if (message.kind === 'closed') {
        if (message.session === this.store.moreSession && message.pin === this.store.morePin) {
          if (this.ports.activeSheetKind() === 'more') {
            this.ports.setShowNativeSheet(false);
            this.ports.setActiveSheetKind('');
          }
          this.store.moreSession = 0;
          this.store.moreApiMode = false;
          this.store.ignoredMoreSession = 0;
          this.store.morePin = '';
          this.ports.clearHomeMenuPin();
          this.store.moreTitle = '';
          this.store.moreOptions = [];
          this.store.moreError = '';
          this.store.moreLoading = false;
        }
        return;
      }
      if (!this.ports.isCurrentMorePin(message.pin) ||
          message.session < this.store.moreSession || message.session === this.store.ignoredMoreSession) return;
      if (message.kind === 'opening') {
        if (this.ports.activeSheetKind() === 'share') this.ports.dismissShareSheet();
        this.store.moreSession = message.session;
        this.store.moreApiMode = false;
        this.store.morePin = message.pin;
        this.store.moreTitle = '';
        this.store.moreOptions = [];
        this.store.moreError = '';
        this.store.moreLoading = true;
        this.ports.setActiveSheetKind('more');
        this.ports.setShowNativeSheet(false);
        return;
      }
      if (message.session !== this.store.moreSession || message.pin !== this.store.morePin) return;
      if (message.kind === 'failed') {
        if (this.ports.pinIdentity(message.pin) === this.ports.pinIdentity(this.ports.pendingHomeMorePin())) {
          this.ports.cancelHomeDetailMore();
        }
        this.store.moreLoading = false;
        this.store.ignoredMoreSession = message.session;
        this.ports.setActiveSheetKind('');
        this.ports.setShowNativeSheet(false);
        this.ports.showMessage(PinmonyI18n.message("pm_unable_to_load_pinterest_options_reopen_the_options_menu_16720c78"));
        return;
      }
      if (message.kind !== 'state') return;
      if (this.ports.pinIdentity(message.pin) === this.ports.pinIdentity(this.ports.pendingHomeMorePin())) {
        this.ports.cancelHomeDetailMore();
      }
      this.store.moreTitle = message.title || '';
      this.store.moreOptions = (message.options || []).filter((option: MoreSheetOption) =>
        !!option.id && !!option.label);
      this.store.moreLoading = false;
      this.store.moreError = this.store.moreOptions.length > 0 ? '' : PinmonyI18n.message("pm_options_temporarily_unavailable_839cbe86");
      this.ports.setActiveSheetKind('more');
      this.ports.setShowNativeSheet(true);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid Pin menu state');
    }
  }


  async openApiDetailMore(): Promise<void> {
    if(this.ports.nativeMenu?.()){await this.ports.nativeMoreOpen?.();return;}
    if (!this.ports.foreground()) return;
    const detail: PinmonyDetailSnapshot | undefined = this.store.detail;
    if (!detail || !this.store.detailActionsReady || !this.ports.isCurrentMorePin(detail.pinUrl)) return;
    const session: number = Math.max(1, this.store.moreSession + 1);
    this.store.moreSession = session;
    this.store.moreApiMode = true;
    this.store.morePin = detail.pinUrl;
    this.store.moreTitle = '选项';
    this.store.moreOptions = [];
    this.store.moreError = '';
    this.store.moreLoading = true;
    this.store.ignoredMoreSession = 0;
    this.ports.setActiveSheetKind('more');
    this.ports.setShowNativeSheet(true);
    const generation: number = this.generation, page: string = this.ports.document();
    const current = (): boolean => this.current(session, detail.pinUrl, page, generation, 'more') && this.store.moreApiMode;
    try {
      const opened: string = await this.ports.runScript('window.PinmonyPostApi && window.PinmonyPostApi.detailMoreOpen(' +
        session.toString() + ',' + JSON.stringify(detail.pinUrl) + ')');
      if (!current()) return;
      if (opened !== 'true' && opened !== '"true"') throw new Error('open');
      let raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi && window.PinmonyPostApi.detailMoreRead(' +
        session.toString() + ',' + JSON.stringify(detail.pinUrl) + '))');
      if (!current()) return;
      const state: MoreSheetMessage | null = JSON.parse(this.ports.webJsonText(raw)) as MoreSheetMessage | null;
      if (!state || state.session !== session || state.pin !== detail.pinUrl || !Array.isArray(state.options) || state.options.length > 100) throw new Error('read');
      this.store.moreOptions = state.options.filter((item: MoreSheetOption): boolean => !!item.id && !!item.label);
      this.store.moreLoading = false;
      this.store.moreError = this.store.moreOptions.length ? '' : PinmonyI18n.message("pm_options_temporarily_unavailable_839cbe86");
    } catch (_) {
      if (!current()) return;
      this.store.moreLoading = false;
      this.store.moreError = PinmonyI18n.message("pm_unable_to_load_service_options_please_retry_3b2d272d");
    }
  }


  scheduleShareWebOpen(): void {
    if(this.ports.nativeShare?.())return;
    if (this.store.shareOnPinDetail) return;
    const session: number = this.store.shareSession;
    if (!session || this.store.shareOpenRequestedSession === session ||
        this.ports.activeSheetKind() !== 'share' || !this.store.shareLoading ||
        this.store.ignoredShareSession === session) return;
    this.store.shareOpenRequestedSession = session;
    const pin: string = this.store.sharePin, page: string = this.ports.document(), generation: number = this.generation;
    const current = (): boolean => this.current(session, pin, page, generation, 'share');
    this.tasks.timeout(() => {
      if (!current()) return;
      this.ports.runScript('window.PinmonyNativeShareOpen && window.PinmonyNativeShareOpen(' +
        session.toString() + ')').then((result: string) => {
        if (current() && result !== 'true' && result !== '"true"') {
          this.ports.showMessage(PinmonyI18n.message("pm_unable_to_open_pinterest_share_options_reopen_sharing_bc040277"));
          this.ports.dismissShareSheet();
        }
      }).catch(() => {
        if (current()) {
          this.ports.showMessage(PinmonyI18n.message("pm_unable_to_open_pinterest_share_options_reopen_sharing_bc040277"));
          this.ports.dismissShareSheet();
        }
      });
    }, 350);
  }


  async searchShareContacts(value: string): Promise<void> {
    if (!this.ports.foreground() || this.ports.activeSheetKind() !== 'share' || this.ports.rejectOfflineAction('share contact search')) return;
    if(this.ports.nativeShare?.()){this.ports.nativeSearch?.(value);return;}
    this.store.shareQuery = value;
    const session: number = this.store.shareSession;
    if (!session) {
      return;
    }
    const pin: string = this.store.sharePin, page: string = this.ports.document(), generation: number = this.generation;
    const query: string = value.slice(0, 200).trim();
    const key: string = JSON.stringify([session, pin, page, generation, query]);
    if (key === this.lastSearchKey) return;
    this.searchTasks.invalidate();
    const token: number = ++this.searchToken;
    const current = (): boolean => token === this.searchToken && this.current(session, pin, page, generation, 'share');
    this.store.shareContacts = [];
    this.store.shareFeedback = PinmonyI18n.message("pm_loading_contacts_6c983c5f");
    this.store.shareError = '';
    if (!await this.searchTasks.wait(300) || !current()) return;
    this.lastSearchKey = key;
    try {
      const result: string = await this.ports.runScript('window.PinmonyNativeShareSearch && ' +
        'window.PinmonyNativeShareSearch(' + session.toString() + ',' + JSON.stringify(query) + ')');
      if (current() && result !== 'true' && result !== '"true"') {
        this.lastSearchKey = ''; this.store.shareError = PinmonyI18n.message("pm_contact_search_unavailable_00543593");
      }
    } catch (error) {
      if (current()) {
        this.lastSearchKey = ''; this.store.shareError = PinmonyI18n.message("pm_contact_search_unavailable_00543593");
      }
    }
  }


  async refreshShareSheet(): Promise<void> {
    if(this.ports.nativeShare?.()){await this.ports.nativeRefresh?.();return;}
    if (this.refreshing || !this.ports.foreground() || this.ports.activeSheetKind() !== 'share' || this.ports.rejectOfflineAction('share refresh')) return;
    this.store.shareSnackKey = '';
    const session: number = this.store.shareSession;
    if (!session) {
      return;
    }
    const pin: string = this.store.sharePin, page: string = this.ports.document(), generation: number = this.generation;
    const token: number = ++this.refreshToken;
    const current = (): boolean => token === this.refreshToken && this.current(session, pin, page, generation, 'share');
    this.refreshing = true;
    this.store.shareError = '';
    this.store.shareLoading = !(PIN_POST_API_ENABLED && this.store.shareOnPinDetail);
    try {
      const result: string = await this.ports.runScript('window.PinmonyNativeShareRefresh && ' +
        'window.PinmonyNativeShareRefresh(' + session.toString() + ')');
      if (current() && result !== 'true' && result !== '"true"') {
        this.store.shareLoading = false;
        this.store.shareError = PinmonyI18n.message("pm_unable_to_reload_share_options_close_and_retry_1cf702a7");
      }
    } catch (error) {
      if (!current()) return;
      this.store.shareLoading = false;
      this.store.shareError = PinmonyI18n.message("pm_unable_to_reload_share_options_ed329738");
    } finally {
      if (token === this.refreshToken) this.refreshing = false;
    }
  }


  async performMoreAction(id: string): Promise<void> {
    if(this.ports.nativeMenu?.()){if(!this.ports.rejectOfflineAction('more.action'))await this.ports.nativeMoreAction?.(id);return;}
    const capturedSession: number = this.store.moreSession, capturedPin: string = this.store.morePin;
    const page: string = this.ports.document(), generation: number = this.generation;
    const current = (): boolean => this.current(capturedSession, capturedPin, page, generation, 'more');
    if (!capturedSession || !current()) return;
    this.ports.traceAction('pin.more', id);
    if (this.ports.rejectOfflineAction('more.action')) return;
    const option: MoreSheetOption | undefined = this.store.moreOptions.find((item: MoreSheetOption): boolean => item.id === id);
    if (!PIN_POST_API_ENABLED || !option || !option.enabled ||
        !/下载|download|查看更多|see more|查看更少|see less|分享|share|详细了解.*AI|learn more.*AI|编辑.*Pin|edit pin/i.test(option.label)) return;
    if (/编辑.*Pin|edit pin/i.test(option.label) && !PIN_EDIT_API_ENABLED) return;
    const session: number = this.store.moreSession;
    const pin: string = this.store.morePin;
    if (!id || !session || !this.ports.isCurrentMorePin(pin)) {
      this.store.moreError = PinmonyI18n.message("pm_this_option_is_unavailable_9fcf4515");
      return;
    }
    if (/分享|share/i.test(option.label)) {
      await this.ports.sharePinUrl(pin, this.store.detail?.title || 'Pinterest Pin');
      if (current() && session === this.store.moreSession) this.ports.dismissMoreSheet();
      return;
    }
    try {
      const result: string = this.store.moreApiMode ? await this.ports.runScript(
        'window.PinmonyPostApi && window.PinmonyPostApi.moreAction(' + session.toString() + ',' +
        JSON.stringify(pin) + ',' + JSON.stringify(id) + ',function(){} )') :
        await this.ports.runScript('window.PinmonyNativeMoreAction && ' +
          'window.PinmonyNativeMoreAction(' + session.toString() + ',' + JSON.stringify(pin) + ',' +
          JSON.stringify(id) + ')');
      if (current() && session === this.store.moreSession && result !== 'true' && result !== '"true"') {
        this.store.moreError = PinmonyI18n.message("pm_action_could_not_be_sent_please_retry_9ba04b0e");
      }
    } catch (error) {
      if (current() && session === this.store.moreSession) this.store.moreError = PinmonyI18n.message("pm_action_could_not_be_sent_please_retry_9ba04b0e");
    }
  }

  async refreshMoreSheet(): Promise<void> {
    if(this.ports.nativeMenu?.()){if(!this.ports.rejectOfflineAction('more.refresh'))await this.ports.nativeMoreOpen?.();return;}
    const capturedSession: number = this.store.moreSession, capturedPin: string = this.store.morePin;
    const page: string = this.ports.document(), generation: number = this.generation;
    const current = (): boolean => this.current(capturedSession, capturedPin, page, generation, 'more');
    if (!capturedSession || !current()) return;
    if (this.ports.rejectOfflineAction('more.refresh')) return;
    const session: number = this.store.moreSession;
    const pin: string = this.store.morePin;
    if (!session || !pin) return;
    this.store.moreError = '';
    this.store.moreLoading = true;
    try {
      if (this.store.moreApiMode) {
        let raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyPostApi && window.PinmonyPostApi.detailMoreRead(' +
          session.toString() + ',' + JSON.stringify(pin) + '))');
        const state: MoreSheetMessage | null = JSON.parse(this.ports.webJsonText(raw)) as MoreSheetMessage | null;
        if (!current()) return;
        if (!state || state.session !== capturedSession || state.pin !== capturedPin || !Array.isArray(state.options) || state.options.length > 100) throw new Error('Invalid');
        this.store.moreOptions = state && Array.isArray(state.options) ? state.options.filter((item: MoreSheetOption): boolean => !!item.id && !!item.label) : [];
        this.store.moreLoading = false;
        this.store.moreError = this.store.moreOptions.length ? '' : PinmonyI18n.message("pm_options_temporarily_unavailable_839cbe86");
        return;
      }
      const result: string = await this.ports.runScript('window.PinmonyNativeMoreRefresh && ' +
        'window.PinmonyNativeMoreRefresh(' + session.toString() + ',' + JSON.stringify(pin) + ')');
      if (current() && session === this.store.moreSession && result !== 'true' && result !== '"true"') {
        this.store.moreLoading = false;
        this.store.moreError = PinmonyI18n.message("pm_unable_to_reload_options_close_and_retry_f384fda1");
      }
    } catch (error) {
      if (current() && session === this.store.moreSession) {
        this.store.moreLoading = false;
        this.store.moreError = PinmonyI18n.message("pm_unable_to_reload_options_5bae4308");
      }
    }
  }

  async performShareAction(id: string): Promise<void> {
    if(this.ports.nativeShare?.()){if(!this.ports.rejectOfflineAction('share action'))await this.ports.nativeAction?.(id);return;}
    const capturedSession: number = this.store.shareSession, capturedPin: string = this.store.sharePin;
    const page: string = this.ports.document(), generation: number = this.generation;
    const current = (): boolean => this.current(capturedSession, capturedPin, page, generation, 'share');
    if (!capturedSession || !current()) return;
    this.ports.traceAction('pin.share', id);
    if (this.ports.rejectOfflineAction('share action')) return;
    if (this.ports.profileShareMode()) {
      if (!this.store.sharePin || !this.ports.shareObjectReady()) return;
      const session: number = this.store.shareSession;
      const objectPage: string = this.store.sharePin;
      if (id.indexOf('profile-contact:') === 0) {
        try {
          const result: string = await this.ports.runScript('window.PinmonyNativeShareAction && window.PinmonyNativeShareAction(' + session.toString() + ',' + JSON.stringify(id) + ')');
          if (current() && result !== 'true' && result !== '"true"') this.store.shareError = PinmonyI18n.message("pm_unable_to_send_please_retry_bbf944b6");
        } catch (_) { if (current()) this.store.shareError = PinmonyI18n.message("pm_unable_to_send_please_retry_bbf944b6"); }
        return;
      }
      if (id.indexOf('profile-share:') === 0) {
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel && window.PinmonyProfilePanel.shareLink(' + JSON.stringify(objectPage) + ',' + session + '))');
        if (!current()) return;
        const link: string = this.ports.webJsonText(raw);
        if (!/^https:\/\/pin\.it\/[A-Za-z0-9]+\/?$/.test(link)) { this.store.shareError = PinmonyI18n.message("pm_share_link_not_ready_50227487"); return; }
        const platform: string = id.slice('profile-share:'.length);
        await this.ports.sharePinUrl(link, this.ports.profileTitle());
        return;
      }
      if (id !== 'profile-copy') return;
      try {
        const raw: string = await this.ports.runScript('JSON.stringify(window.PinmonyProfilePanel && window.PinmonyProfilePanel.shareLink(' + JSON.stringify(objectPage) + ',' + session + '))');
        if (!current()) return;
        const link: string = this.ports.webJsonText(raw);
        if (session !== this.store.shareSession || this.ports.currentProfileUrl() !== objectPage || this.ports.activeSheetKind() !== 'share' || !this.ports.profileShareMode()) return;
        if (!/^https:\/\/pin\.it\/[A-Za-z0-9]+\/?$/.test(link)) { this.store.shareError = PinmonyI18n.message("pm_share_link_not_ready_50227487"); return; }
        await this.ports.copyText(link);
        if (current() && session === this.store.shareSession && this.ports.profileShareMode() && this.ports.activeSheetKind() === 'share') {
          this.store.shareFeedback = PinmonyI18n.message("pm_link_copied_6ce7dfa5"); this.ports.showShareFeedbackSnack();
        }
      } catch (_) { if (current()) this.store.shareError = PinmonyI18n.message("pm_unable_to_copy_link_please_retry_a34acdfe"); }
      return;
    }
    if (!PIN_POST_API_ENABLED) return;
    if (!id || !this.store.shareSession) {
      this.store.shareError = PinmonyI18n.message("pm_this_share_option_is_unavailable_1fb6c5df");
      return;
    }
    const session: number = this.store.shareSession;
    try {
      const result: string = await this.ports.runScript('window.PinmonyNativeShareAction && ' +
        'window.PinmonyNativeShareAction(' + session.toString() + ',' + JSON.stringify(id) + ')');
      if (current() && session === this.store.shareSession && result !== 'true' && result !== '"true"') {
        this.store.shareError = PinmonyI18n.message("pm_action_incomplete_please_retry_bb26135d");
      }
    } catch (error) {
      if (current() && session === this.store.shareSession) {
        this.store.shareError = PinmonyI18n.message("pm_action_incomplete_please_retry_bb26135d");
      }
    }
  }

}
