import { PinmonySearchStore } from '../stores/PinmonySearchStore';
import { PinmonySearchFilterOption } from '../models/PinmonySearch';
@Component
export struct PinmonySearchFilterSheet {
  @ObjectLink searchStore: PinmonySearchStore;
  onSelect: (id: string) => void = (): void => {};
  onRetry: () => void = (): void => {};
  build() {
    Column() {
      if (this.searchStore.searchFilterLoading) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(24)
            .height(24)
          Text('正在读取筛选选项…')
            .fontSize(14)
            .fontColor($r('app.color.secondary_text'))
        }
        .width('100%')
        .height(72)
        .padding({ left: 24, right: 24 })
      }
      if (this.searchStore.searchFilterError) {
        Text(this.searchStore.searchFilterError)
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .padding({ left: 24, right: 24, top: 18, bottom: 18 })
          .width('100%')
        Button('重试读取')
          .height(42)
          .margin({ left: 24, right: 24, bottom: 12 })
          .onClick(() => this.onRetry())
      }
      if (this.searchStore.searchFilterOptions.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.searchStore.searchFilterOptions, (option: PinmonySearchFilterOption, index: number) => {
              if (option.group && (index === 0 ||
                  option.group !== this.searchStore.searchFilterOptions[index - 1].group)) {
                Text(option.group)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.secondary_text'))
                  .padding({ left: 24, right: 24, top: 18, bottom: 6 })
                  .width('100%')
              }
              Row({ space: 12 }) {
                Text(option.label)
                  .fontSize(17)
                  .fontColor($r('app.color.primary_text'))
                  .layoutWeight(1)
                  .maxLines(2)
                if (option.selected) {
                  Text('✓')
                    .fontSize(20)
                    .fontColor($r('app.color.detail_accent'))
                }
              }
              .width('100%')
              .height(56)
              .padding({ left: 24, right: 24 })
              .opacity(option.enabled && !this.searchStore.searchFilterLoading ? 1 : 0.45)
              .accessibilityText(option.label + (option.selected ? '，已选中' : ''))
              .accessibilitySelected(option.selected)
              .onClick(() => {
                if (option.enabled && !this.searchStore.searchFilterLoading) this.onSelect(option.id);
              })
            }, (option: PinmonySearchFilterOption) => option.id)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding({ bottom: 20 })
    .backgroundColor($r('app.color.page_background'))
  }


}
