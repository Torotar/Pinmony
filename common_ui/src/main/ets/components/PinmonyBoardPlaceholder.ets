@Component
export struct PinmonyBoardPlaceholder {
  @Prop coverSize: number = 56;

  build() {
    Row({ space: 1 }) {
      Column().width((this.coverSize - 1) / 2).height(this.coverSize)
        .backgroundColor($r('app.color.surface_muted'))
      Column({ space: 1 }) {
        Column().width((this.coverSize - 1) / 2).height((this.coverSize - 1) / 2)
          .backgroundColor($r('app.color.surface_muted'))
        Column().width((this.coverSize - 1) / 2).height((this.coverSize - 1) / 2)
          .backgroundColor($r('app.color.surface_muted'))
      }
    }.width(this.coverSize).height(this.coverSize).borderRadius(16).clip(true)
      .backgroundColor($r('app.color.page_background')).accessibilityLevel('no')
  }
}
