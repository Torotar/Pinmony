import { LengthMetrics } from '@kit.ArkUI';
import { PinmonyActionNotice } from 'common_ui';
import { PinmonyUserAvatar } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyComment, PinmonyCommentResult } from '../models/PinmonyComments';
import { ImageFlightRect, imageContainRect } from '../services/PinmonyImageTransition';
import { PinmonyImageViewerRequest } from '../services/PinmonyImageViewerSession';

interface CommentPhotoSize { key: string; url: string; width: number; height: number; }

@Component
export struct PinmonyCommentsSheet {
  @StorageProp('pinmonySheetWindowWidthVp') private sheetWindowWidthVp: number = 0;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  private hasCurrentTranslation(item: PinmonyComment): boolean {
    return !!item.translatedText && item.translationLanguage === PinmonyI18n.translationAcceptLanguage(this.uiLanguage);
  }
  @Prop @Watch('resultChanged') result: PinmonyCommentResult = { pin: '', loading: true, error: '', items: [] };
  @State private draft: string = '';
  @State private photoUri: string = '';
  @State private target: PinmonyComment | undefined = undefined;
  @State private editing: boolean = false;
  @State private menuItem: PinmonyComment | undefined = undefined;
  @State private menuOpen: boolean = false;
  private pendingDeleteId: string = '';
  private pendingDeletePin: string = '';
  private pendingDeleteVersion: number = 0;
  @State private deleteOpen: boolean = false;
  @State private choosing: boolean = false;
  @State private photoSizes: CommentPhotoSize[] = [];
  @State private hiddenPhotoId: string = '';
  private photoId: string = '';
  private photoUrl: string = '';
  onViewerOpen?: (request: PinmonyImageViewerRequest) => boolean;
  onViewerCancel?: (owner: string) => void;
  private photoPin: string = '';
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
  onTranslate?: (id: string) => void;

  private photoSourceId(item: PinmonyComment): string {
    return 'pinmony-comment-photo-' + this.result.pin + ':' + item.id;
  }
  private commentPhotoFrame(item: PinmonyComment): ImageFlightRect {
    const size: CommentPhotoSize | undefined = this.photoSizes.find((value: CommentPhotoSize): boolean =>
      value.key === this.photoSourceId(item) && value.url === item.imageUrl);
    return imageContainRect(82, 110, size?.width || 0, size?.height || 0);
  }
  private recordPhotoSize(item: PinmonyComment, width: number, height: number): void {
    if (!item.imageUrl || width <= 0 || height <= 0 || !Number.isFinite(width) || !Number.isFinite(height)) return;
    if (!this.result.items.some((value: PinmonyComment): boolean => value === item || !!value.replies?.includes(item))) return;
    const key: string = this.photoSourceId(item);
    const known: CommentPhotoSize | undefined = this.photoSizes.find((value: CommentPhotoSize): boolean => value.key === key);
    if (known?.url === item.imageUrl && known.width === width && known.height === height) return;
    this.photoSizes = this.photoSizes.filter((value: CommentPhotoSize): boolean => value.key !== key).slice(-1999)
      .concat([{ key: key, url: item.imageUrl, width: width, height: height }]);
  }
  private currentPhoto(): PinmonyComment | undefined {
    for (const item of this.result.items) {
      if (item.id === this.photoId) return item;
      const reply: PinmonyComment | undefined = item.replies?.find((value: PinmonyComment): boolean => value.id === this.photoId);
      if (reply) return reply;
    }
    return undefined;
  }
  private releasePhoto(): void {
    this.hiddenPhotoId = ''; this.photoId = ''; this.photoPin = ''; this.photoUrl = '';
  }
  private clearPhoto(): void { this.onViewerCancel?.('comments'); this.releasePhoto(); }
  aboutToDisappear(): void { this.clearPhoto(); this.photoSizes = []; }
  private openPhoto(item: PinmonyComment): void {
    if (!item.imageUrl || this.photoId || !this.onViewerOpen) return;
    this.photoId = item.id; this.photoPin = this.result.pin; this.photoUrl = item.imageUrl;
    const accepted: boolean = this.onViewerOpen({ owner: 'comments',
      detail: { kind: 'comment-photo', session: 0, pinUrl: this.result.pin, imageUrl: item.imageUrl,
        imageWidth: 0, imageHeight: 0, title: '', description: '', creator: '', creatorAvatar: '',
        sourceLabel: '', actions: [], related: [] },
      imageUrl: item.imageUrl, previewUrl: item.imageUrl, sourceRadius: 10,
      sourceId: () => this.photoSourceId(item),
      isCurrent: () => this.photoPin === this.result.pin && this.photoId === item.id &&
        this.currentPhoto()?.imageUrl === item.imageUrl,
      onReady: () => { if (this.photoId === item.id) this.hiddenPhotoId = item.id; },
      onClosed: () => this.releasePhoto() });
    if (!accepted) this.releasePhoto();
  }
  private resultChanged(): void {
    if (this.draftPin !== this.result.pin) this.photoSizes = [];
    if (this.photoId) {
      const selected: PinmonyComment | undefined = this.currentPhoto();
      if (this.photoPin !== this.result.pin || !selected || selected.imageUrl !== this.photoUrl) this.clearPhoto();
    }
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
    if (minutes < 1) return this.uiText("pm_just_now_de6785d9");
    if (minutes < 60) return minutes.toString() + this.uiText("pm_m_bd957bc4");
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) return hours.toString() + this.uiText("pm_h_3b6fefc5");
    const days: number = Math.floor(hours / 24);
    if (days < 30) return days.toString() + this.uiText("pm_d_49da61ce");
    if (days < 365) return Math.floor(days / 30).toString() + this.uiText("pm_mo_e5afd16c");
    return Math.floor(days / 365).toString() + this.uiText("pm_y_62ef900a");
  }

  private commentKey(item: PinmonyComment): string {
    // ForEach retains old item closures for an unchanged key. Include the snapshot so
    // expanded replies and reaction updates replace that row, without resetting the List.
    return item.id + ':' + JSON.stringify(item) + ':' + this.uiLanguage;
  }

  @Builder
  private commentRow(item: PinmonyComment, reply: boolean = false) {
    Row({ space: 10 }) {
      PinmonyUserAvatar({ profileUrl: item.profileUrl || '', image: item.avatar, name: item.name, colorIndex: item.avatarColorIndex || 0, avatarSize: reply ? 28 : 32 })
        .onClick(() => { if (item.profileUrl && this.onUser) this.onUser(item.profileUrl); })
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text(PinmonyI18n.render(item.name, this.uiLanguage)).fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text')).maxLines(2)
            .constraintSize({ maxWidth: '75%' })
          Text(this.ageLabel(item.createdAt)).fontSize(12).fontColor($r('app.color.secondary_text'))
        }.alignItems(VerticalAlign.Center)
        if (item.text) {
          Text(item.translationVisible && this.hasCurrentTranslation(item) ? (item.translatedText || item.text) : item.text)
            .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(15).fontColor($r('app.color.primary_text'))
        }
        if (item.translationError) {
          PinmonyActionNotice({ message: PinmonyI18n.render(item.translationError, this.uiLanguage) })
        }
        if (item.imageUrl) {
          Stack() {
          Image(item.imageUrl).width(this.commentPhotoFrame(item).width).height(this.commentPhotoFrame(item).height)
            .objectFit(ImageFit.Contain).borderRadius(10).clip(true)
            .id(this.photoSourceId(item))
            .opacity(this.hiddenPhotoId === item.id ? 0 : 1)
            .onClick(() => this.openPhoto(item))
            .onComplete((event) => this.recordPhotoSize(item, event?.width || 0, event?.height || 0))
            .accessibilityText(this.uiText('pm_preview_13d61fea'))
          }.width(82).height(110)
        }
        Row({ space: 8 }) {
        if (item.canTranslate && this.onTranslate) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 5 }) {
              if (item.translationLoading) { LoadingProgress().width(14).height(14).color($r('app.color.accent')) }
              Text(item.translationLoading ? this.uiText("pm_translating_07f81963") : item.translationVisible && this.hasCurrentTranslation(item) ? this.uiText("pm_show_original_098e6618") :
                this.hasCurrentTranslation(item) ? this.uiText("pm_show_translation_7cd62999") : item.translationError ? this.uiText("pm_translate_again_496b5f08") : this.uiText("pm_translate_a52a0833"))
                .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
            }
          }.height(32).padding({ left: 0, right: 4 }).backgroundColor(Color.Transparent)
            .enabled(!item.translationLoading && !this.result.loading && !this.result.busy && !this.result.uncertain)
            .onClick(() => { if (this.onTranslate) this.onTranslate(item.id); })
            .accessibilityText(item.translationVisible && this.hasCurrentTranslation(item) ? this.uiText("pm_show_original_comment_373f6052") : this.uiText("pm_translate_comment_8a5fdd65"))
        }
        if (item.canReply) {
          Text(this.uiText("pm_reply_cf945e21")).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
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
            .accessibilityText((item.liked ? this.uiText("pm_unlike_3ab399c7") : this.uiText("pm_like_aced5d7f")) + '，' + (item.likeCount || 0).toString())
        }
        if (item.canEdit || item.canDelete) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.lucide_ellipsis')).width(18).height(18).fillColor($r('app.color.primary_text'))
          }.width(28).height(28).backgroundColor(Color.Transparent).enabled(!this.result.busy && !this.result.uncertain)
            .onClick(() => { this.menuItem = item; this.deleteOpen = false; this.menuOpen = true; })
            .accessibilityText(this.uiText("pm_comment_options_8216ef81"))
        }
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.alignItems(VerticalAlign.Top).width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Divider().color($r('app.color.secondary_text')).opacity(0.2)
      if (this.result.actionError) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.result.actionError, this.uiLanguage) })
      }
      if (this.result.items.length === 0 && this.result.loading) {
        LoadingProgress().color($r('app.color.accent')).width(32).height(32)
        Text(this.uiText("pm_loading_comments_dded3fba")).fontColor($r('app.color.secondary_text'))
        Blank().layoutWeight(1)
      } else {
        List({ space: 18 }) {
          ForEach(this.result.items, (item: PinmonyComment) => {
            ListItem() {
              Column({ space: 6 }) {
                this.commentRow(item)
                if ((item.replyCount || 0) > 0) {
                  Button({ type: ButtonType.Normal }) {
                    Row({ space: 8 }) {
                      Divider().width(28).color($r('app.color.secondary_text'))
                      Text(item.repliesOpen ? this.uiText("pm_hide_replies_c6edf966") : PinmonyI18n.format("pm_view_comment_replies", [item.replyCount], this.uiLanguage))
                        .fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary_text'))
                    }
                  }.height(32).padding(0).backgroundColor(Color.Transparent).margin({ left: 42 })
                    .enabled(!item.repliesLoading)
                    .onClick(() => { if (this.onReplies) this.onReplies(item.id); })
                }
                if (item.repliesOpen) {
                  Column({ space: 14 }) {
                    if (item.repliesLoading) {
                      LoadingProgress().color($r('app.color.accent')).width(24).height(24)
                    }
                    ForEach(item.replies || [], (reply: PinmonyComment) => {
                      this.commentRow(reply, true)
                    }, (reply: PinmonyComment) => this.commentKey(reply))
                    if (item.repliesError) {
                      PinmonyActionNotice({ message: PinmonyI18n.render(item.repliesError, this.uiLanguage), actionText: this.uiText("pm_reload_replies_e32b3f23"), onAction: () => { if (this.onReplies) this.onReplies(item.id); } })
                    } else if (!item.repliesLoading && !(item.replies || []).length) {
                      Text(this.uiText("pm_no_replies_yet_1ff6ef41")).fontSize(12).fontColor($r('app.color.secondary_text'))
                    }
                  }.width('100%').padding({ left: 42 }).alignItems(HorizontalAlign.Start)
                }
              }.alignItems(HorizontalAlign.Start).width('100%')
            }
          }, (item: PinmonyComment) => this.commentKey(item))
          ListItem() {
            Column({ space: 12 }) {
              if (this.result.error) {
                PinmonyActionNotice({ message: PinmonyI18n.render(this.result.error, this.uiLanguage), actionText: this.uiText("pm_retry_b8784c8d"), onAction: () => {
                  if (this.result.items.length && this.onMore) this.onMore();
                  else if (this.onRetry) this.onRetry();
                } })
              } else if (this.result.loading) {
                LoadingProgress().color($r('app.color.accent')).width(28).height(28)
              } else if (this.result.items.length === 0) {
                Text(this.uiText("pm_write_a_comment_share_feedback_or_send_a_high_five_2ef32875")).fontColor($r('app.color.secondary_text')).textAlign(TextAlign.Center)
                  .margin({ top: 140 })

              }
            }.width('100%')
          }
        }.width('100%').layoutWeight(1)
          .onReachEnd(() => { if (!this.result.loading && !this.result.error && !this.result.ended && this.onMore) this.onMore(); })
      }
      this.composer()
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 12, bottom: 20 })
      .backgroundColor($r('app.color.page_background'))
      .bindSheet($$this.menuOpen, this.commentMenu(), {
      radius: LengthMetrics.vp(32),
      preferType: this.sheetWindowWidthVp >= 600 ? SheetType.CENTER : undefined,
        onWillAppear: (): void => { PinmonyRuntimeLog.info('SheetTrace: event=will-appear source=PinmonyCommentsSheet.menuOpen radius=uniform-32vp'); },
        onDisappear: (): void => this.finishCommentMenuClose(),
        height: SheetSize.FIT_CONTENT, showClose: !this.deleteOpen,
        dragBar: !this.deleteOpen, backgroundColor: $r('app.color.page_background'), maskColor: '#66000000' })
  }

  @Builder
  private composer() {
    Column({ space: 10 }) {
      if (this.target) {
        Column({ space: 6 }) {
          Row() {
            Text(this.editing ? this.uiText("pm_edit_your_comment_398c2214") : this.uiText("pm_reply_to_3376176c") + this.target.name).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_text')).layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.image_close')).width(16).height(16)
            }.width(28).height(28).backgroundColor(Color.Transparent)
              .enabled(!this.result.busy)
              .onClick(() => { this.target = undefined; this.editing = false; this.draft = ''; })
              .accessibilityText(this.uiText("pm_cancel_reply_d346633d"))
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
                .onClick(() => { this.photoUri = ''; }).accessibilityText(this.uiText("pm_remove_selected_image_37e8126a"))
            }.width(82).height(110)
            Blank()
          }.width('100%')
        }
        Row({ space: 8 }) {
          TextInput({ text: this.draft, placeholder: this.editing ? this.uiText("pm_edit_your_comment_398c2214") : this.target ? this.uiText("pm_reply_to_3376176c") + this.target.name : this.uiText("pm_add_a_comment_c56d162d") })
            .maxLength(5000).layoutWeight(1).backgroundColor(Color.Transparent).fontColor($r('app.color.primary_text'))
            .padding({ left: 4, right: 4 }).enabled(!this.result.busy && !this.result.uncertain)
            .onChange((value: string) => { this.draft = value; })
          if (!this.target && !this.editing) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.picture')).fontSize(24).fontColor([$r('app.color.primary_text')])
            }.width(32).height(32).backgroundColor(Color.Transparent).enabled(!this.result.busy && !this.result.uncertain && !this.choosing)
              .onClick(() => this.pickImage()).accessibilityText(this.uiText("pm_add_image_9f0d4e46"))
          }
          Button({ type: ButtonType.Normal }) {
            if (this.result.busy) { LoadingProgress().color($r('app.color.accent')).width(20).height(20) }
            else { SymbolGlyph(this.editing ? $r('sys.symbol.checkmark') : $r('sys.symbol.arrow_up'))
              .fontSize(20).fontColor([$r('app.color.detail_on_accent')]) }
          }.width(44).height(44).borderRadius(16).backgroundColor($r('app.color.accent'))
            .enabled(!this.result.loading && !this.result.busy && !this.result.uncertain && !this.choosing && (!!this.draft.trim() || !!this.photoUri))
            .onClick(() => this.send()).accessibilityText(this.editing ? this.uiText("pm_save_comment_80c50b4a") : this.uiText("pm_send_comment_d25f5715"))
        }.width('100%')
      }.width('100%').padding(10).borderRadius(24).border({ width: 1, color: $r('app.color.secondary_text') })
    }.width('100%')
  }

  private requestCommentDelete(): void {
    if (!this.menuOpen || this.pendingDeleteId || !this.menuItem?.canDelete || !this.onWrite ||
        this.result.busy || this.result.uncertain) return;
    this.pendingDeleteId = this.menuItem.id;
    this.pendingDeletePin = this.result.pin;
    this.pendingDeleteVersion = this.result.mutationVersion || 0;
    this.menuOpen = false;
  }

  private finishCommentMenuClose(): void {
    const id: string = this.pendingDeleteId;
    this.pendingDeleteId = '';
    this.deleteOpen = false;
    this.menuItem = undefined;
    if (id && this.pendingDeletePin === this.result.pin &&
        this.pendingDeleteVersion === (this.result.mutationVersion || 0) && !this.result.busy &&
        !this.result.uncertain && this.onWrite) this.onWrite(JSON.stringify({ action: 'delete', id: id, text: '' }));
  }

  @Builder
  private commentMenu() {
    Column({ space: 16 }) {
      if (this.deleteOpen) {
        Text(this.uiText("pm_are_you_sure_8889016c")).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text'))
        Text(this.uiText("pm_this_comment_will_be_deleted_0b66ff46")).fontSize(16).fontColor($r('app.color.primary_text'))
        Row({ space: 12 }) {
          Button(this.uiText("pm_cancel_2cd0f3be")).layoutWeight(1).backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.primary_text'))
            .onClick(() => { this.deleteOpen = false; })
          Button(this.uiText("pm_delete_2f9daa82")).layoutWeight(1).backgroundColor($r('app.color.accent')).fontColor($r('app.color.detail_on_accent'))
            .onClick(() => {
              this.requestCommentDelete();
            })
        }.width('100%')
      } else {
        if (this.menuItem?.canEdit) {
          Text(this.uiText("pm_edit_05183656")).width('100%').fontSize(17).fontColor($r('app.color.primary_text')).padding({ top: 10, bottom: 10 })
            .onClick(() => {
              this.target = this.menuItem; this.editing = true; this.draft = this.menuItem?.text || ''; this.photoUri = ''; this.menuOpen = false;
            })
        }
        if (this.menuItem?.canDelete) {
          Text(this.uiText("pm_delete_2f9daa82")).width('100%').fontSize(17).fontColor($r('app.color.primary_text')).padding({ top: 10, bottom: 10 })
            .onClick(() => { this.deleteOpen = true; })
        }
      }
    }.width('100%').padding({ left: 16, right: 16, top: 24, bottom: 24 })
  }
}
