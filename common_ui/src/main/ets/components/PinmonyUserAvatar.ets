@Component
export struct PinmonyUserAvatar {
  @Prop @Watch('resetImage') image: string = '';
  @Prop name: string = '';
  @Prop avatarSize: number = 40;
  @State private failed: boolean = false;
  private resetImage(): void { this.failed = false; }
  build() {
    Stack() {
      if (this.image && !/\/user\/default(?:[/_.-]|$)/i.test(this.image) && !this.failed) {
        Image(this.image).width(this.avatarSize).height(this.avatarSize).objectFit(ImageFit.Cover)
          .onError(() => { this.failed = true; })
      } else {
        Text(this.name.trim().slice(0, 1).toUpperCase() || '?')
          .fontSize(this.avatarSize * 0.48).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
          .width(this.avatarSize).height(this.avatarSize).backgroundColor($r('app.color.surface_muted'))
      }
    }.width(this.avatarSize).height(this.avatarSize).borderRadius(this.avatarSize / 2).clip(true)
  }
}
