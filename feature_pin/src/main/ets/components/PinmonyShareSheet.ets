import { PinmonyI18n } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { ShareSheetOption } from '../models/PinmonySheets';
import { PinmonyUserAvatar } from 'common_ui';
@Component
export struct PinmonyShareSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @ObjectLink pinStore: PinmonyPinStore;
  onAction: (id: string) => void = (): void => {};
  onSearch: (value: string) => void = (): void => {};
  onRetry: () => void = (): void => {};
  onReady: () => void = (): void => {};
  hasCopyLink: () => boolean = (): boolean => false;
  isCopyLink: (label: string) => boolean = (): boolean => false;
  private shareActionKey(option: ShareSheetOption): string {
    return JSON.stringify([this.pinStore.shareSession, option.id, option.enabled,
      option.label, option.subtitle || '', this.uiLanguage]);
  }
  @Builder
  private buildShareActionRow(option: ShareSheetOption) {
    Column() {
      Text(option.label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .maxLines(3)
      if (option.subtitle) {
        Text(option.subtitle)
          .fontSize(12)
          .fontColor($r('app.color.secondary_text'))
          .maxLines(4)
          .margin({ top: 3 })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 20, top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .opacity(option.enabled ? 1 : 0.4)
    .enabled(option.enabled)
    .accessibilityText(option.label)
    .onClick(() => {
      if (option.enabled) this.onAction(option.id);
    })
  }


  @Builder
  private buildShareContactRow(contact: ShareSheetOption) {
    Row({ space: 12 }) {
      PinmonyUserAvatar({ image: contact.icon || '', name: contact.label, avatarSize: 42 })
      Text(contact.label)
        .fontSize(16)
        .fontColor($r('app.color.primary_text'))
        .layoutWeight(1)
        .maxLines(2)
    }
    .width('100%')
    .height(60)
    .padding({ left: 20, right: 20 })
    .opacity(contact.enabled ? 1 : 0.4)
    .accessibilityText(contact.label)
    .onClick(() => {
      if (contact.enabled) this.onAction(contact.id);
    })
  }


  build() {
    Column() {
      if (this.pinStore.shareLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text(this.uiText("正在读取分享选项…"))
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .height(72)
        .padding({ left: 20, right: 20 })
      }
      if (!this.pinStore.shareLoading && (PinmonyI18n.render(this.pinStore.shareSectionLabel, this.uiLanguage) || this.pinStore.shareSearchId || this.pinStore.shareSearchActive ||
          this.pinStore.shareSendId || this.pinStore.shareContacts.length > 0)) {
        Divider()
          .color('#4D8A8A8A')
          .margin({ left: 20, right: 20, top: 8, bottom: 18 })
        if (PinmonyI18n.render(this.pinStore.shareSectionLabel, this.uiLanguage)) {
          Text(PinmonyI18n.render(this.pinStore.shareSectionLabel, this.uiLanguage))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_text'))
            .margin({ left: 20, right: 20, bottom: 14 })
        }
        if (this.pinStore.shareSearchActive) {
          TextInput({ text: this.pinStore.shareQuery, placeholder: PinmonyI18n.render(this.pinStore.shareSearchLabel, this.uiLanguage) })
            .width('90%')
            .height(48)
            .margin({ bottom: 12 })
            .flexShrink(0)
            .onChange((value: string) => {
              this.onSearch(value);
            })
          if (PinmonyI18n.isText(this.pinStore.shareFeedback, "正在加载联系人…")) {
            Column({ space: 12 }) {
              LoadingProgress().width(32).height(32).color($r('app.color.accent'))
                .accessibilityText(this.uiText("正在加载联系人"))
              Text(PinmonyI18n.render(this.pinStore.shareFeedback, this.uiLanguage)).fontSize(14).fontColor($r('app.color.secondary_text'))
            }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          } else {
          Scroll() {
            Column() {
              ForEach(this.pinStore.shareContacts, (contact: ShareSheetOption) => {
                this.buildShareContactRow(contact)
              }, (contact: ShareSheetOption) => contact.id)
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
          }
          .align(Alignment.TopStart)
          .layoutWeight(1)
          .width('100%')
          }
        } else {
          if (this.pinStore.shareSearchId) {
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(24)
                .fontColor([$r('app.color.primary_text')])
                .width(48)
                .height(48)
                .borderRadius(14)
                .backgroundColor('#338A8A8A')
              Text(PinmonyI18n.render(this.pinStore.shareSearchLabel, this.uiLanguage))
                .fontSize(16)
                .fontColor($r('app.color.primary_text'))
            }
            .width('100%')
            .height(64)
            .padding({ left: 20, right: 20 })
            .accessibilityText(PinmonyI18n.render(this.pinStore.shareSearchLabel, this.uiLanguage))
            .onClick(() => this.onAction(this.pinStore.shareSearchId))
          }
          ForEach(this.pinStore.shareContacts, (contact: ShareSheetOption) => {
            this.buildShareContactRow(contact)
          }, (contact: ShareSheetOption) => contact.id)
        }
        if (this.pinStore.shareSendId && this.pinStore.shareSendLabel) {
          Button(this.pinStore.shareSendLabel)
            .width('90%')
            .margin({ top: 12, bottom: 12 })
            .onClick(() => this.onAction(this.pinStore.shareSendId))
        }
      }

      if (!this.pinStore.shareOnPinDetail && !this.pinStore.shareLoading && this.pinStore.shareActions.some((option: ShareSheetOption) =>
          !this.pinStore.shareOnPinDetail || !this.hasCopyLink() || !this.isCopyLink(option.label))) {
        Divider()
          .color('#4D8A8A8A')
          .margin({ left: 20, right: 20, top: 12, bottom: 10 })
        ForEach(this.pinStore.shareActions.filter((option: ShareSheetOption) =>
          !this.pinStore.shareOnPinDetail || !this.hasCopyLink() ||
          !this.isCopyLink(option.label)), (option: ShareSheetOption) => {
          this.buildShareActionRow(option)
        }, (option: ShareSheetOption) => this.shareActionKey(option))
      }

      if (this.pinStore.shareError && !PinmonyI18n.isText(this.pinStore.shareError, "分享链接尚未就绪，请重试")) {
        Row({ space: 12 }) {
          Text(PinmonyI18n.render(this.pinStore.shareError, this.uiLanguage))
            .fontSize(14)
            .fontColor('#D94A4A')
            .layoutWeight(1)
          Button(this.uiText("重试"))
            .onClick(() => this.onRetry())
        }
        .margin({ left: 20, right: 20, top: 12 })
      }
      if (this.pinStore.shareOnPinDetail && !(this.pinStore.shareSearchActive && PinmonyI18n.isText(this.pinStore.shareFeedback, "正在加载联系人…")) &&
          ['正在加载联系人…', '正在处理…', '没有可用的联系人'].some((source: string): boolean => PinmonyI18n.isText(this.pinStore.shareFeedback, source))) {
        Text(PinmonyI18n.render(this.pinStore.shareFeedback, this.uiLanguage))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .margin({ left: 20, right: 20, top: 12 })
      }
    }
    .width('100%')
    .height(this.pinStore.shareSearchActive ? '100%' : undefined)
    .justifyContent(FlexAlign.Start)
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
    .onAppear(() => {
      this.onReady();
    })
  }


}
