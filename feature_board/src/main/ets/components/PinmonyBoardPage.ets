import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardTarget } from '../models/PinmonyBoardDetail';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { PinmonyBoardPlaceholder, PinmonyLoadingOverlay } from 'common_ui';
import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions, HdsSnackBar, SnackBarIconType } from '@kit.UIDesignKit';

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
  @Prop @Watch('snapshotChanged') snapshot: PinmonyBoardDetail;
  @State private menuOpen: boolean = false;
  @State private archiveOpen: boolean = false;
  @State private selectedIds: string[] = [];
  @State private editName: string = '';
  @State private editDescription: string = '';
  @State private secret: boolean = false;
  @State private recommend: boolean = false;
  @State private invites: boolean = false;
  @State private requests: boolean = false;
  private editingSession: number = 0;
  private selectionSession: number = 0;
  private savedSession: string = '';
  private confirmedSaved: string[] = [];
  private savedSnack: HdsSnackBar | undefined = undefined;
  onAction?: (value: string) => void;
  onUser?: (url: string) => void;
  onBack?: () => void;
  onPin?: (id: string) => void;
  onMore?: (id: string) => void;
  onShare?: () => void;
  onLoadMore?: () => void;
  onRetry?: () => void;
  onRefresh?: () => void;
  private readonly boardPathStack: NavPathStack = new NavPathStack();
  private readonly contentScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.savedSession = this.snapshot.pageKey + ':' + this.snapshot.session;
    this.confirmedSaved = (this.snapshot.flow?.saved || []).slice();
    this.boardPathStack.clear();
    this.boardPathStack.pushPath({ name: 'pin-web-board' }, false);
  }

  private snapshotChanged(): void {
    this.updateSavedFeedback();
    if (this.snapshot.flow?.phase === 'archive' && !this.archiveOpen && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)
      this.confirmArchive();
    if (this.archiveOpen && this.snapshot.flow?.phase !== 'archive') { this.menuOpen = false; this.archiveOpen = false; }
    if (!this.phase()) this.selectedIds = [];
    if (this.selectionSession !== this.snapshot.session) {
      this.selectionSession = this.snapshot.session; this.selectedIds = []; this.menuOpen = false;
    }
    if (this.phase() === 'edit' && !this.snapshot.flow?.loading && this.editingSession !== this.snapshot.session) {
      this.editingSession = this.snapshot.session;
      this.editName = this.snapshot.title; this.editDescription = this.snapshot.flow?.description || '';
      this.secret = this.snapshot.flow?.privacy === 'secret';
      this.recommend = this.snapshot.flow?.recommend === true;
      this.invites = this.snapshot.flow?.invites === true; this.requests = this.snapshot.flow?.requests === true;
    }
    if (this.phase() !== 'edit') this.editingSession = 0;
  }

  aboutToDisappear(): void { this.savedSnack?.dismiss(); }

  private updateSavedFeedback(): void {
    const session: string = this.snapshot.pageKey + ':' + this.snapshot.session;
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

  private phase(): string { return this.snapshot.flow?.phase === 'archive' ? '' : this.snapshot.flow?.phase || ''; }
  private saveEdit(): void {
    if (!this.editName.trim() || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const value: BoardEditValues = { name: this.editName, description: this.editDescription,
      privacy: this.secret ? 'secret' : 'public', recommend: this.recommend, invites: this.invites, requests: this.requests };
    if (this.onAction) this.onAction(JSON.stringify({ action: 'editSave', value: value }));
  }

  private confirmDelete(): void {
    if (this.phase() !== 'edit' || this.snapshot.flow?.loading || this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
    const session: number = this.snapshot.session;
    const page: string = this.snapshot.pageKey;
    this.getUIContext().showAlertDialog({ title: '删除图板',
      message: '永久删除此图板和其中的所有 Pin 图。此操作无法撤销！',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除图板', action: () => {
        if (this.snapshot.session === session && this.snapshot.pageKey === page && this.phase() === 'edit' &&
            !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain) this.act('delete');
      } }
    });
  }
  private act(action: string, value: string = ''): void {
    if (this.onAction) this.onAction(JSON.stringify({ action: action, value: value }));
  }
  private back(): void {
    if (this.snapshot.flow?.busy) return;
    if (this.snapshot.flow?.phase === 'archive') { this.archiveOpen = false; this.act('close'); return; }
    if (this.menuOpen) { this.menuOpen = false; if (this.archiveOpen) this.act('close'); this.archiveOpen = false; return; }
    if (this.phase()) this.act(this.phase() === 'targets' && !this.snapshot.flow?.uncertain ? 'select' : 'close');
    else if (this.onBack) this.onBack();
  }
  private toggle(id: string): void {
    this.selectedIds = this.selectedIds.includes(id) ? this.selectedIds.filter((value: string) => value !== id) :
      this.selectedIds.concat([id]);
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      // Reserve the official title bar's component area above the scrolling content.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: { enableScrollEffect: false },
        originalStyle: { backgroundStyle: {
          backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
        } }
      },
      content: {
        title: { mainTitle: this.phase() === 'select' ? '选择 Pin 图' : this.phase() === 'targets' ? '选择图板区块' :
          this.phase() === 'ideas' ? '更多点子' : this.phase() === 'edit' ? '编辑图板' : this.snapshot.title || '图板' },
        backIcon: this.phase() === 'select' || this.phase() === 'edit' ? {
          icon: new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('app.color.primary_text')]),
          label: this.phase() === 'edit' ? '关闭编辑' : '关闭整理', isEnabled: !this.snapshot.flow?.busy, action: () => this.back()
        } : { isEnabled: !this.snapshot.flow?.busy, action: () => this.back() },
        menu: { value: this.phase() === 'select' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '下一步', isEnabled: this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy,
          action: () => {
            if (this.selectedIds.length > 0 && !this.snapshot.loadingMore && !this.snapshot.flow?.busy && this.onAction)
              this.onAction(JSON.stringify({ action: 'targets', value: this.selectedIds }));
          }
        } }] : this.phase() === 'edit' ? [{ content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('app.color.primary_text')]),
          label: '完成', isEnabled: !!this.editName.trim() && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain,
          action: () => this.saveEdit()
        } }] : !this.phase() && this.snapshot.editable ? [{ content: {
          icon: $r('app.media.lucide_share_2'), label: '分享图板', isEnabled: this.snapshot.ready,
          action: () => { if (this.onShare) this.onShare(); }
        } }, { content: {
          icon: $r('app.media.lucide_ellipsis'),
          label: '图板选项', isEnabled: this.snapshot.ready,
          action: () => { this.archiveOpen = false; this.menuOpen = true; }
        } }] : [] }
      }
    };
  }

  private rows(): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < this.snapshot.pins.length; index += 3) result.push(index);
    return result;
  }

  @Builder
  private card(pin: PinmonyBoardPin) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
      Image(pin.imageUrl)
        .width('100%')
        .aspectRatio(this.phase() === 'select' ? Math.max(0.5, Math.min(1.4, pin.imageWidth / pin.imageHeight)) :
          pin.imageWidth / pin.imageHeight)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.phase() === 'select' ? 12 : 16)
      if (this.phase() === 'ideas' && this.snapshot.flow?.saved.includes(pin.id)) {
        Column() {
          Text('已收藏至 ' + this.snapshot.title + ' 图板').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).width('100%').padding({ left: 14, right: 14, top: 16 }).maxLines(2)
          Blank()
        }.width('100%').aspectRatio(pin.imageWidth / pin.imageHeight).backgroundColor('#55000000')
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.phase() === 'select' && this.selectedIds.includes(pin.id)) {
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.detail_on_accent')])
          .padding(6).backgroundColor($r('app.color.accent')).borderRadius(15).margin(6)
      }
      if (this.phase() === 'ideas') {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.snapshot.flow?.saved.includes(pin.id) ? $r('sys.symbol.checkmark') : $r('sys.symbol.plus'))
            .fontSize(24).fontColor([this.snapshot.flow?.saved.includes(pin.id) ? Color.White : Color.Black])
        }.width(36).height(36).margin(8)
          .backgroundColor(this.snapshot.flow?.saved.includes(pin.id) ? Color.Black : Color.White)
          .enabled(!this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain && !this.snapshot.flow?.saved.includes(pin.id))
          .onClick(() => this.act('save', pin.id))
          .accessibilityText('收藏至' + this.snapshot.title)
      }
      }.width('100%').borderRadius(this.phase() === 'select' ? 12 : 16).clip(true)
      .border({ width: this.phase() === 'select' && this.selectedIds.includes(pin.id) ? 2 : 0,
        color: $r('app.color.primary_text') })
      .onClick(() => {
        if (this.phase() === 'select') this.toggle(pin.id);
        else if (!this.phase() && this.onPin) this.onPin(pin.id);
      })
      if (!this.phase() || this.phase() === 'ideas') {
        Row() {
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(20).height(20).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.primary_text'))
          }.width(32).height(32).backgroundColor(Color.Transparent)
            .enabled(this.snapshot.ready && !this.snapshot.flow?.busy)
            .onClick(() => { if (this.onMore) this.onMore(pin.id); })
            .accessibilityText('更多选项')
        }.width('100%')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .accessibilitySelected(this.phase() === 'select' && this.selectedIds.includes(pin.id))
    .accessibilityText(pin.title || '打开 Pin 图')
  }

  @Builder
  private selectedPreview() {
    if (this.selectedIds.length > 0) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.snapshot.pins.filter((pin: PinmonyBoardPin) => this.selectedIds.includes(pin.id)), (pin: PinmonyBoardPin) => {
            Image(pin.imageUrl).width(42).height(58).objectFit(ImageFit.Cover).borderRadius(8)
              .onClick(() => { if (this.phase() === 'select') this.toggle(pin.id); })
          }, (pin: PinmonyBoardPin) => pin.id)
        }.padding(12)
      }.scrollable(ScrollDirection.Horizontal).height(82).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
    }
  }

  @Builder
  private flowContent() {
    if (this.phase() === 'targets') {
      Text('所有图板').fontSize(17).width('100%').fontColor($r('app.color.primary_text'))
      ForEach(this.snapshot.flow?.targets || [], (target: PinmonyBoardTarget) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 16 }) {
            if (target.imageUrl) { Image(target.imageUrl).width(56).height(56).borderRadius(16).objectFit(ImageFit.Cover) }
            else { PinmonyBoardPlaceholder() }
            Text(target.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
              .layoutWeight(1).maxLines(2)
          }.width('100%')
        }.width('100%').height(72).padding(0).borderRadius(12).backgroundColor(Color.Transparent)
          .onClick(() => {
            if (target.enabled && !this.snapshot.flow?.loading && !this.snapshot.flow?.busy && !this.snapshot.flow?.uncertain)
              this.act('move', target.id);
          })
      }, (target: PinmonyBoardTarget) => target.id)
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
  private editContent() {
    Column({ space: 20 }) {
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
      Column({ space: 10 }) {
        this.editLabel('合作用户')
        Row() {
          if (this.snapshot.memberAvatar || this.snapshot.ownerAvatar) {
            Image(this.snapshot.memberAvatar || this.snapshot.ownerAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(48).height(48).borderRadius(24)
          }
          Blank()
          Button('+').fontSize(26).width(48).height(48).borderRadius(10)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .onClick(() => {}).accessibilityText('添加合作用户')
        }.width('100%')
      }.width('100%')
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
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private editLabel(value: string) {
    Text(value).fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text')).width('100%')
  }

  private confirmArchive(): void {
    const session: number = this.snapshot.session;
    const page: string = this.snapshot.pageKey;
    this.archiveOpen = true;
    this.getUIContext().showAlertDialog({
      title: '将图板存档？',
      message: '如果将 ' + this.snapshot.title + ' 存档，它将不会出现在你的个人资料中，你也无法将新的 Pin 图收藏至此图板。如果改变主意，你可以取消存档。',
      autoCancel: false,
      primaryButton: { value: '取消', action: () => {
        if (this.snapshot.session !== session || this.snapshot.pageKey !== page) return;
        this.archiveOpen = false; this.act('close');
      } },
      secondaryButton: { value: '存档', action: () => {
        if (this.snapshot.session === session && this.snapshot.pageKey === page &&
            this.snapshot.flow?.phase === 'archive' && !this.snapshot.flow.busy && !this.snapshot.flow.uncertain)
          this.act('archive');
      } },
      cancel: () => {
        if (this.snapshot.session === session && this.snapshot.pageKey === page) {
          this.archiveOpen = false; this.act('close');
        }
      }
    });
  }

  @Builder
  private optionsSheet() {
    Column() {
        Column() {
          this.optionRow('编辑信息和设置', 'edit')
          this.optionRow('存档', 'archiveConfirm')
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
        this.act(action);
      })
  }

  @Builder
  private actionTile(label: string, icon: Resource, action: string) {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph(icon).fontSize(28).fontColor([$r('app.color.primary_text')])
      }.width(72).height(72).borderRadius(24).backgroundColor($r('app.color.surface_muted'))
        .onClick(() => this.act(action)).accessibilityText(label)
      Text(label).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
    }
  }

  @Builder
  private organizeSelection() {
    Column({ space: 16 }) {
      Button(this.selectedIds.length === this.snapshot.pins.length ? '取消全选' : '全选')
        .height(36).padding(0).fontSize(17).fontWeight(FontWeight.Bold)
        .backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
        .onClick(() => { this.selectedIds = this.selectedIds.length === this.snapshot.pins.length ? [] :
          this.snapshot.pins.map((pin: PinmonyBoardPin) => pin.id); })
      ForEach(this.rows(), (start: number) => {
        Row({ space: 12 }) {
          this.card(this.snapshot.pins[start])
          if (start + 1 < this.snapshot.pins.length) { this.card(this.snapshot.pins[start + 1]) }
          else { Blank().layoutWeight(1) }
          if (start + 2 < this.snapshot.pins.length) { this.card(this.snapshot.pins[start + 2]) }
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
      Scroll(this.contentScroller) {
        Column({ space: 8 }) {
          if (this.phase() === 'select') { this.organizeSelection() }
          else { this.flowContent() }
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
        .onReachEnd(() => {
          if (this.snapshot.flow?.busy || this.snapshot.flow?.uncertain) return;
          if (this.phase() === 'targets' && !this.snapshot.flow?.error) this.act('targetsMore');
          else if (this.phase() === 'select' && !this.snapshot.loadingMore && !this.snapshot.error &&
            this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
        })
      if (this.phase() === 'targets') {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 12 }) {
            Text('+').fontSize(26).width(44).height(44).textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(10).fontColor($r('app.color.primary_text'))
            Text('创建图板').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
          }.width('100%')
        }.width('100%').height(76).padding({ left: 16, right: 16, top: 12, bottom: 20 }).borderRadius(0)
          .backgroundColor($r('app.color.page_background')).onClick(() => {})
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private boardDestination(_name?: string, _param?: Object) {
    HdsNavDestination() {
      if (this.phase() === 'select' || this.phase() === 'targets') {
        this.organizeContent()
      } else {
      Stack({ alignContent: Alignment.Bottom }) {
      Refresh({ refreshing: this.snapshot.refreshing === true }) {
      Scroll(this.contentScroller) {
        Column({ space: 16 }) {
          if (this.snapshot.flow?.phase === 'archive') {
            if (this.snapshot.flow.busy) { LoadingProgress().width(28).height(28) }
            if (this.snapshot.flow.error) {
              Text(this.snapshot.flow.error).fontColor($r('app.color.secondary_text'))
              if (!this.snapshot.flow.uncertain) { Button('重试').onClick(() => this.confirmArchive()) }
              Button('取消').enabled(!this.snapshot.flow.busy).onClick(() => { this.archiveOpen = false; this.act('close'); })
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
              Text(this.snapshot.pinCount).fontSize(14).fontColor($r('app.color.secondary_text'))
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.ownerName) {
            Row({ space: 8 }) {
              if (this.snapshot.ownerAvatar) {
                Image(this.snapshot.ownerAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(32).height(32).borderRadius(16)
              }
              Text('来自 ' + this.snapshot.ownerName).fontSize(15).fontColor($r('app.color.primary_text'))
            }.width('100%')
          }
          if (!this.phase() && this.snapshot.editable) {
            Row({ space: 8 }) {
              if (this.snapshot.memberAvatar) {
                Image(this.snapshot.memberAvatar).onClick(() => { if (this.snapshot.ownerUrl && this.onUser) this.onUser(this.snapshot.ownerUrl); }).width(36).height(36).borderRadius(18)
              }
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.lucide_user_round')).width(20).height(20).fillColor($r('app.color.primary_text'))
              }.width(36).height(36).backgroundColor($r('app.color.surface_muted'))
                .onClick(() => {}).accessibilityText('邀请协作者')
            }.width('100%')
            Row({ space: 12 }) {
              this.actionTile('整理', $r('sys.symbol.pin'), 'select')
              this.actionTile('更多点子', $r('sys.symbol.square_grid_2x2'), 'ideas')
            }.width('100%')
          }
          if (this.phase() && this.phase() !== 'select' && this.phase() !== 'ideas') {
            this.flowContent()
          } else if (this.snapshot.loading) {
            LoadingProgress().width(32).height(32).margin({ top: 48 })
            Text('正在加载图板…').fontColor($r('app.color.secondary_text'))
          } else if (!this.snapshot.ready && this.snapshot.error) {
            Text(this.snapshot.error).fontColor($r('app.color.secondary_text')).margin({ top: 48 })
            Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
          } else if (this.snapshot.ready && this.snapshot.pins.length === 0 && this.phase() !== 'ideas') {
            Text('尚未收藏 Pin 图').fontSize(17).fontColor($r('app.color.primary_text')).margin({ top: 64 })
          } else {
            WaterFlow() {
              ForEach(this.phase() === 'ideas' ? this.snapshot.flow?.pins || [] : this.snapshot.pins, (pin: PinmonyBoardPin) => {
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
          if (this.snapshot.loadingMore) {
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
      .align(Alignment.TopStart)
      .onReachEnd(() => {
        if (this.phase() === 'targets') this.act('targetsMore');
        else if ((!this.phase() || this.phase() === 'select') && this.snapshot.hasMore && this.onLoadMore) this.onLoadMore();
      })
      }
      .width('100%').height('100%')
      .pullToRefresh(!this.phase() && !this.snapshot.loading && !this.snapshot.refreshing && this.snapshot.session > 0)
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
      if (!this.phase()) {
        Button('+').width(56).height(56).fontSize(32)
          .backgroundColor($r('app.color.page_background')).fontColor($r('app.color.primary_text'))
          .margin({ bottom: 20 }).onClick(() => {}).accessibilityText('添加到图板')
      }
      }.width('100%').height('100%')
      }
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.contentScroller])
    .onBackPressed(() => {
      this.back();
      return true;
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor($r('app.color.page_background'))
    .bindSheet($$this.menuOpen, this.optionsSheet(), {
      height: SheetSize.FIT_CONTENT, showClose: true, dragBar: true,
      title: { title: '图板选项' }, maskColor: '#66000000',
      backgroundColor: $r('app.color.page_background'),
      onWillDismiss: (action: DismissSheetAction) => {
        if (this.snapshot.flow?.busy) return;
        this.menuOpen = false;
        action.dismiss();
      }
    })
  }

  private organizeLoading(): boolean {
    return (this.phase() === 'select' || this.phase() === 'targets') &&
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
      }
    }.width('100%').height('100%')
  }
}
