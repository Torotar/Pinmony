import { PinmonyAvatarColorSource } from '../PinmonyAvatarColorSource';
@Component
export struct PinmonyUserAvatar {
  @Prop @Watch('avatarIdentityChanged') image: string = '';
  @Prop name: string = '';
  @Prop @Watch('avatarIdentityChanged') colorIndex: number = 0;
  @Prop @Watch('avatarIdentityChanged') profileUrl: string = '';
  @Prop @Watch('avatarIdentityChanged') username: string = '';
  @Prop @Watch('avatarIdentityChanged') userId: string = '';
  @State private hydratedColor: number = 0;
  private avatarVisible: boolean = false;
  private avatarAlive: boolean = false;
  private avatarRequest: number = 0;
  private releaseColor: (() => void) | undefined = undefined;
  private releaseSource: (() => void) | undefined = undefined;
  aboutToAppear(): void {
    this.avatarAlive = true;
    this.releaseSource = PinmonyAvatarColorSource.observe((reload: boolean): void => {
      this.cancelColor(); this.hydratedColor = 0; if (reload) this.resolveColor();
    });
  }
  aboutToDisappear(): void {
    this.avatarAlive = false; this.cancelColor(); this.releaseSource?.(); this.releaseSource = undefined;
  }
  private cancelColor(): void { this.avatarRequest++; this.releaseColor?.(); this.releaseColor = undefined; }
  private avatarIdentityChanged(): void {
    this.resetImage(); this.hydratedColor = 0; this.cancelColor(); this.resolveColor();
  }
  private resolveColor(): void {
    this.cancelColor();
    if (!this.avatarAlive || !this.avatarVisible || !this.websiteFallback ||
      Number.isInteger(this.colorIndex) && this.colorIndex >= 1 && this.colorIndex <= 10 ||
      this.image && !/\/user\/default(?:[/_.-]|$)/i.test(this.image) && !this.failed) return;
    const request: number = this.avatarRequest;
    this.releaseColor = PinmonyAvatarColorSource.read({profileUrl:this.profileUrl,username:this.username,userId:this.userId},(color: number): void => {
      if (this.avatarAlive && this.avatarVisible && request === this.avatarRequest) this.hydratedColor = color;
    });
  }
  @Prop websiteFallback: boolean = true;
  @StorageProp('systemDarkMode') private systemDarkMode: boolean = false;
  private fallbackBackground(): ResourceColor {
    if (!this.websiteFallback) return $r('app.color.surface_muted');
    // Pinterest Avatar color order: red, purple, blue, green, orange; weak then default.
    const light: string[] = ['#FFD7D7','#FF8F8F','#FBDFFF','#EF9FF9','#DBE1FF','#92A4FF','#C7F0DA','#83DDAD','#FFE0CC','#FFB380'];
    const dark: string[] = ['#6B0000','#900909','#51005C','#7A2286','#17287D','#273EB0','#103C25','#07552B','#5C2500','#943B00'];
    const color: number = Number.isInteger(this.colorIndex) && this.colorIndex >= 1 && this.colorIndex <= 10 ? this.colorIndex : this.hydratedColor;
    const valid: boolean = Number.isInteger(color) && color >= 1 && color <= 10;
    return valid ? (this.systemDarkMode ? dark : light)[color - 1] : $r('app.color.surface_muted');
  }
  private fallbackInitial(): string {
    const characters: string[] = Array.from(this.name.trim());
    return characters.length > 0 ? characters[0].toUpperCase() : '?';
  }
  @Prop avatarSize: number = 40;
  @State private failed: boolean = false;
  private resetImage(): void { this.failed = false; }
  build() {
    Stack() {
      if (this.image && !/\/user\/default(?:[/_.-]|$)/i.test(this.image) && !this.failed) {
        Image(this.image).width(this.avatarSize).height(this.avatarSize).objectFit(ImageFit.Cover)
          .onError(() => { this.failed = true; this.resolveColor(); })
      } else {
        Text(this.fallbackInitial())
          .fontSize(this.avatarSize * (this.websiteFallback ? 0.4 : 0.48)).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary_text')).textAlign(TextAlign.Center)
          .width(this.avatarSize).height(this.avatarSize).backgroundColor(this.fallbackBackground())
      }
    }.width(this.avatarSize).height(this.avatarSize).borderRadius(this.avatarSize / 2).clip(true)
      .onVisibleAreaChange([0,0.01],(visible: boolean, ratio: number): void => {
        this.avatarVisible = visible && ratio > 0; if (this.avatarVisible) this.resolveColor(); else this.cancelColor();
      })
  }
}
