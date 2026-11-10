import { PinmonyI18n } from 'common_foundation';
@Component
export struct PinmonyHomeSkeleton {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop showCategories: boolean = true;
  @State private contentWidth: number = 360;

  private contentColumns(): number {
    return Math.max(2, Math.floor((this.contentWidth - 24 + 12) / 192));
  }

  private columnSlots(): number[] {
    const slots: number[] = [];
    for (let index: number = 0; index < this.contentColumns(); index++) slots.push(index);
    return slots;
  }

  private cardHeight(column: number, row: number): number {
    const cardWidth: number = Math.max(130, (this.contentWidth - 24 - (this.contentColumns() - 1) * 12) / this.contentColumns());
    const ratios: number[] = [1.2, 1.6, 1.1, 1.65, 1.1, 1.4];
    return cardWidth * ratios[(column % 2) * 3 + row];
  }

  @Builder
  private card(height: number) {
    Column({ space: 10 }) {
      Column()
        .width('100%')
        .height(height)
        .borderRadius(18)
        .backgroundColor($r('app.color.surface_muted'))
      Column()
        .width('72%')
        .height(12)
        .borderRadius(6)
        .backgroundColor($r('app.color.input_surface'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityLevel('no-hide-descendants')
  }

  build() {
    Column({ space: 12 }) {
      if (this.showCategories) {
        Row({ space: 10 }) {
          ForEach([64, 84, 76], (width: number) => {
            Column()
              .width(width)
              .height(36)
              .borderRadius(18)
              .backgroundColor($r('app.color.input_surface'))
          }, (width: number) => width.toString())
        }
        .width('100%')
        .height(48)
        .padding({ left: 24, right: 24 })
        .accessibilityLevel('no-hide-descendants')
      }
      Row({ space: 8 }) {
        LoadingProgress().width(20).height(20).color($r('app.color.accent'))
        Text(this.uiText("pm_loading_home_content_03c47493"))
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .accessibilityText(this.uiText("pm_loading_home_content_8884d492"))
      Row({ space: 12 }) {
        ForEach(this.columnSlots(), (column: number) => {
          Column({ space: 18 }) {
            ForEach([0, 1, 2], (row: number) => {
              this.card(this.cardHeight(column, row))
            }, (row: number): string => row.toString())
          }.layoutWeight(1)
        }, (column: number): string => column.toString())
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 12, right: 12 })
      .accessibilityLevel('no-hide-descendants')
    }
    .width('100%')
    .onAreaChange((_oldArea: Area, area: Area) => {
      const nextWidth: number = Number(area.width);
      if (nextWidth > 0 && Math.abs(nextWidth - this.contentWidth) > 1) this.contentWidth = nextWidth;
    })
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .clip(true)
    .backgroundColor($r('app.color.page_background'))
    .hitTestBehavior(HitTestMode.None)
  }
}
