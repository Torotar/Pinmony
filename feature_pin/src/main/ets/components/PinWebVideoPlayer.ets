import { PinWebVideo } from '../models/PinWebDetail';
import { PinWebPlaybackState, PinWebVideoPlayback } from '../services/PinWebVideoPlayback';

@Component
export struct PinWebVideoPlayer {
  @Prop @Watch('sourceChanged') video: PinWebVideo = {} as PinWebVideo;
  @Prop poster: string = '';
  @Prop @Watch('activeChanged') active: boolean = true;
  onRefresh?: () => void;
  onPosterSettled?: (failed: boolean) => void;
  @State private state: PinWebPlaybackState = { phase: 'idle', position: 0, duration: 0,
    rendered: false, buffering: false, muted: false, error: '' };
  @State private sliderValue: number = 0;
  private dragging: boolean = false;
  private sourceKey: string = '';
  private visible: boolean = true;
  private readonly surfaceController: XComponentController = new XComponentController();
  private readonly playback: PinWebVideoPlayback = new PinWebVideoPlayback((state: PinWebPlaybackState) => {
    if (state.rendered && !this.state.rendered && this.onPosterSettled) this.onPosterSettled(false);
    this.state = state;
    if (!this.dragging) this.sliderValue = state.position;
  });

  aboutToAppear(): void { this.sourceChanged(); this.activeChanged(); }
  aboutToDisappear(): void { this.playback.release(); }

  private sourceChanged(): void {
    const key: string = this.video.pinId + ':' + this.video.sources.map((s) => s.url).join('|');
    if (key === this.sourceKey) return;
    this.sourceKey = key; this.playback.setVideo(this.video); this.dragging = false; this.sliderValue = 0;
    this.playback.setActive(this.active && this.visible);
    if (this.active && this.visible) this.playback.start();
  }

  private activeChanged(): void { this.playback.setActive(this.active && this.visible); }
  private time(value: number): string {
    const seconds: number = Math.floor(Math.max(0, value) / 1000);
    return Math.floor(seconds / 60).toString() + ':' + (seconds % 60).toString().padStart(2, '0');
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        XComponent({ id: 'pin-video-surface', type: XComponentType.SURFACE, controller: this.surfaceController })
          .width('100%').height('100%')
          .onLoad(() => this.playback.setSurface(this.surfaceController.getXComponentSurfaceId()))
          .accessibilityLevel('no')
        if (!this.state.rendered) {
          this.posterImage(this.poster)
        }
        if (this.state.phase === 'playing') {
          Button({ type: ButtonType.Normal }) { Column().width('100%').height('100%') }
            .width('100%').height('100%').padding(0).backgroundColor(Color.Transparent)
            .enabled(this.active).accessibilityText('暂停视频').onClick(() => this.playback.toggle())
        }
        if (this.state.phase === 'loading' || this.state.buffering) {
          LoadingProgress().width(42).height(42).color(Color.White)
        } else if (this.state.phase !== 'playing') {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.video_play')).width(32).height(32)
          }.width(64).height(64).padding(0).backgroundColor('#66000000')
            .accessibilityText(this.state.phase === 'error' ? '重试播放' : this.state.phase === 'completed' ? '重播' : '播放')
            .enabled(this.active).onClick(() => this.playback.toggle())
        }
      Column() {
      Row({ space: 8 }) {
        Text(this.time(this.state.position)).fontSize(12).fontColor(Color.White)
        Slider({ value: this.sliderValue, min: 0, max: Math.max(1, this.state.duration) })
          .trackThickness(2).blockSize({ width: 12, height: 12 }).blockColor(Color.White)
          .selectedColor(Color.White).trackColor('#66FFFFFF')
          .layoutWeight(1).enabled(['prepared', 'playing', 'paused', 'completed'].includes(this.state.phase))
          .onChange((value: number, mode: SliderChangeMode) => {
            this.sliderValue = value;
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) this.dragging = true;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.dragging = false; this.playback.seek(value);
            }
          }).accessibilityText('视频播放进度')
        Text(this.time(this.state.duration)).fontSize(12).fontColor(Color.White)
        Button({ type: ButtonType.Normal }) {
          Image(this.state.muted ? $r('app.media.video_muted') : $r('app.media.video_volume')).width(22).height(22)
        }.width(40).height(40).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText(this.state.muted ? '取消静音' : '静音').onClick(() => this.playback.mute())
      }.width('100%').padding({ left: 12, right: 6, bottom: 4 })
        .backgroundColor('#22000000')
      }.width('100%').height('100%').justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }.width('100%').aspectRatio(this.video.width > 0 && this.video.height > 0 ?
        Math.max(0.5, Math.min(2, this.video.width / this.video.height)) : 0.5625)
      .backgroundColor(Color.Black)
      if (this.state.error) {
        Text(this.state.error).fontSize(14).fontColor($r('app.color.primary_text')).padding(12)
        Button('重新读取视频地址').onClick(() => { if (this.onRefresh) this.onRefresh(); })
      }
    }.width('100%').borderRadius(18).clip(true).backgroundColor($r('app.color.surface_muted'))
    .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number) => {
      this.visible = visible && ratio > 0; this.activeChanged();
    })
  }
  @Builder
  private posterImage(url: string) {
    Image(url).width('100%').height('100%').objectFit(ImageFit.Contain).accessibilityLevel('no')
      .onComplete(() => { if (url === this.poster && this.onPosterSettled) this.onPosterSettled(false); })
      .onError(() => { if (url === this.poster && this.onPosterSettled) this.onPosterSettled(true); })
  }
}
