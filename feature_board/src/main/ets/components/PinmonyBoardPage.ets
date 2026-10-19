import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardTarget, PinmonyBoardSection } from '../models/PinmonyBoardDetail';
import { boardSectionPreviewImages } from '../services/PinmonyBoardPresentation';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardPlaceholder, PinmonyLoadingOverlay } from 'common_ui';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarIconType } from '@kit.UIDesignKit';

interface BoardTitleMenuItem {
  content: BoardTitleMenuContent;
}

interface BoardTitleMenuContent {
  icon: Resource;
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
      { title: '已收藏至 ' + this.snapshot.title }, {}, { duration: 4000 });
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
    this.getUIContext().showAlertDialog({ title: '删除图板',
      message: '永久删除此图板和其中的所有 Pin 图。此操作无法撤销！',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除图板', action: () => {
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
      icon: $r('app.media.lucide_share_2'), label: '分享图板', isEnabled: this.snapshot.ready,
      action: () => { if (this.onShare) this.onShare(); }
    } };
    if (this.snapshot.editable !== true) {
      const follow: BoardTitleMenuItem = { content: {
        icon: $r('app.media.board_follow_outline'), label: this.snapshot.followBusy ? '处理中…' : this.snapshot.following ? '取消关注' : '关注',
        isEnabled: this.snapshot.ready && this.snapshot.canFollow === true && !this.snapshot.followBusy,
        action: () => { if (this.snapshot.canFollow && !this.snapshot.followBusy) this.act('followToggle'); }
      } };
      return [share, follow];
    }
    const options: BoardTitleMenuItem = { content: {
      icon: $r('app.media.lucide_ellipsis'), label: '图板选项', isEnabled: this.snapshot.ready,
      action: () => { this.archiveOpen = false; this.menuOpen = true; }
    } };
    return this.isDiscoveryBoard() ? [options] : [share, options];
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      // Reserve the official title bar's component area above the scrolling content.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: false },
        scrollEffectStyle: { contentStyle: { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text'), subTitleColor: $r('app.color.secondary_text') } } }, originalStyle: {  backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
        }, contentStyle: this.isDiscoveryBoard() ? {
          backIconStyle: { backgroundColor: Color.Transparent, iconColor: $r('app.color.primary_text') },
          menuStyle: { backgroundColor: Color.Transparent, iconColor: $r('app.color.primary_text') }
        } : { backIconStyle: { iconColor: $r('app.color.primary_text') }, menuStyle: { iconColor: $r('app.color.primary_text'), textColor: $r('app.color.primary_text') }, titleStyle: { mainTitleColor: $r('app.color.primary_text') } } }
      },
      content: {
        title: { mainTitle: this.creatingTarget ? '添加图板区块' : this.selectingPins() ? '选择 Pin 图' : this.phase() === 'targets' ? '选择图板区块' :
          this.phase() === 'sectionEdit' ? '编辑图板区块' : this.phase() === 'section' ? '' : this.phase() === 'ideas' ? '更多点子' : this.phase() === 'edit' ? '编辑图板' : this.isDiscoveryBoard() ? (this.headerScrolled && this.snapshot.title !== '图板' ? this.snapshot.title : '') : this.snapshot.title || '' },
        backIcon: this.selectingPins() || this.phase() === 'edit' || this.phase() === 'sectionEdit' ? {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          label: this.phase() === 'edit' ? '关闭编辑' : '关闭整理', isEnabled: !this.snapshot.flow?.busy, action: () => this.back()
        } : { isEnabled: !this.snapshot.flow?.busy, action: () => this.back() },
        menu: { value: this.phase() === 'sectionEdit' ? [{content:{icon:new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),label:'完成',isEnabled:!!this.sectionEditName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,action:() => this.act('sectionRename',this.sectionEditName.trim())}}] : this.creatingTarget ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '下一步', isEnabled: !!this.targetName.trim() && !this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain,
          action: () => this.act('sectionCreateSelected', this.targetName.trim())
        } }] : this.phase() === 'sectionSelect' ? [{ content: {
          label: this.selectedIds.length ? '完成' : '跳过', isEnabled: !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.loadingMore,
          action: () => { if(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && this.onAction)this.onAction(JSON.stringify({action:'sectionCreate',value:this.selectedIds})); }
        } }] : this.selectingPins() ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '下一步', isEnabled: this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy,
          action: () => {
            if (this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy && this.onAction)
              this.onAction(JSON.stringify({ action: 'targets', value: this.selectedIds }));
          }
        } }] : this.phase() === 'edit' && this.snapshot.editable ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '完成', isEnabled: !!this.editName.trim() && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,
          action: () => this.saveEdit()
        } }] : this.phase() === 'section' ? (this.snapshot.editable === true ? [{ content: {icon:$r('app.media.lucide_ellipsis'),label:'图板区块选项',isEnabled:!this.snapshot.flow?.loading,action:() => {this.menuOpen = true;}} }] : []) : !this.phase() ? this.boardTitleMenu() : [] }
      }
    };
  }

  private selectionPins(): PinmonyBoardPin[] { return this.snapshot.flow?.sectionId && this.selectingPins() || this.snapshot.flow?.sectionId && this.phase() === 'targets' ? this.snapshot.flow?.pins || [] : this.snapshot.pins; }

  private rows(): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < this.selectionPins().length; index += 3) result.push(index);
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
          Text('已收藏至 ' + this.snapshot.title + ' 图板').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).width('100%').padding({ left: 14, right: 14, top: 16 }).maxLines(2)
          Blank()
        }.width('100%').aspectRatio(pin.imageWidth / pin.imageHeight).backgroundColor('#55000000')
          .hitTestBehavior(HitTestMode.None)
      }
      if (pin.cancelled) {
        Column() {
          Text('已取消收藏，重新进入图板后移除').fontSize(14).fontWeight(FontWeight.Medium)
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
          .accessibilityText(this.snapshot.flow?.saved.includes(pin.id) ? '取消收藏' : '收藏至' + this.snapshot.title)
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
            .accessibilityText('更多选项')
        }.width('100%')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .accessibilitySelected(this.selectingPins() && this.selectedIds.includes(pin.id))
    .accessibilityText(pin.title || '打开 Pin 图')
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
        if(!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.targetSections?.length) {Text('此图板暂无图板区块').fontColor($r('app.color.secondary_text'))}
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
      Text('所有图板').fontSize(17).width('100%').fontColor($r('app.color.primary_text'))
      ForEach((this.snapshot.flow?.targets || []).filter((target: PinmonyBoardTarget): boolean => !this.snapshot.flow?.sectionId || target.id !== this.snapshot.boardId && !target.id.startsWith('section:')), (target: PinmonyBoardTarget) => {
        this.moveTargetRow(target)
      }, (target: PinmonyBoardTarget) => target.id)
      }
    } else if (this.phase() === 'edit') {
      this.editContent()
    } else if (this.phase() === 'archived') {
      Text('图板已存档').fontSize(20).fontColor($r('app.color.primary_text'))
      Button('关闭').onClick(() => this.act('close'))
    }
    if (!this.organizeLoading() && (this.snapshot.flow?.loading || this.snapshot.flow?.busy)) { LoadingProgress().width(32).height(32) }
    if (this.snapshot.flow?.error) {
      Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text'))
      if (!this.snapshot.flow.uncertain) { Button('重试').onClick(() => this.act('retry')) }
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
      Text('消息').fontSize(14).fontColor($r('app.color.primary_text'))
    }
  }

  private confirmLeave(): void {
    if (!this.snapshot.collaborator || this.snapshot.editable || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const identity: string = this.confirmationKey();
    const page: string = this.snapshot.pageKey;
    this.getUIContext().showAlertDialog({ title: '离开图板？', message: '此图板将从你的个人资料中移除，你将无法继续向此图板收藏 Pin 图。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '离开', action: () => {
        if (this.confirmationKey() === identity && this.snapshot.pageKey === page && this.phase() === 'edit' && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) this.act('leave');
      } } });
  }

  private sectionRows(): number[] {
    const rows: number[] = [];
    for (let index: number = 0; index < (this.snapshot.sections?.length || 0); index += 2) rows.push(index);
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
      if (section.pinCount !== undefined) { Text(section.pinCount + ' 张 Pin 图').fontSize(13).fontColor($r('app.color.secondary_text')) }
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).enabled(this.snapshot.ready)
      .accessibilityText('图板区块：' + section.title + (section.pinCount === undefined ? '' : '，' + section.pinCount + ' 张 Pin 图'))
      .onClick(() => this.act('section', section.id))
  }

  @Builder
  private sectionEditContent() {
    Column({ space: 20 }) {
      Text('图板区块名称').fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
      TextInput({ text: this.sectionEditName }).maxLength(100).enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain).onChange((value: string) => {this.sectionEditName = value;})
        .height(52).borderRadius(16).border({width:1,color:$r('app.color.secondary_text')})
      Column({ space: 8 }) {
        this.editLabel('操作')
        Text('删除图板区块').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain).onClick(() => this.confirmSectionDelete())
        Text('永久删除此图板区块和其中的所有 Pin 图。此操作无法撤销！').fontSize(15).fontColor($r('app.color.secondary_text'))
      }.width('100%').alignItems(HorizontalAlign.Start).margin({top:16})
      if(this.snapshot.flow?.busy) { LoadingProgress().width(28).height(28) }
      if(this.snapshot.flow?.error) { Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text')) }
    }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
  }

  private confirmSectionDelete(): void {
    const identity: string = this.confirmationKey(), section: string = this.snapshot.flow?.sectionId || '';
    if(this.phase() !== 'sectionEdit' || this.snapshot.flow?.busy || this.snapshot.flow?.loading || this.snapshot.flow?.uncertain)return;
    this.getUIContext().showAlertDialog({title:'删除图板区块',message:'永久删除此图板区块和其中的所有 Pin 图。此操作无法撤销！',
      primaryButton:{value:'取消',action:(): void => {}},secondaryButton:{value:'删除图板区块',action:(): void => {
        if(this.confirmationKey() === identity && this.snapshot.flow?.sectionId === section && this.phase() === 'sectionEdit' &&
          !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)this.act('sectionDelete');
      }}});
  }

  @Builder
  private editContent() {
    Column({ space: 20 }) {
      if (this.snapshot.editable) {
      Column({ space: 10 }) {
        this.editLabel('名称')
        TextInput({ text: this.editName }).maxLength(100).height(48).borderRadius(16)
          .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.secondary_text') })
          .fontColor($r('app.color.primary_text')).onChange((value: string) => { this.editName = value; })
          .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy)
      }.width('100%')
      Column({ space: 10 }) {
        this.editLabel('描述')
        TextArea({ text: this.editDescription, placeholder: '添加' }).maxLength(500).height(82).borderRadius(16)
          .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.secondary_text') })
          .fontColor($r('app.color.primary_text')).onChange((value: string) => { this.editDescription = value; })
          .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy)
        this.setting('将此图板设为私密图板', '此内容仅对你和你的合作用户可见', this.secret, (value: boolean) => { this.secret = value; })
      }.width('100%')
      }
      Column({ space: 10 }) {
        this.editLabel('合作用户')
        Row() {
          if (this.snapshot.collaboratorAvatars?.length) {
            Row() {
              ForEach(this.snapshot.collaboratorAvatars || [], (avatar: string, index: number) => {
                Image(avatar).width(48).height(48).borderRadius(24).margin({ left: index > 0 ? -16 : 0 })
              }, (avatar: string) => avatar)
            }
          } else if (this.snapshot.memberAvatar || this.snapshot.ownerAvatar) {
            Image(this.snapshot.memberAvatar || this.snapshot.ownerAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(48).height(48).borderRadius(24)
          }
          Blank()
          Button('+').fontSize(26).width(48).height(48).borderRadius(10)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .enabled(!this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
            .onClick(() => { if (this.onCollaborators) this.onCollaborators(); }).accessibilityText('添加合作用户')
        }.width('100%')
      }.width('100%')
      if (this.snapshot.editable) {
      Column({ space: 24 }) {
        this.editLabel('设置')
        this.setting('个性化', '在主页中显示灵感来自此图板的 Pin 图', this.recommend, (value: boolean) => { this.recommend = value; })
        this.setting('图板请求', '用户可以请求加入此图板', this.requests, (value: boolean) => { this.requests = value; })
      }.width('100%')
      Column({ space: 8 }) {
        this.editLabel('操作')
        Text('删除图板').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).onClick(() => this.confirmDelete())
        Text('永久删除此图板和其中的所有 Pin 图。此操作无法撤销！').fontSize(15).fontColor($r('app.color.secondary_text'))
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 16 })
      } else {
        Column({ space: 8 }) {
          this.editLabel('操作')
          Text('离开图板').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
            .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.loading && !this.snapshot.flow?.uncertain)
            .onClick(() => this.confirmLeave())
          Text('离开此群组图板并将其从个人资料中移除。你将无法将新的 Pin 图收藏到此图板。').fontSize(15).fontColor($r('app.color.secondary_text'))
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
      title: '将图板存档？',
      message: '如果将 ' + this.snapshot.title + ' 存档，它将不会出现在你的个人资料中，你也无法将新的 Pin 图收藏至此图板。如果改变主意，你可以取消存档。',
      autoCancel: false,
      primaryButton: { value: '取消', action: () => {
        if (this.confirmationKey() !== identity || this.snapshot.pageKey !== page) return;
        this.archiveOpen = false; this.act('close');
      } },
      secondaryButton: { value: '存档', action: () => {
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
            this.optionRow('编辑', 'sectionEdit')
            this.optionRow('分享', 'sectionShare')
          } else if (this.isDiscoveryBoard()) {
            this.optionRow('分享', 'share')
            this.optionRow('关注', 'follow')
          } else {
            this.optionRow('编辑信息和设置', 'edit')
            this.optionRow('存档', 'archiveConfirm')
          }
          if (!this.isDiscoveryBoard() && this.snapshot.collaborator && !this.snapshot.editable) {
            this.optionRow('取消关注', 'unfollow')
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
      Button(this.selectedIds.length === this.selectionPins().length ? '取消全选' : '全选')
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
      }, (start: number) => start.toString())
      if (this.snapshot.loadingMore) { LoadingProgress().width(28).height(28) }
      if (this.snapshot.error) {
        Text(this.snapshot.error).fontColor($r('app.color.secondary_text'))
        Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
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
            TextInput({ placeholder: '名称', text: this.targetName }).maxLength(100).height(80)
              .border({ width: 1, color: $r('app.color.secondary_text') }).borderRadius(16)
              .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
              .onChange((value: string) => { this.targetName = value; })
            if (this.snapshot.flow?.busy) { LoadingProgress().width(32).height(32) }
            if (this.snapshot.flow?.error) { Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text')) }
          } else if (this.selectingPins()) {
            if(this.snapshot.flow?.error) { Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text')) }
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
            Text('添加图板区块').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          }.width('100%')
        }.width('100%').height(76).padding({ left: 16, right: 16, top: 12, bottom: 20 }).borderRadius(0)
          .backgroundColor($r('app.color.page_background')).enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.loading && !this.snapshot.flow?.error).onClick(() => { this.targetName = ''; this.creatingTarget = true; }).accessibilityText('添加图板区块')
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
              Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text'))
              if (!this.snapshot.flow.uncertain) { Button('重试').onClick(() => this.confirmArchive()) }
              Button('取消').enabled(!this.snapshot.flow.busy).onClick(() => { this.archiveOpen = false; this.act('close'); })
            }
          }
          if (!this.phase() && this.invitationVisible) {
            Row({ space: 12 }) {
              Image(this.invitationAvatar).width(44).height(44).borderRadius(22)
              Column({ space: 12 }) {
                Text(this.invitationName + ' 邀请你在此图板上进行合作').fontSize(16).fontColor($r('app.color.primary_text'))
                Row({ space: 8 }) {
                  Button('拒绝').backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text')).enabled(false)
                  Button('接受').backgroundColor($r('app.color.accent')).fontColor(Color.White)
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
              Text(this.snapshot.title).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
            }
          }
          if (!this.phase() && this.snapshot.pinCount) {
            Row({ space: 8 }) {
              if (this.snapshot.privacy === 'secret') {
                Row({ space: 5 }) {
                  Image($r('app.media.board_private_lock')).width(17).height(17).fillColor($r('app.color.primary_text'))
                  Text('私密').fontSize(14).fontColor($r('app.color.primary_text'))
                }.padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(6)
                  .backgroundColor($r('app.color.surface_muted')).accessibilityText('私密图板')
                Text('·').fontSize(14).fontColor($r('app.color.secondary_text'))
              }
              if (this.snapshot.featuredCreator) { Text('精选创建者 ·').fontSize(14).fontColor($r('app.color.accent')) }
              Text(this.snapshot.pinCount).fontSize(14).fontColor($r('app.color.secondary_text'))
              if (this.isDiscoveryBoard() && (this.snapshot.sectionCount || 0) > 0) {
                Text('· ' + this.snapshot.sectionCount + ' 个图板区块').fontSize(14).fontColor($r('app.color.secondary_text'))
              }
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.featured && this.snapshot.description) {
            Text(this.snapshot.description).fontSize(16).fontColor($r('app.color.primary_text')).width('100%')
          }
          if (!this.phase() && this.snapshot.ownerName && !this.joinedAvatar) {
            Row({ space: 8 }) {
              if (this.snapshot.ownerAvatar) {
                Image(this.snapshot.ownerAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(32).height(32).borderRadius(16)
              }
              Column({ space: 4 }) {
                if (this.isDiscoveryBoard() && this.snapshot.sponsored) {
                  Text('精选赞助商').fontSize(13).fontColor($r('app.color.primary_text'))
                }
                Row({ space: 4 }) {
                  Text((this.isDiscoveryBoard() && this.snapshot.sponsored ? '' : '来自 ') + this.snapshot.ownerName)
                    .fontSize(15).fontWeight(this.isDiscoveryBoard() && this.snapshot.sponsored ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor($r('app.color.primary_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '85%' })
                  if (this.isDiscoveryBoard() && this.snapshot.ownerVerified) {
                    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(10).fontColor([Color.White])
                      .padding(3).backgroundColor($r('app.color.accent')).borderRadius(8).accessibilityText('已认证')
                  }
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%')
          }
          if (!this.phase() && this.joinedAvatar) {
            Row({ space: 8 }) {
              Image(this.snapshot.memberAvatar || this.snapshot.ownerAvatar).width(36).height(36).borderRadius(18)
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
                  this.actionTile('整理', $r('app.media.lucide_brush_cleaning'), 'select', true)
                }
                this.actionTile('更多点子', $r('sys.symbol.square_grid_2x2'), 'ideas')
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
              } else if (this.snapshot.memberAvatar) {
                Image(this.snapshot.memberAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(36).height(36).borderRadius(18)
              }
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.lucide_user_round_plus')).width(20).height(20)
              }.width(36).height(36).backgroundColor($r('app.color.surface_muted'))
                .onClick(() => { if (this.onCollaborators) this.onCollaborators(); }).accessibilityText('邀请协作者')
            }.width('100%')
            Row({ space: 12 }) {
              if (this.snapshot.pins.length > 0) {
                this.actionTile('整理', $r('app.media.lucide_brush_cleaning'), 'select', true)
              }
              this.actionTile('更多点子', $r('sys.symbol.square_grid_2x2'), 'ideas')
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.sections?.length) {
            if (this.isDiscoveryBoard()) {
              ForEach(this.snapshot.sections || [], (section: PinmonyBoardSection) => {
                Column({ space: 12 }) {
                  Text(section.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
                    .width('100%').onClick(() => this.act('section', section.id)).accessibilityText('打开区块：' + section.title)
                  if (section.pins?.length) {
                    WaterFlow() {
                      ForEach(section.pins || [], (pin: PinmonyBoardPin) => {
                        FlowItem() { this.card(pin) }.width('100%')
                      }, (pin: PinmonyBoardPin) => pin.id)
                    }.width('100%').columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
                  }
                  if (!section.pins?.length || section.pinCount === undefined || section.pinCount > (section.pins?.length || 0)) {
                    Button('查看区块' + (section.pinCount === undefined ? '' : ' · ' + section.pinCount + ' 张 Pin 图')).backgroundColor($r('app.color.surface_muted'))
                      .fontColor($r('app.color.primary_text')).onClick(() => this.act('section', section.id))
                  }
                }.width('100%').alignItems(HorizontalAlign.Start)
              }, (section: PinmonyBoardSection) => section.id)
              if (this.snapshot.pins.length > 0) {
                Text('其他 Pin 图').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
              }
            } else {
            Column({ space: 24 }) {
              ForEach(this.sectionRows(), (index: number) => {
                Row({ space: 16 }) {
                  this.sectionCard(this.snapshot.sections![index])
                  if (index + 1 < (this.snapshot.sections?.length || 0)) {
                    this.sectionCard(this.snapshot.sections![index + 1])
                  } else { Blank().layoutWeight(1) }
                }.width('100%').alignItems(VerticalAlign.Top)
              }, (index: number) => this.snapshot.sections![index].id)
            }.width('100%')
            }
          }
          if (!this.phase() && this.snapshot.sectionsError) {
            Text(this.snapshot.sectionsError).fontSize(14).fontColor($r('app.color.secondary_text'))
            Button('重试读取区块').onClick(() => this.act('sectionsRetry'))
          }
          if (this.phase() === 'section') {
            Text(this.snapshot.title).fontSize(22).fontColor($r('app.color.accent')).width('100%').textAlign(TextAlign.Center).onClick(() => this.act('close'))
            Text(this.snapshot.flow?.sectionTitle || '图板区块').fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center)
            if (this.snapshot.editable === true) {
              Row({ space: 12 }) {
                if (this.snapshot.flow?.pins.length && this.snapshot.canContribute) {
                  this.actionTile('整理', $r('app.media.lucide_brush_cleaning'), 'sectionOrganize', true)
                }
                this.actionTile('更多点子', $r('sys.symbol.square_grid_2x2'), 'sectionIdeas')
              }.width('100%').justifyContent(FlexAlign.Center).direction(Direction.Ltr)
            }
            if (this.snapshot.flow?.loading) { LoadingProgress().width(28).height(28) }
            if (this.snapshot.flow?.error) { Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text')); Button('重试').onClick(() => this.act('retry')) }
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && !this.snapshot.flow?.pins.length) {
              Text('此区块内目前没有任何 Pin 图。').fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Center).margin({top:60,bottom:60})
            }
          }
          if (this.phase() && this.phase() !== 'select' && this.phase() !== 'ideas' && this.phase() !== 'section') {
            this.flowContent()
          } else if (this.snapshot.loading) {
            if (!this.isDiscoveryBoard()) {
              LoadingProgress().width(32).height(32).margin({ top: 48 })
              Text('正在加载图板…').fontColor($r('app.color.secondary_text'))
            }
          } else if (!this.snapshot.ready && this.snapshot.error) {
            Text(this.snapshot.error).fontColor($r('app.color.secondary_text')).margin({ top: 48 })
            Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
          } else if (this.snapshot.ready && this.snapshot.pins.length === 0 && this.phase() !== 'ideas' && this.phase() !== 'section') {
            Text('尚未收藏 Pin 图').fontSize(17).fontColor($r('app.color.primary_text')).margin({ top: 64 })
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
            .columnsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
          }
          if (this.phase() === 'ideas') {
            this.flowContent()
            if (!this.snapshot.flow?.loading && !this.snapshot.flow?.error && this.snapshot.flow?.pins.length === 0) {
              Text('暂无更多点子').fontColor($r('app.color.secondary_text'))
            }
          }
          if (this.snapshot.loadingMore && !this.isDiscoveryBoard()) {
            LoadingProgress().width(28).height(28)
          } else if (this.snapshot.ready && this.snapshot.error) {
            Text(this.snapshot.error).fontColor($r('app.color.secondary_text'))
            Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
          }
        }
        .width('100%').constraintSize({ maxWidth: 760 })
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
          .onClick(() => { if ((!this.phase() || this.phase() === 'section') && this.onPublish) this.onPublish(); }).accessibilityText('发布')
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
      title: { title: this.phase() === 'section' ? '图板区块选项' : '图板选项' }, maskColor: '#66000000',
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
        PinmonyLoadingOverlay({ message: this.snapshot.flow?.busy ? '正在提交，请稍候…' : '正在加载收藏图板…' })
      } else if (this.isDiscoveryBoard() && this.snapshot.loading && !this.snapshot.boardId && !this.phase()) {
        Column({ space: 14 }) {
          LoadingProgress().width(32).height(32)
          Text('正在加载图板…').fontColor($r('app.color.secondary_text'))
        }
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText('正在加载图板')
      }
    }.width('100%').height('100%')
  }
}
