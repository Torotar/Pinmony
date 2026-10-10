import { PinmonyVideo } from '../models/PinmonyVideo';
import { PinmonyPlaybackState, PinmonyVideoPlayback } from '../services/PinmonyVideoPlayback';

@Component
export struct PinmonyVideoCard {
  @Prop @Watch('sourceChanged') video: PinmonyVideo = { pinId: '', sources: [], width: 0, height: 0, duration: 0 };
  @Prop poster: string = '';
  @Prop @Watch('activeChanged') active: boolean = false;
  @State private rendered: boolean = false;
  private visible: boolean = false;
  private sourceKey: string = '';
  private readonly surface: XComponentController = new XComponentController();
  private readonly playback: PinmonyVideoPlayback = new PinmonyVideoPlayback((state: PinmonyPlaybackState) => {
    this.rendered = state.rendered;
  });

  aboutToAppear(): void { this.sourceChanged(); }
  aboutToDisappear(): void { this.visible = false; this.playback.release(); }

  private sourceChanged(): void {
    const key: string = this.video.pinId + ':' + this.video.sources.map(s => s.url).join('|');
    if (key === this.sourceKey) return;
    this.sourceKey = key;
    this.playback.setVideo(this.video);
    this.playback.mute();
    this.activeChanged();
  }

  private activeChanged(): void {
    const enabled: boolean = this.active && this.visible;
    this.playback.setActive(enabled);
    if (enabled) this.playback.start();
    else this.playback.stop();
  }

  private durationText(): string {
    const seconds: number = Math.ceil(Math.max(0, this.video.duration) / 1000);
    return Math.floor(seconds / 60).toString() + ':' + (seconds % 60).toString().padStart(2, '0');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({ id: 'pin-card-video-' + this.video.pinId, type: XComponentType.SURFACE, controller: this.surface })
        .width('100%').height('100%').accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
        .onLoad(() => this.playback.setSurface(this.surface.getXComponentSurfaceId()))
      if (!this.rendered) {
        Image(this.poster).width('100%').height('100%').objectFit(ImageFit.Cover).accessibilityLevel('no')
      }
      if (this.video.duration > 0) {
        Text(this.durationText()).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#111111')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 }).backgroundColor('#EFFFFFFF')
          .borderRadius(7).margin({ left: 5, top: 5 }).accessibilityText('视频时长 ' + this.durationText())
      }
    }.width('100%').height('100%').borderRadius(18).clip(true)
      .backgroundColor($r('app.color.surface_muted'))
      .onVisibleAreaChange([0, 0.6], (visible: boolean, ratio: number) => {
        const next: boolean = visible && ratio >= 0.6;
        if (next !== this.visible) { this.visible = next; this.activeChanged(); }
      })
  }
}
