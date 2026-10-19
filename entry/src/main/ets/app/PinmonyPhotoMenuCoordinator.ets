import { PinmonyI18n } from 'common_foundation';
import { PinmonyReadinessGate } from './PinmonyReadinessGate';
import { PinmonyPinStore } from 'feature_pin';
import { PinmonyBoardStore } from 'feature_board';
import { PinmonyInboxStore } from 'feature_inbox';
import { PinmonyHomeStore } from 'feature_home';
import { PinmonyShareBridge } from './PinmonyShareBridge';
import { PinmonyTaskRegistry } from 'common_foundation';
import { webview } from '@kit.ArkWeb';
import { PinmonyAuthStatus } from 'common_session';
import { PinmonyBoardDetail, PinmonyBoardPin, boardVisiblePins } from 'feature_board';
import { PinmonyDetailAction, PinmonyDetailSnapshot } from 'feature_pin';
import { PinmonyHomeMenuOption, PinmonyHomeMenuState } from 'feature_home';
export interface PinmonyPhotoMenuCoordinatorPorts {
  nativeMenu?: () => boolean;
  nativeRead?: (token: number,pin: string) => Promise<PinmonyHomeMenuState>;
  nativeAction?: (id: string) => Promise<void>;
  nativePause?: () => void;
  nativeShare?: (pin: string) => Promise<void>;
  activeSheetKind: () => string;
  setActiveSheetKind: (value: string) => string;
  authEpoch: () => number;
  authStatus: () => PinmonyAuthStatus;
  boardOperation: (method: string, id?: string) => void;
  boardStore: () => PinmonyBoardStore;
  cancelledBoardPins: () => Set<string>;
  nativeBoardContentWrites?: () => boolean;
  cancelBoardPin?: (pin: string, current: () => boolean) => Promise<string>;
  clearRootTabGuard: (reason: string) => void;
  controller: () => webview.WebviewController;
  coordinatorTasks: () => PinmonyTaskRegistry;
  currentBoardUrl: () => string;
  currentHomePageKey: () => string;
  currentInboxUrl: () => string;
  currentPinUrl: () => string;
  dismissShareSheet: () => void;
  homeStore: () => PinmonyHomeStore;
  inboxStore: () => PinmonyInboxStore;
  isCurrentBoardMenuPin: (pinUrl: string, pageKey: string) => boolean;
  isCurrentMorePin: (pin: string) => boolean;
  isCurrentSearchMenuPin: (pinUrl: string, pageKey: string) => boolean;
  openApiBoards: (requestedPin?: string) => Promise<void>;
  openApiDetailMore: () => Promise<void>;
  pinIdentity: (value: string) => string;
  pinStore: () => PinmonyPinStore;
  rejectOfflineAction: (action: string, message?: string) => boolean;
  retainedBoardContent: () => PinmonyBoardDetail | undefined;
  setRetainedBoardContent: (value: PinmonyBoardDetail | undefined) => PinmonyBoardDetail | undefined;
  sharePinUrl: (url: string, title?: string) => Promise<void>;
  shareBoardPinAfterMenu: (pin: string, page: string) => Promise<void>;
  showMessage: (message: string) => void;
  showNativeSheet: () => boolean;
  setShowNativeSheet: (value: boolean) => boolean;
  singlePinMovePage: () => string;
  setSinglePinMovePage: (value: string) => string;
  webJsonText: (value: string) => string;
}
export class PinmonyPhotoMenuCoordinator {
  private readonly detailReady: PinmonyReadinessGate = new PinmonyReadinessGate();
  private readonly menuReady: PinmonyReadinessGate = new PinmonyReadinessGate();
  private menuRevision: number = 0;
  private menuGeneration: number = 0;
  menuChanged(session: number): void {
    if (session !== this.homeStore.customHomeMenuToken || !this.homeStore.customHomeMenu) return;
    this.menuRevision++;
    this.menuReady.notify();
  }
  notify(): void { this.detailReady.notify(); this.menuReady.notify(); }
  pause(): void { if(this.ports.nativeMenu?.())this.ports.nativePause?.(); this.menuGeneration++; this.menuReady.cancel(); this.cancelHomeDetailMore(); }
  private readonly homeStore: PinmonyHomeStore;
  private readonly inboxStore: PinmonyInboxStore;
  private readonly pinStore: PinmonyPinStore;
  private readonly boardStore: PinmonyBoardStore;
  private readonly ports: PinmonyPhotoMenuCoordinatorPorts;
  constructor(ports: PinmonyPhotoMenuCoordinatorPorts) { this.ports = ports; this.homeStore = ports.homeStore(); this.inboxStore = ports.inboxStore(); this.pinStore = ports.pinStore(); this.boardStore = ports.boardStore(); }
async openCustomHomeMenu(pinUrl: string, pageKey: string, inboxAction: string = '', profilePin: boolean = false): Promise<void> {
    if (this.ports.rejectOfflineAction('share panel'))
        return;
    if(this.ports.nativeMenu?.() && inboxAction === 'share'){await this.ports.nativeShare?.(pinUrl);return;}
    const token: number = ++this.homeStore.customHomeMenuToken;
    this.homeStore.inboxMenuPending = !!inboxAction;
    this.homeStore.homeMenuPin = pinUrl;
    this.homeStore.homeMenuPage = pageKey;
    this.pinStore.sharePin = pinUrl;
    this.pinStore.shareSession = token;
    this.pinStore.moreSession = token;
    this.pinStore.shareTitle = !inboxAction && !profilePin &&
        (pageKey === this.ports.currentHomePageKey() || this.ports.isCurrentBoardMenuPin(pinUrl, pageKey) ||
            this.ports.isCurrentSearchMenuPin(pinUrl, pageKey)) ? PinmonyI18n.message('选项') : PinmonyI18n.message('分享');
    this.pinStore.shareSearchActive = false;
    this.ports.setActiveSheetKind('share');
    this.homeStore.customHomeMenu = { session: token, pinUrl: pinUrl, loading: true, busy: false,
        error: '', feedback: '', options: [], actions: [] };
    this.ports.setShowNativeSheet(true);
    const generation: number = ++this.menuGeneration;
    this.menuReady.cancel();
    let lastSnapshot: string = '';
    try {
        const native: boolean = this.ports.nativeMenu?.() === true;
        const opened: string = native ? 'true' : await this.ports.controller().runJavaScript('window.PinmonyPostApi && ' +
            'window.PinmonyPostApi.homeMenuOpen(' + token + ',' + JSON.stringify(pinUrl) + ',' + JSON.stringify(pageKey) + ')');
        if (generation !== this.menuGeneration || token !== this.homeStore.customHomeMenuToken)
            return;
        if (opened !== 'true' && opened !== '"true"')
            throw new Error('menu unavailable');
        while (generation === this.menuGeneration && token === this.homeStore.customHomeMenuToken && this.homeStore.customHomeMenu &&
            (this.ports.isCurrentBoardMenuPin(pinUrl, pageKey) || this.ports.isCurrentSearchMenuPin(pinUrl, pageKey) || pageKey === this.ports.currentHomePageKey() || profilePin && this.ports.isCurrentMorePin(pinUrl) || !!inboxAction && this.inboxStore.inboxFlow?.screen === 'chat' &&
                pageKey.replace(/\/$/, '') === this.ports.currentInboxUrl().replace(/\/$/, ''))) {
            const revision: number = this.menuRevision;
            let serialized: string = native ? JSON.stringify(await this.ports.nativeRead!(token,pinUrl)) : await this.ports.controller().runJavaScript('JSON.stringify(window.PinmonyPostApi && ' +
                'window.PinmonyPostApi.homeMenuRead(' + token + ',' + JSON.stringify(pinUrl) + '))');
            if (generation !== this.menuGeneration || token !== this.homeStore.customHomeMenuToken)
                return;
            if (serialized.startsWith('"'))
                serialized = JSON.parse(serialized) as string;
            const state: PinmonyHomeMenuState = JSON.parse(serialized) as PinmonyHomeMenuState;
            if (!state || state.session !== token || this.ports.pinIdentity(state.pinUrl) !== this.ports.pinIdentity(pinUrl))
                break;
            if (!inboxAction && !profilePin && (pageKey === this.ports.currentHomePageKey() || this.ports.isCurrentSearchMenuPin(pinUrl, pageKey))) {
                state.options = [];
                state.actions.push({ id: 'home-system-share', label: '分享链接', enabled: !state.loading && !state.error && !state.busy });
            }
            else if (!inboxAction && !profilePin && this.ports.isCurrentBoardMenuPin(pinUrl, pageKey)) {
                const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
                const download: PinmonyHomeMenuOption | undefined = state.actions.find((option: PinmonyHomeMenuOption): boolean => option.id === 'home-download');
                const more: PinmonyHomeMenuOption | undefined = state.actions.find((option: PinmonyHomeMenuOption): boolean => option.id === 'home-see-more');
                const edit: PinmonyHomeMenuOption | undefined = state.actions.find((option: PinmonyHomeMenuOption): boolean => option.id === 'home-edit' && option.enabled);
                state.options = [];
                state.actions = [
                    { id: 'board-menu-cancel-save', label: '取消收藏', enabled: !this.ports.cancelledBoardPins().has(pinUrl) && !state.loading && !state.error && !state.busy &&
                            !!board?.editable && (!board.flow?.phase || board.flow.phase === 'section') && !board.loadingMore && boardVisiblePins(board).some((pin: PinmonyBoardPin): boolean => pin.pinUrl === pinUrl) },
                    { id: 'board-menu-move', label: '移至其他图板', enabled: !state.loading && !state.error && !state.busy &&
                            !!board?.editable && (!board.flow?.phase || board.flow.phase === 'section') && boardVisiblePins(board).some((pin: PinmonyBoardPin): boolean => pin.pinUrl === pinUrl) },
                    { id: 'home-download', label: '下载', enabled: !!download?.enabled },
                    { id: 'home-see-more', label: '查看更多', enabled: !!more?.enabled },
                    { id: 'home-system-share', label: '系统分享', enabled: !state.loading && !state.error && !state.busy }
                ];
                state.actions = state.actions.filter((option: PinmonyHomeMenuOption): boolean => option.enabled);
                if(edit)state.actions.unshift(edit);
                if (board && /\/pins\/$/i.test(board.pageKey)) {
                    state.actions = state.actions.filter((option: PinmonyHomeMenuOption): boolean =>
                        option.id !== 'board-menu-cancel-save' && option.id !== 'board-menu-move');
                }
            }
            if (inboxAction)
                state.actions = state.actions.filter((option: PinmonyHomeMenuOption): boolean => option.id === 'home-save');
            if (profilePin)
                state.actions = state.actions.filter((option: PinmonyHomeMenuOption): boolean => option.id !== 'home-see-more' && option.id !== 'home-see-less');
            const snapshotKey: string = JSON.stringify(state);
            if (snapshotKey !== lastSnapshot) {
                lastSnapshot = snapshotKey;
                this.homeStore.customHomeMenu = state;
            }
            if (inboxAction === 'share' && !state.loading && !state.error) {
                this.homeStore.customHomeMenu = undefined;
                this.pinStore.shareLoading = true;
                const snapshot: string = JSON.stringify({ kind: 'state', session: token, pinUrl: pinUrl,
                    title: '分享', options: state.options, actions: [], contacts: [], query: '' });
                await this.ports.controller().runJavaScript('(function(){ var snapshot=' + snapshot +
                    '; function publish(){ if (!window.PinmonyPostApi || !window.PinmonyShareBridge) return; ' +
                    'window.PinmonyShareBridge.sheetState(JSON.stringify(window.PinmonyPostApi.shareSnapshot(snapshot,publish))); } publish(); ' +
                    'window.PinmonyPostApi.shareSearch(snapshot.session, ""); })()');
                return;
            }
            if (inboxAction === 'save' && !state.loading && !state.error) {
                await this.ports.openApiBoards(pinUrl);
                return;
            }
            if(native)return;
            await this.menuReady.wait(
                (): boolean => generation === this.menuGeneration && token === this.homeStore.customHomeMenuToken && !!this.homeStore.customHomeMenu,
                (): boolean => revision !== this.menuRevision, (): boolean => false, 5000);
            if (generation !== this.menuGeneration || token !== this.homeStore.customHomeMenuToken) return;
        }
        if (generation === this.menuGeneration && token === this.homeStore.customHomeMenuToken)
            this.ports.dismissShareSheet();
    }
    catch (error) {
        if (generation !== this.menuGeneration || token !== this.homeStore.customHomeMenuToken || !this.homeStore.customHomeMenu)
            return;
        this.homeStore.customHomeMenu = { session: token, pinUrl: pinUrl, loading: false, busy: false,
            error: PinmonyI18n.message('无法读取帖子操作，请重试'), feedback: '', options: [], actions: [] };
    }
}

async performCustomHomeAction(id: string): Promise<void> {
    if (this.ports.rejectOfflineAction('home menu action'))
        return;
    const menu: PinmonyHomeMenuState | undefined = this.homeStore.customHomeMenu;
    if (!menu || menu.loading || menu.busy || !this.ports.isCurrentMorePin(menu.pinUrl))
        return;
    if (id === 'board-menu-cancel-save') {
        const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
        if (!board?.editable || !this.ports.isCurrentBoardMenuPin(menu.pinUrl, board.pageKey) ||
            !menu.actions.some((option: PinmonyHomeMenuOption): boolean => option.id === id && option.enabled))
            return;
        const token: number = ++this.homeStore.customHomeMenuToken;
        if(this.ports.nativeBoardContentWrites?.() && this.ports.cancelBoardPin) {
          const nativeCurrent = (): boolean => token === this.homeStore.customHomeMenuToken && this.ports.authStatus() === 'authenticated' &&
            this.homeStore.customHomeMenu === menu && this.boardStore.boardDetail?.pageKey === board.pageKey && this.ports.currentBoardUrl() === board.pageKey;
          menu.busy = true;
          try {
            const error: string = await this.ports.cancelBoardPin(menu.pinUrl,nativeCurrent);
            if(!nativeCurrent())return;
            if(error)menu.error = error;
            else {
              this.ports.cancelledBoardPins().add(menu.pinUrl);
              this.ports.setRetainedBoardContent(this.boardStore.boardDetail);
              this.ports.dismissShareSheet();this.ports.showMessage(PinmonyI18n.message('已取消收藏'));
            }
          }catch (_) {if(nativeCurrent())menu.error = PinmonyI18n.message('取消收藏结果未确认，请关闭后刷新核对；不会重复提交');}
          finally {if(nativeCurrent()){menu.busy = false;menu.actions.forEach((option: PinmonyHomeMenuOption): void => {option.enabled = false;});}}
          return;
        }
        const epoch: number = this.ports.authEpoch();
        const current = (): boolean => token === this.homeStore.customHomeMenuToken && this.ports.authEpoch() === epoch &&
            this.ports.authStatus() === 'authenticated' && this.homeStore.customHomeMenu === menu && this.ports.currentBoardUrl() === board.pageKey;
        menu.busy = true;
        try {
            const args: string = board.session.toString() + ',' + JSON.stringify(board.pageKey);
            const started: string = await this.ports.controller().runJavaScript('window.PinmonyBoardApi.cancelPinStart(' + args + ',' + JSON.stringify(this.ports.pinIdentity(menu.pinUrl)) + ')');
            if (!current())
                return;
            if (started !== 'true' && started !== '"true"')
                throw new Error('not-started');
            for (let attempt: number = 0; attempt < 140; attempt++) {
                if (!current())
                    return;
                const raw: string = await this.ports.controller().runJavaScript('JSON.stringify(window.PinmonyBoardApi.cancelPinRead(' + args + ',' + JSON.stringify(menu.pinUrl) + '))');
                if (!current())
                    return;
                const result: PinmonyHomeMenuState | null = JSON.parse(this.ports.webJsonText(raw)) as PinmonyHomeMenuState | null;
                if (!result)
                    throw new Error('stale');
                if (!result.busy) {
                    if (PinmonyI18n.isText(result.feedback, '已取消收藏')) {
                        this.ports.cancelledBoardPins().add(menu.pinUrl);
                        board.pins = board.pins.map((pin: PinmonyBoardPin): PinmonyBoardPin => {
                            if (pin.pinUrl === menu.pinUrl)
                                pin.cancelled = true;
                            return pin;
                        });
                        this.boardStore.boardDetail = JSON.parse(JSON.stringify(board)) as PinmonyBoardDetail;
                        this.ports.setRetainedBoardContent(board);
                        this.ports.dismissShareSheet();
                        this.ports.showMessage(PinmonyI18n.message('已取消收藏'));
                    }
                    else {
                        menu.error = result.error || PinmonyI18n.message('取消收藏结果未确认，请关闭后刷新核对');
                    }
                    return;
                }
                if (!await this.ports.coordinatorTasks().wait(250))
                    return;
            }
            throw new Error('timeout');
        }
        catch (_) {
            if (current())
                menu.error = PinmonyI18n.message('取消收藏结果未确认，请关闭后刷新核对；不会重复提交');
        }
        finally {
            if (current()) {
                menu.busy = false;
                menu.actions.forEach((option: PinmonyHomeMenuOption) => { option.enabled = false; });
            }
        }
        return;
    }
    if (id === 'board-menu-move') {
        const board: PinmonyBoardDetail | undefined = this.boardStore.boardDetail;
        if (!board?.editable || board.flow?.phase && board.flow.phase !== 'section' || !this.ports.isCurrentBoardMenuPin(menu.pinUrl, board.pageKey) ||
            !menu.actions.some((option: PinmonyHomeMenuOption): boolean => option.id === id && option.enabled))
            return;
        const pin: PinmonyBoardPin | undefined = boardVisiblePins(board).find((item: PinmonyBoardPin): boolean => item.pinUrl === menu.pinUrl);
        if (!pin)
            return;
        this.ports.dismissShareSheet();
        this.ports.setSinglePinMovePage(board.pageKey);
        this.ports.boardOperation('flow', JSON.stringify(board.flow?.phase === 'section' ? {action:'sectionSingleMove',value:pin.id} : { action: 'targets', value: [pin.id] }));
        return;
    }
    if (id === 'home-system-share') {
        if (this.ports.authStatus() !== 'authenticated' || this.ports.activeSheetKind() !== 'share' ||
            !menu.actions.some((option: PinmonyHomeMenuOption): boolean => option.id === id && option.enabled))
            return;
        const pinUrl: string = menu.pinUrl;
        const page: string = this.homeStore.homeMenuPage;
        if (this.ports.isCurrentBoardMenuPin(pinUrl, page)) {
            await this.ports.shareBoardPinAfterMenu(pinUrl, page);
            return;
        }
        this.ports.dismissShareSheet();
        await this.ports.sharePinUrl(pinUrl);
        return;
    }
    if (id === 'home-save') {
        if (!menu.actions.some((option: PinmonyHomeMenuOption): boolean => option.id === id && option.enabled))
            return;
        this.homeStore.customHomeMenuToken++;
        await this.ports.openApiBoards(menu.pinUrl);
        return;
    }
    if(this.ports.nativeMenu?.()){
        if(!menu.actions.some((option: PinmonyHomeMenuOption): boolean => option.id === id && option.enabled))return;
        menu.busy = true;
        try{await this.ports.nativeAction?.(id);}
        finally{if(this.homeStore.customHomeMenu === menu){menu.busy = false;menu.actions = menu.actions.map((option: PinmonyHomeMenuOption): PinmonyHomeMenuOption => ({id:option.id,label:option.label,enabled:option.enabled && (!/see-(?:more|less)$/.test(id) || option.id !== id)}));}}
        return;
    }
    try {
        const result: string = await this.ports.controller().runJavaScript('window.PinmonyPostApi && ' +
            'window.PinmonyPostApi.homeMenuAction(' + menu.session + ',' + JSON.stringify(menu.pinUrl) + ',' + JSON.stringify(id) + ')');
        if (menu.session !== this.homeStore.customHomeMenu?.session)
            return;
        if (result !== 'true' && result !== '"true"')
            this.ports.showMessage(PinmonyI18n.message('该操作暂不可用，请重试'));
    }
    catch (error) {
        if (menu.session === this.homeStore.customHomeMenu?.session && this.ports.activeSheetKind() === 'share') this.ports.showMessage(PinmonyI18n.message('操作失败，请重试'));
    }
}

async openHomeMoreViaDetail(pinUrl: string, returnUrl: string): Promise<void> {
    if(this.ports.nativeMenu?.()){await this.openCustomHomeMenu(pinUrl,returnUrl);return;}
    this.ports.clearRootTabGuard('home-more-detail');
    if (this.ports.rejectOfflineAction('home menu detail'))
        return;
    const identity: string = this.ports.pinIdentity(pinUrl);
    if (!identity)
        return;
    const token: number = ++this.homeStore.homeDetailMoreToken;
    this.homeStore.pendingHomeMorePin = pinUrl;
    this.pinStore.detailReturnUrl = returnUrl;
    let dispatched: boolean = false;
    try {
        this.ports.controller().loadUrl(pinUrl);
        const current = (): boolean => token === this.homeStore.homeDetailMoreToken;
        const ready = (): boolean => !!this.pinStore.detail && this.pinStore.detailActionsReady &&
          this.ports.pinIdentity(this.pinStore.detail.pinUrl) === identity && this.ports.pinIdentity(this.ports.currentPinUrl()) === identity;
        const available: boolean = await this.detailReady.wait(current, ready, (): boolean => false, 15000);
        if (!current()) return;
        const detail: PinmonyDetailSnapshot | undefined = this.pinStore.detail;
        if (available && detail) {
          const more: PinmonyDetailAction | undefined = detail.actions.find((action: PinmonyDetailAction): boolean => action.kind === 'more' && action.enabled);
          if (more) {
            if (detail.dataSource === 'api') {
              await this.ports.openApiDetailMore();
              if (!current()) return;
              dispatched = this.ports.activeSheetKind() === 'more' && this.pinStore.moreApiMode;
            } else {
              const result: string = await this.ports.controller().runJavaScript('window.PinmonyDetailMore && window.PinmonyDetailMore(' + detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' + JSON.stringify(more.id) + ')');
              if (!current()) return;
              dispatched = result === 'true' || result === '"true"';
            }
          }
        }
        if (token !== this.homeStore.homeDetailMoreToken)
            return;
        this.cancelHomeDetailMore();
        if (dispatched)
            return;
        this.ports.showMessage(PinmonyI18n.message('这张 Pin 的网页选项未能加载，请在详情页重试'));
    }
    catch (error) {
        if (token !== this.homeStore.homeDetailMoreToken)
            return;
        this.cancelHomeDetailMore();
        this.ports.showMessage(PinmonyI18n.message('无法加载这张 Pin 的详情选项，请重试'));
    }
}

cancelHomeDetailMore(): void {
    this.homeStore.homeDetailMoreToken++;
    this.homeStore.pendingHomeMorePin = '';
    this.detailReady.cancel();
}
}
