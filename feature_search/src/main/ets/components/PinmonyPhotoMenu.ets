import { PinmonyI18n } from 'common_foundation';
export interface PinmonyPhotoMenuOptions { select: (index: number) => void; }
@Component
struct PhotoMenuContent {
  @StorageLink('pinmonyLanguage') private language: string = 'zh';
  select: (index: number) => void = () => {};
  build() {
    Menu() {
      MenuItem({ content: PinmonyI18n.text('pm_photo_upload', this.language) }).onClick(() => this.select(0))
      MenuItem({ content: PinmonyI18n.text('pm_photo_history', this.language) }).onClick(() => this.select(1))
    }
  }
}
@Builder
export function buildPhotoMenu(options: PinmonyPhotoMenuOptions) {
  PhotoMenuContent({ select: options.select })
}
