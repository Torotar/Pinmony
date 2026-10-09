import { CapsuleSegmentButtonV2, SegmentButtonV2Items } from '@kit.ArkUI';
import { PinWebInboxItem, PinWebInboxSnapshot } from '../models/PinWebInbox';

@Component
export struct PinWebInboxPage {
  @Prop @Watch('onSnapshotChanged') snapshot: PinWebInboxSnapshot = {} as PinWebInboxSnapshot;
  @Prop actionsReady: boolean = true;
  @Prop sectionReady: boolean = true;
  @Prop interactionReady: boolean = true;
  @Prop retainedContent: boolean = false;
  @Prop initialScrollOffset: number = 0;
  onContentScroll?: (offset: number, state: ScrollState) => void;
  onScrollAvailability?: (scrollable: boolean) => void;
  onScrollPosition?: (pageUrl: string, section: string, offset: number) => void;
  private readonly scroller: Scroller = new Scroller();
  private activeSection: string = '';
  private restoringScroll: boolean = false;
  private contentHeight: number = 0;
  private viewportHeight: number = 0;
  @Prop loading: boolean = false;
  @Prop refreshing: boolean = false;
  onRefresh?: () => void;
  @Prop error: string = '';
  onSection?: (section: string) => void;
  onUser?: (url: string) => void;
  onAction?: (id: string) => void;
  onHome?: () => void;
  onRetry?: () => void;
  onLoadMore?: () => void;
  onContactsRetry?: () => void;

  aboutToAppear(): void {
    this.activeSection = this.snapshot.section;
    this.restoringScroll = this.initialScrollOffset > 0;
    if (this.onScrollAvailability) this.onScrollAvailability(false);
  }

  private onSnapshotChanged(): void {
    if (this.activeSection === this.snapshot.section) return;
    this.activeSection = this.snapshot.section;
    // Each segment starts expanded; layout determines whether its own
    // content permits scroll-driven bottom-bar collapse.
    if (this.onScrollAvailability) this.onScrollAvailability(false);
    this.restoreScroll();
  }

  private restoreScroll(): void {
    this.restoringScroll = true;
    setTimeout(() => {
      try { this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.initialScrollOffset), animation: false }); }
      catch (_) { console.warn('PinWeb: inbox scroll restoration unavailable'); }
      this.restoringScroll = false;
      this.reportScrollAvailability();
    }, 0);
  }

  private contentOverflowsViewport(): boolean {
    return Number.isFinite(this.contentHeight) && Number.isFinite(this.viewportHeight) &&
      this.viewportHeight > 0 && this.contentHeight > this.viewportHeight + 1;
  }

  private reportScrollAvailability(): void {
    if (this.onScrollAvailability) this.onScrollAvailability(this.contentOverflowsViewport());
  }

  private releaseScrollMeasurements(): void {
    this.contentHeight = 0;
    this.viewportHeight = 0;
    this.reportScrollAvailability();
  }

  private reportScroll(): void {
    if (this.restoringScroll) return;
    try {
      const position = this.scroller.offset();
      if (!position) return;
      if (this.onScrollPosition) this.onScrollPosition(this.snapshot.pageUrl, this.snapshot.section,
        Math.max(0, position.yOffset));
    } catch (_) { console.warn('PinWeb: inbox scroll position unavailable'); }
  }

  private timeText(item: PinWebInboxItem): string {
    if (item.timeLabel) return item.timeLabel;
    if (!item.updatedAt) return '';
    const date: number = Date.parse(item.updatedAt);
    const minutes: number = Math.floor((Date.now() - date) / 60000);
    if (!Number.isFinite(date) || minutes < 0) return '';
    if (minutes < 60) return minutes.toString() + ' 分钟';
    if (minutes < 1440) return Math.floor(minutes / 60).toString() + ' 小时';
    return Math.floor(minutes / 1440).toString() + ' 天';
  }

  @Builder
  private groupTitle(label: string) {
    Text(label)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.primary_text'))
      .width('100%')
      .textAlign(TextAlign.Start)
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })
  }

  @Builder
  private updatesGroup(label: string, items: PinWebInboxItem[]) {
    if (items.length > 0) {
      if (label) { this.groupTitle(label) }
      ForEach(items, (item: PinWebInboxItem) => { this.itemRow(item, false) },
        (item: PinWebInboxItem) => item.id)
    }
  }

  @Builder
  private itemRow(item: PinWebInboxItem, contact: boolean = true) {
    Row({ space: 14 }) {
      if (item.imageUrl) {
        Image(item.imageUrl)
          .width(48)
          .height(48)
          .borderRadius(24)
          .objectFit(ImageFit.Cover)
          .onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); else if (item.enabled && this.onAction) this.onAction(item.id); })
      } else {
        Text(item.title.slice(0, 1).toUpperCase())
          .fontSize(23)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#5867B5')
          .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      }
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
            .width('100%')
            .textAlign(TextAlign.Start)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      if (!contact && (this.timeText(item) || item.moreId)) {
        Column({ space: 8 }) {
          if (this.timeText(item)) {
            Text(this.timeText(item)).fontSize(12).fontColor($r('app.color.secondary_text'))
              .textAlign(TextAlign.End).width(48)
          }
          if (item.moreId) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 3 }) {
                ForEach([0, 1, 2], (dot: number) => {
                  Circle().width(3).height(3).fill($r('app.color.secondary_text'))
                })
              }
            }
              .padding(0).backgroundColor(Color.Transparent).width(40).height(40)
              .accessibilityText('更多操作')
              .onClick(() => {
                if (item.moreId && this.onAction) this.onAction(item.moreId);
              })
          }
        }.alignItems(HorizontalAlign.End).alignSelf(ItemAlign.Start)
      } else if (contact && item.enabled) {
        Text('›')
        .fontSize(26)
        .fontColor($r('app.color.secondary_text'))
        .margin({ left: 8 })
        .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .accessibilityDescription(item.enabled ? '' : '当前接口入口不可用')
    .accessibilityText(item.title + (item.subtitle ? '，' + item.subtitle : ''))
  }

  @Builder
  private emptyState() {
    Column({ space: 12 }) {
      Image(this.snapshot.section === 'updates' ?
        $r('app.media.inbox_updates_reference') : $r('app.media.inbox_messages_reference'))
        .width(this.snapshot.section === 'updates' ? 220 : 190)
        .height(this.snapshot.section === 'updates' ? 220 : 190)
        .objectFit(ImageFit.Contain)
        .accessibilityLevel('no')
      Text(this.snapshot.emptyTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
      Text(this.snapshot.emptyDescription)
        .fontSize(15)
        .lineHeight(23)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .maxLines(5)
      if (this.snapshot.section === 'updates' && this.snapshot.homeId && this.snapshot.homeLabel) {
        Button(this.snapshot.homeLabel)
          .fontSize(15)
          .fontColor($r('app.color.primary_text'))
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(16)
          .height(42)
          .margin({ top: 8 })
          .onClick(() => { if (this.onHome) this.onHome(); })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      if (this.snapshot.session > 0) {
        Row() {
          CapsuleSegmentButtonV2({
            items: new SegmentButtonV2Items([
              { text: this.snapshot.updateLabel },
              { text: this.snapshot.inboxLabel }
            ]),
            selectedIndex: this.snapshot.section === 'messages' ? 1 : 0,
            onItemClicked: (index: number) => {
              if (!this.refreshing && this.interactionReady &&
                ((!this.loading && !this.error) || this.snapshot.dataSource === 'api') && this.onSection) {
                this.onSection(index === 0 ? 'updates' : 'messages');
              }
            }
          })
          .width(280)
        }
        .width('100%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 12 })
      }

      Refresh({ refreshing: this.refreshing }) {
      Column() {
      if (this.loading || (this.error && !this.retainedContent)) {
        Column({ space: 16 }) {
          if (this.loading) {
            LoadingProgress()
              .width(28)
              .height(28)
            Text('正在读取收件箱…')
              .fontSize(15)
              .fontColor($r('app.color.secondary_text'))
          } else {
            Text(this.error)
              .fontSize(15)
              .fontColor($r('app.color.primary_text'))
              .textAlign(TextAlign.Center)
            Button('重试')
              .onClick(() => { if (this.onRetry) this.onRetry(); })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24, bottom: 110 })
      } else {
        if (this.error) {
          Row({ space: 12 }) {
            Text(this.error).fontSize(14).fontColor($r('app.color.secondary_text')).layoutWeight(1)
            Button('重试').onClick(() => { if (this.onRetry) this.onRetry(); })
          }.padding({ left: 20, right: 20, bottom: 12 }).width('100%')
        }
        Scroll(this.scroller) {
          Column() {
            if (this.snapshot.section === 'messages') {
              Row({ space: 12 }) {
                Text('✎')
                  .fontSize(31)
                  .fontColor(Color.White)
                  .textAlign(TextAlign.Center)
                  .width(54)
                  .height(54)
                  .borderRadius(18)
                  .backgroundColor($r('app.color.detail_accent'))
                Text(this.snapshot.composeLabel || '新消息')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 18, bottom: 18 })
              .accessibilityText(this.snapshot.composeLabel)
              .enabled(!!this.snapshot.composeId)
              .onClick(() => {
                if (this.snapshot.composeId && this.onAction) this.onAction(this.snapshot.composeId);
              })
            }

            if (this.snapshot.items.length === 0 && this.snapshot.emptyTitle) {
              Column() {
                this.emptyState()
              }
              .width('100%')
              .padding({ top: this.snapshot.section === 'updates' ? 120 : 24,
                bottom: this.snapshot.section === 'updates' ? 48 : 12 })
            } else if (this.snapshot.section === 'messages') {
              if (this.snapshot.items.length > 0) {
                this.groupTitle(this.snapshot.messagesLabel || '消息')
              }
              ForEach(this.snapshot.items, (item: PinWebInboxItem) => {
                this.itemRow(item, false)
              }, (item: PinWebInboxItem) => item.id)
            } else {
              this.updatesGroup(this.snapshot.unreadLabel || '未读',
                this.snapshot.items.filter((item: PinWebInboxItem) => item.unread === true))
              this.updatesGroup(this.snapshot.readLabel || '已读',
                this.snapshot.items.filter((item: PinWebInboxItem) => item.unread === false))
              this.updatesGroup('', this.snapshot.items.filter((item: PinWebInboxItem) => item.unread === undefined))
            }

            if (this.snapshot.section === 'updates' && this.snapshot.dataSource === 'api') {
              if (this.snapshot.moreLoading) {
                LoadingProgress().width(28).height(28).alignSelf(ItemAlign.Center)
              } else if (this.snapshot.hasMore || this.snapshot.moreError) {
                Button(this.snapshot.moreError || '加载更多').alignSelf(ItemAlign.Center)
                  .onClick(() => { if (this.onLoadMore) this.onLoadMore(); })
              } else if (this.snapshot.items.length === 0 && !this.snapshot.emptyTitle) {
                Text('暂无更新').fontColor($r('app.color.secondary_text')).alignSelf(ItemAlign.Center)
              }
            }
            if (this.snapshot.section === 'messages' &&
              (this.snapshot.contactsLabel || this.snapshot.contacts.length > 0)) {
              Text(this.snapshot.contactsLabel ||
                (this.snapshot.inboxLabel.toLowerCase() === 'inbox' ? 'Contacts' : '联系人'))
                .fontSize(18)
                .fontColor($r('app.color.primary_text'))
                .width('100%')
                .textAlign(TextAlign.Start)
                .margin({ top: 24, bottom: 8 })
                .padding({ left: 20 })
              if (this.snapshot.contactsLoading) {
                Row({ space: 12 }) {
                  LoadingProgress().width(24).height(24)
                  Text('正在读取联系人…').fontSize(14).fontColor($r('app.color.secondary_text'))
                }.padding({ left: 20, top: 12, bottom: 12 })
              } else if (this.snapshot.contactsError) {
                Column({ space: 8 }) {
                  Text(this.snapshot.contactsError).fontSize(14).fontColor($r('app.color.secondary_text'))
                  Button('重试').onClick(() => { if (this.onContactsRetry) this.onContactsRetry(); })
                }.alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12 })
              } else if (this.snapshot.contacts.length > 0) {
                ForEach(this.snapshot.contacts, (item: PinWebInboxItem) => {
                  this.itemRow(item)
                }, (item: PinWebInboxItem) => item.id)
              } else if (this.snapshot.contactsDataSource === 'api') {
                Text('暂无推荐联系人').fontSize(14).fontColor($r('app.color.secondary_text'))
                  .padding({ left: 20, top: 12, bottom: 12 })
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .constraintSize({ maxWidth: 720 })
          .padding({ bottom: 120 })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.contentHeight = Number(newArea.height);
            this.reportScrollAvailability();
          })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.viewportHeight = Number(newArea.height);
          this.reportScrollAvailability();
        })
        .onAppear(() => this.restoreScroll())
        .onDisAppear(() => this.releaseScrollMeasurements())
        .onDidScroll((_xOffset: number, offset: number, state: ScrollState) => {
          this.reportScroll();
          this.reportScrollAvailability();
          if (!this.restoringScroll && this.contentOverflowsViewport() && this.onContentScroll) {
            this.onContentScroll(offset, state);
          }
        })
        .onScrollStop(() => this.reportScroll())
      }
      }.width('100%').height('100%')
      }
      .width('100%').layoutWeight(1)
      .pullToRefresh(!this.refreshing && !this.loading)
      .onRefreshing(() => { if (this.onRefresh) this.onRefresh(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}


