import { PinWebComment, PinWebCommentResult } from '../models/PinWebComments';

@Component
export struct PinWebCommentsSheet {
  @Prop @Watch('resultChanged') result: PinWebCommentResult = { pin: '', loading: true, error: '', items: [] };
  @State private draft: string = '';
  @State private photoUri: string = '';
  @State private target: PinWebComment | undefined = undefined;
  @State private editing: boolean = false;
  @State private menuItem: PinWebComment | undefined = undefined;
  @State private menuOpen: boolean = false;
  @State private deleteOpen: boolean = false;
  @State private choosing: boolean = false;
  private mutationVersion: number = 0;
  private draftPin: string = '';
  onUser?: (url: string) => void;
  onWrite?: (value: string) => void;
  onPickImage?: () => Promise<string>;
  onClose?: () => void;
  onRetry?: () => void;
  onMore?: () => void;
  onReplies?: (id: string) => void;
  onLike?: (id: string) => void;

  private resultChanged(): void {
    if (this.draftPin !== this.result.pin || (this.result.mutationVersion || 0) > this.mutationVersion) {
      this.draft = ''; this.photoUri = ''; this.target = undefined; this.editing = false;
      this.menuOpen = false; this.deleteOpen = false;
    }
    this.draftPin = this.result.pin; this.mutationVersion = this.result.mutationVersion || 0;
  }
  private send(): void {
    if (!this.onWrite || this.result.busy || this.result.loading || this.result.uncertain || this.choosing ||
        (!this.draft.trim() && !this.photoUri)) return;
    this.onWrite(JSON.stringify({ action: this.photoUri ? 'photo' : this.editing ? 'edit' : this.target ? 'reply' : 'create',
      id: this.target?.id || '', text: this.draft, imageUri: this.photoUri }));
  }
  private async pickImage(): Promise<void> {
    if (!this.onPickImage || this.choosing || this.result.busy || this.result.uncertain) return;
    const pin: string = this.result.pin;
    this.choosing = true;
    try {
      const uri: string = await this.onPickImage();
      if (uri && pin === this.result.pin) { this.photoUri = uri; this.target = undefined; this.editing = false; }
    } finally { this.choosing = false; }
  }

  private ageLabel(value: string): string {
    const time: number = Date.parse(value);
    if (!Number.isFinite(time)) return '';
    const minutes: number = Math.max(0, Math.floor((Date.now() - time) / 60000));
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return minutes.toString() + '分钟';
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) return hours.toString() + '小时';
    const days: number = Math.floor(hours / 24);
    if (days < 30) return days.toString() + '天';
    if (days < 365) return Math.floor(days / 30).toString() + '个月';
    return Math.floor(days / 365).toString() + '年';
  }

  private commentKey(item: PinWebComment): string {
    // ForEach retains old item closures for an unchanged key. Include the snapshot so
    // expanded replies and reaction updates replace that row, without resetting the List.
    return item.id + ':' + JSON.stringify(item);
  }

  @Builder
  private commentRow(item: PinWebComment, reply: boolean = false) {
    Row({ space: 10 }) {
      if (item.avatar) {
        Image(item.avatar).onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); }).width(reply ? 28 : 32).height(reply ? 28 : 32)
          .borderRadius(16).objectFit(ImageFit.Cover)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Text(item.name.trim().slice(0, 1).toUpperCase()).fontSize(reply ? 12 : 13)
            .fontColor($r('app.color.primary_text'))
        }.width(reply ? 28 : 32).height(reply ? 28 : 32).borderRadius(16)
          .backgroundColor($r('app.color.surface_muted'))
      }
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text(item.name).fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).maxLines(2)
            .constraintSize({ maxWidth: '75%' })
          Text(this.ageLabel(item.createdAt)).fontSize(12).fontColor($r('app.color.secondary_text'))
        }.alignItems(VerticalAlign.Center)
        if (item.text) {
          Text(item.text).fontSize(15).fontColor($r('app.color.primary_text'))
        }
        if (item.imageUrl) {
          Image(item.imageUrl).width(82).height(110).objectFit(ImageFit.Contain).borderRadius(10)
        }
        Row({ space: 8 }) {
        if (item.canReply) {
          Text('回复').fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
            .onClick(() => {
              if (!this.result.busy && !this.result.uncertain) { this.target = item; this.editing = false; this.photoUri = ''; }
            })
        }
        if (item.canLike) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 5 }) {
              Image(item.liked ? $r('app.media.lucide_heart_filled') : $r('app.media.lucide_heart'))
                .width(15).height(15).objectFit(ImageFit.Contain)
              if ((item.likeCount || 0) > 0) {
                Text(item.likeCount!.toString()).fontSize(12).fontColor($r('app.color.primary_text'))
              }
            }
          }.height(32).padding({ left: 0, right: 8 }).backgroundColor(Color.Transparent)
            .enabled(!item.busy && !this.result.loading && !this.result.busy && !this.result.uncertain)
            .onClick(() => { if (this.onLike) this.onLike(item.id); })
            .accessibilityText((item.liked ? '取消点赞' : '点赞') + '，' + (item.likeCount || 0).toString())
        }
        if (item.canEdit || item.canDelete) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(18).height(18).fillColor($r('app.color.primary_text'))
          }.width(28).height(28).backgroundColor(Color.Transparent).enabled(!this.result.busy && !this.result.uncertain)
            .onClick(() => { this.menuItem = item; this.deleteOpen = false; this.menuOpen = true; })
            .accessibilityText('评论选项')
        }
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.alignItems(VerticalAlign.Top).width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(24).fontColor([$r('app.color.primary_text')])
        }.width(36).height(36).backgroundColor(Color.Transparent).onClick(() => { if (this.onClose) this.onClose(); })
          .accessibilityText('关闭评论')
        Text('你觉得怎么样？').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).layoutWeight(1)
      }.width('100%').padding({ bottom: 12 })
      Divider().color($r('app.color.secondary_text')).opacity(0.2)
      if (this.result.actionError) {
        Text(this.result.actionError).fontColor($r('app.color.secondary_text'))
      }
      if (this.result.items.length === 0 && this.result.loading) {
        LoadingProgress().width(32).height(32)
        Text('正在加载评论…').fontColor($r('app.color.secondary_text'))
        Blank().layoutWeight(1)
      } else {
        List({ space: 18 }) {
          ForEach(this.result.items, (item: PinWebComment) => {
            ListItem() {
              Column({ space: 6 }) {
                this.commentRow(item)
                if ((item.replyCount || 0) > 0) {
                  Button({ type: ButtonType.Normal }) {
                    Row({ space: 8 }) {
                      Divider().width(28).color($r('app.color.secondary_text'))
                      Text(item.repliesOpen ? '收起回复' : '查看 ' + item.replyCount + ' 条回复')
                        .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
                    }
                  }.height(32).padding(0).backgroundColor(Color.Transparent).margin({ left: 42 })
                    .enabled(!item.repliesLoading)
                    .onClick(() => { if (this.onReplies) this.onReplies(item.id); })
                }
                if (item.repliesOpen) {
                  Column({ space: 14 }) {
                    if (item.repliesLoading) {
                      LoadingProgress().width(24).height(24)
                    }
                    ForEach(item.replies || [], (reply: PinWebComment) => {
                      this.commentRow(reply, true)
                    }, (reply: PinWebComment) => this.commentKey(reply))
                    if (item.repliesError) {
                      Text(item.repliesError).fontSize(12).fontColor($r('app.color.secondary_text'))
                      Button('重新读取回复').onClick(() => { if (this.onReplies) this.onReplies(item.id); })
                    } else if (!item.repliesLoading && !(item.replies || []).length) {
                      Text('暂无回复').fontSize(12).fontColor($r('app.color.secondary_text'))
                    }
                  }.width('100%').padding({ left: 42 }).alignItems(HorizontalAlign.Start)
                }
              }.alignItems(HorizontalAlign.Start).width('100%')
            }
          }, (item: PinWebComment) => this.commentKey(item))
          ListItem() {
            Column({ space: 12 }) {
              if (this.result.error) {
                Text(this.result.error).fontColor($r('app.color.secondary_text'))
                Button('重试').onClick(() => {
                  if (this.result.items.length && this.onMore) this.onMore();
                  else if (this.onRetry) this.onRetry();
                })
              } else if (this.result.loading) {
                LoadingProgress().width(28).height(28)
              } else if (this.result.items.length === 0) {
                Text('写评论，分享反馈，或者击个掌开始对话').fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
                  .margin({ top: 140 })
              } else if (!this.result.ended) {
                Button('加载更多评论').onClick(() => { if (this.onMore) this.onMore(); })
              }
            }.width('100%')
          }
        }.width('100%').layoutWeight(1)
          .onReachEnd(() => { if (!this.result.loading && !this.result.error && !this.result.ended && this.onMore) this.onMore(); })
      }
      this.composer()
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 12, bottom: 20 })
      .backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.menuOpen, this.commentMenu(), { height: SheetSize.FIT_CONTENT, showClose: !this.deleteOpen,
        dragBar: !this.deleteOpen, backgroundColor: $r('app.color.page_background'), maskColor: '#66000000' })
  }

  @Builder
  private composer() {
    Column({ space: 10 }) {
      if (this.target) {
        Column({ space: 6 }) {
          Row() {
            Text(this.editing ? '编辑你的评论' : '回复 ' + this.target.name).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.image_close')).width(16).height(16)
            }.width(28).height(28).backgroundColor(Color.Transparent)
              .enabled(!this.result.busy)
              .onClick(() => { this.target = undefined; this.editing = false; this.draft = ''; })
              .accessibilityText('取消回复')
          }
          if (!this.editing) { Text(this.target.text).fontSize(12).fontColor($r('app.color.secondary_text')).width('100%') }
        }.width('100%').padding(10).backgroundColor($r('app.color.surface_muted'))
      }
      Column({ space: 8 }) {
        if (this.photoUri) {
          Row() {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(this.photoUri).width(82).height(110).objectFit(ImageFit.Contain).borderRadius(10)
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.image_close')).width(15).height(15)
              }.width(26).height(26).margin({ top: -2, right: -2 })
                .backgroundColor('#CC303136').enabled(!this.result.busy)
                .onClick(() => { this.photoUri = ''; }).accessibilityText('移除已选图片')
            }.width(82).height(110)
            Blank()
          }.width('100%')
        }
        Row({ space: 8 }) {
          TextInput({ text: this.draft, placeholder: this.editing ? '编辑你的评论' : this.target ? '回复 ' + this.target.name : '添加评论' })
            .maxLength(5000).layoutWeight(1).backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
            .padding({ left: 4, right: 4 }).enabled(!this.result.busy && !this.result.uncertain)
            .onChange((value: string) => { this.draft = value; })
          if (!this.target && !this.editing) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.picture')).fontSize(24).fontColor([$r('app.color.primary_text')])
            }.width(32).height(32).backgroundColor(Color.Transparent).enabled(!this.result.busy && !this.result.uncertain && !this.choosing)
              .onClick(() => this.pickImage()).accessibilityText('添加图片')
          }
          Button({ type: ButtonType.Normal }) {
            if (this.result.busy) { LoadingProgress().width(20).height(20) }
            else { SymbolGlyph(this.editing ? $r('sys.symbol.checkmark') : $r('sys.symbol.arrow_up'))
              .fontSize(20).fontColor([$r('app.color.detail_on_accent')]) }
          }.width(32).height(32).borderRadius(10).backgroundColor($r('app.color.accent'))
            .enabled(!this.result.loading && !this.result.busy && !this.result.uncertain && !this.choosing && (!!this.draft.trim() || !!this.photoUri))
            .onClick(() => this.send()).accessibilityText(this.editing ? '保存评论' : '发送评论')
        }.width('100%')
      }.width('100%').padding(10).borderRadius(24).border({ width: 1, color: $r('app.color.secondary_text') })
    }.width('100%')
  }

  @Builder
  private commentMenu() {
    Column({ space: 16 }) {
      if (this.deleteOpen) {
        Text('你确定吗？').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text('此评论将被删除').fontSize(16).fontColor($r('app.color.primary_text'))
        Row({ space: 12 }) {
          Button('取消').layoutWeight(1).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .onClick(() => { this.deleteOpen = false; })
          Button('删除').layoutWeight(1).backgroundColor($r('app.color.accent')).fontColor($r('app.color.detail_on_accent'))
            .onClick(() => {
              if (this.menuItem && this.onWrite && !this.result.busy && !this.result.uncertain)
                this.onWrite(JSON.stringify({ action: 'delete', id: this.menuItem.id, text: '' }));
              this.menuOpen = false;
            })
        }.width('100%')
      } else {
        if (this.menuItem?.canEdit) {
          Text('编辑').width('100%').fontSize(17).fontColor($r('app.color.primary_text')).padding({ top: 10, bottom: 10 })
            .onClick(() => {
              this.target = this.menuItem; this.editing = true; this.draft = this.menuItem?.text || ''; this.photoUri = ''; this.menuOpen = false;
            })
        }
        if (this.menuItem?.canDelete) {
          Text('删除').width('100%').fontSize(17).fontColor($r('app.color.primary_text')).padding({ top: 10, bottom: 10 })
            .onClick(() => { this.deleteOpen = true; })
        }
      }
    }.width('100%').padding({ left: 16, right: 16, top: 24, bottom: 24 })
  }
}
