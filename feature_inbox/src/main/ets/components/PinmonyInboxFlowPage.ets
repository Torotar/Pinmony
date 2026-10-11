import { HdsNavigation, HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { InboxFlowUser, InboxFlowMessage, PinmonyInboxFlowSnapshot } from '../models/PinmonyInboxFlow';
interface ReactionPopupState { isVisible: boolean; }

@Component
export struct PinmonyInboxFlowPage {
  @Prop @Watch('snapshotChanged') snapshot: PinmonyInboxFlowSnapshot = {} as PinmonyInboxFlowSnapshot;
  onUser?: (url: string) => void;
  onAction?: (action: string, value: string) => void;
  onPin?: (url: string) => void;
  onNotifications?: () => void;
  onPinAction?: (action: string, url: string) => void;
  onNewsHidden?: (newsId: string) => void;
  onNewsRestored?: (newsId: string) => void;
  onBlockChanged?: (blocked: boolean, userName: string) => void;
  private scroller: Scroller = new Scroller();
  private positionedConversation: string = '';
  @State private query: string = '';
  @State private draft: string = '';
  @State private imageRatios: Map<string, number> = new Map<string, number>();
  @State private selectedMessage: InboxFlowMessage | undefined = undefined;
  @State private showMessageMenu: boolean = false;
  @State private reactionMessageId: string = '';
  @State private blockTarget: InboxFlowUser | undefined = undefined;
  private historyPending: boolean = false;
  private contentHeight: number = 0;
  private historyHeight: number = 0;
  private historyOffset: number = 0;
  private sentRevision: number = 0;
  @State private showUpdatesMenu: boolean = false;
  private queryToken: number = 0;
  private lastHiddenNewsId: string = '';
  private lastRestoredNewsId: string = '';
  private lastBlockRevision: number = 0;
  private flowPathStack: NavPathStack = new NavPathStack();
  aboutToAppear(): void { this.flowPathStack.pushPath({ name: 'inbox-flow' }, false); }

  private snapshotChanged(): void {
    if (this.historyPending && !this.snapshot.loading && this.snapshot.error) this.historyPending = false;
    if (this.snapshot.newsHidden && this.snapshot.newsId && this.snapshot.newsId !== this.lastHiddenNewsId) {
      this.lastHiddenNewsId = this.snapshot.newsId;
      if (this.snapshot.screen === 'updatesMenu') this.showUpdatesMenu = false;
      if (this.onNewsHidden) this.onNewsHidden(this.snapshot.newsId);
    }
    if (!this.snapshot.newsHidden && this.lastHiddenNewsId && this.snapshot.newsId === this.lastHiddenNewsId &&
        this.snapshot.newsId !== this.lastRestoredNewsId) {
      this.lastRestoredNewsId = this.snapshot.newsId;
      if (this.onNewsRestored) this.onNewsRestored(this.snapshot.newsId);
    }
    if ((this.snapshot.blockRevision || 0) > this.lastBlockRevision) {
      this.lastBlockRevision = this.snapshot.blockRevision || 0;
      const target: InboxFlowUser | undefined = this.snapshot.users.filter((user: InboxFlowUser) => user.id === this.snapshot.blockedUserId)[0];
      this.showMessageMenu = false;
      this.blockTarget = undefined;
      if (this.onBlockChanged) this.onBlockChanged(!!this.snapshot.blocked, target ? target.name : '联系人');
    }
    if ((this.snapshot.sentRevision || 0) > this.sentRevision) {
      this.sentRevision = this.snapshot.sentRevision || 0;
      this.draft = '';
      setTimeout((): void => { this.scroller.scrollEdge(Edge.Bottom); }, 30);
    }
    if (this.snapshot.screen !== 'chat' || !this.snapshot.messages.length ||
      this.positionedConversation === this.snapshot.conversationId) return;
    this.positionedConversation = this.snapshot.conversationId || '';
    setTimeout(() => { if (this.snapshot.screen === 'chat') this.scroller.scrollEdge(Edge.Bottom); }, 30);
  }

  private act(action: string, value: string = ''): void {
    if (this.onAction) this.onAction(action, value);
  }

  private blockTargetName(): string {
    return this.blockTarget ? this.blockTarget.name : '联系人';
  }

  private messageTime(value: string): string {
    const date: Date = new Date(value);
    if (!Number.isFinite(date.getTime())) return '';
    const today: Date = new Date();
    const time: string = date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
    return date.toDateString() === today.toDateString() ? time :
      ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'][date.getDay()] + time;
  }

  @Builder
  private conversationTitle() {
    Row({ space: 10 }) {
      if (this.snapshot.screen === 'chat') {
        ForEach(this.snapshot.users.filter((user: InboxFlowUser) => !user.self).slice(0, 1),
          (user: InboxFlowUser) => { this.avatar(user, 32) }, (user: InboxFlowUser) => user.id)
      }
      Text(this.snapshot.screen === 'compose' ? '新消息' : this.snapshot.title || '聊天')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
    }.width('100%').padding({ left: 64, right: 72 }).alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private avatar(user: InboxFlowUser, size: number = 40) {
    if (user.avatar) {
      Image(user.avatar).onClick(() => { if (user.profileUrl && this.onUser) this.onUser(user.profileUrl); }).width(size).height(size).borderRadius(size / 2).objectFit(ImageFit.Cover)
    } else {
      Text(user.name.slice(0, 1)).onClick(() => { if (user.profileUrl && this.onUser) this.onUser(user.profileUrl); }).width(size).height(size).borderRadius(size / 2).backgroundColor('#5867B5')
        .fontColor(Color.White).fontSize(22).textAlign(TextAlign.Center)
    }
  }

  @Builder
  private userRow(user: InboxFlowUser) {
    Row({ space: 12 }) {
      this.avatar(user)
      Text(user.name).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text')).layoutWeight(1).textAlign(TextAlign.Start)
      if (this.snapshot.screen === 'compose') {
        Text(this.snapshot.selectedIds.includes(user.id) ? '✓' : '○').fontSize(20)
          .fontColor($r('app.color.primary_text'))
      } else if (!user.self) {
        Button(this.snapshot.blocked && this.snapshot.blockedUserId === user.id ? '取消屏蔽' : '屏蔽')
          .height(36).borderRadius(12).fontSize(14).fontWeight(FontWeight.Normal)
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
          .enabled(!this.snapshot.messageBusy)
          .onClick(() => { this.blockTarget = user; this.showMessageMenu = true; })
      }
    }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .onClick(() => { if (this.snapshot.screen === 'compose') this.act('select', user.id); })
  }

  @Builder
  private pinActions(message: InboxFlowMessage) {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.lucide_share_2')).width(20).height(20).fillColor($r('app.color.primary_text'))
      }.width(40).height(40).backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.surface_muted') }).accessibilityText('分享 Pin 图')
        .onClick(() => { if (message.pinUrl && this.onPinAction) this.onPinAction('share', message.pinUrl); })
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.lucide_bookmark')).width(20).height(20)
      }.width(40).height(40).backgroundColor($r('app.color.page_background'))
        .border({ width: 1, color: $r('app.color.surface_muted') }).accessibilityText('收藏 Pin 图')
        .onClick(() => { if (message.pinUrl && this.onPinAction) this.onPinAction('save', message.pinUrl); })
    }
  }

  @Builder
  private reactionChoices() {
    Row({ space: 4 }) {
      ForEach(['❤️', '😂', '😍', '😮', '👍', '👎'], (reaction: string) => {
        Button({ type: ButtonType.Normal }) {
          Text(reaction).fontSize(24).textAlign(TextAlign.Center).width('100%')
        }.width(40).height(44).padding(0).backgroundColor(Color.Transparent)
          .enabled(!this.snapshot.messageBusy)
          .onClick(() => { this.act('react', this.reactionMessageId + '|' + reaction); this.reactionMessageId = ''; })
      })
    }.padding(8)
  }

  @Builder
  private messageMenuContent() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        ForEach(['❤️', '😂', '😍', '😮', '👍', '👎'], (reaction: string) => {
          Button({ type: ButtonType.Normal }) {
            Text(reaction).fontSize(24).textAlign(TextAlign.Center).width('100%')
          }.padding(0).layoutWeight(1).height(44)
            .backgroundColor($r('app.color.surface_muted'))
            .enabled(!this.snapshot.messageBusy)
            .onClick(() => {
              if (this.selectedMessage) this.act('react', this.selectedMessage.id + '|' + reaction);
              this.showMessageMenu = false;
            })
        })
      }.width('100%')
      Divider().margin({ top: 8, bottom: 8 })
      if (this.selectedMessage?.pinUrl) {
        Button('收藏').width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
          .onClick(() => { if (this.selectedMessage && this.onPinAction) this.onPinAction('save', this.selectedMessage.pinUrl); this.showMessageMenu = false; })
        Button('分享').width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
          .onClick(() => { if (this.selectedMessage && this.onPinAction) this.onPinAction('share', this.selectedMessage.pinUrl); this.showMessageMenu = false; })
      }
      if (this.selectedMessage?.own) {
        Button('删除').width('100%').backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
          .onClick(() => {
            const id: string = this.selectedMessage?.id || '';
            this.getUIContext().showAlertDialog({ title: '删除消息', message: '确认删除这条消息？',
              primaryButton: { value: '取消', action: (): void => {} },
              secondaryButton: { value: '删除', action: (): void => { this.act('deleteMessage', id); this.showMessageMenu = false; } } });
          })
      }
    }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
  }

  @Builder
  private blockSheetContent() {
    Column({ space: 16 }) {
      Text((this.snapshot.blocked ? '取消屏蔽' : '屏蔽') + this.blockTargetName() + '？')
        .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        .alignSelf(ItemAlign.Start)
      Text(this.snapshot.blocked ?
        '你可以查看、关注、发送消息或收藏对方的 Pin 图。取消屏蔽后，对方可以再次与你互动。' :
        '你将无法查看、关注、联系对方，也无法收藏对方的 Pin 图。屏蔽后，对方不会收到通知。')
        .fontSize(16).fontColor($r('app.color.primary_text')).lineHeight(26)
        .textAlign(TextAlign.Start)
      Row({ space: 12 }) {
        Button('算了').backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
          .onClick(() => { this.showMessageMenu = false; this.blockTarget = undefined; })
        Button(this.snapshot.blocked ? '取消屏蔽' : '屏蔽')
          .backgroundColor(this.snapshot.blocked ? Color.Black : $r('app.color.accent'))
          .fontColor(Color.White).enabled(!this.snapshot.messageBusy && !!this.blockTarget)
          .onClick(() => {
            if (this.blockTarget) this.act(this.snapshot.blocked ? 'unblockUser' : 'blockUser', this.blockTarget.id);
          })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding({ left: 28, right: 28, top: 16, bottom: 28 })
  }

  @Builder
  private activeSheetContent() {
    if (this.snapshot.screen === 'settings') this.blockSheetContent();
    else this.messageMenuContent();
  }

  @Builder
  private messageRow(message: InboxFlowMessage) {
    Column({ space: 12 }) {
      if (message.createdAt) {
        Text(this.messageTime(message.createdAt)).fontSize(12)
          .fontColor($r('app.color.secondary_text')).alignSelf(ItemAlign.Center)
      }
      Row({ space: 8 }) {
        if (message.own && !message.deleted && message.image && message.pinUrl) { this.pinActions(message) }
        if (!message.own && message.sender) {
          Column() { this.avatar(message.sender, 28) }.alignSelf(ItemAlign.End)
        }
        Column({ space: 8 }) {
          if (!message.own && message.sender?.name && !message.deleted) {
            Text(message.sender.name).fontSize(12).fontColor($r('app.color.secondary_text'))
          }
          if (message.image && !message.deleted) {
            Image(message.image).width(Math.min(220, 460 * (this.imageRatios.get(message.image) || 1)))
              .constraintSize({ maxHeight: 460 }).borderRadius(18)
              .objectFit(ImageFit.Contain)
              .onComplete((event) => {
                if (event && event.width > 0 && event.height > 0) {
                  const ratio: number = event.width / event.height;
                  if (this.imageRatios.get(message.image) !== ratio) {
                    const ratios: Map<string, number> = new Map<string, number>(this.imageRatios);
                    ratios.set(message.image, ratio); this.imageRatios = ratios;
                  }
                }
              })
              .onClick(() => { if (message.pinUrl && this.onPin) this.onPin(message.pinUrl); })
          }
          if (message.deleted) {
            Text(message.own ? '你删除了一条消息' : this.snapshot.title + ' 删除了一条消息')
              .fontColor($r('app.color.secondary_text')).fontSize(14).padding(12).borderRadius(24)
              .border({ width: 1, color: $r('app.color.surface_muted'), style: BorderStyle.Dashed })
          } else if (message.text === '❤️') {
            Image($r('app.media.lucide_heart_filled')).width(48).height(48).fillColor($r('app.color.accent'))
          } else if (message.text) {
            Text(message.text).fontSize(16).fontColor($r('app.color.primary_text'))
              .padding(12).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
          } else if (message.pinUrl && !message.image) {
            Text('Pin 图图片暂不可读取').fontColor($r('app.color.secondary_text'))
          }
          if (!message.deleted) {
            Button({ type: ButtonType.Normal }) {
              Row() {
                if (message.reactions?.length) {
                  Text(message.reactions.join(' ')).fontSize(18).fontColor($r('app.color.primary_text'))
                } else {
                  SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(20).fontColor([$r('app.color.primary_text')])
                  Text('+').fontSize(12).fontColor($r('app.color.primary_text'))
                }
              }
            }.constraintSize({ minWidth: 40 }).height(30).padding({ left: 6, right: 6 }).borderRadius(18)
              .backgroundColor($r('app.color.surface_muted'))
              .alignSelf(ItemAlign.End).margin({ top: -16, right: 4 }).zIndex(1)
              .accessibilityText('选择消息表情')
              .onClick(() => { this.reactionMessageId = this.reactionMessageId === message.id ? '' : message.id; })
              .bindPopup(this.reactionMessageId === message.id, {
                builder: this.reactionChoices, placement: Placement.Top, showInSubWindow: false,
                onStateChange: (event: ReactionPopupState) => { if (!event.isVisible && this.reactionMessageId === message.id) this.reactionMessageId = ''; }
              })
          }
        }.constraintSize({ maxWidth: 260 }).alignItems(HorizontalAlign.Start)
          .gesture(LongPressGesture().onAction(() => { if (!message.deleted) { this.selectedMessage = message; this.showMessageMenu = true; } }))
        if (!message.own && !message.deleted && message.image && message.pinUrl) { this.pinActions(message) }
      }.width('100%').justifyContent(message.own ? FlexAlign.End : FlexAlign.Start)
        .padding({ left: 20, right: 20 })
    }.width('100%').padding({ top: 12, bottom: 12 })
  }

  @Builder
  private updatesMenuContent() {
    Column({ space: 4 }) {
      if (this.snapshot.canUnsubscribePin) {
        Button({ type: ButtonType.Normal }) {
          Text('关闭此 Pin 图的更新').fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
        }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
          .backgroundColor(Color.Transparent).enabled(!this.snapshot.messageBusy && !this.snapshot.unsubscribedPin)
          .onClick(() => this.act('unsubscribePin'))
      }
      Button({ type: ButtonType.Normal }) {
        Text('删除更新').fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
      }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
        .backgroundColor(Color.Transparent).enabled(!this.snapshot.messageBusy)
        .onClick(() => this.act('hideNews'))
      Button({ type: ButtonType.Normal }) {
        Text('查看通知设置').fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).width('100%').textAlign(TextAlign.Start)
      }.width('100%').constraintSize({ minHeight: 48 }).padding({ left: 8, right: 8, top: 12, bottom: 12 })
        .backgroundColor(Color.Transparent).onClick(() => { if (this.onNotifications) this.onNotifications(); })
      if (this.snapshot.unsubscribedPin) {
        Text('你不会再收到有关此 Pin 图的通知。').fontSize(14).fontColor($r('app.color.secondary_text'))
      }
      if (this.snapshot.error) { Text(this.snapshot.error).fontSize(14).fontColor($r('app.color.secondary_text')) }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  build() {
    if (this.snapshot.screen === 'updatesMenu') {
      Column().width('100%').height('100%')
        .onAppear(() => { this.showUpdatesMenu = true; })
        .bindSheet($$this.showUpdatesMenu, this.updatesMenuContent(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: true,
          title: { title: '更新选项' },
          backgroundColor: $r('app.color.page_background'),
          maskColor: '#66000000',
          onWillDismiss: (action: DismissSheetAction) => {
            action.dismiss();
            this.showUpdatesMenu = false;
            this.act('back');
          }
        })
    } else {
    HdsNavigation(this.flowPathStack) {}.width('100%').height('100%').hideTitleBar(true)
      .navDestination(this.flowDestination)
    }
  }
  @Builder
  private flowDestination() {
    HdsNavDestination() {
    Column() {
      if (this.snapshot.screen === 'compose') {
        TextInput({ text: this.query, placeholder: '按姓名或电子邮箱搜索' }).margin({ left: 16, right: 16, bottom: 8 })
          .onChange((value: string) => {
            this.query = value;
            const token: number = ++this.queryToken;
            setTimeout(() => { if (token === this.queryToken && this.snapshot.screen === 'compose') this.act('search', value); }, 300);
          })
          .onSubmit(() => { this.queryToken++; this.act('search', this.query); })
      }
      if (this.snapshot.error) {
        Column({ space: 8 }) {
          Text(this.snapshot.error).fontColor($r('app.color.secondary_text'))
          Button('重试').onClick(() => this.act('retry'))
        }.padding(16)
      }
      if (this.snapshot.loading) { LoadingProgress().width(28).height(28) }

      Scroll(this.scroller) {
        Column() {
          if (this.snapshot.screen === 'compose' || this.snapshot.screen === 'settings') {
            ForEach(this.snapshot.users, (user: InboxFlowUser) => { this.userRow(user) }, (user: InboxFlowUser) => user.id)
          } else {
            if (this.snapshot.users.length > 0) {
              Column({ space: 16 }) {
                Row({ space: 4 }) {
                  ForEach(this.snapshot.users.slice(0, 2), (user: InboxFlowUser) => { this.avatar(user, 72) },
                    (user: InboxFlowUser) => user.id)
                }
                Text(this.snapshot.title).fontSize(18).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_text'))
                Text('美好的事情可能即将发生').fontSize(14).fontColor($r('app.color.secondary_text'))
              }.width('100%').padding({ top: 40, bottom: 40 }).alignItems(HorizontalAlign.Center)
            }
            ForEach(this.snapshot.messages, (message: InboxFlowMessage) => { this.messageRow(message) },
              (message: InboxFlowMessage) => message.id)
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ bottom: this.snapshot.screen === 'settings' ? 120 : 20 })
          .onAreaChange((_old: Area, area: Area) => {
            this.contentHeight = Number(area.height);
            if (this.historyPending && !this.snapshot.loading && this.contentHeight > this.historyHeight) {
              this.historyPending = false;
              this.scroller.scrollTo({ xOffset: 0, yOffset: this.historyOffset + this.contentHeight - this.historyHeight });
            }
          })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .onScrollStop(() => {
          if (this.snapshot.screen !== 'chat' || !this.snapshot.hasMore || this.snapshot.loading || this.historyPending || this.snapshot.error) return;
          if (this.scroller.currentOffset().yOffset > 80) return;
          this.historyHeight = this.contentHeight; this.historyOffset = this.scroller.currentOffset().yOffset;
          this.historyPending = true; this.act('more');
        })
        .onAppear(() => { if (this.snapshot.screen === 'chat') this.scroller.scrollEdge(Edge.Bottom); })
      if (this.snapshot.screen === 'chat') {
        Row({ space: 8 }) {
          TextInput({ text: this.draft, placeholder: '输入消息…' }).layoutWeight(1).maxLength(2000)
            .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.sendError)
            .onChange((value: string) => { this.draft = value; })
            .onSubmit(() => { if (this.draft.trim()) this.act('send', this.draft); })
          if (this.draft.trim()) {
            Button('发送').enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.sendError)
              .onClick(() => this.act('send', this.draft))
          } else {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(20)
              .fontColor([$r('app.color.accent')])
          }.width(44).height(44).backgroundColor($r('app.color.page_background'))
            .border({ width: 1, color: $r('app.color.surface_muted') })
            .accessibilityText('发送爱心')
            .enabled(!this.snapshot.loading && !this.snapshot.sending && !this.snapshot.sendError)
            .onClick(() => this.act('send', '❤️'))
          }
        }.padding({ left: 16, right: 16, top: 8, bottom: 24 })
        if (this.snapshot.sendError) {
          Text(this.snapshot.sendError).fontSize(13).fontColor($r('app.color.secondary_text')).padding(12)
          Button('重新读取会话').onClick(() => this.act('retry'))
        }
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.showMessageMenu, this.activeSheetContent(), {
        height: SheetSize.FIT_CONTENT, showClose: true,
        title: { title: this.snapshot.screen === 'settings' ? (this.snapshot.blocked ? '取消屏蔽联系人' : '屏蔽联系人') : '' }, dragBar: true,
        backgroundColor: $r('app.color.page_background'),
        onWillDismiss: (action: DismissSheetAction) => { action.dismiss(); this.showMessageMenu = false; this.selectedMessage = undefined; this.blockTarget = undefined; }
      })
    }.width('100%').height('100%')
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: { enableScrollEffect: false },
          originalStyle: { backgroundStyle: {
            backgroundColor: $r('app.color.page_background'), maskExtraHeight: 0
          } }
        },
        content: { title: { mainTitle: this.snapshot.screen === 'chat' ? '' :
          this.snapshot.screen === 'compose' ? '新消息' : this.snapshot.title || '消息设置' },
          stackBuilder: this.snapshot.screen === 'chat' ? () => { this.conversationTitle(); } : undefined,
          backIcon: { isEnabled: true, action: () => this.act('back') },
          menu: { value: this.snapshot.screen === 'chat' ? [{ content: { icon: $r('app.media.inbox_more'), label: '消息设置', action: () => this.act('settings') } }] :
            this.snapshot.screen === 'compose' ? [{ content: { label: '下一步', isEnabled: !this.snapshot.loading && this.snapshot.selectedIds.length > 0, action: () => this.act('next') } }] : [] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideTitleBar(false).hideBackButton(false)
      .bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onBackPressed(() => { this.act('back'); return true; })
  }
}




