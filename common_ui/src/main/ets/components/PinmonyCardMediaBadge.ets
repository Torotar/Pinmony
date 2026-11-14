@Component
export struct PinmonyCardMediaBadge {
  @Prop caption: string = '';
  @Prop spokenLabel: string = '';

  build() {
    Text(this.caption).fontSize(14).fontWeight(FontWeight.Medium)
      .fontColor('#111111').padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor('#EFFFFFFF').borderRadius(7).margin(5)
      .align(Alignment.TopStart).hitTestBehavior(HitTestMode.None)
      .accessibilityText(this.spokenLabel || this.caption)
  }
}
