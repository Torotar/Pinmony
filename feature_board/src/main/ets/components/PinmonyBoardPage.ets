import { BlurStrategy } from '@kit.UIDesignKit';
import { PinmonyImmersiveLight } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardTarget, PinmonyBoardSection, PinmonyBoardCreator } from '../models/PinmonyBoardDetail';
import { boardSectionPreviewImages } from '../services/PinmonyBoardPresentation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardPlaceholder, PinmonyLoadingOverlay } from 'common_ui';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarIconType, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

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

@Component
export struct PinmonyBoardPage {
  @StorageLink('immersiveLightMode') private immersiveLightMode: string = 'immersive';
  private get immersiveLightEnabled(): boolean { return this.immersiveLightMode !== 'off'; }
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop discoveryBoard: boolean = false;
  @Prop profileBoard: boolean = false;
  @Prop @Watch('snapshotChanged') snapshot: PinmonyBoardDetail;
  @State private menuOpen: boolean = false;
  @State private headerScrolled: boolean = false;
  @State private archiveOpen: boolean = false;
  @State private selectedIds: string[] = [];
  @State private editName: string = '';
  @State private editDescription: string = '';
  @State private secret: boolean = false;
  @State private recommend: boolean = false;
  @State private invites: boolean = false;
  @State private requests: boolean = false;
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
  private readonly boardPathStack: NavPathStack = new NavPathStack();
  private parentScroller: Scroller = new Scroller();
  private flowScroller: Scroller = new Scroller();
  private readonly sectionScrollers: Map<string, Scroller> = new Map<string, Scroller>();
  private scrollOwner: string = '';
  private visibleScrollScope: string = '';
  private readonly scrollOffsets: Map<string, number> = new Map<string, number>();
  private scrollRestoreToken: number = 0;
  private restoringScroll: boolean = false;

  private scrollScope(): string {return this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration ?? this.snapshot.session).toString() + ':' + (this.phase() === 'section' ? 'section:' + (this.snapshot.flow?.sectionId || '') : this.phase() || 'parent');}
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
    if(owner !== this.scrollOwner){this.scrollOwner = owner;this.parentScroller = new Scroller();this.flowScroller = new Scroller();this.sectionScrollers.clear();this.scrollOffsets.clear();}
    if(!this.phase())return this.parentScroller;
    if(this.phase() !== 'section' || !this.snapshot.flow?.sectionId)return this.flowScroller;
    const id: string = this.snapshot.flow.sectionId;
    let scroller: Scroller | undefined = this.sectionScrollers.get(id);
    if(!scroller){if(this.sectionScrollers.size >= 20)this.sectionScrollers.delete(this.sectionScrollers.keys().next().value!);scroller = new Scroller();this.sectionScrollers.set(id,scroller);}
    return scroller;
  }

  aboutToAppear(): void {
    this.contentScroll();this.restoreContentScroll();
    this.savedSession = this.snapshot.pageKey + ':' + (this.snapshot.nativeAccountGeneration === undefined ? this.snapshot.session.toString() : 'native-' + this.snapshot.nativeAccountGeneration.toString());
    this.confirmedSaved = (this.snapshot.flow?.saved || []).slice();
    this.syncEditValues();
    this.boardPathStack.clear();
    this.boardPathStack.pushPath({ name: 'pin-web-board' }, false);
  }

  private snapshotChanged(): void {
    this.contentScroll();this.restoreContentScroll();
    this.updateSavedFeedback();
    if (this.snapshot.flow?.phase === 'archive' && !this.archiveOpen && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)
      this.confirmArchive();
    if (this.archiveOpen && this.snapshot.flow?.phase !== 'archive') { this.menuOpen = false; this.archiveOpen = false; }
    if (!this.phase()) this.selectedIds = [];
    if (this.phase() !== 'targets') this.creatingTarget = false;
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

  aboutToDisappear(): void { this.scrollRestoreToken++;this.savedSnack?.dismiss(); }

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
    this.savedSnack.show({ icon: $r('sys.symbol.checkmark'), iconType: SnackBarIconType.NORMAL,
      iconSymbolModifier: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.accent')]) },
      { title: this.uiText("pm_saved_to_b23743c1") + this.snapshot.title }, {}, { duration: 4000 });
  }

  private isDiscoveryBoard(): boolean { return this.discoveryBoard || !this.profileBoard && this.snapshot.featured === true; }

  private selectingPins(): boolean { return this.phase() === 'select' || this.phase() === 'sectionSelect'; }
  private phase(): string { return this.snapshot.flow?.phase === 'archive' ? '' : this.snapshot.flow?.phase || ''; }
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
  private act(action: string, value: string = ''): void {
    if (this.onAction) this.onAction(JSON.stringify({ action: action, value: value }));
  }
  private back(): void {
    if (this.snapshot.flow?.busy) return;
    if (this.creatingTarget && !this.snapshot.flow?.uncertain) { this.creatingTarget = false; return; }
    if (this.snapshot.flow?.phase === 'archive') { this.archiveOpen = false; this.act('close'); return; }
    if (this.menuOpen) { this.menuOpen = false; if (this.archiveOpen) this.act('close'); this.archiveOpen = false; return; }
    if ((this.phase() === 'sectionEdit' || (this.phase() === 'select' || this.phase() === 'ideas') && this.snapshot.flow?.sectionId) && !this.snapshot.flow?.uncertain) { this.act('sectionReturn'); return; }
    if(this.phase() === 'targets' && this.snapshot.flow?.targetBoardId && !this.snapshot.flow.uncertain){this.act('sectionTargetBack');return;}
    if (this.phase()) this.act(this.phase() === 'targets' && !this.snapshot.flow?.uncertain ? 'select' : 'close');
    else if (this.onBack) this.onBack();
  }
  private toggle(id: string): void {
    if(this.snapshot.flow?.busy || this.snapshot.flow?.uncertain)return;
    this.selectedIds = this.selectedIds.includes(id) ? this.selectedIds.filter((value: string) => value !== id) :
      this.selectedIds.concat([id]);
  }

  private boardTitleMenu(): BoardTitleMenuItem[] {
    const share: BoardTitleMenuItem = { content: {
      icon: $r('app.media.lucide_share_2'), label: this.uiText("pm_share_board_c77612ba"), isEnabled: this.snapshot.ready,
      action: () => { if (this.onShare) this.onShare(); }
    } };
    if (this.snapshot.editable !== true) {
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

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      // Reserve the official title bar's component area above the scrolling content.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: { blurStrategy: this.immersiveLightEnabled ? BlurStrategy.ENABLE : BlurStrategy.DISABLE, thermoCtrl: this.immersiveLightEnabled,
        scrollEffectOpts: { enableScrollEffect: this.immersiveLightEnabled, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR },
        systemMaterialEffect: PinmonyImmersiveLight.effect(this.immersiveLightMode),
        scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.immersive_title_scrolled'), maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: {  backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 0, blurRadius: this.immersiveLightEnabled ? 18 : 0 }, contentStyle: this.isDiscoveryBoard() ? {
          backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') },
          menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }
        } : { backIconStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text') }, menuStyle: { backgroundColor: this.immersiveLightMode === 'off' || this.immersiveLightMode === 'gentle' ? Color.Transparent : undefined, iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text') } } }
      },
      content: {
        title: { mainTitle: this.creatingTarget ? this.uiText("pm_add_section_779008ec") : this.selectingPins() ? this.uiText("pm_select_pins_46854e37") : this.phase() === 'targets' ? this.uiText("pm_select_section_c87be634") :
          this.phase() === 'sectionEdit' ? this.uiText("pm_edit_section_60525d3b") : this.phase() === 'section' ? '' : this.phase() === 'ideas' ? this.uiText("pm_more_ideas_8f569818") : this.phase() === 'edit' ? this.uiText("pm_edit_board_2fd3c40f") : this.isDiscoveryBoard() ? (this.headerScrolled && this.snapshot.title !== '图板' ? PinmonyI18n.render(this.snapshot.title, this.uiLanguage) : '') : PinmonyI18n.render(this.snapshot.title || '', this.uiLanguage) },
        backIcon: this.selectingPins() || this.phase() === 'edit' || this.phase() === 'sectionEdit' ? {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          label: this.phase() === 'edit' ? this.uiText("pm_close_editor_64280f04") : this.uiText("pm_close_organizer_a3fa0809"), isEnabled: !this.snapshot.flow?.busy, action: () => this.back()
        } : { isEnabled: !this.snapshot.flow?.busy, action: () => this.back() },
        menu: { value: this.phase() === 'sectionEdit' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:this.uiText("pm_done_c0b3fbff"),isEnabled:!!this.sectionEditName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,action:() => this.act('sectionRename',this.sectionEditName.trim())}}] : this.creatingTarget ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: this.uiText("pm_next_acfc4e74"), isEnabled: !!this.targetName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain,
          action: () => this.act('sectionCreateSelected', this.targetName.trim())
        } }] : this.phase() === 'sectionSelect' ? [{ content: {
          label: this.selectedIds.length ? this.uiText("pm_done_c0b3fbff") : this.uiText("pm_skip_fc50a99c"), isEnabled: !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.loadingMore,
          action: () => { if(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && this.onAction)this.onAction(JSON.stringify({action:'sectionCreate',value:this.selectedIds})); }
        } }] : this.selectingPins() ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
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
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.detail_on_accent')])
          .padding(6).backgroundColor($r('app.color.accent')).borderRadius(15).margin(6)
      }
      if (this.phase() === 'ideas') {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.snapshot.flow?.saved.includes(pin.id) ? $r('sys.symbol.checkmark') : $r('sys.symbol.plus'))
            .fontSize(24).fontColor([this.snapshot.flow?.saved.includes(pin.id) ? Color.White : Color.Black])
        }.width(36).height(36).margin(8)
          .backgroundColor(this.snapshot.flow?.saved.includes(pin.id) ? Color.Black : Color.White)
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
          .onClick(() => this.act(this.snapshot.flow?.sectionId ? 'saveParentIdea' : 'save', pin.id))
          .accessibilityText(this.snapshot.flow?.saved.includes(pin.id) ? this.uiText("pm_unsave_dca60869") : this.uiText("pm_save_to_48bf7c69") + this.snapshot.title)
      }
      }.width('100%').borderRadius(this.selectingPins() ? 12 : 16).clip(true)
      .border({ width: this.selectingPins() && this.selectedIds.includes(pin.id) ? 2 : 0,
        color: $r('app.color.primary_text') })
      .onClick(() => {
        if (pin.cancelled) return;
        if (this.selectingPins()) this.toggle(pin.id);
        else if ((!this.phase() || this.phase() === 'section') && this.onPin) this.onPin(pin.id);
      })
      if (!this.phase() || this.phase() === 'ideas' || this.phase() === 'section') {
        Row() {
          Column({ space: 2 }) {
            if (pin.title) { Text(pin.title).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }) }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
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
        Button({ type: ButtonType.Normal }) {
          Row({ space: 16 }) {
            if (target.imageUrl) { Image(target.imageUrl).width(56).height(56).borderRadius(16).objectFit(ImageFit.Cover) }
            else { PinmonyBoardPlaceholder() }
            Text(target.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
              .layoutWeight(1).maxLines(2)
          }.width('100%')
        }.width('100%').height(72).padding({left:target.id.startsWith('section:') ? 24 : 0,right:0,top:0,bottom:0})
          .borderRadius(12).backgroundColor(Color.Transparent)
          .onClick(() => {
            if (target.enabled && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
              this.act(this.snapshot.flow?.sectionId && !direct && !target.id.startsWith('section:') && target.id !== this.snapshot.boardId ? 'sectionTargetOpen' : 'move', target.id);
          })
  }

  @Builder
  private flowContent() {
    if (this.phase() === 'targets') {
      if(this.snapshot.flow?.targetBoardId) {
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id === this.snapshot.flow?.targetBoardId), (target: PinmonyBoardTarget) => {this.moveTargetRow(target,true)}, (target: PinmonyBoardTarget) => target.id)
        ForEach(this.snapshot.flow?.targetSections || [], (section: PinmonyBoardSection) => {
          this.moveTargetRow({id:'section:' + this.snapshot.flow?.targetBoardId + ':' + section.id,title:section.title,imageUrl:section.images[0] || '',enabled:true},true)
        }, (section: PinmonyBoardSection) => section.id)
        if(!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.targetSections?.length) {Text(this.uiText("pm_this_board_has_no_sections_yet_2eb7dc0a")).fontColor($r('app.color.secondary_text'))}
      } else {
      if(this.snapshot.flow?.sectionId) {
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id === this.snapshot.boardId), (target: PinmonyBoardTarget) => { this.moveTargetRow(target) }, (target: PinmonyBoardTarget) => target.id)
        ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => target.id.startsWith('section:')), (target: PinmonyBoardTarget) => { this.moveTargetRow(target) }, (target: PinmonyBoardTarget) => target.id)
      } else {
      ForEach(this.snapshot.sections || [], (section: PinmonyBoardSection) => {
        Text(section.title).fontSize(19).fontWeight(FontWeight.Bold).maxLines(2)
          .fontColor($r('app.color.primary_text')).width('100%').padding({ left: 32, top: 12, bottom: 20 })
      }, (section: PinmonyBoardSection) => section.id)
      }
      Text(this.uiText("pm_all_boards_f1847589")).fontSize(17).width('100%').fontColor($r('app.color.primary_text'))
      ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => !this.snapshot.flow?.sectionId || target.id !== this.snapshot.boardId && !target.id.startsWith('section:')), (target: PinmonyBoardTarget) => {
        this.moveTargetRow(target)
      }, (target: PinmonyBoardTarget) => target.id)
      }
    } else if (this.phase() === 'edit') {
      this.editContent()
    } else if (this.phase() === 'archived') {
      Text(this.uiText("pm_board_archived_03322af8")).fontSize(20).fontColor($r('app.color.primary_text'))
      Button(this.uiText("pm_close_3fd47edc")).onClick(() => this.act('close'))
    }
    if (!this.organizeLoading() && (this.snapshot.flow?.loading || this.snapshot.flow?.busy)) { LoadingProgress().width(32).height(32) }
    if (this.snapshot.flow?.error) {
      Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
      if (!this.snapshot.flow.uncertain) { Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.act('retry')) }
    }
  }

  @Builder
  private setting(label: string, description: string, value: boolean, changed: (value: boolean) => void) {
    Row({ space: 10 }) {
      Checkbox().select(value).width(24).height(24).margin(0).selectedColor($r('app.color.accent'))
        .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
        .onChange(changed).accessibilityText(label)
      Column({ space: 4 }) {
        Text(label).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(description).fontSize(15).fontColor($r('app.color.secondary_text'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private messageTile() {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.message')).fontColor([$r('app.color.primary_text')]).fontSize(28)
      }.width(72).height(72).borderRadius(20).backgroundColor($r('app.color.surface_muted'))
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
      Text(section.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
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
      if(this.snapshot.flow?.busy) { LoadingProgress().width(28).height(28) }
      if(this.snapshot.flow?.error) { Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')) }
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
          Button('+').fontSize(26).width(48).height(48).borderRadius(10)
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
    Text(value).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%')
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
    Column() {
        Column() {
          if (this.phase() === 'section') {
            this.optionRow(this.uiText("pm_edit_05183656"), 'sectionEdit')
            this.optionRow(this.uiText("pm_share_7e564575"), 'sectionShare')
          } else if (this.isDiscoveryBoard()) {
            this.optionRow(this.uiText("pm_share_7e564575"), 'share')
            this.optionRow(this.uiText("pm_follow_eb137dee"), 'follow')
          } else {
            this.optionRow(this.uiText("pm_edit_details_and_settings_14e9f0ef"), 'edit')
            this.optionRow(this.uiText("pm_archive_c73a6774"), 'archiveConfirm')
          }
          if (!this.isDiscoveryBoard() && this.snapshot.collaborator && !this.snapshot.editable) {
            this.optionRow(this.uiText("pm_unfollow_dc89d336"), 'unfollow')
          }
        }.width('100%')
    }.width('100%').padding({ bottom: 20 }).backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private optionRow(label: string, action: string) {
    Row({ space: 14 }) {
      Column() {
        Text(label).fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).maxLines(2)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 24, right: 20, top: 14, bottom: 14 })
      .accessibilityText(label)
      .onClick(() => {
        this.menuOpen = false;
        if (action === 'sectionShare') { this.pendingSectionShareKey = this.confirmationKey() + ':' + (this.snapshot.flow?.sectionId || ''); return; }
        if (action === 'sectionEdit') { this.pendingSectionEditKey = this.confirmationKey() + ':' + (this.snapshot.flow?.sectionId || ''); return; }
        if (action === 'share') { if (this.onShare) this.onShare(); }
        else if(action)this.act(action);
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
      }.width(72).height(72).borderRadius(24).backgroundColor($r('app.color.surface_muted'))
        .onClick(() => { if(action === 'sectionOrganize')this.selectedIds = [];if(action)this.act(action); }).accessibilityText(label)
      Text(label).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
    }
  }

  @Builder
  private organizeSelection() {
    Column({ space: 16 }) {
      Button(this.selectedIds.length === this.selectionPins().length ? this.uiText("pm_deselect_all_f4d4bae5") : this.uiText("pm_select_all_3a5040b6"))
        .height(36).padding(0).fontSize(17).fontWeight(FontWeight.Bold)
        .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
        .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
        .onClick(() => { this.selectedIds = this.selectedIds.length === this.selectionPins().length ? [] :
          this.selectionPins().filter((pin: PinmonyBoardPin): boolean => !pin.cancelled).map((pin: PinmonyBoardPin) => pin.id); })
      ForEach(this.rows(), (start: number) => {
        Row({ space: 12 }) {
          this.card(this.selectionPins()[start])
          if (start + 1 < this.selectionPins().length) { this.card(this.selectionPins()[start + 1]) }
          else { Blank().layoutWeight(1) }
          if (start + 2 < this.selectionPins().length) { this.card(this.selectionPins()[start + 2]) }
          else { Blank().layoutWeight(1) }
        }.width('100%').alignItems(VerticalAlign.Top)
      }, (start: number) => this.selectionColumns().toString() + ':' + start.toString())
      if (this.snapshot.loadingMore) { LoadingProgress().width(28).height(28) }
      if (this.snapshot.error) {
        Text(PinmonyI18n.render(this.snapshot.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
        Button(this.uiText("pm_retry_b8784c8d")).onClick(() => { if (this.onRetry) this.onRetry(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private organizeContent() {
    Column() {
      this.selectedPreview()
      if (this.phase() === 'targets') {
        Divider().color($r('app.color.secondary_text')).opacity(0.15).margin({ left: 16, right: 16 })
      }
      Scroll(this.contentScroll()) {
        Column({ space: 8 }) {
          if (this.creatingTarget) {
            TextInput({ placeholder: this.uiText("pm_name_d44e9b3d"), text: this.targetName }).maxLength(100).height(80)
              .border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(16)
              .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
              .onChange((value: string) => { this.targetName = value; })
            if (this.snapshot.flow?.busy) { LoadingProgress().width(32).height(32) }
            if (this.snapshot.flow?.error) { Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')) }
          } else if (this.selectingPins()) {
            if(this.snapshot.flow?.error) { Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')) }
            this.organizeSelection()
          }
          else { this.flowContent() }
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
        .onReachEnd(() => {
          if (this.creatingTarget || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
          if (this.phase() === 'targets' && !this.snapshot.flow?.targetBoardId && !this.snapshot.flow?.error) this.act('targetsMore');
          else if (this.selectingPins() && !this.snapshot.flow?.sectionId && !this.snapshot.loadingMore && !this.snapshot.error &&
            this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
        })
      if (this.phase() === 'targets' && !this.creatingTarget && !this.snapshot.flow?.targetBoardId) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Text('+').fontSize(26).width(44).height(44).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(10).fontColor($r('app.color.primary_text'))
            Text(this.uiText("pm_add_section_779008ec")).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          }.width('100%')
        }.width('100%').height(76).padding({ left: 16, right: 16, top: 12, bottom: 20 }).borderRadius(0)
          .backgroundColor($r('app.color.page_background')).enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.loading && !this.snapshot.flow?.error).onClick(() => { this.targetName = ''; this.creatingTarget = true; }).accessibilityText(this.uiText("pm_add_section_779008ec"))
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
      Refresh({ refreshing: this.snapshot.refreshing === true }) {
      Scroll(this.contentScroll()) {
        Column({ space: 16 }) {
          if (this.snapshot.flow?.phase === 'archive') {
            if (this.snapshot.flow.busy) { LoadingProgress().width(28).height(28) }
            if (this.snapshot.flow.error) {
              Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
              if (!this.snapshot.flow.uncertain) { Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.confirmArchive()) }
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
            if (this.snapshot.subtitle) { Text(this.snapshot.subtitle).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%') }
            if (this.snapshot.title && this.snapshot.title !== '图板') {
              Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage)).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
            }
          }
          if (!this.phase() && this.snapshot.pinCount) {
            Row({ space: 8 }) {
              if (this.snapshot.privacy === 'secret') {
                Row({ space: 5 }) {
                  Image($r('app.media.board_private_lock')).width(17).height(17).fillColor($r('app.color.primary_text'))
                  Text(this.uiText("pm_secret_412677b5")).fontSize(14).fontColor($r('app.color.primary_text'))
                }.padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(6)
                  .backgroundColor($r('app.color.surface_muted')).accessibilityText(this.uiText("pm_secret_board_afc1422a"))
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
            Text(this.snapshot.description).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
          }
          if (!this.phase() && this.snapshot.featuredCreators?.length) {
            Row({ space: 6 }) {
              ForEach(this.snapshot.featuredCreators || [], (creator: PinmonyBoardCreator, index: number) => {
                PinmonyUserAvatar({ image: creator.avatar, name: creator.name, avatarSize: 30 }).margin({ left: index > 0 ? -12 : 0 })
              }, (creator: PinmonyBoardCreator) => creator.id)
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              Text(this.uiText("pm_from_df6e36f7")).fontSize(15).fontColor($r('app.color.primary_text'))
              ForEach(this.snapshot.featuredCreators || [], (creator: PinmonyBoardCreator, index: number) => {
                Row({ space: 4 }) {
                if (index > 0) { Text(index === (this.snapshot.featuredCreators?.length || 0) - 1 ? this.uiText("pm_and_3d711428") : '、').fontSize(15).fontColor($r('app.color.primary_text')) }
                Text(creator.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                  .onClick(() => { if (creator.url && this.onUser) this.onUser(creator.url); })
                if (creator.verified) {
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(10).fontColor([Color.White])
                    .padding(3).backgroundColor($r('app.color.accent')).borderRadius(8).accessibilityText(this.uiText("pm_verified_9a64637b"))
                }
                }.margin({ right: 4, bottom: 4 })
              }, (creator: PinmonyBoardCreator) => creator.id)
              }.layoutWeight(1)
            }.width('100%')
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
            }.width('100%')
            Row({ space: 12 }) {
              if (this.snapshot.pins.length > 0) {
                this.actionTile(this.uiText("pm_organize_ff093473"), $r('app.media.lucide_brush_cleaning'), 'select', true)
              }
              this.actionTile(this.uiText("pm_more_ideas_8f569818"), $r('sys.symbol.square_grid_2x2'), 'ideas')
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.sections?.length) {
            if (this.isDiscoveryBoard()) {
              ForEach(this.snapshot.sections || [], (section: PinmonyBoardSection) => {
                Column({ space: 12 }) {
                  Text(section.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                    .width('100%').onClick(() => this.act('section', section.id)).accessibilityText(this.uiText("pm_open_section_3bcd9df8") + section.title)
                  if (section.pins?.length) {
                    WaterFlow() {
                      ForEach(section.pins || [], (pin: PinmonyBoardPin) => {
                        FlowItem() { this.card(pin) }.width('100%')
                      }, (pin: PinmonyBoardPin) => pin.id)
                    }.width('100%').columnsTemplate(this.contentColumnsTemplate()).columnsGap(12).rowsGap(12)
                  }
                  if (!section.pins?.length || section.pinCount === undefined || section.pinCount > (section.pins?.length || 0)) {
                    Button(this.uiText("pm_view_section_c6bcaa05") + (section.pinCount === undefined ? '' : ' · ' + section.pinCount + this.uiText("pm_pins_0a89904f"))).backgroundColor($r('app.color.surface_muted'))
                      .fontColor($r('app.color.primary_text')).onClick(() => this.act('section', section.id))
                  }
                }.width('100%').alignItems(HorizontalAlign.Start)
              }, (section: PinmonyBoardSection) => section.id)
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
              }, (index: number) => this.contentColumns().toString() + ':' + this.snapshot.sections![index].id)
            }.width('100%')
            }
          }
          if (!this.phase() && this.snapshot.sectionsError) {
            Text(PinmonyI18n.render(this.snapshot.sectionsError, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("pm_retry_loading_sections_0d100b07")).onClick(() => this.act('sectionsRetry'))
          }
          if (this.phase() === 'section') {
            Text(PinmonyI18n.render(this.snapshot.title, this.uiLanguage)).fontSize(22).fontColor($r('app.color.accent')).width('100%').textAlign(TextAlign.Center).onClick(() => this.act('close'))
            Text(this.snapshot.flow?.sectionTitle || this.uiText("pm_section_6d4e3a60")).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center)
            if (this.snapshot.editable === true) {
              Row({ space: 12 }) {
                if (this.snapshot.flow?.pins.length && this.snapshot.canContribute) {
                  this.actionTile(this.uiText("pm_organize_ff093473"), $r('app.media.lucide_brush_cleaning'), 'sectionOrganize', true)
                }
                this.actionTile(this.uiText("pm_more_ideas_8f569818"), $r('sys.symbol.square_grid_2x2'), 'sectionIdeas')
              }.width('100%').justifyContent(FlexAlign.Center).direction(Direction.Ltr)
            }
            if (this.snapshot.flow?.loading) { LoadingProgress().width(28).height(28) }
            if (this.snapshot.flow?.error) { Text(PinmonyI18n.render(this.snapshot.flow.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')); Button(this.uiText("pm_retry_b8784c8d")).onClick(() => this.act('retry')) }
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.pins.length) {
              Text(this.uiText("pm_there_are_no_pins_in_this_section_yet_694eda70")).fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center).margin({top:60,bottom:60})
            }
          }
          if (this.phase() && this.phase() !== 'select' && this.phase() !== 'ideas' && this.phase() !== 'section') {
            this.flowContent()
          } else if (this.snapshot.loading) {
            if (!this.isDiscoveryBoard()) {
              LoadingProgress().width(32).height(32).margin({ top: 48 })
              Text(this.uiText("pm_loading_board_3d66e034")).fontColor($r('app.color.secondary_text'))
            }
          } else if (!this.snapshot.ready && this.snapshot.error) {
            Text(PinmonyI18n.render(this.snapshot.error, this.uiLanguage)).fontColor($r('app.color.secondary_text')).margin({ top: 48 })
            Button(this.uiText("pm_retry_b8784c8d")).onClick(() => { if (this.onRetry) this.onRetry(); })
          } else if (this.snapshot.ready && this.snapshot.pins.length === 0 && this.phase() !== 'ideas' && this.phase() !== 'section') {
            Text(this.uiText("pm_no_saved_pins_yet_24c645e0")).fontSize(17).fontColor($r('app.color.primary_text')).margin({ top: 64 })
          } else {
            WaterFlow() {
              ForEach((this.phase() === 'ideas' || this.phase() === 'section') ? this.snapshot.flow?.pins || [] : this.snapshot.pins, (pin: PinmonyBoardPin) => {
                FlowItem() {
                  this.card(pin)
                }
                .width('100%')
              }, (pin: PinmonyBoardPin) => pin.id)
            }
            .width('100%')
            .columnsTemplate(this.contentColumnsTemplate())
            .columnsGap(12)
            .rowsGap(12)
          }
          if (this.phase() === 'ideas') {
            this.flowContent()
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && this.snapshot.flow?.pins.length === 0) {
              Text(this.uiText("pm_no_more_ideas_35120ab6")).fontColor($r('app.color.secondary_text'))
            }
          }
          if (this.snapshot.loadingMore && !this.isDiscoveryBoard()) {
            LoadingProgress().width(28).height(28)
          } else if (this.snapshot.ready && this.snapshot.error) {
            Text(PinmonyI18n.render(this.snapshot.error, this.uiLanguage)).fontColor($r('app.color.secondary_text'))
            Button(this.uiText("pm_retry_b8784c8d")).onClick(() => { if (this.onRetry) this.onRetry(); })
          }
        }
        .width('100%')
        .onAreaChange((_old: Area, area: Area) => {
          const width: number = Number(area.width);
          if (width > 0 && Math.abs(width - this.contentWidth) > 1) this.contentWidth = width;
        })
        .padding({ left: 16, right: 16, top: 18, bottom: 40 })
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
        if (this.phase() === 'section') this.act('sectionMore');
        else if (this.phase() === 'targets') this.act('targetsMore');
        else if ((!this.phase() || this.selectingPins()) && this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
      })
      }
      .width('100%').height('100%')
      .pullToRefresh(!this.phase() && !this.snapshot.loading && !this.snapshot.refreshing && (this.snapshot.session > 0 || this.snapshot.nativeReadsReady === true))
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      if (this.snapshot.editable === true && (!this.phase() || this.phase() === 'section') && !this.isDiscoveryBoard()) {
        Button('+').width(56).height(56).fontSize(32)
          .backgroundColor($r('app.color.page_background')).fontColor($r('app.color.primary_text'))
          .margin({ bottom: 20 }).enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
          .onClick(() => { if ((!this.phase() || this.phase() === 'section') && this.onPublish) this.onPublish(); }).accessibilityText(this.uiText("pm_publish_b61f333b"))
      }
      }.width('100%').height('100%')
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
      height: SheetSize.FIT_CONTENT, showClose: true, dragBar: true,
      title: { title: this.phase() === 'section' ? this.uiText("pm_section_options_1e74fdd5") : this.uiText("pm_board_options_33bd1089") }, maskColor: '#66000000',
      backgroundColor: $r('app.color.page_background'),
      onDisappear: () => {
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
    return (this.selectingPins() || this.phase() === 'targets') &&
      (!!this.snapshot.flow?.loading || !!this.snapshot.flow?.busy);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      HdsNavigation(this.boardPathStack) {
        Column().width('100%').height('100%')
      }
      .width('100%').height('100%')
      .hideTitleBar(true)
      .navDestination(this.boardDestination)
      .backgroundColor($r('app.color.page_background'))
      .accessibilityLevel(this.organizeLoading() ? 'no-hide-descendants' : 'auto')
      if (this.organizeLoading()) {
        PinmonyLoadingOverlay({ message: this.snapshot.flow?.busy ? this.uiText("pm_submitting_please_wait_e7f123ba") : this.uiText("pm_loading_saved_boards_4262c72d") })
      } else if (this.isDiscoveryBoard() && this.snapshot.loading && !this.snapshot.boardId && !this.phase()) {
        Column({ space: 14 }) {
          LoadingProgress().width(32).height(32)
          Text(this.uiText("pm_loading_board_3d66e034")).fontColor($r('app.color.secondary_text'))
        }
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(this.uiText("pm_loading_board_b5e739be"))
      }
    }.width('100%').height('100%')
  }
}
