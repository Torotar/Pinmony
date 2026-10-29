import { PinmonyActionNotice } from 'common_ui';
import { HdsSnackBar } from '@kit.UIDesignKit';
import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n, PinmonyProfileLayoutPreference } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardTarget, PinmonyBoardSection, PinmonyBoardCreator } from '../models/PinmonyBoardDetail';
import { boardSectionPreviewImages } from '../services/PinmonyBoardPresentation';
import { PinmonyDraggablePublishButton } from './PinmonyDraggablePublishButton';
import { PinmonyBoardCoverContent } from './PinmonyBoardCoverContent';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardPlaceholder, PinmonyLoadingOverlay, PinmonyBoardPickerRow, PinmonyBoardPickerFooter } from 'common_ui';
import { HdsTabs, HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions, SnackBarIconType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

interface BoardTitleMenuItem {
  content: BoardTitleMenuContent;
}

interface BoardTitleMenuContent {
  icon: Resource | SymbolGlyphModifier;
  label: string;
  isEnabled: boolean;
  action: () => void;
}

interface BoardEditValues {
  name: string;
  description: string;
  privacy: string;
  recommend: boolean;
  invites: boolean;
  requests: boolean;
}

interface BoardSurfaceAction {
  action: string;
  value?: string[];
}

interface BoardSurfaceParams {
  board: PinmonyBoardDetail;
}

const BOARD_ORGANIZE_PAGE_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 180, curve: Curve.EaseOut }),
  TransitionEffect.translate({ x: '100%' }).animation({ duration: 150, curve: Curve.EaseIn }));

@Component
export struct PinmonyBoardPage {
  @Prop discoveryBoard: boolean = false;
  @Prop profileBoard: boolean = false;
  @Prop singlePinMove: boolean = false;
  @Prop snapshot: PinmonyBoardDetail;
  @Prop invitationName: string = '';
  @Prop invitationAvatar: string = '';
  @Prop invitationVisible: boolean = false;
  @Prop invitationBusy: boolean = false;
  @Prop joinedAvatar: string = '';
  @State private retainedBoard: PinmonyBoardDetail | undefined = undefined;
  @State private retainedSelection: PinmonyBoardDetail | undefined = undefined;
  @State private retainedEdit: PinmonyBoardDetail | undefined = undefined;
  @State private targetSelectedIds: string[] = [];
  onAction?: (value: string) => void;
  onUser?: (url: string) => void;
  onBack?: () => void;
  onPin?: (id: string) => void;
  onMore?: (id: string) => void;
  onFavorite?: (id: string) => Promise<void>;
  onCollaborators?: () => void;
  onMessage?: () => void;
  onAcceptInvitation: () => void = () => {};
  onDismissInvitation: () => void = () => {};
  onShare?: () => void;
  onPublish?: () => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;

  private organizing(): boolean {
    const phase: string = this.snapshot.flow?.phase || '';
    return !!this.retainedBoard && this.retainedBoard.pageKey === this.snapshot.pageKey && !this.singlePinMove &&
      (phase === 'select' || phase === 'sectionSelect' || phase === 'targets');
  }

  private targeting(): boolean {
    return this.organizing() && this.snapshot.flow?.phase === 'targets' && !!this.retainedSelection;
  }

  private editing(): boolean {
    return !!this.retainedBoard && this.retainedBoard.pageKey === this.snapshot.pageKey &&
      this.retainedBoard.nativeAccountGeneration === this.snapshot.nativeAccountGeneration &&
      this.snapshot.flow?.phase === 'edit';
  }

  private covering(): boolean {
    return this.editing() && !!this.retainedEdit && !!this.snapshot.flow?.cover;
  }

  private dispatch(value: string): void {
    try {
      const action: BoardSurfaceAction = JSON.parse(value) as BoardSurfaceAction;
      if ((action.action === 'select' || action.action === 'sectionOrganize' || action.action === 'edit') &&
          !this.organizing() && !this.editing()) {
        this.retainedBoard = JSON.parse(JSON.stringify(this.snapshot)) as PinmonyBoardDetail;
      }
      if (action.action === 'targets' && this.organizing() && this.snapshot.flow?.phase !== 'targets') {
        this.retainedSelection = JSON.parse(JSON.stringify(this.snapshot)) as PinmonyBoardDetail;
        this.targetSelectedIds = Array.isArray(action.value) ? action.value.slice() : [];
      }
      if ((action.action === 'coverOpen' || action.action === 'coverAdjust') && this.editing() && !this.snapshot.flow?.cover) {
        this.retainedEdit = JSON.parse(JSON.stringify(this.snapshot)) as PinmonyBoardDetail;
      }
    } catch (_) { /* Leave validation to the existing action handler. */ }
    if (this.onAction) this.onAction(value);
  }

  @Builder
  private boardSurface($$: BoardSurfaceParams) {
    PinmonyBoardSurface({ snapshot: $$.board, profileBoard: this.profileBoard, discoveryBoard: this.discoveryBoard,
      initialSelectedIds: $$.board.flow?.phase === 'targets' ? this.targetSelectedIds : [],
      singlePinMove: this.singlePinMove, invitationName: this.invitationName, invitationAvatar: this.invitationAvatar,
      invitationVisible: this.invitationVisible, invitationBusy: this.invitationBusy, joinedAvatar: this.joinedAvatar,
      onAction: (value: string): void => this.dispatch(value), onUser: this.onUser, onBack: this.onBack,
      onPin: this.onPin, onMore: this.onMore, onFavorite: this.onFavorite, onCollaborators: this.onCollaborators,
      onMessage: this.onMessage, onAcceptInvitation: this.onAcceptInvitation, onDismissInvitation: this.onDismissInvitation,
      onShare: this.onShare, onPublish: this.onPublish, onLoadMore: this.onLoadMore, onRetry: this.onRetry,
      onRefresh: this.onRefresh })
      .width('100%').height('100%')
  }

  build() {
    Stack() {
      Column() { this.boardSurface({ board: this.organizing() || this.editing() ? this.retainedBoard! : this.snapshot }) }
        .width('100%').height('100%')
        .hitTestBehavior(this.organizing() || this.editing() ? HitTestMode.None : HitTestMode.Default)
        .accessibilityLevel(this.organizing() || this.editing() ? 'no-hide-descendants' : 'auto')
      if (this.organizing()) {
        Column() { this.boardSurface({ board: this.targeting() ? this.retainedSelection! : this.snapshot }) }
          .width('100%').height('100%')
          .hitTestBehavior(this.targeting() ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.targeting() ? 'no-hide-descendants' : 'auto')
          .transition(BOARD_ORGANIZE_PAGE_TRANSITION)
      }
      if (this.targeting()) {
        Column() { this.boardSurface({ board: this.snapshot }) }
          .width('100%').height('100%')
          .transition(BOARD_ORGANIZE_PAGE_TRANSITION)
      }
      if (this.editing()) {
        Column() { this.boardSurface({ board: this.covering() ? this.retainedEdit! : this.snapshot }) }
          .width('100%').height('100%')
          .hitTestBehavior(this.covering() ? HitTestMode.None : HitTestMode.Default)
          .accessibilityLevel(this.covering() ? 'no-hide-descendants' : 'auto')
          .transition(BOARD_ORGANIZE_PAGE_TRANSITION)
      }
      if (this.covering()) {
        Column() { this.boardSurface({ board: this.snapshot }) }
          .width('100%').height('100%')
          .transition(BOARD_ORGANIZE_PAGE_TRANSITION)
      }
    }.width('100%').height('100%')
  }
}

@Component
struct PinmonyBoardSurface {
  @StorageLink('profileLegacyLayout') private legacyProfile: boolean = false;
  @State private viewOpen: boolean = false;
  @StorageLink('pinmonyBoardDensity') private density: number = 1;
  private viewPage: string = '';
  private viewScope: string = '';
  @State private publishAreaWidth: number = 0;
  @State private publishAreaHeight: number = 0;
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop discoveryBoard: boolean = false;
  @Prop profileBoard: boolean = false;
  @Prop @Watch('snapshotChanged') singlePinMove: boolean = false;
  @Prop initialSelectedIds: string[] = [];
  @Prop @Watch('snapshotChanged') snapshot: PinmonyBoardDetail;
  @State private moveSheetOpen: boolean = false;
  @State private menuOpen: boolean = false;
  @State private mergeOpen: boolean = false;
  @State private privacyOpen: boolean = false;
  private privacyPage: string = '';
  @State private headerScrolled: boolean = false;
  @State private archiveOpen: boolean = false;
  @State private selectedIds: string[] = [];
  @State private editName: string = '';
  @State private editDescription: string = '';
  @State private secret: boolean = false;
  @State private recommend: boolean = false;
  @State private invites: boolean = false;
  @State private requests: boolean = false;
  @State private coverPreviewReady: boolean = false;
  @State private coverPreviewLoading: boolean = false;
  private editingSession: string = '';
  private selectionSession: string = '';
  private pendingSectionEditKey: string = '';
  private pendingSectionShareKey: string = '';
  @State private sectionEditName: string = '';
  private savedSession: string = '';
  private confirmedSaved: string[] = [];
  private savedSnack: HdsSnackBar | undefined = undefined;
  onAction?: (value: string) => void;
  onUser?: (url: string) => void;
  onBack?: () => void;
  onPin?: (id: string) => void;
  onMore?: (id: string) => void;
  onFavorite?: (id: string) => Promise<void>;
  @State private favoritePending: string = '';
  onCollaborators?: () => void;
  onMessage?: () => void;
  @Prop invitationName: string = '';
  @Prop invitationAvatar: string = '';
  @Prop invitationVisible: boolean = false;
  @Prop invitationBusy: boolean = false;
  @Prop joinedAvatar: string = '';
  onAcceptInvitation: () => void = () => {};
  onDismissInvitation: () => void = () => {};
  onShare?: () => void;
  onPublish?: () => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  @State private creatingTarget: boolean = false;
  @State private targetName: string = '';
  @State private creatingBoardTarget: boolean = false;
  @State private boardTargetName: string = '';
  @State private boardTargetSecret: boolean = false;
  @State private boardCreateSubmitted: boolean = false;
  @State private sectionMotionX: number = 0;
  @State private sectionMotionBusy: boolean = false;
  private sectionMotionWidth: number = 0;
  private sectionEntryPending: boolean = false;
  private sectionMotionEpoch: number = 0;
  private boardCreateStarted: boolean = false;
  private readonly boardPathStack: NavPathStack = new NavPathStack();
  private parentScroller: Scroller = new Scroller();
  private flowScroller: Scroller = new Scroller();
  private targetScroller: Scroller = new Scroller();
  private coverScroller: Scroller = new Scroller();
  private readonly sectionScrollers: Map<string, Scroller> = new Map<string, Scroller>();
  private scrollOwner: string = '';
  private visibleScrollScope: string = '';
  private readonly scrollOffsets: Map<string, number> = new Map<string, number>();
  private scrollRestoreToken: number = 0;
  private restoringScroll: boolean = false;

  private scrollScope(): string {return this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration ?? this.snapshot.session).toString() + ':' + (this.snapshot.flow?.cover ? 'cover' : this.phase() === 'section' ? 'section:' + (this.snapshot.flow?.sectionId || '') : this.phase() || 'parent');}
  private restoreContentScroll(): void {
    const scope: string = this.scrollScope();
    if(scope === this.visibleScrollScope && !this.restoringScroll)return;
    this.visibleScrollScope = scope;this.restoringScroll = true;
    const token: number = ++this.scrollRestoreToken;
    if(this.snapshot.flow?.loading || this.snapshot.loading)return;
    const offset: number = this.scrollOffsets.get(scope) || 0;
    this.headerScrolled = offset > 180;
    setTimeout((): void => {
      if(token !== this.scrollRestoreToken || scope !== this.scrollScope())return;
      this.contentScroll().scrollTo({xOffset:0,yOffset:offset,animation:false});this.restoringScroll = false;
    }, 16);
  }

  private contentScroll(): Scroller {
    const owner: string = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration ?? this.snapshot.session).toString();
    if(owner !== this.scrollOwner){this.scrollOwner = owner;this.parentScroller = new Scroller();this.flowScroller = new Scroller();this.coverScroller = new Scroller();this.sectionScrollers.clear();this.scrollOffsets.clear();}
    if(this.snapshot.flow?.cover)return this.coverScroller;
    if(!this.phase())return this.parentScroller;
    if(this.phase() !== 'section' || !this.snapshot.flow?.sectionId)return this.flowScroller;
    const id: string = this.snapshot.flow.sectionId;
    let scroller: Scroller | undefined = this.sectionScrollers.get(id);
    if(!scroller){if(this.sectionScrollers.size >= 20)this.sectionScrollers.delete(this.sectionScrollers.keys().next().value!);scroller = new Scroller();this.sectionScrollers.set(id,scroller);}
    return scroller;
  }

  aboutToAppear(): void {
    this.moveSheetOpen = this.singlePinMove && this.snapshot.flow?.phase === 'targets';
    if (this.snapshot.flow?.phase === 'targets') {
      this.selectedIds = this.initialSelectedIds.slice();
      this.selectionSession = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration ?? this.snapshot.session).toString();
    }
    this.contentScroll();this.restoreContentScroll();
    this.savedSession = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration === undefined ? this.snapshot.session.toString() : 'native-' + this.snapshot.nativeAccountGeneration.toString());
    this.confirmedSaved = (this.snapshot.flow?.saved || []).slice();
    this.syncEditValues();
    this.boardPathStack.clear();
    this.boardPathStack.pushPath({ name: 'pin-web-board' }, false);
  }

  private snapshotChanged(): void {
    this.moveSheetOpen = this.singlePinMove && this.snapshot.flow?.phase === 'targets';
    if (this.sectionEntryPending && this.phase() === 'section') {
      this.sectionEntryPending = false;
      if (this.sectionMotionWidth > 0) {
        this.sectionMotionX = this.sectionMotionWidth;
        this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.sectionMotionX = 0; });
      }
    }
    this.contentScroll();this.restoreContentScroll();
    this.updateSavedFeedback();
    if (this.snapshot.flow?.phase === 'archive' && !this.archiveOpen && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)
      this.confirmArchive();
    if (this.archiveOpen && this.snapshot.flow?.phase !== 'archive') { this.menuOpen = false; this.archiveOpen = false; }
    if (!this.phase()) this.selectedIds = [];
    if (this.snapshot.flow?.phase !== 'targets') { this.creatingTarget = false; this.creatingBoardTarget = false; }
    if (this.boardCreateSubmitted && this.snapshot.flow?.busy) this.boardCreateStarted = true;
    if (this.boardCreateSubmitted && this.boardCreateStarted && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) {
      this.boardCreateSubmitted = false;
      this.boardCreateStarted = false;
      if (!this.snapshot.flow?.error) { this.creatingBoardTarget = false; this.boardTargetName = ''; this.boardTargetSecret = false; }
    }
    const selection: string = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration ?? this.snapshot.session).toString();
    if (this.selectionSession !== selection) {
      this.selectionSession = selection; this.selectedIds = []; this.menuOpen = false;
    }
    this.syncEditValues();
  }

  private syncEditValues(): void {
    const identity: string = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration === undefined ?
      this.snapshot.session.toString() : 'native-' + this.snapshot.nativeAccountGeneration.toString());
    if (this.phase() === 'edit' && !this.snapshot.flow?.loading && this.editingSession !== identity) {
      this.editingSession = identity;
      this.editName = this.snapshot.title; this.editDescription = this.snapshot.flow?.description || '';
      this.secret = this.snapshot.flow?.privacy === 'secret';
      this.recommend = this.snapshot.flow?.recommend === true;
      this.invites = this.snapshot.flow?.invites === true; this.requests = this.snapshot.flow?.requests === true;
    }
    if (this.phase() !== 'edit') this.editingSession = '';
  }

  aboutToDisappear(): void { this.scrollRestoreToken++;this.sectionMotionEpoch++;this.savedSnack?.dismiss(); }

  private updateSavedFeedback(): void {
    const session: string = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration === undefined ? this.snapshot.session.toString() : 'native-' + this.snapshot.nativeAccountGeneration.toString());
    const saved: string[] = this.snapshot.flow?.saved || [];
    if (this.savedSession !== session || this.phase() !== 'ideas') {
      this.savedSession = session; this.confirmedSaved = saved.slice(); this.savedSnack?.dismiss(); return;
    }
    if (this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const newlySaved: boolean = saved.some((id: string): boolean => !this.confirmedSaved.includes(id));
    this.confirmedSaved = saved.slice();
    if (!newlySaved) return;
    if (!this.savedSnack) this.savedSnack = new HdsSnackBar(this.getUIContext());
    this.savedSnack.show({ icon: $r('sys.symbol.checkmark_circle'), iconType: SnackBarIconType.NORMAL,
      iconSymbolModifier: new SymbolGlyphModifier($r('sys.symbol.checkmark_circle')).fontColor([$r('app.color.accent')]) },
      { title: this.uiText("pm_saved_to_b23743c1") + this.snapshot.title }, {}, { duration: 4000 });
  }

  private isDiscoveryBoard(): boolean { return this.discoveryBoard || !this.profileBoard && this.snapshot.featured === true; }

  private selectingPins(): boolean { return this.phase() === 'select' || this.phase() === 'sectionSelect'; }
  private phase(): string {
    if (this.snapshot.flow?.phase === 'targets' && this.singlePinMove) return this.snapshot.flow.sectionId ? 'section' : '';
    return this.snapshot.flow?.phase === 'mergeTargets' || this.snapshot.flow?.phase === 'archive' || this.privacyOpen && this.snapshot.flow?.phase === 'edit' ? '' : this.snapshot.flow?.phase || '';
  }
  private saveEdit(): void {
    if (!this.editName.trim() || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const value: BoardEditValues = { name: this.editName, description: this.editDescription,
      privacy: this.secret ? 'secret' : 'public', recommend: this.recommend, invites: this.invites, requests: this.requests };
    if (this.onAction) this.onAction(JSON.stringify({ action: 'editSave', value: value }));
  }

  private confirmationKey(): string {
    return this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration === undefined ? this.snapshot.session.toString() :
      'native-' + this.snapshot.nativeAccountGeneration.toString() + ':' + (this.snapshot.nativeWriteIntent || 0).toString());
  }
  private confirmDelete(): void {
    if (this.phase() !== 'edit' || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const identity: string = this.confirmationKey();
    const page: string = this.snapshot.pageKey;
    this.getUIContext().showAlertDialog({ title: this.uiText("pm_delete_board_193df6a1"),
      message: this.uiText("pm_permanently_delete_this_board_and_all_its_pins_this_cannot_be_un_6c0d51fd"),
      primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: () => {} },
      secondaryButton: { value: this.uiText("pm_delete_board_193df6a1"), action: () => {
        if (this.confirmationKey() === identity && this.snapshot.pageKey === page && this.phase() === 'edit' &&
            !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) this.act('delete');
      } }
    });
  }
  private confirmDeleteSelected(): void {
    const ids: string[] = this.selectedIds.slice();
    if (this.phase() !== 'select' || !ids.length || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    this.getUIContext().showAlertDialog({ title: this.uiText("pm_delete_pin_e216e3fe"),
      message: this.uiText("pm_delete_this_pin_bd01697d"),
      primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: () => {} },
      secondaryButton: { value: this.uiText("pm_delete_pin_e216e3fe"), action: () => {
        if (this.phase() === 'select' && this.selectedIds.length === ids.length &&
            ids.every((id: string): boolean => this.selectedIds.includes(id)) && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) {
          this.act('deleteSelected', JSON.stringify(ids));
        }
      } }
    });
  }
  private confirmMerge(target: PinmonyBoardTarget): void {
    const identity: string = this.confirmationKey();
    const targetId: string = target.id;
    if (this.phase() !== 'mergeTargets' || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    this.getUIContext().showAlertDialog({
      title: this.uiText('pm_merge_board_confirm_title'),
      message: this.uiText('pm_merge_board_confirm_message').replace('{source}', this.snapshot.title).replace('{target}', target.title),
      primaryButton: { value: this.uiText('pm_cancel_2cd0f3be'), action: () => {} },
      secondaryButton: { value: this.uiText('pm_merge_board_confirm_action'), action: () => {
        if (this.confirmationKey() === identity && this.phase() === 'mergeTargets' && this.snapshot.flow?.phase === 'mergeTargets' &&
          !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && target.id === targetId) this.act('merge', targetId);
      } }
    });
  }
  private act(action: string, value: string = ''): void {
    if (action === 'section' && !this.phase()) this.sectionEntryPending = true;
    if (this.onAction) this.onAction(JSON.stringify({ action: action, value: value }));
  }
  private submitBoardTarget(): void {
    if (!this.boardTargetName.trim() || this.snapshot.flow?.busy || this.snapshot.flow?.loading || this.snapshot.flow?.uncertain) return;
    this.boardCreateStarted = false;
    this.boardCreateSubmitted = true;
    this.act('createTarget', JSON.stringify({ name: this.boardTargetName.trim(), secret: this.boardTargetSecret }));
  }
  private back(): void {
    if (this.sectionMotionBusy) return;
    if (this.snapshot.flow?.busy) return;
    if(this.snapshot.flow?.cover){this.act('coverBack');return;}
    if (this.mergeOpen) { this.menuOpen = false; return; }
    if (this.creatingTarget && !this.snapshot.flow?.uncertain) { this.creatingTarget = false; return; }
    if (this.creatingBoardTarget && !this.snapshot.flow?.uncertain) { this.creatingBoardTarget = false; this.boardCreateSubmitted = false; return; }
    if (this.snapshot.flow?.phase === 'archive') { this.archiveOpen = false; this.act('close'); return; }
    if (this.menuOpen) { this.menuOpen = false; if (this.archiveOpen) this.act('close'); this.archiveOpen = false; return; }
    if(this.snapshot.flow?.phase === 'targets' && this.snapshot.flow.targetBoardId && !this.snapshot.flow.uncertain){this.act('sectionTargetBack');return;}
    if(this.snapshot.flow?.phase === 'targets') { this.act(this.singlePinMove ? 'close' : 'select'); return; }
    if ((this.phase() === 'sectionEdit' || (this.phase() === 'select' || this.phase() === 'ideas') && this.snapshot.flow?.sectionId) && !this.snapshot.flow?.uncertain) { this.act('sectionReturn'); return; }
    if (this.phase() === 'section' && this.sectionMotionWidth > 0) {
      const epoch: number = ++this.sectionMotionEpoch;
      const sectionId: string = this.snapshot.flow?.sectionId || '';
      this.sectionMotionBusy = true;
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseIn, onFinish: () => {
        if (epoch !== this.sectionMotionEpoch) return;
        if (this.phase() === 'section' && this.snapshot.flow?.sectionId === sectionId) this.act('close');
        this.sectionMotionX = 0;
        this.sectionMotionBusy = false;
      } }, () => { this.sectionMotionX = this.sectionMotionWidth; });
      return;
    }
    if (this.phase()) this.act(this.phase() === 'targets' && !this.snapshot.flow?.uncertain ? 'select' : 'close');
    else if (this.onBack) this.onBack();
  }
  private toggle(id: string): void {
    if(this.snapshot.flow?.busy || this.snapshot.flow?.uncertain)return;
    this.selectedIds = this.selectedIds.includes(id) ? this.selectedIds.filter((value: string) => value !== id) :
      this.selectedIds.concat([id]);
  }

  private boardTitleMenu(): BoardTitleMenuItem[] {
    if (/\/pins\/$/i.test(this.snapshot.pageKey)) return [];
    const share: BoardTitleMenuItem = { content: {
      icon: $r('app.media.lucide_share_2'), label: this.uiText("pm_share_board_c77612ba"), isEnabled: this.snapshot.ready,
      action: () => { if (this.onShare) this.onShare(); }
    } };
    if (this.snapshot.ready && this.snapshot.editable !== true &&
      (this.snapshot.canFollow === true || this.snapshot.followBusy === true)) {
      const follow: BoardTitleMenuItem = { content: {
        icon: new SymbolGlyphModifier(this.snapshot.following ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
          .fontSize(28)
          .fontColor([this.snapshot.following ? $r('app.color.accent') : $r('app.color.primary_text')]),
        label: this.snapshot.followBusy ? this.uiText("pm_processing_d3d21191") : this.snapshot.following ? this.uiText("pm_unfollow_dc89d336") : this.uiText("pm_follow_eb137dee"),
        isEnabled: this.snapshot.ready && this.snapshot.canFollow === true && !this.snapshot.followBusy,
        action: () => { if (this.snapshot.canFollow && !this.snapshot.followBusy) this.act('followToggle'); }
      } };
      return [share, follow];
    }
    const options: BoardTitleMenuItem = { content: {
      icon: $r('app.media.lucide_ellipsis'), label: this.uiText("pm_board_options_33bd1089"), isEnabled: this.snapshot.ready,
      action: () => { this.archiveOpen = false; this.menuOpen = true; }
    } };
    return this.isDiscoveryBoard() ? [options] : [share, options];
  }

  private pinCardKey(pin: PinmonyBoardPin): string {
    return JSON.stringify(pin) + ':' + this.uiLanguage;
  }

  @Builder
  private privacySheet() {
    Column({ space: 28 }) {
      Text(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_board_secret_description' : 'pm_board_public_description'))
        .fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
      if(this.snapshot.editable === true) {
        Row({ space: 16 }) {
          Column({ space: 8 }) {
            Text(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_board_make_public' : 'pm_keep_this_board_secret_4ca2f51d'))
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            Text(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_board_public_visibility' : 'pm_board_secret_visibility'))
              .fontSize(15).fontColor($r('app.color.secondary_text'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          ForEach([this.snapshot.privacy || ''], (privacy: string) => {
          Checkbox().select(false).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({ strokeColor: Color.White }).width(24).height(24).margin(12)
            .enabled(this.snapshot.nativeReadsReady === true && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy &&
              !this.snapshot.flow?.uncertain && !this.snapshot.flow?.error && !this.snapshot.flow?.phase)
            .onChange((value: boolean) => {
              if(value && this.privacyOpen && this.snapshot.editable === true && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading)
                this.act('privacy',this.snapshot.privacy === 'secret' ? 'public' : 'secret');
            })
            .accessibilityText(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_board_make_public' : 'pm_keep_this_board_secret_4ca2f51d'))
          }, (privacy: string) => privacy + ':' + this.uiLanguage)
        }.width('100%').alignItems(VerticalAlign.Center)
      }
      if(this.snapshot.flow?.loading || this.snapshot.flow?.busy) { LoadingProgress().color($r('app.color.accent')).width(24).height(24) }
      if(this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error,this.uiLanguage) }) }
    }.width('100%').padding({ left:24,right:24,top:20,bottom:28 }).alignItems(HorizontalAlign.Start)
  }

  private boardCreateMenu(): BoardTitleMenuItem[] {
    return [{ content: {
      icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
      label: this.uiText("pm_create_cde2cd07"),
      isEnabled: !!this.boardTargetName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain,
      action: () => this.submitBoardTarget()
    } }];
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      // Reserve the official title bar's component area above the scrolling content.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled && !this.snapshot.flow?.cover, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: this.snapshot.flow?.cover ? $r('app.color.page_background') : $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: {  backgroundStyle: { backgroundColor: this.snapshot.flow?.cover ? $r('app.color.page_background') : Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: this.isDiscoveryBoard() ? {
          backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
          menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }
        } : { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text') } } }
      },
      content: {
        title: { mainTitle: this.snapshot.flow?.cover ? this.uiText('pm_board_cover_title') : (this.snapshot.flow?.phase !== 'targets' || !this.singlePinMove) && this.creatingBoardTarget ? this.uiText("pm_create_board_513babc9") : (this.snapshot.flow?.phase !== 'targets' || !this.singlePinMove) && this.creatingTarget ? this.uiText("pm_add_section_779008ec") : this.selectingPins() ? this.uiText("pm_select_pins_46854e37") : this.phase() === 'targets' ? this.uiText(this.snapshot.flow?.targetBoardId || this.snapshot.flow?.sectionId ? 'pm_select_section_c87be634' : 'pm_save_to_board_0233a416') :
          this.phase() === 'sectionEdit' ? this.uiText("pm_edit_section_60525d3b") : this.phase() === 'section' ? (this.modernBoardActions() ? PinmonyI18n.render(this.snapshot.title, this.uiLanguage) + ' / ' + (this.snapshot.flow?.sectionTitle || this.uiText("pm_section_6d4e3a60")) : '') : this.phase() === 'ideas' ? this.uiText("pm_more_ideas_8f569818") : this.phase() === 'edit' ? this.uiText("pm_edit_board_2fd3c40f") : this.isDiscoveryBoard() ? (this.headerScrolled && this.snapshot.title !== '图板' ? PinmonyI18n.render(this.snapshot.title, this.uiLanguage) : '') : PinmonyI18n.render(this.snapshot.title || '', this.uiLanguage) },
        backIcon: this.snapshot.flow?.cover ? {isEnabled:!this.snapshot.flow.busy,action:() => this.back()} : this.selectingPins() || this.phase() === 'edit' || this.phase() === 'sectionEdit' ? {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          label: this.phase() === 'edit' ? this.uiText("pm_close_editor_64280f04") : this.uiText("pm_close_organizer_a3fa0809"), isEnabled: !this.snapshot.flow?.busy, action: () => this.back()
        } : { isEnabled: !this.snapshot.flow?.busy, action: () => this.back() },
        menu: { value: this.snapshot.flow?.cover ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.uiText('pm_done_c0b3fbff'),isEnabled:this.coverPreviewReady && !!this.snapshot.flow.cover.selected && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain && !this.snapshot.flow.cover.loading,action:() => this.act('coverSave')}}] : this.phase() === 'sectionEdit' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.uiText("pm_done_c0b3fbff"),isEnabled:!!this.sectionEditName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,action:() => this.act('sectionRename',this.sectionEditName.trim())}}] : this.creatingBoardTarget || this.creatingTarget ? [] : this.phase() === 'sectionSelect' ? [{ content: {
          label: this.selectedIds.length ? this.uiText("pm_done_c0b3fbff") : this.uiText("pm_skip_fc50a99c"), isEnabled: !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.loadingMore,
          action: () => { if(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && this.onAction)this.onAction(JSON.stringify({action:'sectionCreate',value:this.selectedIds})); }
        } }] : this.selectingPins() ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontSize(24).fontWeight(FontWeight.Medium).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_next_acfc4e74"), isEnabled: this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy,
          action: () => {
            if (this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy && this.onAction)
              this.onAction(JSON.stringify({ action: 'targets', value: this.selectedIds }));
          }
        } }] : this.phase() === 'edit' && this.snapshot.editable ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_done_c0b3fbff"), isEnabled: !!this.editName.trim() && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,
          action: () => this.saveEdit()
        } }] : this.phase() === 'section' ? (this.snapshot.editable === true ? [{ content: {icon:$r('app.media.lucide_ellipsis'),label:this.uiText("pm_section_options_1e74fdd5"),isEnabled:!this.snapshot.flow?.loading,action:() => {this.menuOpen = true;}} }] : []) : !this.phase() ? this.boardTitleMenu() : [] }
      }
    };
  }

  private selectionPins(): PinmonyBoardPin[] { return this.snapshot.flow?.sectionId && this.selectingPins() || this.snapshot.flow?.sectionId && this.phase() === 'targets' ? this.snapshot.flow?.pins || [] : this.snapshot.pins; }

  @State private contentWidth: number = 360;

  private contentColumns(): number {
    if (this.modernBoardActions() && this.density === 0) return Math.max(1, Math.floor(this.contentWidth / 360));
    if (this.modernBoardActions() && this.density === 2) return Math.max(3, Math.floor(this.contentWidth / 122));
    return Math.max(2, Math.floor((this.contentWidth - 32 + 12) / 192));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.contentColumns(); i++) slots.push(i);
    return slots;
  }

  private contentColumnsTemplate(): string {
    return this.columnSlots().map((): string => '1fr').join(' ');
  }

  private selectionColumns(): number {
    return Math.max(3, Math.floor((this.contentWidth - 20) / 122));
  }

  private selectionSlots(): number[] {
    const slots: number[] = [];
    for (let i: number = 0; i < this.selectionColumns(); i++) slots.push(i);
    return slots;
  }

  private rows(): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < this.selectionPins().length; index += this.selectionColumns()) result.push(index);
    return result;
  }

  @Builder
  private card(pin: PinmonyBoardPin) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
      Image(pin.imageUrl)
        .width('100%')
        .aspectRatio(this.selectingPins() ? Math.max(0.5, Math.min(1.4, pin.imageWidth / pin.imageHeight)) :
          pin.imageWidth / pin.imageHeight)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.selectingPins() ? 12 : 16)
      if (pin.duration) {
        Text(pin.duration).fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .padding({ left: 5, right: 5, top: 3, bottom: 3 }).backgroundColor('#99000000').borderRadius(6)
          .align(Alignment.TopStart).margin(6).hitTestBehavior(HitTestMode.None)
      }
      if (this.phase() === 'ideas' && this.snapshot.flow?.saved.includes(pin.id)) {
        Column() {
          Text(this.uiText("pm_saved_to_b23743c1") + this.snapshot.title + this.uiText("pm_boards_049d08f1")).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).width('100%').padding({ left: 14, right: 14, top: 16 }).maxLines(2)
          Blank()
        }.width('100%').aspectRatio(pin.imageWidth / pin.imageHeight).backgroundColor('#55000000')
          .hitTestBehavior(HitTestMode.None)
      }
      if (pin.cancelled) {
        Column() {
          Text(this.uiText("pm_unsaved_it_will_disappear_when_you_reopen_the_board_04bda668")).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).width('100%').padding({ left: 14, right: 14, top: 16 })
          Blank()
        }.width('100%').aspectRatio(pin.imageWidth / pin.imageHeight).backgroundColor('#88000000')
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.selectingPins() && this.selectedIds.includes(pin.id)) {
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(22).fontColor([$r('app.color.detail_on_accent')])
          .padding(6).backgroundColor($r('app.color.accent')).borderRadius(17).margin(6)
      }
      if (this.phase() === 'ideas') {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.snapshot.flow?.saved.includes(pin.id) ? $r('sys.symbol.checkmark') : $r('sys.symbol.plus'))
            .fontSize(24).fontColor([this.snapshot.flow?.saved.includes(pin.id) ? Color.White : Color.Black])
        }.width(36).height(36).margin(8)
          .backgroundColor(this.snapshot.flow?.saved.includes(pin.id) ? $r('app.color.accent') : Color.White)
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
          .onClick(() => this.act(this.snapshot.flow?.sectionId ? 'saveParentIdea' : 'save', pin.id))
          .accessibilityText(this.snapshot.flow?.saved.includes(pin.id) ? this.uiText("pm_unsave_dca60869") : this.uiText("pm_save_to_48bf7c69") + this.snapshot.title)
      }
      }.width('100%').borderRadius(this.selectingPins() ? 12 : 16).clip(true)
      .id('pinmony-board-photo-' + pin.id)
      .border({ width: this.selectingPins() && this.selectedIds.includes(pin.id) ? 2 : 0,
        color: $r('app.color.primary_text') })
      .onClick(() => {
        if (pin.cancelled) return;
        if (this.selectingPins()) this.toggle(pin.id);
        else if ((!this.phase() || this.phase() === 'section') && this.onPin) this.onPin(pin.id);
      })
      if ((!this.phase() || this.phase() === 'ideas' || this.phase() === 'section') && !(this.modernBoardActions() && this.density === 2)) {
        Row() {
          Column({ space: 2 }) {
            if (pin.title) { Text(PinmonyI18n.render(pin.title, this.uiLanguage)).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.profileBoard && (!this.phase() || this.phase() === 'section') && typeof pin.favorite === 'boolean') {
            Button({ type: ButtonType.Circle }) {
              if (this.favoritePending === pin.id) {
                LoadingProgress().color($r('app.color.accent')).width(22).height(22)
              } else {
                SymbolGlyph(pin.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
                  .fontSize(22).fontColor([$r('app.color.primary_text')])
              }
            }.width(32).height(32).backgroundColor(Color.Transparent)
              .enabled(!pin.cancelled && this.snapshot.ready && !this.snapshot.flow?.busy && !this.favoritePending)
              .accessibilityText(this.uiText(pin.favorite ? 'pm_star_remove' : 'pm_star_add'))
              .accessibilitySelected(pin.favorite)
              .onClick(async () => {
                if (this.favoritePending || !this.onFavorite) return;
                this.favoritePending = pin.id;
                try { await this.onFavorite(pin.id); } finally { this.favoritePending = ''; }
              })
          }
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(20).height(20).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.primary_text'))
          }.width(32).height(32).backgroundColor(Color.Transparent)
            .enabled(!pin.cancelled && this.snapshot.ready && !this.snapshot.flow?.busy)
            .onClick(() => { if (this.onMore) this.onMore(pin.id); })
            .accessibilityText(this.uiText("pm_more_options_c611656f"))
        }.width('100%')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .accessibilitySelected(this.selectingPins() && this.selectedIds.includes(pin.id))
    .accessibilityText(pin.title || this.uiText("pm_open_pin_e0bdd278"))
  }

  @Builder
  private selectedPreview() {
    if (this.selectedIds.length > 0) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.selectionPins().filter((pin: PinmonyBoardPin) => this.selectedIds.includes(pin.id)), (pin: PinmonyBoardPin) => {
            Image(pin.imageUrl).width(42).height(58).objectFit(ImageFit.Cover).borderRadius(8)
              .onClick(() => { if (this.selectingPins()) this.toggle(pin.id); })
          }, (pin: PinmonyBoardPin) => pin.id)
        }.padding(12)
      }.scrollable(ScrollDirection.Horizontal).height(82).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
    }
  }

  @Builder
  private moveTargetRow(target: PinmonyBoardTarget, direct: boolean = false) {
    PinmonyBoardPickerRow({title:target.title,imageUrl:target.imageUrl,secret:target.secret === true,
      hasSections:!direct && !target.id.startsWith('section:') && target.hasSections === true,
      indented:target.id.startsWith('section:'),
      actionEnabled:target.enabled && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,
      onSelect:() => this.act(!direct && target.hasSections === true && !target.id.startsWith('section:') && target.id !== this.snapshot.boardId ? 'sectionTargetOpen' : 'move',target.id)})
  }
  @Builder
  private flowContent() {
    if (this.snapshot.flow?.phase === 'targets') {
      if(this.snapshot.flow?.targetBoardId) {
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id === this.snapshot.flow?.targetBoardId), (target: PinmonyBoardTarget) => {this.moveTargetRow(target,true)}, (target: PinmonyBoardTarget) => target.id)
        ForEach(this.snapshot.flow?.targetSections || [], (section: PinmonyBoardSection) => {
          this.moveTargetRow({id:'section:' + this.snapshot.flow?.targetBoardId + ':' + section.id,title:section.title,imageUrl:section.images[0] || '',enabled:true,secret:this.snapshot.flow?.targets.find((target: PinmonyBoardTarget): boolean => target.id === this.snapshot.flow?.targetBoardId)?.secret},true)
        }, (section: PinmonyBoardSection) => JSON.stringify(section) + ':' + this.uiLanguage)
        if(!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.targetSections?.length) {Text(this.uiText("pm_this_board_has_no_sections_yet_2eb7dc0a")).fontColor($r('app.color.secondary_text'))}
      } else {
      if(this.snapshot.flow?.sectionId) {
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id === this.snapshot.boardId), (target: PinmonyBoardTarget) => { this.moveTargetRow(target) }, (target: PinmonyBoardTarget) => target.id)
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id.startsWith('section:')), (target: PinmonyBoardTarget) => { this.moveTargetRow(target) }, (target: PinmonyBoardTarget) => target.id)
      } else {
      if((this.snapshot.sections || []).length) {
        Text(PinmonyI18n.render(this.snapshot.title,this.uiLanguage)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id.startsWith('section:')), (target: PinmonyBoardTarget) => {
          this.moveTargetRow(target,true)
        }, (target: PinmonyBoardTarget) => JSON.stringify(target) + ':' + this.uiLanguage)
      }
      }
      Text(this.uiText("pm_all_boards_f1847589")).fontSize(17).width('100%').fontColor($r('app.color.primary_text'))
      ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => !target.id.startsWith('section:') && (!this.snapshot.flow?.sectionId || target.id !== this.snapshot.boardId)), (target: PinmonyBoardTarget) => {
        this.moveTargetRow(target)
      }, (target: PinmonyBoardTarget) => JSON.stringify(target) + ':' + this.uiLanguage)
      }
    } else if (this.phase() === 'edit') {
      if(this.snapshot.flow?.cover) {
        PinmonyBoardCoverContent({cover:this.snapshot.flow.cover,locked:this.snapshot.flow.busy,
          onAction:(action: string,value: string): void => {this.act(action,value);},onReady:(ready: boolean): void => {this.coverPreviewReady = ready;},
          onPreviewLoading:(loading: boolean): void => {this.coverPreviewLoading = loading;}})
      } else { this.editContent() }
    } else if (this.phase() === 'archived') {
      Text(this.uiText("pm_board_archived_03322af8")).fontSize(20).fontColor($r('app.color.primary_text'))
      Button(this.uiText("pm_close_3fd47edc")).onClick(() => this.act('close'))
    }
    if (!this.snapshot.flow?.cover && !this.organizeLoading() && !this.snapshot.postOperationLoading && (this.snapshot.flow?.loading || this.snapshot.flow?.busy)) { LoadingProgress().color($r('app.color.accent')).width(32).height(32) }
    if (this.snapshot.flow?.error) {
      PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.act('retry'), actionEnabled: !this.snapshot.flow.uncertain })
    }
  }

  @Builder
  private setting(label: string, description: string, value: boolean, changed: (value: boolean) => void) {
    Row({ space: 10 }) {
      Checkbox().select(value).width(24).height(24).margin(0).selectedColor($r('app.color.accent')).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).mark({ strokeColor: Color.White })
        .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
        .onChange(changed).accessibilityText(label)
      Column({ space: 4 }) {
        Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(PinmonyI18n.render(description, this.uiLanguage)).fontSize(15).fontColor($r('app.color.secondary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private messageTile() {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.message')).fontColor([$r('app.color.primary_text')]).fontSize(28)
      }.width(72).height(72).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
        .onClick(() => { if (this.onMessage) this.onMessage(); })
      Text(this.uiText("pm_messages_4da199fa")).fontSize(14).fontColor($r('app.color.primary_text'))
    }
  }

  private confirmLeave(): void {
    if (!this.snapshot.collaborator || this.snapshot.editable || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const identity: string = this.confirmationKey();
    const page: string = this.snapshot.pageKey;
    this.getUIContext().showAlertDialog({ title: this.uiText("pm_leave_board_25f267d9"), message: this.uiText("pm_this_board_will_be_removed_from_your_profile_you_will_no_longer__774c3739"),
      primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: () => {} },
      secondaryButton: { value: this.uiText("pm_leave_7345ed45"), action: () => {
        if (this.confirmationKey() === identity && this.snapshot.pageKey === page && this.phase() === 'edit' && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) this.act('leave');
      } } });
  }

  private sectionRows(): number[] {
    const rows: number[] = [];
    for (let index: number = 0; index < (this.snapshot.sections?.length || 0); index += this.contentColumns()) rows.push(index);
    return rows;
  }

  @Builder
  private sectionCard(section: PinmonyBoardSection) {
    Column({ space: 6 }) {
      Row({ space: 1 }) {
        ForEach([0, 1], (slot: number) => {
          Stack() {
          if (boardSectionPreviewImages(section)[slot]) {
            Image(boardSectionPreviewImages(section)[slot]).width('100%').height('100%').objectFit(ImageFit.Cover)
              .accessibilityLevel('no')
          } else { Blank().width('100%').height('100%') }
          }.layoutWeight(1).height('100%').backgroundColor($r('app.color.surface_muted'))
        }, (slot: number) => slot.toString())
      }.width('100%').aspectRatio(1.6).borderRadius(16).clip(true).backgroundColor($r('app.color.page_background'))
      Text(PinmonyI18n.render(section.title, this.uiLanguage)).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      if (section.pinCount !== undefined) { Text(section.pinCount + this.uiText("pm_pins_0a89904f")).fontSize(13).fontColor($r('app.color.secondary_text')) }
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).enabled(this.snapshot.ready)
      .accessibilityText(this.uiText("pm_section_bc71e92e") + section.title + (section.pinCount === undefined ? '' : '，' + section.pinCount + this.uiText("pm_pins_0a89904f")))
      .onClick(() => this.act('section', section.id))
  }

  @Builder
  private sectionEditContent() {
    Column({ space: 20 }) {
      Text(this.uiText("pm_section_name_0e25c295")).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
      TextInput({ text: this.sectionEditName }).maxLength(100).enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain).onChange((value: string) => {this.sectionEditName = value;})
        .height(52).borderRadius(16).border({width:1,color:$r('app.color.secondary_text')})
      Column({ space: 8 }) {
        this.editLabel(this.uiText("pm_actions_ed31fbb4"))
        Text(this.uiText("pm_delete_section_dc032a0b")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain).onClick(() => this.confirmSectionDelete())
        Text(this.uiText("pm_permanently_delete_this_section_and_all_its_pins_this_cannot_be__f7229feb")).fontSize(15).fontColor($r('app.color.secondary_text'))
      }.width('100%').alignItems(HorizontalAlign.Start).margin({top:16})
      if(this.snapshot.flow?.busy) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
      if(this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage) }) }
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
  }

  private confirmSectionDelete(): void {
    const identity: string = this.confirmationKey(), section: string = this.snapshot.flow?.sectionId || '';
    if(this.phase() !== 'sectionEdit' || this.snapshot.flow?.busy || this.snapshot.flow?.loading || this.snapshot.flow?.uncertain)return;
    this.getUIContext().showAlertDialog({title:this.uiText("pm_delete_section_dc032a0b"),message:this.uiText("pm_permanently_delete_this_section_and_all_its_pins_this_cannot_be__f7229feb"),
      primaryButton:{value:this.uiText("pm_cancel_2cd0f3be"),action:(): void => {}},secondaryButton:{value:this.uiText("pm_delete_section_dc032a0b"),action:(): void => {
        if(this.confirmationKey() === identity && this.snapshot.flow?.sectionId === section && this.phase() === 'sectionEdit' &&
          !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)this.act('sectionDelete');
      }}});
  }

  @Builder
  private editContent() {
    Column({ space: 20 }) {
      if (this.snapshot.editable) {
      Column({space:10}) {
        this.editLabel(this.uiText('pm_board_cover_label'))
        Stack({alignContent:Alignment.BottomEnd}) {
          Button({type:ButtonType.Normal}) {
            Stack({alignContent:Alignment.BottomEnd}) {
            if(this.snapshot.flow?.coverImage && this.snapshot.flow.coverPreview) {
              Stack({alignContent:Alignment.TopStart}) {
                Image(this.snapshot.flow.coverPreview.imageUrl)
                  .width(this.snapshot.flow.coverPreview.width).height(this.snapshot.flow.coverPreview.height)
                  .position({x:this.snapshot.flow.coverPreview.left,y:this.snapshot.flow.coverPreview.top}).objectFit(ImageFit.Cover)
              }.width('100%').height('100%').clip(true)
            } else if(this.snapshot.flow?.coverImage) {
              Image(this.snapshot.flow.coverImage).width('100%').height('100%').objectFit(ImageFit.Cover)
            } else {
              Column({space:12}) {
                Image($r('app.media.comment_photo')).width(28).height(28).fillColor($r('app.color.primary_text'))
                Text(this.uiText('pm_board_cover_placeholder')).fontSize(17).fontColor($r('app.color.primary_text'))
                  .textAlign(TextAlign.Center).padding({left:24,right:24})
              }.width('100%').height('100%').justifyContent(FlexAlign.Center)
            }
            }.width('100%').height('100%')
          }.width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
            .onClick((): void => {this.coverPreviewReady = false;this.coverPreviewLoading = false;this.act(this.snapshot.flow?.coverImage ? 'coverAdjust' : 'coverOpen');})
            .accessibilityText(this.uiText(this.snapshot.flow?.coverImage ? 'pm_board_cover_adjust' : 'pm_board_cover_choose'))
          Button({type:ButtonType.Normal}) {
            Image($r('app.media.board_cover_pencil_outline')).width(22).height(22).fillColor($r('app.color.primary_text'))
          }.width(40).height(40).padding(0).borderRadius(12).backgroundColor($r('app.color.input_surface')).margin(10)
            .onClick((): void => {this.coverPreviewReady = false;this.coverPreviewLoading = false;this.act('coverOpen');})
            .accessibilityText(this.uiText('pm_board_cover_choose'))
        }.width('100%').aspectRatio(5/3).borderRadius(20).clip(true).backgroundColor($r('app.color.surface_muted'))
          .enabled(this.snapshot.nativeReadsReady === true && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
      }.width('100%')
      Column({ space: 10 }) {
        this.editLabel(this.uiText("pm_name_d44e9b3d"))
        TextInput({ text: this.editName }).maxLength(100).height(48).borderRadius(16)
          .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.secondary_text') })
          .fontColor($r('app.color.primary_text')).onChange((value: string) => { this.editName = value; })
          .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy)
      }.width('100%')
      Column({ space: 10 }) {
        this.editLabel(this.uiText("pm_description_dc2ba467"))
        TextArea({ text: this.editDescription, placeholder: this.uiText("pm_add_7a8a11ea") }).maxLength(500).height(82).borderRadius(16)
          .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.secondary_text') })
          .fontColor($r('app.color.primary_text')).onChange((value: string) => { this.editDescription = value; })
          .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy)
        this.setting(this.uiText("pm_keep_this_board_secret_4ca2f51d"), this.uiText("pm_only_you_and_your_collaborators_can_see_this_910cbc39"), this.secret, (value: boolean) => { this.secret = value; })
      }.width('100%')
      }
      Column({ space: 10 }) {
        this.editLabel(this.uiText("pm_collaborator_59fa99bc"))
        Row() {
          if (this.snapshot.collaboratorAvatars?.length) {
            Row() {
              ForEach(this.snapshot.collaboratorAvatars || [], (avatar: string, index: number) => {
                Image(avatar).width(48).height(48).borderRadius(24).margin({ left: index > 0 ? -16 : 0 })
              }, (avatar: string) => avatar)
            }
          } else {
            PinmonyUserAvatar({ image: this.snapshot.memberAvatar || this.snapshot.ownerAvatar, name: this.snapshot.ownerName, avatarSize: 48 }).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); })
          }
          Blank()
          Button('+', { type: ButtonType.Normal }).fontSize(26).width(48).height(48).borderRadius(16)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
            .onClick(() => { if (this.onCollaborators) this.onCollaborators(); }).accessibilityText(this.uiText("pm_add_collaborators_99ac9cf0"))
        }.width('100%')
      }.width('100%')
      if (this.snapshot.editable) {
      Column({ space: 24 }) {
        this.editLabel(this.uiText("pm_settings_df3d58c7"))
        this.setting(this.uiText("pm_personalization_38c043e0"), this.uiText("pm_show_pins_inspired_by_this_board_in_your_home_feed_87893338"), this.recommend, (value: boolean) => { this.recommend = value; })
        this.setting(this.uiText("pm_board_requests_6a81235a"), this.uiText("pm_people_can_request_to_join_this_board_0e65b91a"), this.requests, (value: boolean) => { this.requests = value; })
      }.width('100%')
      Column({ space: 8 }) {
        this.editLabel(this.uiText("pm_actions_ed31fbb4"))
        Text(this.uiText("pm_delete_board_193df6a1")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).onClick(() => this.confirmDelete())
        Text(this.uiText("pm_permanently_delete_this_board_and_all_its_pins_this_cannot_be_un_6c0d51fd")).fontSize(15).fontColor($r('app.color.secondary_text'))
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
      } else {
        Column({ space: 8 }) {
          this.editLabel(this.uiText("pm_actions_ed31fbb4"))
          Text(this.uiText("pm_leave_board_16a08fc5")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain)
            .onClick(() => this.confirmLeave())
          Text(this.uiText("pm_leave_this_group_board_and_remove_it_from_your_profile_you_will__9ee2741a")).fontSize(15).fontColor($r('app.color.secondary_text'))
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private editLabel(value: string) {
    Text(PinmonyI18n.render(value, this.uiLanguage)).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%')
  }

  private confirmArchive(): void {
    const identity: string = this.confirmationKey();
    const page: string = this.snapshot.pageKey;
    this.archiveOpen = true;
    this.getUIContext().showAlertDialog({
      title: this.uiText("pm_archive_board_b37a311e"),
      message: this.uiText("pm_if_you_archive_cb914746") + this.snapshot.title + this.uiText("pm_it_will_no_longer_appear_on_your_profile_and_you_cannot_save_new_d6e15b6f"),
      autoCancel: false,
      primaryButton: { value: this.uiText("pm_cancel_2cd0f3be"), action: () => {
        if (this.confirmationKey() !== identity || this.snapshot.pageKey !== page) return;
        this.archiveOpen = false; this.act('close');
      } },
      secondaryButton: { value: this.uiText("pm_archive_c73a6774"), action: () => {
        if (this.confirmationKey() === identity && this.snapshot.pageKey === page &&
            this.snapshot.flow?.phase === 'archive' && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)
          this.act('archive');
      } },
      cancel: () => {
        if (this.confirmationKey() === identity && this.snapshot.pageKey === page) {
          this.archiveOpen = false; this.act('close');
        }
      }
    });
  }

  @Builder
  private optionsSheet() {
    if(this.mergeOpen) { this.mergeSheet() } else {
    Column() {
        Column() {
          if (this.phase() === 'section') {
            this.optionRow(this.uiText("pm_edit_section_60525d3b"), 'sectionEdit')
            this.optionRow(this.uiText("pm_share_7e564575"), 'sectionShare')
          } else if (this.isDiscoveryBoard()) {
            this.optionRow(this.uiText("pm_share_7e564575"), 'share')
            this.optionRow(this.uiText("pm_follow_eb137dee"), 'follow')
          } else {
            this.optionRow(this.uiText("pm_edit_details_and_settings_14e9f0ef"), 'edit')
            this.optionRow(this.uiText("pm_merge_board_menu"), 'merge')
            this.optionRow(this.uiText("pm_archive_c73a6774"), 'archiveConfirm')
          }
          if (!this.isDiscoveryBoard() && this.snapshot.collaborator && !this.snapshot.editable) {
            this.optionRow(this.uiText("pm_unfollow_dc89d336"), 'unfollow')
          }
        }.width('100%')
    }.width('100%').padding({ bottom: 20 }).backgroundColor($r('app.color.page_background'))
  }

  }

  @Builder
  private optionRow(label: string, action: string) {
    Row({ space: 14 }) {
      Column() {
        Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).maxLines(2)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 24, right: 20, top: 14, bottom: 14 })
      .accessibilityText(label)
      .onClick(() => {
        if (action === 'merge') { this.mergeOpen = true; PinmonyRuntimeLog.info('BoardMergeTrace: event=open'); this.act('mergeTargets'); return; }
        this.menuOpen = false;
        if (action === 'sectionShare') { this.pendingSectionShareKey = this.confirmationKey() + ':' + (this.snapshot.flow?.sectionId || ''); return; }
        if (action === 'sectionEdit') { this.pendingSectionEditKey = this.confirmationKey() + ':' + (this.snapshot.flow?.sectionId || ''); return; }
        if (action === 'share') { if (this.onShare) this.onShare(); }
        else if(action)this.act(action);
      })
  }

  @Builder
  private mergeSheet() {
    Column({ space: 12 }) {
      if (this.snapshot.flow?.phase === 'mergeTargets') {
        if (this.snapshot.flow.loading || this.snapshot.flow.busy) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
        if (this.snapshot.flow.error) {
          PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage), actionText: this.uiText('pm_retry_b8784c8d'), onAction: () => this.act('mergeTargetsRetry'), actionEnabled: !this.snapshot.flow.loading })
        }
        Scroll() {
          Column() {
            ForEach(this.snapshot.flow.targets.filter((target: PinmonyBoardTarget): boolean => !target.id.startsWith('section:') && target.id !== this.snapshot.boardId), (target: PinmonyBoardTarget) => {
              PinmonyBoardPickerRow({ title: target.title, imageUrl: target.imageUrl, secret: target.secret === true,
                actionEnabled: target.enabled && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.error,
                onSelect: () => { if(this.snapshot.flow?.phase === 'mergeTargets' && !this.snapshot.flow.loading && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain && !this.snapshot.flow.error)this.confirmMerge(target); } })
            }, (target: PinmonyBoardTarget) => JSON.stringify(target) + ':' + this.uiLanguage)
            if (this.snapshot.flow.hasMore) {
              Button(this.uiText('pm_load_more_merge_boards')).enabled(!this.snapshot.flow.loading).onClick(() => this.act('mergeTargetsMore'))
            }
            if (!this.snapshot.flow.loading && !this.snapshot.flow.error && !this.snapshot.flow.targets.some((target: PinmonyBoardTarget): boolean => target.enabled && target.id !== this.snapshot.boardId)) {
              Text(this.uiText('pm_no_merge_target_boards')).fontColor($r('app.color.secondary_text'))
            }
          }.width('100%')
        }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Auto)
      } else { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
    }.width('100%').height('100%').justifyContent(FlexAlign.Start).padding({ left: 20, right: 20, top: 8, bottom: 20 }).backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private viewOption(key: string, selected: boolean, action: () => void, enabled: boolean = true) {
    Button({type:ButtonType.Normal}) {
      Row() {
        Text(this.uiText(key)).fontSize(18).fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
        Checkbox().select(selected).shape(CheckBoxShape.CIRCLE)
          .selectedColor($r('app.color.accent')).unselectedColor($r('app.color.secondary_text'))
          .mark({strokeColor:Color.White}).width(24).height(24).margin(0)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }.width('100%')
    }.width('100%').height(48).backgroundColor(Color.Transparent).stateEffect(false).hoverEffect(HoverEffect.None).enabled(enabled).accessibilityChecked(selected).onClick(action)
  }

  @Builder
  private boardViewSheet() {
    Column({space:0}) {
      if (!this.phase()) {
      Text(this.uiText('pm_board_view_type')).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
      this.viewOption('pm_all_pins_9a2e0270',this.snapshot.favoriteOnly!==true,()=>{this.selectBoardViewFavorites(false);},this.boardViewFilterReady())
      this.viewOption('pm_board_view_favorites',this.snapshot.favoriteOnly===true,()=>{this.selectBoardViewFavorites(true);},this.boardViewFilterReady() && this.snapshot.canFilterFavorites===true)
      }
      Text(this.uiText('pm_board_view_density')).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%').margin({top:12})
      ForEach([this.density], (_density: number) => {
      this.viewOption('pm_board_view_wide',this.density===0,()=>{this.selectBoardDensity(0);})
      this.viewOption('pm_board_view_default',this.density===1,()=>{this.selectBoardDensity(1);})
      this.viewOption('pm_board_view_compact',this.density===2,()=>{this.selectBoardDensity(2);})
      }, (density: number): string => density.toString())
    }.width('100%').padding({left:24,right:24,top:12,bottom:24})
  }

  private selectBoardDensity(value: number): void {
    if (!this.boardViewLive() || this.density === value) return;
    PinmonyProfileLayoutPreference.saveBoardDensity(value);
  }

  private boardViewLive(): boolean {
    return this.viewOpen && !!this.viewPage && this.viewPage === this.snapshot.pageKey &&
      this.viewScope === this.scrollScope() && this.modernBoardActions();
  }
  private boardViewFilterReady(): boolean {
    return this.boardViewLive() && !this.phase() && this.boardActionEnabled(1) && !this.snapshot.loadingMore;
  }
  private selectBoardViewFavorites(value: boolean): void {
    if (!this.boardViewFilterReady() || !this.snapshot.canFilterFavorites || value === (this.snapshot.favoriteOnly === true)) return;
    this.act('favorites');
  }
  private closeBoardView(): void {
    this.viewPage = '';this.viewScope = '';this.viewOpen = false;
  }

  private modernBoardActions(): boolean {
    return !this.legacyProfile && this.snapshot.editable === true && (!this.phase() || this.phase() === 'section') && !this.isDiscoveryBoard();
  }

  @Builder
  private boardViewButton() {
    Button({type:ButtonType.Circle}) {
      Image($r('app.media.profile_sliders')).width(22).height(22).fillColor($r('app.color.primary_text'))
    }.width(40).height(40).backgroundColor($r('app.color.input_surface'))
      .enabled(this.boardActionEnabled(1)).accessibilityText(this.uiText('pm_board_view_title'))
      .onClick(() => {this.viewPage=this.snapshot.pageKey;this.viewScope=this.scrollScope();this.viewOpen=true;})
      .bindSheet($$this.viewOpen,this.boardViewSheet(),{height:SheetSize.FIT_CONTENT,showClose:true,dragBar:true,
        title:{title:this.uiText('pm_board_view_title')},backgroundColor:$r('app.color.page_background'),
        onDisappear: () => { this.closeBoardView(); }})
  }

  private boardActionEnabled(index: number): boolean {
    return this.snapshot.ready && !this.snapshot.loading && !this.snapshot.refreshing &&
      !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain &&
      (index !== 0 || !!(this.phase() === 'section' ? this.snapshot.flow?.pins.length : this.snapshot.pins.length));
  }

  @Builder
  private boardActionTab(label: string, icon: Resource, index: number) {
    Column({ space: 2 }) {
      if (index === 0) {
        Image(icon).width(24).height(24).fillColor($r('app.color.primary_text'))
      } else {
        SymbolGlyph(icon).fontSize(24).fontColor([$r('app.color.primary_text')])
      }
      Text(this.uiText(label)).fontSize(11).lineHeight(14).height(14).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').height(56).padding({top:4,bottom:4}).justifyContent(FlexAlign.Start)
      .opacity(this.boardActionEnabled(index) ? 1 : 0.4).accessibilityText(this.uiText(label))
  }

  @Builder
  private boardActionTabs() {
    HdsTabs({ barPosition: BarPosition.End }) {
      TabContent() { Column() }
        .tabBar(this.boardActionTab('pm_organize_ff093473', $r('app.media.board_organize_outline'), 0))
      TabContent() { Column() }
        .tabBar(this.boardActionTab('pm_publish_b61f333b', $r('sys.symbol.plus'), 1))
      TabContent() { Column() }
        .tabBar(this.boardActionTab('pm_more_ideas_8f569818', $r('sys.symbol.square_grid_2x2'), 2))
    }.width('100%').height('100%').barHeight(56).barMode(BarMode.Fixed)
      .scrollable(false).barOverlap(true).animationDuration(0)
      .barBackgroundColor(this.immersiveLightEnabled ? Color.Transparent : $r('app.color.surface_muted'))
      .barFloatingStyle({barBottomMargin:28,systemMaterialEffect:PinmonyImmersiveLight.effect(this.immersiveLightMode)})
      .backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.Transparent)
      .onContentWillChange((): boolean => false)
      .onTabBarClick((index: number) => {
        if (!this.boardActionEnabled(index)) return;
        if (index === 0) this.act(this.phase() === 'section' ? 'sectionOrganize' : 'select');
        else if (index === 1 && this.onPublish) this.onPublish();
        else if (index === 2) this.act(this.phase() === 'section' ? 'sectionIdeas' : 'ideas');
      })
  }

  @Builder
  private actionTile(label: string, icon: Resource, action: string, imageIcon: boolean = false) {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        if (imageIcon) {
          Image(icon).width(28).height(28).objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(icon).fontSize(28).fontColor([$r('app.color.primary_text')])
        }
      }.width(72).height(72).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
        .onClick(() => { if(action === 'sectionOrganize')this.selectedIds = [];if(action)this.act(action); }).accessibilityText(label)
      Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
    }
  }

  @Builder
  private organizeSelection() {
    Column({ space: 16 }) {
      Row() {
        Button(this.selectedIds.length === this.selectionPins().length ? this.uiText("pm_deselect_all_f4d4bae5") : this.uiText("pm_select_all_3a5040b6"))
          .height(36).padding(0).fontSize(17).fontWeight(FontWeight.Bold)
          .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
          .onClick(() => { this.selectedIds = this.selectedIds.length === this.selectionPins().length ? [] :
            this.selectionPins().filter((pin: PinmonyBoardPin): boolean => !pin.cancelled).map((pin: PinmonyBoardPin) => pin.id); })
        Blank().layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([$r('app.color.primary_text')])
        }.width(40).height(40).backgroundColor($r('app.color.input_surface'))
          .enabled(this.phase() === 'select' && this.selectedIds.length > 0 && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
          .accessibilityText(this.uiText("pm_delete_pin_e216e3fe"))
          .onClick(() => this.confirmDeleteSelected())
      }.width('100%')
      ForEach(this.rows(), (start: number) => {
        Row({ space: 12 }) {
          this.card(this.selectionPins()[start])
          if (start + 1 < this.selectionPins().length) { this.card(this.selectionPins()[start + 1]) }
          else { Blank().layoutWeight(1) }
          if (start + 2 < this.selectionPins().length) { this.card(this.selectionPins()[start + 2]) }
          else { Blank().layoutWeight(1) }
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (start: number) => this.selectionColumns().toString() + ':' + start.toString() + ':' +
        JSON.stringify(this.selectionPins().slice(start, start + this.selectionColumns())) + ':' + this.uiLanguage)
      if (this.snapshot.loadingMore) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
      if (this.snapshot.error) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private organizeContent(targetSheet: boolean = false) {
    Column() {
      this.selectedPreview()
      if (targetSheet || this.phase() === 'targets') {
        Divider().color($r('app.color.secondary_text')).opacity(0.15).margin({ left: 16, right: 16 })
      }
      Scroll(targetSheet ? this.targetScroller : this.contentScroll()) {
        Column({ space: 8 }) {
          if (this.creatingBoardTarget) {
            TextInput({ placeholder: this.uiText("pm_name_d44e9b3d"), text: this.boardTargetName }).maxLength(100).height(80)
              .border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(16)
              .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
              .margin({ bottom: 12 })
              .onChange((value: string) => { this.boardTargetName = value; })
            this.setting(this.uiText("pm_keep_board_secret_2264c319"), '', this.boardTargetSecret, (value: boolean) => { this.boardTargetSecret = value; })
            Button(this.uiText("pm_create_cde2cd07"))
              .width('100%').height(52).borderRadius(16)
              .margin({ top: 12 })
              .fontColor($r('app.color.detail_on_accent')).backgroundColor($r('app.color.accent'))
              .enabled(!!this.boardTargetName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain)
              .onClick(() => this.submitBoardTarget())
            if (this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage) }) }
          } else if (this.creatingTarget) {
            TextInput({ placeholder: this.uiText("pm_name_d44e9b3d"), text: this.targetName }).maxLength(100).height(80)
              .border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(16)
              .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
              .onChange((value: string) => { this.targetName = value; })
            Button(this.uiText("pm_create_cde2cd07"))
              .width('100%').height(52).borderRadius(16).margin({ top: 12 })
              .fontColor($r('app.color.detail_on_accent')).backgroundColor($r('app.color.accent'))
              .enabled(!!this.targetName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain)
              .onClick(() => this.act('sectionCreateSelected', this.targetName.trim()))
            if (this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage) }) }
          } else if (!targetSheet && this.selectingPins()) {
            if(this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage) }) }
            this.organizeSelection()
          }
          else { this.flowContent() }
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
        .onReachEnd(() => {
          if (this.creatingTarget || this.creatingBoardTarget || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
          if ((targetSheet || this.phase() === 'targets') && !this.snapshot.flow?.targetBoardId && !this.snapshot.flow?.error) this.act('targetsMore');
          else if (this.selectingPins() && !this.snapshot.flow?.sectionId && !this.snapshot.loadingMore && !this.snapshot.error &&
            this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
        })
      if ((targetSheet || this.phase() === 'targets') && !this.creatingTarget && !this.creatingBoardTarget && !this.snapshot.flow?.targetBoardId) {
        Row({ space: 12 }) {
          Button(this.uiText('pm_create_board_513babc9'), { type: ButtonType.Normal })
            .layoutWeight(1).height(52).borderRadius(16)
            .fontColor($r('app.color.primary_text')).backgroundColor(Color.Transparent)
            .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.loading && !this.snapshot.flow?.error)
            .onClick(() => {this.boardTargetName = ''; this.boardTargetSecret = false; this.boardCreateSubmitted = false; this.creatingBoardTarget = true;})
          Divider().vertical(true).height(24).strokeWidth(0.5)
            .color($r('app.color.secondary_text')).opacity(0.35)
          Button(this.uiText('pm_add_section_779008ec'), { type: ButtonType.Normal })
            .layoutWeight(1).height(52).borderRadius(16)
            .fontColor($r('app.color.primary_text')).backgroundColor(Color.Transparent)
            .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.loading && !this.snapshot.flow?.error)
            .onClick(() => {this.targetName = '';this.creatingTarget = true;})
        }.width('100%').padding({ left: 16, right: 16, bottom: 12 })
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private boardDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      if (this.phase() === 'sectionEdit') {
        this.sectionEditContent()
      } else if (this.selectingPins() || this.phase() === 'targets') {
        this.organizeContent()
      } else {
      Stack({ alignContent: Alignment.Bottom }) {
      Refresh({ refreshing: !this.snapshot.postOperationLoading && (this.snapshot.refreshing === true || this.phase() === 'section' && this.snapshot.flow?.refreshing === true) }) {
      Scroll(this.contentScroll()) {
        Column({ space: 16 }) {
          if (this.snapshot.flow?.phase === 'archive') {
            if (this.snapshot.flow.busy) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
            if (this.snapshot.flow.error) {
              PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.confirmArchive(), actionEnabled: !this.snapshot.flow.uncertain })
              Button(this.uiText("pm_cancel_2cd0f3be")).enabled(!this.snapshot.flow.busy).onClick(() => { this.archiveOpen = false; this.act('close'); })
            }
          }
          if (!this.phase() && this.invitationVisible) {
            Row({ space: 12 }) {
              PinmonyUserAvatar({ image: this.invitationAvatar, name: this.invitationName, avatarSize: 44 })
              Column({ space: 12 }) {
                Text(this.invitationName + this.uiText("pm_invited_you_to_collaborate_on_this_board_261f393f")).fontSize(16).fontColor($r('app.color.primary_text'))
                Row({ space: 8 }) {
                  Button(this.uiText("pm_decline_136de7a8")).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).enabled(false)
                  Button(this.uiText("pm_accept_329fcec6")).backgroundColor($r('app.color.accent')).fontColor(Color.White)
                    .enabled(!this.invitationBusy).onClick(() => this.onAcceptInvitation())
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.padding(16).width('100%').borderRadius(20).backgroundColor($r('app.color.surface_muted'))
              .gesture(PanGesture({ direction: PanDirection.Up }).onActionEnd(() => { if (!this.invitationBusy) this.onDismissInvitation(); }))
          }
          if (!this.phase() && (this.snapshot.featured || this.isDiscoveryBoard())) {
            if (this.snapshot.headerImage) {
              Image(this.snapshot.headerImage).width('100%').height(200).objectFit(ImageFit.Cover).borderRadius(16)
            }
            if (this.snapshot.subtitle) { Text(PinmonyI18n.render(this.snapshot.subtitle, this.uiLanguage)).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%') }
            if (this.snapshot.title && this.snapshot.title !== '图板') {
              Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage)).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
            }
          }
          if (!this.phase() && this.snapshot.pinCount) {
            Row({ space: 8 }) {
              if (this.snapshot.privacy === 'secret' || this.snapshot.privacy === 'public') {
                Row({ space: 5 }) {
                  Image(this.snapshot.privacy === 'secret' ? $r('app.media.board_private_lock') : $r('app.media.lucide_globe'))
                    .width(17).height(17).fillColor($r('app.color.primary_text'))
                  Text(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_secret_board_afc1422a' : 'pm_public_board'))
                    .fontSize(14).fontColor($r('app.color.primary_text'))
                }.padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(6)
                  .backgroundColor($r('app.color.surface_muted'))
                  .accessibilityText(this.uiText(this.snapshot.privacy === 'secret' ? 'pm_secret_board_afc1422a' : 'pm_public_board'))
                  .onClick(() => {
                    if(!this.snapshot.flow?.busy && !this.snapshot.flow?.loading){this.privacyPage = this.snapshot.pageKey;this.privacyOpen = true;}
                  })
                  .bindSheet($$this.privacyOpen, this.privacySheet(), {
                    height: SheetSize.FIT_CONTENT, showClose: true, dragBar: false,
                    title: {title:this.uiText(this.snapshot.privacy === 'secret' ? 'pm_board_secret_title' : 'pm_board_public_title')},
                    backgroundColor: $r('app.color.page_background'), maskColor:'#66000000',
                    onWillDismiss: (action: DismissSheetAction) => {
                      if(this.snapshot.flow?.busy)return;
                      if(this.snapshot.flow?.phase === 'edit' && this.snapshot.flow.loading)this.act('close');
                      this.privacyOpen = false;action.dismiss();
                    },
                    onDisappear: () => {
                      this.privacyOpen = false;
                      if(this.snapshot.pageKey === this.privacyPage && this.snapshot.flow?.phase === 'edit' && !this.snapshot.flow.busy)this.act('close');
                      this.privacyPage = '';
                    }
                  })
                Text('·').fontSize(14).fontColor($r('app.color.secondary_text'))
              }
              if (this.snapshot.featured) { Text(this.uiText("pm_featured_board_4b3cbe23")).fontSize(14).fontColor($r('app.color.primary_text')) }
              Text(PinmonyI18n.render(this.snapshot.pinCount, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
              if (this.isDiscoveryBoard() && (this.snapshot.sectionCount || 0) > 0) {
                Text('· ' + this.snapshot.sectionCount + this.uiText("pm_sections_68d526a8")).fontSize(14).fontColor($r('app.color.secondary_text'))
              }
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.featured && this.snapshot.description) {
            Text(PinmonyI18n.render(this.snapshot.description, this.uiLanguage)).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
          }
          if (!this.phase() && this.snapshot.featuredCreators?.length) {
            Row({ space: 6 }) {
              ForEach(this.snapshot.featuredCreators || [], (creator: PinmonyBoardCreator, index: number) => {
                PinmonyUserAvatar({ image: creator.avatar, name: creator.name, avatarSize: 30 }).margin({ left: index > 0 ? -12 : 0 })
              }, (creator: PinmonyBoardCreator) => creator.id)
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              Text(this.uiText("pm_from_df6e36f7")).fontSize(15).lineHeight(22).fontColor($r('app.color.primary_text'))
              ForEach(this.snapshot.featuredCreators || [], (creator: PinmonyBoardCreator, index: number) => {
                Row({ space: 4 }) {
                if (index > 0) { Text(index === (this.snapshot.featuredCreators?.length || 0) - 1 ? this.uiText("pm_and_3d711428") : '、').fontSize(15).lineHeight(22).fontColor($r('app.color.primary_text')) }
                Text(PinmonyI18n.render(creator.name, this.uiLanguage)).fontSize(15).lineHeight(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                  .onClick(() => { if (creator.url && this.onUser) this.onUser(creator.url); })
                if (creator.verified) {
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(10).fontColor([Color.White])
                    .padding(3).backgroundColor($r('app.color.accent')).borderRadius(8).accessibilityText(this.uiText("pm_verified_9a64637b"))
                }
                }.alignItems(VerticalAlign.Center).margin({ right: 4 })
              }, (creator: PinmonyBoardCreator) => (creator.id) + ':' + this.uiLanguage)
              }.layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Center)
          }
          if (!this.phase() && !this.snapshot.featuredCreators?.length && this.snapshot.ownerName && !this.joinedAvatar) {
            Row({ space: 8 }) {
              if (this.snapshot.ownerName) {
                PinmonyUserAvatar({ image: this.snapshot.ownerAvatar, name: this.snapshot.ownerName, avatarSize: 32 }).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); })
              }
              Column({ space: 4 }) {
                if (this.isDiscoveryBoard() && this.snapshot.sponsored) {
                  Text(this.uiText("pm_featured_sponsor_beab5d83")).fontSize(13).fontColor($r('app.color.primary_text'))
                }
                Row({ space: 4 }) {
                  Text((this.isDiscoveryBoard() && this.snapshot.sponsored ? '' : this.uiText("pm_from_df6e36f7")) + this.snapshot.ownerName)
                    .fontSize(15).fontWeight(this.isDiscoveryBoard() && this.snapshot.sponsored ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '85%' })
                  if (this.isDiscoveryBoard() && this.snapshot.ownerVerified) {
                    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(10).fontColor([Color.White])
                      .padding(3).backgroundColor($r('app.color.accent')).borderRadius(8).accessibilityText(this.uiText("pm_verified_9a64637b"))
                  }
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%')
          }
          if (!this.phase() && this.joinedAvatar) {
            Row({ space: 8 }) {
              PinmonyUserAvatar({ image: this.snapshot.memberAvatar || this.snapshot.ownerAvatar, name: this.snapshot.ownerName, avatarSize: 36 })
              Image(this.joinedAvatar).width(36).height(36).borderRadius(18)
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.collaborator && !this.snapshot.editable) {
            Row() {
              ForEach(this.snapshot.collaboratorAvatars || [], (avatar: string, index: number) => {
                Image(avatar).width(36).height(36).borderRadius(18).margin({ left: index > 0 ? -12 : 0 })
              }, (avatar: string) => avatar)
              Button({ type: ButtonType.Circle }) { Image($r('app.media.lucide_user_round_plus')).width(20).height(20) }
                .width(36).height(36).backgroundColor($r('app.color.surface_muted')).onClick(() => { if (this.onCollaborators) this.onCollaborators(); })
            }.width('100%')
            if (this.snapshot.canContribute) {
              Row({ space: 12 }) {
                if (this.snapshot.pins.length > 0) {
                  this.actionTile(this.uiText("pm_organize_ff093473"), $r('app.media.lucide_brush_cleaning'), 'select', true)
                }
                this.actionTile(this.uiText("pm_more_ideas_8f569818"), $r('sys.symbol.square_grid_2x2'), 'ideas')
                this.messageTile()
              }.width('100%')
            }
          }
          if (!this.phase() && this.snapshot.editable) {
            Row({ space: 8 }) {
              if (this.snapshot.collaboratorAvatars?.length) {
                Row() {
                  ForEach(this.snapshot.collaboratorAvatars || [], (avatar: string, index: number) => {
                    Image(avatar).width(36).height(36).borderRadius(18).margin({ left: index > 0 ? -12 : 0 })
                  }, (avatar: string) => avatar)
                }
              } else {
                PinmonyUserAvatar({ image: this.snapshot.memberAvatar, name: this.snapshot.ownerName, avatarSize: 36 }).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); })
              }
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.lucide_user_round_plus')).width(20).height(20)
              }.width(36).height(36).backgroundColor($r('app.color.surface_muted'))
                .onClick(() => { if (this.onCollaborators) this.onCollaborators(); }).accessibilityText(this.uiText("pm_invite_collaborators_42600def"))
              if (this.modernBoardActions()) {
                Blank().layoutWeight(1)
                this.boardViewButton()
              }
            }.width('100%')
            if (!this.modernBoardActions()) {
            Row({ space: 12 }) {
              if (this.snapshot.pins.length > 0) {
                this.actionTile(this.uiText("pm_organize_ff093473"), $r('app.media.lucide_brush_cleaning'), 'select', true)
              }
              this.actionTile(this.uiText("pm_more_ideas_8f569818"), $r('sys.symbol.square_grid_2x2'), 'ideas')
            }.width('100%')
            }
          }
          if (!this.phase() && this.snapshot.sections?.length) {
            if (this.isDiscoveryBoard()) {
              ForEach(this.snapshot.sections || [], (section: PinmonyBoardSection) => {
                Column({ space: 12 }) {
                  Text(PinmonyI18n.render(section.title, this.uiLanguage)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                    .width('100%').onClick(() => this.act('section', section.id)).accessibilityText(this.uiText("pm_open_section_3bcd9df8") + section.title)
                  if (section.pins?.length) {
                    WaterFlow() {
                      ForEach(section.pins || [], (pin: PinmonyBoardPin) => {
                        FlowItem() { this.card(pin) }.width('100%')
                      }, (pin: PinmonyBoardPin) => this.pinCardKey(pin))
                    }.width('100%').columnsTemplate(this.contentColumnsTemplate()).columnsGap(12).rowsGap(12)
                  }
                  if (!section.pins?.length || section.pinCount === undefined || section.pinCount > (section.pins?.length || 0)) {
                    Button(this.uiText("pm_view_section_c6bcaa05") + (section.pinCount === undefined ? '' : ' · ' + section.pinCount + this.uiText("pm_pins_0a89904f"))).backgroundColor($r('app.color.surface_muted'))
                      .fontColor($r('app.color.primary_text')).onClick(() => this.act('section', section.id))
                  }
                }.width('100%').alignItems(HorizontalAlign.Start)
              }, (section: PinmonyBoardSection) => JSON.stringify(section) + ':' + this.uiLanguage)
              if (this.snapshot.pins.length > 0) {
                Text(this.uiText("pm_other_pins_e6a0e45e")).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
              }
            } else {
            Column({ space: 24 }) {
              ForEach(this.sectionRows(), (index: number) => {
                Row({ space: 16 }) {
                  ForEach(this.columnSlots(), (slot: number) => {
                    if (index + slot < (this.snapshot.sections?.length || 0)) { this.sectionCard(this.snapshot.sections![index + slot]) }
                    else { Blank().layoutWeight(1) }
                  }, (slot: number) => slot.toString())
                }.width('100%').alignItems(VerticalAlign.Top)
              }, (index: number) => this.contentColumns().toString() + ':' + JSON.stringify(this.snapshot.sections!.slice(index, index + this.contentColumns())) + ':' + this.uiLanguage)
            }.width('100%')
            }
          }
          if (!this.phase() && this.snapshot.sectionsError) {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.sectionsError, this.uiLanguage), actionText: this.uiText("pm_retry_loading_sections_0d100b07"), onAction: () => this.act('sectionsRetry') })
          }
          if (this.phase() === 'section') {
            if (!this.modernBoardActions()) {
              Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage)).fontSize(22).fontColor($r('app.color.accent')).width('100%').textAlign(TextAlign.Center).onClick(() => this.back())
              Text(this.snapshot.flow?.sectionTitle || this.uiText("pm_section_6d4e3a60")).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center)
            }
            if (this.modernBoardActions()) {
              Row() { Blank().layoutWeight(1); this.boardViewButton() }.width('100%')
            }
            if (this.snapshot.editable === true && !this.modernBoardActions()) {
              Row({ space: 12 }) {
                if (this.snapshot.flow?.pins.length && this.snapshot.canContribute) {
                  this.actionTile(this.uiText("pm_organize_ff093473"), $r('app.media.lucide_brush_cleaning'), 'sectionOrganize', true)
                }
                this.actionTile(this.uiText("pm_more_ideas_8f569818"), $r('sys.symbol.square_grid_2x2'), 'sectionIdeas')
              }.width('100%').justifyContent(FlexAlign.Center).direction(Direction.Ltr)
            }
            if (this.snapshot.flow?.phase === 'section' && this.snapshot.flow.loading && !this.snapshot.flow.refreshing && !this.snapshot.postOperationLoading) { LoadingProgress().color($r('app.color.accent')).width(28).height(28) }
            if (this.snapshot.flow?.error) { PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage) }); PinmonyActionNotice({ message: this.uiText("pm_retry_b8784c8d"), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => this.act('retry') }) }
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.pins.length) {
              Text(this.uiText("pm_there_are_no_pins_in_this_section_yet_694eda70")).fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center).margin({top:60,bottom:60})
            }
          }
          if (this.phase() && this.phase() !== 'select' && this.phase() !== 'ideas' && this.phase() !== 'section') {
            this.flowContent()
          } else if (this.snapshot.loading) {
            if (!this.isDiscoveryBoard()) {
              LoadingProgress().color($r('app.color.accent')).width(32).height(32).margin({ top: 48 })
              Text(this.uiText("pm_loading_board_3d66e034")).fontColor($r('app.color.secondary_text'))
            }
          } else if (!this.snapshot.ready && this.snapshot.error) {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          } else if (this.snapshot.ready && this.snapshot.pins.length === 0 && this.phase() !== 'ideas' && this.phase() !== 'section') {
            Text(this.uiText("pm_no_saved_pins_yet_24c645e0")).fontSize(17).fontColor($r('app.color.primary_text')).margin({ top: 64 })
          } else {
            ForEach([this.contentColumnsTemplate() + ':' + this.density.toString() + ':' + (this.phase() === 'section' ? JSON.stringify(this.snapshot.flow?.pins || []) : '')], (layout: string) => {
            WaterFlow() {
              ForEach((this.phase() === 'ideas' || this.phase() === 'section') ? this.snapshot.flow?.pins || [] : this.snapshot.pins, (pin: PinmonyBoardPin) => {
                FlowItem() {
                  this.card(pin)
                }
                .width('100%')
              }, (pin: PinmonyBoardPin) => this.pinCardKey(pin))
            }
            .width('100%')
            .columnsTemplate(this.contentColumnsTemplate())
            .columnsGap(12)
            .rowsGap(12)
            }, (layout: string): string => layout)
          }
          if (this.phase() === 'ideas') {
            this.flowContent()
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && this.snapshot.flow?.pins.length === 0) {
              Text(this.uiText("pm_no_more_ideas_35120ab6")).fontColor($r('app.color.secondary_text'))
            }
          }
          if (this.snapshot.loadingMore && !this.snapshot.flow?.cover && !this.isDiscoveryBoard()) {
            LoadingProgress().color($r('app.color.accent')).width(28).height(28)
          } else if (this.snapshot.ready && this.snapshot.error) {
            PinmonyActionNotice({ message: PinmonyI18n.render(this.snapshot.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }
        }
        .width('100%')
        .onAreaChange((_old: Area, area: Area) => {
          const width: number = Number(area.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
        .padding({ left: 16, right: 16, top: 18, bottom: this.modernBoardActions() ? 132 : 40 })
      }
      .width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onDidScroll(() => {
        if(this.restoringScroll)return;
        const offset: number = this.contentScroll().currentOffset().yOffset;
        this.scrollOffsets.set(this.scrollScope(),offset);this.headerScrolled = offset > 180;
      })
      .align(Alignment.TopStart)
      .onReachEnd(() => {
        if (this.snapshot.flow?.cover) {
          if(this.snapshot.flow.cover.hasMore && !this.snapshot.flow.cover.loading && !this.snapshot.flow.cover.error && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)this.act('coverMore');
        }
        else if (this.phase() === 'section') this.act('sectionMore');
        else if (this.phase() === 'targets') this.act('targetsMore');
        else if (this.phase() === 'ideas' && !this.snapshot.flow?.sectionId && this.snapshot.flow?.hasMore && !this.snapshot.flow.loading && !this.snapshot.flow.error && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain) this.act('ideasMore');
        else if ((!this.phase() || this.selectingPins()) && this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
      })
      }
      .width('100%').height('100%')
      .pullToRefresh((!this.phase() || this.phase() === 'section') && this.snapshot.ready && !this.snapshot.flow?.busy)
      .onRefreshing(() => {
        PinmonyRuntimeLog.info('BoardRefreshTrace: stage=gesture');
        if (this.onRefresh) this.onRefresh();
      })
      if (this.snapshot.editable === true && (!this.phase() || this.phase() === 'section') && !this.isDiscoveryBoard() && !this.modernBoardActions()) {
        PinmonyDraggablePublishButton({ areaWidth: this.publishAreaWidth, areaHeight: this.publishAreaHeight,
          actionEnabled: !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,
          onPublish: () => { if ((!this.phase() || this.phase() === 'section') && this.onPublish) this.onPublish(); } })
      }
      if (this.modernBoardActions()) { this.boardActionTabs() }
      }.width('100%').height('100%')
      .onAreaChange((_oldArea: Area, area: Area) => {
        this.publishAreaWidth = Number(area.width);
        this.publishAreaHeight = Number(area.height);
      })
      }
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.contentScroll()])
    .onBackPressed(() => {
      this.back();
      return true;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.menuOpen, this.optionsSheet(), {
      radius: { topLeft: 32, topRight: 32, bottomLeft: 32, bottomRight: 32 },
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyBoardPage.menuOpen radius=four-corners-32vp'); },
      height: this.mergeOpen ? SheetSize.LARGE : SheetSize.FIT_CONTENT, showClose: true, dragBar: true,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      title: { title: this.mergeOpen ? this.uiText('pm_merge_board_menu') : this.phase() === 'section' ? this.uiText("pm_section_options_1e74fdd5") : this.uiText("pm_board_options_33bd1089") }, maskColor: '#66000000',
      backgroundColor: $r('app.color.page_background'),
      onDisappear: () => {
        if(this.mergeOpen) { this.mergeOpen = false; PinmonyRuntimeLog.info('BoardMergeTrace: event=closed'); if(this.snapshot.flow?.phase === 'mergeTargets')this.act('close'); }
        const key: string = this.pendingSectionEditKey, share: string = this.pendingSectionShareKey;
        this.pendingSectionEditKey = '';this.pendingSectionShareKey = '';
        const current: string = this.confirmationKey() + ':' + (this.snapshot.flow?.sectionId || '');
        if(key && key === current){this.sectionEditName = this.snapshot.flow?.sectionTitle || '';this.act('sectionEdit');}
        else if(share && share === current && this.phase() === 'section' && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && this.onShare)this.onShare();
      },
      onWillDismiss: (action: DismissSheetAction) => {
        if (this.snapshot.flow?.busy) return;
        this.menuOpen = false;
        action.dismiss();
      }
    })
  }

  private organizeLoading(): boolean {
    return this.snapshot.flow?.phase !== 'targets' && this.selectingPins() &&
      (!!this.snapshot.flow?.loading || !!this.snapshot.flow?.busy);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      HdsNavigation(this.boardPathStack) {
        Column().width('100%').height('100%')
      }
      .width('100%').height('100%')
      .translate({ x: this.sectionMotionX })
      .hitTestBehavior(this.sectionMotionBusy ? HitTestMode.None : HitTestMode.Default)
      .hideTitleBar(true)
      .navDestination(this.boardDestination)
      .backgroundColor($r('app.color.page_background'))
      .accessibilityLevel(this.organizeLoading() || this.snapshot.postOperationLoading ? 'no-hide-descendants' : 'auto')
      if (this.snapshot.flow?.cover && ((this.snapshot.flow.cover.loading &&
        (this.snapshot.flow.cover.adjusting || this.snapshot.flow.cover.pins.length === 0)) || this.coverPreviewLoading)) {
        Stack({ alignContent: Alignment.Center }) {
          LoadingProgress().color($r('app.color.accent')).width(32).height(32)
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      } else if (this.organizeLoading()) {
        PinmonyLoadingOverlay({ message: this.snapshot.flow?.busy ? this.uiText("pm_submitting_please_wait_e7f123ba") : this.uiText("pm_loading_saved_boards_4262c72d") })
      } else if (this.snapshot.postOperationLoading) {
        PinmonyLoadingOverlay({ showMessage: false })
      } else if (this.isDiscoveryBoard() && this.snapshot.loading && !this.snapshot.boardId && !this.phase()) {
        Column({ space: 14 }) {
          LoadingProgress().color($r('app.color.accent')).width(32).height(32)
          Text(this.uiText("pm_loading_board_3d66e034")).fontColor($r('app.color.secondary_text'))
        }
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(this.uiText("pm_loading_board_b5e739be"))
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.moveSheetOpen, this.organizeContent(true), {
      height: SheetSize.LARGE, showClose: true, dragBar: true,
      onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=board-single-move'); },
      title: { title: this.creatingBoardTarget ? this.uiText('pm_create_board_513babc9') : this.creatingTarget ? this.uiText('pm_add_section_779008ec') : this.uiText(this.snapshot.flow?.targetBoardId ? 'pm_select_section_c87be634' : 'pm_save_to_board_0233a416') },
      backgroundColor: $r('app.color.page_background'), maskColor: '#66000000',
      onWillDismiss: (action: DismissSheetAction) => {
        if (this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
        if (action.reason === DismissReason.PRESS_BACK && (this.creatingTarget || this.creatingBoardTarget || this.snapshot.flow?.targetBoardId)) {
          if (this.creatingTarget) this.creatingTarget = false;
          else if (this.creatingBoardTarget) { this.creatingBoardTarget = false; this.boardCreateSubmitted = false; }
          else this.act('sectionTargetBack');
          return;
        }
        this.moveSheetOpen = false;
        action.dismiss();
        if (this.snapshot.flow?.phase === 'targets') this.act(this.singlePinMove ? 'close' : 'select');
      }
    })
    .onAreaChange((_old: Area, area: Area) => {
      const width: number = Number(area.width);
      if (width > 0) this.sectionMotionWidth = width;
    })
  }
}
