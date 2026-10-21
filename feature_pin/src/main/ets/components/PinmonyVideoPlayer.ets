import { PinmonyI18n } from 'common_foundation';
import { PinmonyVideo } from '../models/PinmonyDetail';
import { PinmonyPlaybackState, PinmonyVideoPlayback, PIN_VIDEO_FILE_RECOVERY_ENABLED } from '../services/PinmonyVideoPlayback';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyMediaFile } from 'common_network';
import { PinmonyVideoFileLease } from 'common_ui';
import { common } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';

@Component
export struct PinmonyVideoPlayer {
  @Prop @Watch('autoplayChanged') autoplayWifi: boolean = false;
  @Prop @Watch('autoplayChanged') autoplayCellular: boolean = false;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  private uiText(source: string): string { return PinmonyI18n.text(source, this.uiLanguage); }
  @Prop @Watch('sourceChanged') video: PinmonyVideo = {} as PinmonyVideo;
  @Prop poster: string = '';
  @Prop openId: number = 0;
  @Prop @Watch('activeChanged') active: boolean = true;
  @Prop @Watch('sourceChanged') mediaOwner: string = '';
  @Prop @Watch('sourceChanged') sessionReady: boolean = false;
  @Prop readingAddress: boolean = false;
  @Prop @Watch('retryRequested') retryRevision: number = 0;
  onFailureChanged?: (pinId: string, message: string) => void;
  onPosterSettled?: (failed: boolean) => void;
  @State private state: PinmonyPlaybackState = { phase: 'idle', position: 0, duration: 0,
    rendered: false, buffering: false, muted: false, error: '' };
  @State private sliderValue: number = 0;
  private dragging: boolean = false;
  private sourceKey: string = '';
  private visible: boolean = true;
  private pendingRetry: boolean = false;
  private mounted: boolean = false;
  private sourceUpdateQueued: boolean = false;
  private componentGeneration: number = 0;
  private networkType: string = 'unknown';
  private networkConnection: connection.NetConnection | undefined = undefined;
  private networkRevision: number = 0;
  private autoplayStarted: boolean = false;
  private manualPlayback: boolean = false;
  private readonly surfaceController: XComponentController = new XComponentController();
  private readonly mediaFile: PinmonyMediaFile = new PinmonyMediaFile((event: string) =>
    PinmonyRuntimeLog.info('VideoFileTrace: openId=' + this.openId.toString() + ' ' + event));
  private readonly playback: PinmonyVideoPlayback = new PinmonyVideoPlayback((state: PinmonyPlaybackState) => {
    if (state.rendered && !this.state.rendered && this.onPosterSettled) this.onPosterSettled(false);
    const errorChanged: boolean = this.state.error !== state.error;
    this.state = state;
    if (errorChanged && this.onFailureChanged) this.onFailureChanged(this.video.pinId, state.error);
    if (!this.dragging) this.sliderValue = state.position;
  }, (event: string) => PinmonyRuntimeLog.info('VideoTrace: openId=' + this.openId.toString() + ' ' + event), PIN_VIDEO_FILE_RECOVERY_ENABLED ? {
    load: async (source: string): Promise<PinmonyVideoFileLease> => {
      const owner: string = this.mediaOwner;
      const key: string = this.sourceKey;
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return this.mediaFile.read(source, context.cacheDir, (): boolean => this.active && this.visible &&
        this.sessionReady &&
        owner === this.mediaOwner && key === this.sourceKey && this.video.sources.some((item) => item.kind === 'mp4' && item.url === source));
    },
    cancel: () => this.mediaFile.cancel()
  } : undefined);

  aboutToAppear(): void {
    this.mounted = true;
    if (this.onFailureChanged) this.onFailureChanged(this.video.pinId, '');
    this.sourceChanged(); this.activeChanged();
    this.watchNetwork();
  }
  aboutToDisappear(): void {
    this.mounted = false; this.componentGeneration++; this.sourceUpdateQueued = false;
    this.networkRevision++;
    try { this.networkConnection?.unregister(() => {}); } catch (_) {}
    this.networkConnection = undefined;
    this.sourceKey = ''; this.pendingRetry = false; this.playback.release();
  }

  private sourceChanged(): void {
    if (!this.mounted || this.sourceUpdateQueued) return;
    this.sourceUpdateQueued = true;
    const generation: number = this.componentGeneration;
    Promise.resolve().then(() => {
      if (!this.mounted || generation !== this.componentGeneration) return;
      this.sourceUpdateQueued = false; this.applySource();
    });
  }

  private applySource(): void {
    if (!this.sessionReady) {
      if (this.sourceKey) { this.sourceKey = ''; this.pendingRetry = false; this.playback.stop(); }
      return;
    }
    const key: string = this.mediaOwner + ':' + this.video.pinId + ':' + this.video.sources.map((s) => s.url).join('|') + ':' + (this.video.readRevision || 0).toString();
    if (key === this.sourceKey) return;
    this.sourceKey = key; this.pendingRetry = false;
    this.autoplayStarted = false; this.manualPlayback = false;
    this.playback.setVideo(this.video); this.dragging = false; this.sliderValue = 0;
    this.playback.setActive(this.active && this.visible && this.sessionReady);
    this.autoplayChanged();
  }

  private activeChanged(): void {
    this.playback.setActive(this.active && this.visible && this.sessionReady);
    if (!this.active || !this.sessionReady) this.pendingRetry = false;
    if (this.pendingRetry && this.active && this.visible && this.sessionReady && !this.readingAddress) {
      this.pendingRetry = false; this.manualPlayback = true; this.playback.retry();
    }
    this.autoplayChanged();
  }
  private watchNetwork(): void {
    try {
      this.networkConnection = connection.createNetConnection();
      this.networkConnection.on('netAvailable', () => { this.refreshNetwork(); });
      this.networkConnection.on('netCapabilitiesChange', () => { this.refreshNetwork(); });
      this.networkConnection.on('netLost', () => { this.refreshNetwork(); });
      this.networkConnection.on('netUnavailable', () => { this.refreshNetwork(); });
      this.networkConnection.register(() => { if (this.mounted) this.refreshNetwork(); });
      this.refreshNetwork();
    } catch (_) { this.networkType = 'unknown'; this.autoplayChanged(); }
  }
  private async refreshNetwork(): Promise<void> {
    const revision: number = ++this.networkRevision;
    try {
      const handle: connection.NetHandle = await connection.getDefaultNet();
      const capabilities: connection.NetCapabilities = await connection.getNetCapabilities(handle);
      if (!this.mounted || revision !== this.networkRevision) return;
      // Mobile transport takes precedence for mixed/VPN paths to avoid treating paid data as Wi-Fi.
      this.networkType = capabilities.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR) ? 'cellular' : capabilities.bearerTypes.includes(connection.NetBearType.BEARER_WIFI) ? 'wifi' : 'unknown';
    } catch (_) { if (!this.mounted || revision !== this.networkRevision) return; this.networkType = 'unknown'; }
    this.autoplayChanged();
  }
  private autoplayChanged(): void {
    if (!this.mounted || !this.sourceKey || this.manualPlayback) return;
    const allowed: boolean = this.networkType === 'wifi' ? this.autoplayWifi : this.networkType === 'cellular' ? this.autoplayCellular : false;
    if (!allowed) {
      if (this.autoplayStarted) { this.playback.setActive(false); this.playback.setActive(this.active && this.visible && this.sessionReady); this.autoplayStarted = false; }
      return;
    }
    if (!this.autoplayStarted && this.active && this.visible && this.sessionReady && (this.state.phase === 'idle' || this.state.phase === 'paused')) {
      this.autoplayStarted = true; this.playback.start();
    }
  }
  private togglePlayback(): void { this.manualPlayback = true; this.playback.toggle(); }
  private retryRequested(): void {
    if (!this.active || !this.sessionReady || this.readingAddress) return;
    this.pendingRetry = true; this.activeChanged();
  }
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
            .enabled(this.active && this.sessionReady && !this.readingAddress).accessibilityText(this.uiText("pm_pause_video_550c18fe")).onClick(() => this.togglePlayback())
        }
        if (this.readingAddress || this.state.phase === 'loading' || this.state.buffering ||
            !this.state.rendered && (this.state.phase === 'prepared' || this.state.phase === 'playing')) {
          LoadingProgress().width(42).height(42).color(Color.White)
        } else if (this.state.phase !== 'playing') {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.video_play')).width(32).height(32)
          }.width(64).height(64).padding(0).backgroundColor('#66000000')
            .accessibilityText(this.state.phase === 'error' ? this.uiText("pm_retry_playback_f867a4c8") : this.state.phase === 'completed' ? this.uiText("pm_replay_4c5a69ac") : this.uiText("pm_play_c3396195"))
            .enabled(this.active && this.sessionReady && !this.readingAddress).onClick(() => this.togglePlayback())
        }
      Column() {
      Row({ space: 8 }) {
        Text(this.time(this.state.position)).fontSize(12).fontColor(Color.White)
        Slider({ value: this.sliderValue, min: 0, max: Math.max(1, this.state.duration) })
          .trackThickness(2).blockSize({ width: 12, height: 12 }).blockColor(Color.White)
          .selectedColor(Color.White).trackColor('#66FFFFFF')
          .layoutWeight(1).enabled(!this.readingAddress && ['prepared', 'playing', 'paused', 'completed'].includes(this.state.phase))
          .onChange((value: number, mode: SliderChangeMode) => {
            this.sliderValue = value;
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) this.dragging = true;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.dragging = false; this.playback.seek(value);
            }
          }).accessibilityText(this.uiText("pm_video_progress_73fbb1f1"))
        Text(this.time(this.state.duration)).fontSize(12).fontColor(Color.White)
        Button({ type: ButtonType.Normal }) {
          Image(this.state.muted ? $r('app.media.video_muted') : $r('app.media.video_volume')).width(22).height(22)
        }.width(40).height(40).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText(this.state.muted ? this.uiText("pm_unmute_8d01732e") : this.uiText("pm_mute_7db2e189")).onClick(() => this.playback.mute())
      }.width('100%').padding({ left: 12, right: 6, bottom: 4 })
        .backgroundColor('#22000000')
      }.width('100%').height('100%').justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }.width('100%').aspectRatio(this.video.width > 0 && this.video.height > 0 ?
        Math.max(0.5, Math.min(2, this.video.width / this.video.height)) : 0.5625)
      .backgroundColor(Color.Black)
      if (this.readingAddress) {
        Text(this.uiText("pm_loading_video_url_3669a32d")).fontSize(14).fontColor($r('app.color.primary_text')).padding(12)
          .accessibilityText(this.uiText("pm_loading_video_url_please_wait_3788d096"))
      } else if (this.state.phase === 'loading' && this.state.loadingStage !== 'download') {
        Text(this.uiText("pm_preparing_video_d20d6092"))
          .fontSize(14).fontColor($r('app.color.primary_text')).padding(12)
      } else if (!this.state.rendered && (this.state.phase === 'prepared' || this.state.phase === 'playing')) {
        Text(this.uiText("pm_loading_video_843966d2")).fontSize(14).fontColor($r('app.color.primary_text')).padding(12)
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
