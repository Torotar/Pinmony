@Component
export struct PinmonySearchSkeleton {
  @Prop showCategories: boolean = true;
  @Prop loadingText: string = '正在加载搜索结果…';

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
    .accessibilityLevel('no-hide-descendants')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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
      Row({ space: 12 }) {
        Column({ space: 18 }) {
          this.card(200)
          this.card(260)
          this.card(180)
        }.layoutWeight(1)
        Column({ space: 18 }) {
          this.card(270)
          this.card(180)
          this.card(230)
        }.layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 12, right: 12 })
      .accessibilityLevel('no-hide-descendants')
      }
      .width('100%')
      .height('100%')
      .clip(true)
      Row({ space: 8 }) {
        LoadingProgress().width(20).height(20).color($r('app.color.accent'))
        Text(this.loadingText).fontSize(14).fontColor($r('app.color.secondary_text'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16, bottom: 24 })
      .backgroundColor($r('app.color.page_background'))
      .accessibilityText(this.loadingText)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('app.color.page_background'))
    .hitTestBehavior(HitTestMode.None)
  }
}
