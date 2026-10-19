import { PinmonyI18n } from 'common_foundation';
import { PinmonySystemActions } from './PinmonySystemActions';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonySearchStore } from 'feature_search';
import { PinmonyHomeController } from 'feature_home';
import { PinmonyHomeStore } from 'feature_home';
import { webview } from '@kit.ArkWeb';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { PinmonyPostResult } from 'feature_pin';
import { PinmonySearchResult, PinmonySearchSnapshot } from 'feature_search';
import { UIContext } from '@kit.ArkUI';
export interface PinmonyBusinessResultsCoordinatorPorts {
  foreground: () => boolean;
  epoch: () => number;
  document: () => string;
  activeSheetKind: () => string;
  controller: () => webview.WebviewController;
  dismissApiBoards: () => void;
  dismissMoreSheet: () => void;
  getUIContext: () => UIContext;
  hasMeaningfulSearchPinTitle: (value: string) => boolean;
  homeController: () => PinmonyHomeController;
  homeStore: () => PinmonyHomeStore;
  isCurrentMorePin: (pin: string) => boolean;
  openEditPin: (pin: string) => Promise<void>;
  pinIdentity: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  searchStore: () => PinmonySearchStore;
  sharePinUrl: (url: string, title?: string) => Promise<void>;
  showMessage: (message: string) => void;
  showShareFeedbackSnack: () => void;
  showUndoSnack: (message: string, pin: string, undo: () => void) => void;
  systemActions: () => PinmonySystemActions;
  undoMoreFeedback: () => Promise<void>;
  undoSavedPin: () => Promise<void>;
}
export class PinmonyBusinessResultsCoordinator {
  private readonly homeStore: PinmonyHomeStore;
  private readonly searchStore: PinmonySearchStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly ports: PinmonyBusinessResultsCoordinatorPorts;
  constructor(ports: PinmonyBusinessResultsCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.searchStore = ports.searchStore(); this.pinStore = ports.pinStore(); }
async handlePostResult(value: string): Promise<void> {
    if (!this.ports.foreground()) return;
    const epoch: number = this.ports.epoch(), document: string = this.ports.document();
    const sheet: string = this.ports.activeSheetKind(), shareSession: number = this.pinStore.shareSession, moreSession: number = this.pinStore.moreSession;
    const current = (): boolean => this.ports.foreground() && epoch === this.ports.epoch() && document === this.ports.document() && sheet === this.ports.activeSheetKind() && shareSession === this.pinStore.shareSession && moreSession === this.pinStore.moreSession;
    try {
        const result: PinmonyPostResult = JSON.parse(value) as PinmonyPostResult;
        if (!result || !this.ports.isCurrentMorePin(result.pinUrl))
            return;
        if (result.scope === 'share' && (result.session !== this.pinStore.shareSession || this.ports.activeSheetKind() !== 'share'))
            return;
        if (result.scope === 'more' && (result.session !== this.pinStore.moreSession ||
            this.ports.activeSheetKind() !== 'more' && !this.homeStore.customHomeMenu))
            return;
        if (result.kind === 'editOpen' && this.ports.activeSheetKind() === 'more') {
            this.ports.dismissMoreSheet();
            this.ports.openEditPin(result.pinUrl);
        }
        else if (result.kind === 'feedbackReady') {
            this.pinStore.saveUndoPin = '';
            this.pinStore.saveUndoId = '';
            this.pinStore.feedbackUndoPin = result.pinUrl;
            this.pinStore.feedbackUndoSession = result.session;
            if (this.ports.activeSheetKind() === 'more')
                this.ports.dismissMoreSheet();
            this.ports.showUndoSnack(PinmonyI18n.message('将为你显示更多此类 Pin'), result.pinUrl, () => this.ports.undoMoreFeedback());
        }
        else if (result.kind === 'saveReady' && result.objectId && this.ports.activeSheetKind() === 'save' &&
            this.pinStore.saveResult.pin === result.pinUrl) {
            this.pinStore.confirmedSaves.confirm(this.ports.pinIdentity(result.pinUrl), true, result.objectId);
            if (this.pinStore.detail) {
                this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.ports.pinIdentity(result.pinUrl), this.pinStore.detail);
                this.pinStore.detailCache.put(this.ports.pinIdentity(result.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
            }
            this.pinStore.saveUndoPin = result.pinUrl;
            this.pinStore.saveUndoId = result.objectId;
            this.ports.dismissApiBoards();
            this.ports.showUndoSnack(result.value, result.pinUrl, () => this.ports.undoSavedPin());
        }
        else if ((result.kind === 'saveUndone' || result.kind === 'saveUndoError') &&
            (this.pinStore.saveUndoPin === result.pinUrl && this.pinStore.saveUndoId === result.objectId ||
                this.pinStore.confirmedSaves.copyId(this.ports.pinIdentity(result.pinUrl)) === result.objectId && !!result.objectId)) {
            if (result.kind === 'saveUndone') {
                this.pinStore.confirmedSaves.confirm(this.ports.pinIdentity(result.pinUrl), false);
                if (this.pinStore.detail) {
                    this.pinStore.detail = this.pinStore.confirmedSaves.apply(this.ports.pinIdentity(result.pinUrl), this.pinStore.detail);
                    this.pinStore.detailCache.put(this.ports.pinIdentity(result.pinUrl), this.pinStore.detail, this.pinStore.detailScrollOffset);
                }
                this.pinStore.saveUndoPin = '';
                this.pinStore.saveUndoId = '';
                this.ports.showMessage(result.value);
            }
            else if (!this.pinStore.viewerSaveBusy)
                this.ports.showUndoSnack(result.value, result.pinUrl, () => this.ports.undoSavedPin());
        }
        else if ((result.kind === 'feedbackUndone' || result.kind === 'feedbackUndoError') &&
            result.pinUrl === this.pinStore.feedbackUndoPin && result.session === this.pinStore.feedbackUndoSession) {
            this.pinStore.feedbackUndoBusy = false;
            if (result.kind === 'feedbackUndone')
                this.pinStore.feedbackUndoPin = '';
            if (result.kind === 'feedbackUndoError')
                this.ports.showUndoSnack(result.value, result.pinUrl, () => this.ports.undoMoreFeedback());
            else
                this.ports.showMessage(result.value);
        }
        else if (result.kind === 'help' && result.value === 'https://help.pinterest.com/en/article/gen-ai-labels') {
            const context: common.UIAbilityContext = this.ports.getUIContext().getHostContext() as common.UIAbilityContext;
            await context.openLink(result.value);
        }
        if (result.kind === 'copy' && (/^https:\/\/pin\.it\/[A-Za-z0-9]+$/.test(result.value) ||
            /^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/\d+\/$/.test(result.value) &&
                this.ports.pinIdentity(result.value) === this.ports.pinIdentity(result.pinUrl))) {
            try {
                await this.ports.systemActions().copyText(result.value);
            }
            catch (_) {
                if (current() && result.session === this.pinStore.shareSession && this.ports.activeSheetKind() === 'share' && this.ports.isCurrentMorePin(result.pinUrl)) {
                    this.pinStore.shareFeedback = '';
                    this.pinStore.shareError = PinmonyI18n.message('复制链接失败，请重试');
                    this.ports.showMessage(this.pinStore.shareError);
                }
                return;
            }
            if (result.session === this.pinStore.shareSession && this.ports.activeSheetKind() === 'share' && this.ports.isCurrentMorePin(result.pinUrl)) {
                this.pinStore.shareError = '';
                this.pinStore.shareSnackKey = '';
                this.pinStore.shareFeedback = PinmonyI18n.message('链接已复制');
                this.ports.showShareFeedbackSnack();
            }
        }
        else if (result.kind === 'download' && /^https:\/\/i\.pinimg\.com\//.test(result.value)) {
            this.ports.controller().startDownload(result.value);
        }
        else if (result.kind === 'systemShare' && (/^https:\/\/pin\.it\/[A-Za-z0-9]+$/.test(result.value) ||
            /^https:\/\/(?:[^/]+\.)?pinterest\.com\/pin\/\d+\/$/.test(result.value) &&
                this.ports.pinIdentity(result.value) === this.ports.pinIdentity(result.pinUrl)) &&
            /^(?:Facebook|Messenger|X|WhatsApp|短信)$/.test(result.platform || '')) {
            const context: common.UIAbilityContext = this.ports.getUIContext().getHostContext() as common.UIAbilityContext;
            if (result.targetUrl && /^https:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|messenger\.com)\//.test(result.targetUrl)) {
                try {
                    await context.openLink(result.targetUrl, { appLinkingOnly: true });
                    return;
                }
                catch (error) { /* Resolve installed share providers below when App Linking has no handler. */ }
            }
            if (!current() || result.session !== this.pinStore.shareSession || this.ports.activeSheetKind() !== 'share' ||
                !this.ports.isCurrentMorePin(result.pinUrl))
                return;
            this.ports.showMessage(PinmonyI18n.message('请在系统分享中选择 ') + result.platform);
            await this.ports.sharePinUrl(result.value, result.title || 'Pinterest Pin');
        }
        else if (result.kind === 'external' && /^https:\/\/(?:[^/]+\.)?(?:twitter\.com|x\.com|facebook\.com|messenger\.com|whatsapp\.com)\//.test(result.value)) {
            const context: common.UIAbilityContext = this.ports.getUIContext().getHostContext() as common.UIAbilityContext;
            await context.openLink(result.value);
        }
        else if (result.kind === 'message') {
            this.ports.showMessage(result.value);
        }
    }
    catch (error) {
        if (current()) this.ports.showMessage(PinmonyI18n.message('操作失败，请重试'));
    }
}

updateSearchPinTitle(pinUrl: string, value: string): void {
    const identity: string = this.ports.pinIdentity(pinUrl);
    const title: string = (value || '').trim().replace(/\s+/g, ' ').slice(0, 180);
    const search: PinmonySearchSnapshot | undefined = this.searchStore.search;
    if (!identity || !this.ports.hasMeaningfulSearchPinTitle(title))
        return;
    this.searchStore.knownSearchPinTitles.set(identity, title);
    if (this.searchStore.knownSearchPinTitles.size > 100) {
        const oldest: string = this.searchStore.knownSearchPinTitles.keys().next().value;
        this.searchStore.knownSearchPinTitles.delete(oldest);
    }
    if (!search)
        return;
    let changed: boolean = false;
    const results: PinmonySearchResult[] = search.results.map((item: PinmonySearchResult): PinmonySearchResult => {
        if (item.kind !== 'pin' || this.ports.pinIdentity(item.targetUrl) !== identity || item.title === title)
            return item;
        changed = true;
        return { id: item.id, kind: item.kind, title: title, subtitle: item.subtitle,
            targetUrl: item.targetUrl, imageUrl: item.imageUrl, imageWidth: item.imageWidth,
            imageHeight: item.imageHeight, video: item.video, enabled: item.enabled };
    });
    if (!changed)
        return;
    this.searchStore.search = { kind: search.kind, session: search.session, pageKey: search.pageKey,
        query: search.query, placeholder: search.placeholder,
        selectedCategory: search.selectedCategory, categories: search.categories,
        suggestions: search.suggestions, heroes: search.heroes, ideaSections: search.ideaSections,
        results: results, inputReady: search.inputReady, suggestionBusy: search.suggestionBusy, suggestionError: search.suggestionError, quiz: search.quiz, api: search.api, apiError: search.apiError, apiBusy: search.apiBusy, apiActive: search.apiActive, apiEnded: search.apiEnded, discoveryApi: search.discoveryApi, discoveryBusy: search.discoveryBusy, discoveryError: search.discoveryError, discoveryActive: search.discoveryActive, discoveryEnded: search.discoveryEnded };
    if (this.searchStore.retainedSearch?.pageKey === search.pageKey)
        this.searchStore.retainedSearch = this.searchStore.search;
}

updateHomePinTitle(pinUrl: string, value: string): void {
    return this.ports.homeController().updateHomePinTitle(pinUrl, value);
}
}
