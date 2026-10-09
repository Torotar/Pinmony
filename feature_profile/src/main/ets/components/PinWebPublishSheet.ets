import { PinWebPublishOption } from '../models/PinWebProfile';

@Component
export struct PinWebPublishSheet {
  @Prop options: PinWebPublishOption[] = [];
  @Prop loading: boolean = false;
  onSelect?: (id: string) => void;
  onRetry?: () => void;

  private groupOptions(group: string): PinWebPublishOption[] {
    return this.options.filter((option: PinWebPublishOption): boolean => option.group === group);
  }

  private groupLabel(group: string): string {
    const item: PinWebPublishOption | undefined = this.options.find((option: PinWebPublishOption): boolean =>
      option.group === group);
    return item ? item.groupLabel : '';
  }

  @Builder
  private option(item: PinWebPublishOption) {
    Row({ space: 16 }) {
      Image(item.kind === 'board' ? $r('app.media.lucide_layout_grid') :
        item.kind === 'website' ? $r('app.media.profile_website') : $r('app.media.profile_photo'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(item.label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_text'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(58)
    .padding({ left: 16, right: 16 })
    .borderRadius(16)
    .backgroundColor($r('app.color.surface_muted'))
    .opacity(item.enabled ? 1 : 0.5)
    .onClick(() => { if (item.enabled && this.onSelect) this.onSelect(item.id); })
    .accessibilityText(item.label)
    .accessibilityDescription(item.enabled ? '打开 Pinterest 创建流程' : '当前网页未提供此选项')
  }

  @Builder
  private group(group: string) {
    if (this.groupOptions(group).length > 0) {
      Column({ space: 10 }) {
        Text(this.groupLabel(group))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
        ForEach(this.groupOptions(group), (item: PinWebPublishOption) => {
          this.option(item)
        }, (item: PinWebPublishOption) => item.id)
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: 24 }) {
      this.group('create')
      this.group('add')
      if (this.loading) {
        LoadingProgress().width(28).height(28)
        Text('正在读取 Pinterest 创建选项…')
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
      } else if (this.options.length === 0) {
        Text('无法读取当前网页的创建选项')
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
        Button('重新读取')
          .onClick(() => { if (this.onRetry) this.onRetry(); })
      }
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 32 })
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
