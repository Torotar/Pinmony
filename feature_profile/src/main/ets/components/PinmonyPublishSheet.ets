import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyPublishOption } from '../models/PinmonyProfile';

@Component
export struct PinmonyPublishSheet {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop options: PinmonyPublishOption[] = [];
  @Prop loading: boolean = false;
  @Prop boardMode: boolean = false;
  @Prop sectionMode: boolean = false;
  onSelect?: (id: string) => void;
  onRetry?: () => void;
  onSection?: () => void;

  private groupOptions(group: string): PinmonyPublishOption[] {
    return this.options.filter((option: PinmonyPublishOption): boolean => option.group === group && (!this.boardMode || option.kind !== 'board'));
  }

  private groupLabel(group: string): string {
    if (group === 'create') return this.uiText("pm_create_cde2cd07");
    if (group === 'add') return this.uiText("pm_add_7a8a11ea");
    const item: PinmonyPublishOption | undefined = this.options.find((option: PinmonyPublishOption): boolean =>
      option.group === group);
    return item ? PinmonyI18n.render(item.groupLabel, this.uiLanguage) : '';
  }

  private optionLabel(item: PinmonyPublishOption): string {
    // All supported publish commands have stable kinds, including bridge and
    // retained snapshots whose labels predate local message tokens.
    if (item.kind === 'website') return this.uiText("pm_website_fb8d739d");
    if (item.kind === 'photo') return this.uiText("pm_photos_7b50017a");
    if (item.kind === 'board') return this.uiText("pm_board_bd3f17ee");
    return PinmonyI18n.render(item.label, this.uiLanguage);
  }

  @Builder
  private option(item: PinmonyPublishOption) {
    Row({ space: 16 }) {
      Image(item.kind === 'board' ? $r('app.media.lucide_layout_grid') :
        item.kind === 'website' ? $r('app.media.profile_website') : $r('app.media.profile_photo'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(this.optionLabel(item))
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
    .accessibilityText(this.optionLabel(item))
    .accessibilityDescription(item.enabled ? this.uiText("pm_open_pinterest_creation_flow_006166f5") : this.uiText("pm_this_option_is_unavailable_on_the_current_page_423e6914"))
  }

  @Builder
  private group(group: string) {
    if (this.groupOptions(group).length > 0) {
      Column({ space: 10 }) {
        Text(this.groupLabel(group))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .width('100%')
        ForEach(this.groupOptions(group), (item: PinmonyPublishOption) => {
          this.option(item)
        }, (item: PinmonyPublishOption) => item.id)
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: 24 }) {
      this.group('create')
      this.group('add')
      if (this.boardMode && !this.sectionMode && !this.loading) {
        Text(this.uiText("pm_add_7a8a11ea")).fontSize(14).fontColor($r('app.color.secondary_text')).width('100%')
        Text(this.uiText("pm_section_6d4e3a60")).fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).width('100%').height(58)
          .padding({ left: 16, right: 16 }).backgroundColor($r('app.color.surface_muted')).borderRadius(16)
          .onClick(() => { if (this.onSection) this.onSection(); })
      }
      if (this.loading) {
        LoadingProgress().width(28).height(28)
        Text(this.uiText("pm_preparing_to_publish_97f29dc9"))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
      } else if (this.options.length === 0) {
        PinmonyActionNotice({ message: this.uiText("pm_publishing_not_ready_please_retry_8ec4cc6d"), actionText: this.uiText("pm_reload_df7392cc"), onAction: () => { if (this.onRetry) this.onRetry(); } })
      }
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 32 })
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
