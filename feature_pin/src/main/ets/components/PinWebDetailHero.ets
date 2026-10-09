import { PinWebRuntimeLog } from 'common_foundation';

export interface DetailHeroSource { key: string; url: string; pinUrl: string; revision: number; }

@Component
export struct PinWebDetailHero {
  // The parent ForEach replaces this component only on a source change or retry.
  @Prop source: DetailHeroSource = { key: '', url: '', pinUrl: '', revision: 0 };
  @Prop heightVp: number = 300;
  @Prop openId: number = 0;
  @Prop label: string = '';
  @Prop phase: string = 'current';
  @Prop blocked: boolean = false;
  @Prop @Watch('onRenderChanged') renderIdentity: string = '';
  @Prop @Watch('onStageChanged') stageReady: boolean = false;
  @Prop @Watch('onStageChanged') confirmedLoaded: boolean = false;
  @State private imageState: string = 'loading';
  private visible: boolean = false;
  private mountedKey: string = '';
  private decoded: boolean = false;
  private deadline: number = -1;
  private startedAt: number = 0;
  onLoaded?: (pinUrl: string, imageUrl: string) => void;
  onFailed?: (pinUrl: string) => void;
  onRetry?: () => void;
  onTap?: () => void;

  aboutToAppear(): void {
    this.visible = true; this.mountedKey = this.source.key; this.startedAt = Date.now();
    this.audit('node-created');
    this.deadline = setTimeout(() => {
      if (!this.isCurrent() || this.decoded || this.imageState === 'failed') return;
      this.deadline = -1; this.imageState = 'timeout'; this.audit('timeout');
    }, 8000);
    this.onStageChanged();
  }

  aboutToDisappear(): void {
    this.visible = false; this.stopDeadline(); this.audit('node-disposed');
  }

  private isCurrent(): boolean {
    return this.visible && this.mountedKey === this.source.key;
  }

  private stopDeadline(): void {
    if (this.deadline !== -1) clearTimeout(this.deadline);
    this.deadline = -1;
  }

  private onStageChanged(): void {
    if (!this.isCurrent() || this.decoded || this.imageState !== 'loading') return;
    if (this.stageReady && !this.confirmedLoaded && this.source.revision === 0) {
      this.imageState = 'timeout'; this.stopDeadline(); this.audit('stage-timeout');
    }
  }

  private onRenderChanged(): void {
    if (this.isCurrent() && this.decoded && this.onLoaded) this.onLoaded(this.source.pinUrl, this.source.url);
  }

  private completeImage(status: number): void {
    if (!this.isCurrent()) { this.audit('callback-rejected'); return; }
    if (status === 0) { this.audit('data-ready'); return; }
    if (status !== 1 || this.decoded) return;
    this.decoded = true; this.imageState = 'loaded'; this.stopDeadline(); this.audit('decoded');
    if (this.onLoaded) this.onLoaded(this.source.pinUrl, this.source.url);
  }

  private failImage(): void {
    if (!this.isCurrent()) { this.audit('callback-rejected'); return; }
    this.imageState = 'failed'; this.stopDeadline(); this.audit('failed');
    if (this.onFailed) this.onFailed(this.source.pinUrl);
  }

  private retryImage(): void {
    if (!this.isCurrent() || !this.onRetry) return;
    this.audit('retry'); this.onRetry();
  }

  private audit(event: string): void {
    const phase: string = this.phase === 'cached' || this.phase === 'opening' ? this.phase : 'current';
    PinWebRuntimeLog.info('HeroImageTrace: openId=' + this.openId.toString() + ' event=' + event + ' phase=' + phase +
      ' revision=' + this.source.revision.toString() + ' elapsedMs=' + Math.max(0, Date.now() - this.startedAt).toString());
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // State feedback never removes the Image while its source is still current.
      Image(this.source.url).width('100%').height(this.heightVp).objectFit(ImageFit.Cover).borderRadius(18)
        .onComplete((event) => this.completeImage(event?.loadingStatus ?? -1))
        .onError(() => this.failImage())
        .onClick(() => { if (this.isCurrent() && this.onTap) this.onTap(); })
        .accessibilityText(this.label || 'Pin 图片')
      if (!this.blocked && this.imageState === 'loading') {
        LoadingProgress().width(28).height(28).color($r('app.color.accent'))
          .hitTestBehavior(HitTestMode.None).accessibilityText('正在加载图片')
      } else if (!this.blocked && (this.imageState === 'timeout' || this.imageState === 'failed')) {
        Column({ space: 8 }) {
          Text(this.imageState === 'failed' ? '图片加载失败' : '图片加载超时')
            .fontSize(14).fontColor($r('app.color.secondary_text'))
          Button('重新加载图片').onClick(() => this.retryImage())
        }.padding(12).borderRadius(12).backgroundColor($r('app.color.page_background'))
      }
    }.width('100%').height(this.heightVp)
  }
}
