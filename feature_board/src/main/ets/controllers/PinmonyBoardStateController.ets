import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog, PinmonyTaskRegistry } from 'common_foundation';
import { PinmonyBoardStore } from '../stores/PinmonyBoardStore';
import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardSection } from '../models/PinmonyBoardDetail';

export interface PinmonyBoardStatePorts {
  authenticated: () => boolean;
  foreground: () => boolean;
  rootOnly: () => boolean;
  currentBoard: () => string;
  boardAddress: (address: string) => string;
  profileAddress: (address: string) => string;
  pinAddress: (address: string) => string;
  addressKey: (address: string) => string;
  publishReturn: () => string;
  hasDetail: () => boolean;
  backTarget: () => string;
  retainedContent: () => PinmonyBoardDetail | undefined;
  movePage: () => string;
  clearMovePage: () => void;
  confirmInvitation: (page: string) => void;
  invalidateProfile: () => void;
  feedback: (message: string) => void;
  closeFlow: () => void;
  back: () => void;
  navigate: (page: string) => void;
}

export class PinmonyBoardStateController {
  private readonly store: PinmonyBoardStore;
  private readonly ports: PinmonyBoardStatePorts;
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  constructor(store: PinmonyBoardStore, ports: PinmonyBoardStatePorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.tasks.invalidate(); }
  resume(): void {
    const board: PinmonyBoardDetail | undefined = this.store.boardDetail;
    if (board?.nativeReadsReady === undefined && board?.loading && board.session === 0 && board.pageKey === this.ports.currentBoard() &&
        this.ports.authenticated() && this.ports.foreground() && !this.ports.rootOnly()) this.scheduleTimeout(board.pageKey);
  }
  syncRoute(address: string): void {
    if (this.ports.rootOnly() || !this.ports.authenticated() || !this.ports.foreground()) return;
    const page: string = this.ports.boardAddress(address);
    if (this.ports.publishReturn() && this.store.boardDetail?.pageKey === this.ports.publishReturn() &&
        this.ports.profileAddress(address)) {
      this.store.presentationPage = this.ports.publishReturn();
      this.store.presentationOnly = true;
      this.store.boardDetail.session = 0;
      this.store.boardDetail.flow = undefined;
      return;
    }
    if (this.ports.pinAddress(address) && this.store.boardDetail) {
      this.pause();
      // Keep the same ArkUI instance under the child Pin, including its Scroller.
      this.store.presentationPage = this.store.boardDetail.pageKey;
      this.store.presentationOnly = true;
      this.store.boardDetail.session = 0;
      this.store.boardDetail.editable = false;
      this.store.boardDetail.flow = undefined;
      this.store.boardDetail.loadingMore = false;
      return;
    }
    if (this.store.pendingBoardUrl) {
      if (page === this.store.pendingBoardUrl) {
        // onPageBegin can precede getUrl(); keep covering the old document until the target route is current.
        if (this.ports.currentBoard() !== page) return;
        this.store.pendingBoardUrl = '';
        this.store.pendingBoardSource = '';
        this.store.boardOpeningToken++;
      } else if (this.ports.addressKey(address) === this.ports.addressKey(this.store.pendingBoardSource)) {
        return;
      } else {
        this.store.pendingBoardUrl = '';
        this.store.pendingBoardSource = '';
        this.store.boardOpeningToken++;
      }
    }
    if (page && this.store.boardDetail?.pageKey === page) {
      if (this.store.boardDetail.session === 0 && this.store.boardDetail.loading && this.ports.currentBoard() === page)
        this.scheduleTimeout(page);
      return;
    }
    this.pause();
    this.store.presentationPage = page;
    this.store.presentationOnly = false;
    const collectionTitle: string = /\/pins\/$/i.test(page) ? '所有 Pin 图' : '图板';
    this.store.boardDetail = page ? { kind: 'state', session: 0, pageKey: page, boardId: '', title: collectionTitle,
      pinCount: '', ownerName: '', ownerAvatar: '', loading: true, loadingMore: false,
      ready: false, error: '', hasMore: false, pins: [] } : undefined;
    if (page) {
      this.scheduleTimeout(page);
    }
  }

  private scheduleTimeout(page: string): void {
    const generation: number = this.generation;
    this.tasks.invalidate();
    this.tasks.timeout((): void => {
        if (generation !== this.generation || !this.ports.authenticated() || !this.ports.foreground() || this.ports.rootOnly()) return;
        if (this.ports.currentBoard() !== page || this.store.boardDetail?.pageKey !== page || this.store.boardDetail.session !== 0 || this.store.boardDetail.nativeReadsReady !== undefined) return;
        const board: PinmonyBoardDetail = this.store.boardDetail;
        this.store.boardDetail = { kind: board.kind, session: board.session, pageKey: board.pageKey,
          boardId: board.boardId, title: board.title, pinCount: board.pinCount,
          ownerName: board.ownerName, ownerAvatar: board.ownerAvatar, ownerUrl: board.ownerUrl, loading: false,
          loadingMore: board.loadingMore, ready: board.ready, error: PinmonyI18n.message('图板接口尚未就绪，请重试'),
          hasMore: board.hasMore, pins: board.pins };
      }, 20000);
  }

  private validSectionPin(pin: PinmonyBoardPin): boolean {
    return !!pin && typeof pin.id === 'string' && /^\d{1,30}$/.test(pin.id) && typeof pin.title === 'string' && pin.title.length <= 300 &&
      typeof pin.pinUrl === 'string' && /^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pin.pinUrl) && pin.pinUrl.endsWith('/pin/' + pin.id + '/') &&
      typeof pin.imageUrl === 'string' && pin.imageUrl.length <= 2048 && /^https:\/\/i\.pinimg\.com\//.test(pin.imageUrl) &&
      Number.isFinite(pin.imageWidth) && pin.imageWidth > 0 && Number.isFinite(pin.imageHeight) && pin.imageHeight > 0 &&
      (pin.duration === undefined || pin.duration === '' || typeof pin.duration === 'string' && /^\d{1,4}:\d{2}$/.test(pin.duration));
  }

  update(value: string): void {
    if (this.ports.rootOnly() || !this.ports.authenticated() || !this.ports.foreground()) return;
    if (this.ports.hasDetail()) return;
    if (this.ports.backTarget() && this.ports.currentBoard() !== this.ports.backTarget()) return;
    try {
      const message: PinmonyBoardDetail = JSON.parse(value) as PinmonyBoardDetail;
      if (!message || message.kind !== 'state' || typeof message.session !== 'number' || !Number.isInteger(message.session) || message.session < 0 ||
          typeof message.loading !== 'boolean' || typeof message.loadingMore !== 'boolean' || typeof message.ready !== 'boolean' || typeof message.hasMore !== 'boolean' ||
          message.pageKey !== this.ports.currentBoard() || !Array.isArray(message.pins)) return;
      if (typeof message.title !== 'string' || typeof message.pinCount !== 'string' ||
          typeof message.ownerName !== 'string' || typeof message.ownerAvatar !== 'string' ||
          typeof message.error !== 'string' || !message.pins.every((pin): boolean =>
            !!pin && /^\d+$/.test(pin.id) && typeof pin.title === 'string' && pin.title.length <= 300 && (pin.creatorName === undefined || typeof pin.creatorName === 'string' && pin.creatorName.length <= 300) && (pin.duration === undefined || typeof pin.duration === 'string' && /^\d{1,4}:\d{2}$/.test(pin.duration) || pin.duration === '') &&
            /^https:\/\//i.test(pin.imageUrl) && pin.imageWidth > 0 && pin.imageHeight > 0)) return;
      if (message.privacy !== undefined && message.privacy !== 'public' && message.privacy !== 'secret') return;
      if (message.nextPage !== undefined && (typeof message.nextPage !== 'string' || message.nextPage.length > 2048)) return;
      if (message.memberAvatar !== undefined && (typeof message.memberAvatar !== 'string' || message.memberAvatar.length > 2048 ||
          !!message.memberAvatar && !/^https:\/\//i.test(message.memberAvatar))) return;
      if (message.revision !== undefined && (typeof message.revision !== 'number' || !Number.isFinite(message.revision) || message.revision < 0)) return;
      if (this.store.boardDetail?.pageKey === message.pageKey && message.session < this.store.boardDetail.session) return;
      if (this.store.presentationOnly && !message.ready && this.store.boardDetail?.ready) {
        // Preparing the new session must not collapse the retained list and scroll position.
        this.store.boardDetail.error = message.error;
        return;
      }
      if (message.flow && (!['', 'select', 'targets', 'ideas', 'section', 'edit', 'archive', 'archived', 'deleted', 'left', 'unfollowed'].includes(message.flow.phase) ||
          typeof message.flow.loading !== 'boolean' || typeof message.flow.busy !== 'boolean' ||
          typeof message.flow.uncertain !== 'boolean' || typeof message.flow.error !== 'string' || message.flow.error.length > 500 ||
          typeof message.flow.description !== 'string' || typeof message.flow.privacy !== 'string' ||
          !Array.isArray(message.flow.pins) || message.flow.pins.length > 500 ||
          !Array.isArray(message.flow.targets) || message.flow.targets.length > 500 ||
          !Array.isArray(message.flow.saved) || message.flow.saved.length > 500 ||
          !message.flow.pins.every((pin): boolean => !!pin && /^\d+$/.test(pin.id) &&
            typeof pin.title === 'string' && /^https:\/\//i.test(pin.imageUrl) && pin.imageWidth > 0 && pin.imageHeight > 0) ||
          !message.flow.targets.every((target): boolean => !!target && /^\d+$/.test(target.id) &&
            typeof target.title === 'string' && target.title.length <= 300 &&
            typeof target.imageUrl === 'string' && (!target.imageUrl || /^https:\/\//i.test(target.imageUrl))) ||
          !message.flow.saved.every((id): boolean => typeof id === 'string' && /^\d+$/.test(id)))) return;
      if (message.flow?.phase === 'section' && (typeof message.flow.sectionId !== 'string' || !/^\d+$/.test(message.flow.sectionId) || typeof message.flow.sectionTitle !== 'string' || message.flow.sectionTitle.length > 300)) return;
      // The board bridge emits an initial loading snapshot before it has
      // resolved the collection owner. Keep the route-derived title during
      // that interval instead of briefly falling back to "图板".
      const existingTitle: string = this.store.boardDetail?.title ||
        (/\/pins\/$/i.test(message.pageKey) ? '所有 Pin 图' : '图板');
      const changed: boolean = message.session === this.store.boardDetail?.session &&
        (message.revision || 0) > (this.store.boardDetail?.revision || 0);
      if (message.pageKey === this.ports.movePage() && message.ready && !message.flow?.phase) this.ports.clearMovePage();
      const retained: PinmonyBoardDetail | undefined = this.ports.retainedContent();
      if (retained?.pageKey === message.pageKey && retained.ready && !message.flow?.phase) {
        message.pins = retained.pins;
        message.pinCount = retained.pinCount;
      }
      PinmonyRuntimeLog.info('BoardRole: owner=' + (message.editable === true).toString() +
        ' collaborator=' + (message.collaborator === true).toString() + ' contribute=' + (message.canContribute === true).toString() +
        ' avatars=' + (Array.isArray(message.collaboratorAvatars) ? message.collaboratorAvatars.length : 0).toString());
      if (message.session > 0 || !message.loading) this.tasks.invalidate();
      this.store.boardDetail = { kind: message.kind, session: message.session, nativeVersion: message.nativeVersion, nativeRecoveryVersion: message.nativeRecoveryVersion, nativeReadsReady: message.nativeReadsReady,
        pageKey: message.pageKey, boardId: message.boardId, title: message.title || existingTitle,
        pinCount: !message.ready && !message.pinCount && this.store.boardDetail?.pageKey === message.pageKey ? this.store.boardDetail.pinCount : message.pinCount,
        privacy: message.privacy, ownerName: message.ownerName, ownerAvatar: message.ownerAvatar, ownerUrl: this.ports.profileAddress(message.ownerUrl || ''),
        loading: message.loading, loadingMore: message.loadingMore, refreshing: message.refreshing,
        ready: message.ready, error: message.error, hasMore: message.hasMore, pins: message.pins,
        chatMemberCount: Number.isInteger(message.chatMemberCount) ? message.chatMemberCount : 0,
        chatPeer: message.chatPeer && /^\d+$/.test(message.chatPeer.id) && typeof message.chatPeer.name === 'string' && message.chatPeer.name.length <= 300 && typeof message.chatPeer.username === 'string' && /^[a-zA-Z0-9_]*$/.test(message.chatPeer.username) && typeof message.chatPeer.avatar === 'string' && message.chatPeer.avatar.length <= 2048 && (!message.chatPeer.avatar || /^https:\/\//i.test(message.chatPeer.avatar)) ? message.chatPeer : undefined,
        featured: message.featured === true,
        featuredCreator: message.featuredCreator === true,
        sponsored: message.sponsored === true,
        ownerVerified: message.ownerVerified === true,
        sectionCount: Number.isInteger(message.sectionCount) && (message.sectionCount || 0) > 0 && (message.sectionCount || 0) <= 10000 ? message.sectionCount : 0,
        sections: Array.isArray(message.sections) ? message.sections.filter((section): boolean => !!section && /^\d+$/.test(section.id) && typeof section.title === 'string' && section.title.length <= 300 && (section.pinCount === undefined || typeof section.pinCount === 'number' && Number.isFinite(section.pinCount) && section.pinCount >= 0) && Array.isArray(section.images) && section.images.length <= 2 && section.images.every((url: string): boolean => typeof url === 'string' && url.length <= 2048 && /^https:\/\/i\.pinimg\.com\//.test(url))).slice(0, 100).map((section: PinmonyBoardSection): PinmonyBoardSection => ({
          id: section.id, title: section.title, pinCount: section.pinCount, images: section.images,
          pins: Array.isArray(section.pins) ? section.pins.filter((pin: PinmonyBoardPin): boolean => this.validSectionPin(pin)).slice(0, 2) : []
        })) : [],
        sectionsError: typeof message.sectionsError === 'string' ? message.sectionsError.slice(0, 300) : '',
        subtitle: typeof message.subtitle === 'string' ? message.subtitle.slice(0, 300) : '',
        description: typeof message.description === 'string' ? message.description.slice(0, 2000) : '',
        headerImage: typeof message.headerImage === 'string' && /^https:\/\/i\.pinimg\.com\//.test(message.headerImage) ? message.headerImage.slice(0, 2048) : '',
        editable: message.editable, canContribute: message.canContribute === true, collaborator: message.collaborator === true,
        collaboratorAvatars: Array.isArray(message.collaboratorAvatars) ? message.collaboratorAvatars.filter((url: string): boolean => typeof url === 'string' && url.length <= 2048 && /^https:\/\//i.test(url)).slice(0, 6) : [], flow: message.flow, memberAvatar: message.memberAvatar, revision: message.revision };
      this.store.presentationOnly = !message.ready;
      if (message.ready) this.ports.confirmInvitation(message.pageKey);
      if (message.ready) PinmonyRuntimeLog.info('BoardReturn: session-confirmed');
      if (changed) this.ports.invalidateProfile();
      if (message.flow?.phase === 'unfollowed') {
        this.ports.feedback(PinmonyI18n.message('已取消关注'));
        this.ports.closeFlow();
        return;
      }
      if (message.flow?.phase === 'deleted' || message.flow?.phase === 'left') {
        if (message.flow.phase === 'left') this.ports.feedback(PinmonyI18n.message('已离开图板'));
        this.store.boardDetail.flow = undefined;
        this.ports.back();
        return;
      }
      if (message.nextPage && this.ports.boardAddress(message.nextPage) === message.nextPage &&
          /^https:\/\/(?:www|uk)\.pinterest\.com\//.test(message.nextPage) &&
          message.nextPage.split('/')[2] === message.pageKey.split('/')[2] && message.nextPage !== message.pageKey) {
        if (this.store.boardReturnPage === message.pageKey) this.store.boardReturnPage = message.nextPage;
        this.store.pendingBoardUrl = message.nextPage;
        this.store.pendingBoardSource = message.pageKey;
        this.ports.navigate(message.nextPage);
        return;
      }
      if (this.store.pendingBoardUrl === message.pageKey) {
        this.store.pendingBoardUrl = '';
        this.store.pendingBoardSource = '';
        this.store.boardOpeningToken++;
      }
    } catch (_) { PinmonyRuntimeLog.warn('Pinmony: invalid board state'); }
  }

}
