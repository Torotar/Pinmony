import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items } from '@kit.ArkUI';
import { PinmonyInboxItem, PinmonyInboxSnapshot } from '../models/PinmonyInbox';
import { PinmonyBoardInvitation, PinmonyBoardInvitations } from '../models/PinmonyBoardInvitation';
import { PinmonyBoardInvitationList } from './PinmonyBoardInvitationList';
import { PinmonyUserAvatar } from 'common_ui';

@Component
export struct PinmonyInboxPage {
  @StorageLink('pinmonyRootScrollTop2') @Watch('onRootScrollTop') private rootScrollTop: number = 0;
  private onRootScrollTop(): void {
    try {
      const scroller: Scroller = this.scroller;
      const offset: number = scroller.offset()?.yOffset || 0;
      if (offset <= 1) {
        if (!(this.refreshing || this.loading) && this.onRefresh) this.onRefresh();
      } else {
        scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
      }
    } catch (_) {}
  }

  @StorageLink('pinmonyLanguage') @Watch('syncSegmentItems') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('onSnapshotChanged') snapshot: PinmonyInboxSnapshot = {} as PinmonyInboxSnapshot;
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
  private segmentUpdateLabel: string = '';
  private segmentInboxLabel: string = '';
  private readonly segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: this.uiText("pm_updates_3055a035") }, { text: this.uiText("pm_inbox_63a5e7b7") }
  ]);

  private syncSegmentItems(): void {
    const update: string = PinmonyI18n.render(this.snapshot.updateLabel || PinmonyI18n.message("pm_updates_3055a035"), this.uiLanguage);
    const inbox: string = PinmonyI18n.render(this.snapshot.inboxLabel || PinmonyI18n.message("pm_inbox_63a5e7b7"), this.uiLanguage);
    if (this.segmentUpdateLabel === update && this.segmentInboxLabel === inbox) return;
    this.segmentUpdateLabel = update;
    this.segmentInboxLabel = inbox;
    this.segmentItems[0].text = update;
    this.segmentItems[1].text = inbox;
  }

  @State private sectionOpacity: number = 1;
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
  onList?: (section: string) => void;
  onRetry?: () => void;
  onLoadMore?: () => void;
  onContactsRetry?: () => void;
  @Prop invitations: PinmonyBoardInvitations | undefined = undefined;
  onInvitationPreview: (item: PinmonyBoardInvitation) => void = () => {};
  onInvitationAll: () => void = () => {};

  aboutToAppear(): void {
    this.syncSegmentItems();
    this.activeSection = this.snapshot.section;
    this.restoringScroll = this.initialScrollOffset > 0;
    if (this.onScrollAvailability) this.onScrollAvailability(false);
  }

  private onSnapshotChanged(): void {
    this.syncSegmentItems();
    if (this.activeSection === this.snapshot.section) return;
    this.activeSection = this.snapshot.section;
    this.sectionOpacity = 0;
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.sectionOpacity = 1;
    });
    // Each segment starts expanded; layout determines whether its own
    // content permits scroll-driven bottom-bar collapse.
    if (this.onScrollAvailability) this.onScrollAvailability(false);
    this.restoreScroll();
  }

  private restoreScroll(): void {
    this.restoringScroll = true;
    setTimeout(() => {
      try { this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, this.initialScrollOffset), animation: false }); }
      catch (_) { console.warn('Pinmony: inbox scroll restoration unavailable'); }
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
    } catch (_) { console.warn('Pinmony: inbox scroll position unavailable'); }
  }

  private selectSection(section: string): void {
    if (!this.refreshing && this.interactionReady && section !== this.snapshot.section &&
        ((!this.loading && !this.error) || this.snapshot.dataSource === 'api') && this.onSection) this.onSection(section);
  }

  private swipeSection(offsetX: number, offsetY: number): void {
    if (Math.abs(offsetX) < 48 || Math.abs(offsetX) <= Math.abs(offsetY)) return;
    if (offsetX < 0 && this.snapshot.section === 'updates') this.selectSection('messages');
    else if (offsetX > 0 && this.snapshot.section === 'messages') this.selectSection('updates');
  }

  private timeText(item: PinmonyInboxItem): string {
    if (item.timeLabel) return item.timeLabel;
    if (!item.updatedAt) return '';
    const date: number = Date.parse(item.updatedAt);
    const minutes: number = Math.floor((Date.now() - date) / 60000);
    if (!Number.isFinite(date) || minutes < 0) return '';
    if (minutes < 60) return minutes.toString() + this.uiText("pm_minutes_40de5434");
    if (minutes < 1440) return Math.floor(minutes / 60).toString() + this.uiText("pm_hours_8f82ece0");
    return Math.floor(minutes / 1440).toString() + this.uiText("pm_days_4ce3054e");
  }

  @Builder
  private groupTitle(label: string) {
    Text(PinmonyI18n.render(label, this.uiLanguage))
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.primary_text'))
      .width('100%')
      .textAlign(TextAlign.Start)
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })
  }

  @Builder
  private listTitle(label: string, section: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        Text(PinmonyI18n.render(label, this.uiLanguage)).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
          .layoutWeight(1).textAlign(TextAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.secondary_text')])
          .margin({ left: 8 })
      }.width('100%')
    }.width('100%').backgroundColor(Color.Transparent).padding({ left: 20, right: 20, top: 16, bottom: 8 })
      .stateEffect(false)
      .accessibilityText(label).onClick(() => { if (this.interactionReady && this.onList) this.onList(section); })
  }

  private updateRowKey(item: PinmonyInboxItem): string {
    return item.id + ':' + (item.subdued ? 'subdued' : 'normal') + ':' + (item.moreId || '');
  }

  @Builder
  private updatesGroup(label: string, items: PinmonyInboxItem[]) {
    if (items.length > 0) {
      if (label) { this.groupTitle(label) }
      ForEach(items, (item: PinmonyInboxItem) => { this.itemRow(item, false) },
        (item: PinmonyInboxItem) => this.updateRowKey(item))
    }
  }

  @Builder
  private itemRow(item: PinmonyInboxItem, contact: boolean = true) {
    Row({ space: 14 }) {
      if (item.imageUrl && !contact && !item.profileUrl && !/\/user\/default(?:[/_.-]|$)/i.test(item.imageUrl)) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Image(item.imageUrl).width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
          if (/评论了|commented on/i.test(item.title)) {
            Image($r('app.media.lucide_message_circle')).width(14).height(14)
              .fillColor($r('app.color.secondary_text')).padding(5).width(24).height(24)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(12)
              .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
          } else if (/点赞了|liked your/i.test(item.title)) {
            Image($r('app.media.lucide_heart_filled')).width(14).height(14)
              .fillColor($r('app.color.accent')).padding(5).width(24).height(24)
              .backgroundColor($r('app.color.surface_muted')).borderRadius(12)
              .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
          }
        }.width(48).height(48)
          .onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); else if (item.enabled && this.onAction) this.onAction(item.id); })
      } else {
        PinmonyUserAvatar({ image: item.imageUrl, name: item.title, avatarSize: 48 })
          .onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); else if (item.enabled && this.onAction) this.onAction(item.id); })
      }
      Column({ space: 4 }) {
        Text(PinmonyI18n.render(item.title, this.uiLanguage))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.subtitle) {
          Row({ space: 4 }) {
            if (item.outgoing) { SymbolGlyph($r('sys.symbol.arrow_up_circle')).fontSize(14).fontColor([$r('app.color.secondary_text')]) }
          Text(PinmonyI18n.render(item.subtitle, this.uiLanguage))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      if (!contact && (this.timeText(item) || item.moreId)) {
        Column({ space: 8 }) {
          if (this.timeText(item)) {
            Column({ space: 4 }) {
              if (this.timeText(item).includes('\n')) {
                Text(this.timeText(item).split('\n')[1])
                  .fontSize(12).fontColor($r('app.color.secondary_text')).maxLines(1)
              }
              Text(PinmonyI18n.render(this.timeText(item).split('\n')[0], this.uiLanguage))
                .fontSize(12).fontColor($r('app.color.secondary_text')).maxLines(1)
            }.alignItems(HorizontalAlign.End)
          }
          if (item.moreId) {
            Button({ type: ButtonType.Circle }) {
              Row({ space: 3 }) {
                ForEach([0, 1, 2], (dot: number) => {
                  Circle().width(3).height(3).fill(this.snapshot.section === 'updates' ?
                    $r('app.color.primary_text') : $r('app.color.secondary_text'))
                })
              }
            }
              .padding(0).backgroundColor(Color.Transparent).width(40).height(40)
              .accessibilityText(this.uiText("pm_more_actions_9f07d2ce"))
              .onClick(() => {
                if (item.moreId && this.onAction) this.onAction(item.moreId);
              })
          }
        }.constraintSize({ minWidth: 40 }).flexShrink(0).alignItems(HorizontalAlign.End).alignSelf(ItemAlign.Center)
      } else if (contact && item.enabled) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.secondary_text')])
        .margin({ left: 8 })
        .onClick(() => { if (item.enabled && this.onAction) this.onAction(item.id); })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .opacity(item.subdued ? 0.45 : 1)
    .accessibilityDescription(item.enabled ? '' : this.uiText("pm_service_unavailable_87f44469"))
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
      Text(PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
      Text(PinmonyI18n.render(this.snapshot.emptyDescription, this.uiLanguage))
        .fontSize(15)
        .lineHeight(23)
        .fontColor($r('app.color.primary_text'))
        .textAlign(TextAlign.Center)
        .maxLines(5)
      if (this.snapshot.section === 'updates' && this.snapshot.homeId && PinmonyI18n.render(this.snapshot.homeLabel, this.uiLanguage)) {
        Button(PinmonyI18n.render(this.snapshot.homeLabel, this.uiLanguage))
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
      if (this.snapshot.updateLabel && this.snapshot.inboxLabel) {
        Row() {
          CapsuleSegmentButtonV2({
            items: this.segmentItems,
            enableStateAnimation: true,
            selectedIndex: this.snapshot.section === 'messages' ? 1 : 0,
            onItemClicked: (index: number) => {
              this.selectSection(index === 0 ? 'updates' : 'messages');
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
            Text(this.uiText("pm_loading_inbox_b0cbe6ba"))
              .fontSize(15)
              .fontColor($r('app.color.secondary_text'))
          } else {
            PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24, bottom: 110 })
      } else {
        if (this.error) {
          Row({ space: 12 }) {
            PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onRetry) this.onRetry(); } })
          }.padding({ left: 20, right: 20, bottom: 12 }).width('100%')
        }
        Scroll(this.scroller) {
          Column() {
            if (this.snapshot.section === 'messages' && this.invitations && this.invitations.items.length > 0) {
              PinmonyBoardInvitationList({ snapshot: this.invitations, onPreview: this.onInvitationPreview, onAll: this.onInvitationAll })
            }
            if (this.snapshot.section === 'messages') {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('app.media.lucide_pen_line')).width(28).height(28)
                    .accessibilityLevel('no')
                }.width(54)
                  .height(54)
                  .borderRadius(18)
                  .backgroundColor($r('app.color.detail_accent'))
                Text(PinmonyI18n.render(this.snapshot.composeLabel, this.uiLanguage) || this.uiText("pm_new_message_3fc957bf"))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18)
                  .fontColor([$r('app.color.secondary_text')])
                  .accessibilityLevel('no')
              }
              .width('100%')
              .padding({ left: 18, right: 20, top: 18, bottom: 18 })
              .accessibilityText(PinmonyI18n.render(this.snapshot.composeLabel, this.uiLanguage))
              .enabled(!!this.snapshot.composeId)
              .onClick(() => {
                if (this.interactionReady && this.snapshot.composeId && this.onAction) this.onAction(this.snapshot.composeId);
              })
            }

            if (this.snapshot.section === 'messages' && this.snapshot.items.length > 0) {
              this.listTitle(PinmonyI18n.render(this.snapshot.messagesLabel || '', this.uiLanguage) || this.uiText("pm_messages_4da199fa"), 'messages')
            }
            if (this.snapshot.items.length === 0 && PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage)) {
              Column() {
                this.emptyState()
              }
              .width('100%')
              .padding({ top: this.snapshot.section === 'updates' ? 120 : 24,
                bottom: this.snapshot.section === 'updates' ? 48 : 12 })
            } else if (this.snapshot.section === 'messages') {
              ForEach(this.snapshot.items, (item: PinmonyInboxItem) => {
                this.itemRow(item, false)
              }, (item: PinmonyInboxItem) => item.id)
            } else {
              this.updatesGroup(PinmonyI18n.render(this.snapshot.unreadLabel || '', this.uiLanguage) || this.uiText("pm_unread_4d0680f9"),
                this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === true))
              this.updatesGroup(PinmonyI18n.render(this.snapshot.readLabel || '', this.uiLanguage) || this.uiText("pm_read_efdd1a47"),
                this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === false))
              this.updatesGroup('', this.snapshot.items.filter((item: PinmonyInboxItem) => item.unread === undefined))
            }

            if (this.snapshot.section === 'updates' && this.snapshot.dataSource === 'api') {
              if (this.snapshot.moreLoading) {
                LoadingProgress().width(28).height(28).alignSelf(ItemAlign.Center)
              } else if (this.snapshot.hasMore || this.snapshot.moreError) {
                Button(this.snapshot.moreError || this.uiText("pm_load_more_af90a08f")).alignSelf(ItemAlign.Center)
                  .onClick(() => { if (this.onLoadMore) this.onLoadMore(); })
              } else if (this.snapshot.items.length === 0 && !PinmonyI18n.render(this.snapshot.emptyTitle, this.uiLanguage)) {
                Text(this.uiText("pm_no_updates_yet_7891215d")).fontColor($r('app.color.secondary_text')).alignSelf(ItemAlign.Center)
              }
            }
            if (this.snapshot.section === 'messages' &&
              (PinmonyI18n.render(this.snapshot.contactsLabel, this.uiLanguage) || this.snapshot.contacts.length > 0)) {
              this.listTitle(PinmonyI18n.render(this.snapshot.contactsLabel, this.uiLanguage) ||
                this.uiText("pm_contacts_3303b569"), 'contacts')
              if (this.snapshot.contactsLoading) {
                Row({ space: 12 }) {
                  LoadingProgress().width(24).height(24)
                  Text(this.uiText("pm_loading_contacts_54858f2d")).fontSize(14).fontColor($r('app.color.secondary_text'))
                }.padding({ left: 20, top: 12, bottom: 12 })
              } else if (this.snapshot.contactsError) {
                Column({ space: 8 }) {
                  PinmonyActionNotice({ active: this.interactionReady, message: PinmonyI18n.render(this.snapshot.contactsError, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => { if (this.onContactsRetry) this.onContactsRetry(); } })
                }.alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12 })
              } else if (this.snapshot.contacts.length > 0) {
                ForEach(this.snapshot.contacts, (item: PinmonyInboxItem) => {
                  this.itemRow(item)
                }, (item: PinmonyInboxItem) => item.id)
              } else if (this.snapshot.contactsDataSource === 'api') {
                Text(this.uiText("pm_no_suggested_contacts_03b9d232")).fontSize(14).fontColor($r('app.color.secondary_text'))
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
    .parallelGesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
      .onActionEnd((event: GestureEvent) => this.swipeSection(event.offsetX, event.offsetY)))
  }
}


