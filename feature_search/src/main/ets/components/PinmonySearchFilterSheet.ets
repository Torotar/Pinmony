import { PinmonySearchStore } from '../stores/PinmonySearchStore';
import { PinmonySearchFilterOption } from '../models/PinmonySearch';
@Component
export struct PinmonySearchFilterSheet {
  @ObjectLink searchStore: PinmonySearchStore;
  onSelect: (id: string) => void = (): void => {};
  onRetry: () => void = (): void => {};
  @State private trackWidth: number = 1;
  private dragStart: number = 0;
  private priceHandleOffset(upper: boolean): number {
    const span: number = this.searchStore.searchProductUpper - this.searchStore.searchProductLower;
    return span > 0 ? Math.max(0, Math.min(1, (this.price(upper) - this.searchStore.searchProductLower) / span)) * this.trackWidth : 0;
  }
  @Builder
  private priceHandle(upper: boolean) {
    Stack() {
      Circle().width(16).height(16).fill($r('app.color.primary_text'))
    }.width(40).height(44).position({ x: this.priceHandleOffset(upper), y: 0 })
      .accessibilityText((upper ? '最高价 ' : '最低价 ') + this.price(upper).toString())
      .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 0 })
        .onActionStart(() => { this.dragStart = this.price(upper); })
        .onActionUpdate((event: GestureEvent) => {
          const span: number = this.searchStore.searchProductUpper - this.searchStore.searchProductLower;
          const value: number = Math.round(this.dragStart + event.offsetX / Math.max(1, this.trackWidth) * span);
          if (upper) this.searchStore.searchProductMax = Math.max(this.price(false), Math.min(this.searchStore.searchProductUpper, value)).toString();
          else this.searchStore.searchProductMin = Math.min(this.price(true), Math.max(this.searchStore.searchProductLower, value)).toString();
          this.searchStore.searchProductError = '';
        }))
  }
  private price(upper: boolean): number {
    const value: string = upper ? this.searchStore.searchProductMax : this.searchStore.searchProductMin;
    return value ? Number(value) : upper ? this.searchStore.searchProductUpper : this.searchStore.searchProductLower;
  }
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
      if (this.searchStore.searchFilterOptions.length > 0 || this.searchStore.searchProductPrices || this.searchStore.searchProductDomains.length > 0) {
        Scroll() {
          Column() {
            if (this.searchStore.searchProductDomains.length || this.searchStore.searchProductPrices) {
              Column({space:12}) {
                if(this.searchStore.searchProductPrices) {
                  Text('价格范围').fontSize(17).fontColor($r('app.color.primary_text')).width('100%')
                  Row() {
                    Text(this.searchStore.searchProductCurrency + ' ' + this.price(false).toString())
                      .fontColor($r('app.color.primary_text')).fontWeight(FontWeight.Bold)
                    Blank()
                    Text(this.searchStore.searchProductCurrency + ' ' + this.price(true).toString())
                      .fontColor($r('app.color.primary_text')).fontWeight(FontWeight.Bold)
                  }.width('100%')
                  Stack({ alignContent: Alignment.TopStart }) {
                    Row().width(this.trackWidth).height(4).backgroundColor($r('app.color.surface_muted'))
                      .position({ x: 20, y: 20 })
                    Row().width(Math.max(0, this.priceHandleOffset(true) - this.priceHandleOffset(false))).height(4)
                      .backgroundColor($r('app.color.primary_text')).position({ x: this.priceHandleOffset(false) + 20, y: 20 })
                    this.priceHandle(false)
                    this.priceHandle(true)
                  }.width('100%').height(44)
                    .onAreaChange((_old: Area, area: Area) => { this.trackWidth = Math.max(1, Number(area.width) - 40); })
                  Text('拖拽以更改价格').fontSize(15).fontColor($r('app.color.secondary_text'))
                }
                Text('商家').fontSize(17).fontColor($r('app.color.primary_text')).width('100%')
                ForEach(this.searchStore.searchProductDomains,(domain: PinmonySearchFilterOption) => {
                  Row() {
                    Text(domain.label).layoutWeight(1).fontColor($r('app.color.primary_text'))
                    Checkbox({name:domain.id,group:'search-merchants'}).select(domain.selected)
                      .shape(CheckBoxShape.CIRCLE)
                      .selectedColor($r('app.color.accent'))
                      .unselectedColor($r('app.color.secondary_text'))
                      .mark({ strokeColor: Color.White }).enabled(domain.enabled)
                      .accessibilityText(domain.label)
                      .onChange((selected: boolean) => {
                        this.searchStore.searchProductDomains = this.searchStore.searchProductDomains.map((item: PinmonySearchFilterOption): PinmonySearchFilterOption =>
                          ({id:item.id,label:item.label,group:item.group,selected:item.id === domain.id ? selected : item.selected,enabled:item.enabled}));
                      })
                  }.width('100%')
                },(domain: PinmonySearchFilterOption) => domain.id)
                if(this.searchStore.searchProductError) { Text(this.searchStore.searchProductError).fontColor($r('app.color.secondary_text')) }
                Row({space:12}) {
                  Button('清除').layoutWeight(1).height(48).onClick(() => {
                    this.searchStore.searchProductMin = '';this.searchStore.searchProductMax = '';
                    this.onSelect('native-product:' + JSON.stringify({domains:[],min:'',max:''}));
                  })
                  Button('应用').layoutWeight(1).height(48).onClick(() => this.onSelect('native-product:' + JSON.stringify({
                    domains:this.searchStore.searchProductDomains.filter((item: PinmonySearchFilterOption): boolean => item.selected).map((item: PinmonySearchFilterOption): string => item.id),
                    min:this.searchStore.searchProductMin,max:this.searchStore.searchProductMax})))
                }.width('100%')
              }.width('100%').padding(24).enabled(!this.searchStore.searchFilterLoading)
            }
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
                Checkbox({ name: option.id, group: 'search-content-filters' })
                  .select(option.selected)
                  .shape(CheckBoxShape.CIRCLE)
                  .selectedColor($r('app.color.accent'))
                      .unselectedColor($r('app.color.secondary_text'))
                      .mark({ strokeColor: Color.White })
                  .enabled(option.enabled && !this.searchStore.searchFilterLoading)
                  .width(24).height(24)
                  .hitTestBehavior(HitTestMode.None)
                  .accessibilityLevel('no')
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
