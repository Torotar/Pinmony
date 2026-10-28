import { PinmonyShuffleSnapshot, PinmonyShuffleItem } from '../models/PinmonyShuffle';
import { shuffleHitCandidates, PinmonyShuffleHitPoint } from '../services/PinmonyShuffleHitTest';
import { PinmonyShuffleHitMasks } from '../services/PinmonyShuffleHitMasks';
import { PinmonyRuntimeLog, PinmonyI18n } from 'common_foundation';

@Component
export struct PinmonyShuffleCanvas {
  @Prop @Watch('warmHitMasks') shuffle: PinmonyShuffleSnapshot;
  @Prop coverUrl: string = '';
  @Prop canvasWidthVp: number = 1;
  @Prop canvasHeightVp: number = 1;
  @Prop @Watch('warmHitMasks') interactionReady: boolean = false;
  @Prop pinLabel: string = '';
  onPin?: (id: string) => void;
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @State private hitLoading: boolean = false;
  @State private hitMaskUnavailable: boolean = false;
  hitMasks: PinmonyShuffleHitMasks = new PinmonyShuffleHitMasks();
  private hitRevision: number = 0;
  private hitSession: number = 0;
  private warmedShuffleId: string = '';
  aboutToDisappear(): void { this.hitRevision++; this.hitSession++; this.warmedShuffleId = ''; this.hitMasks.suspend(); }
  aboutToAppear(): void { this.warmHitMasks(); }

  private warmHitMasks(): void {
    if (!this.interactionReady || this.warmedShuffleId === this.shuffle.id) return;
    const id: string = this.shuffle.id, session: number = this.hitSession;
    this.warmedShuffleId = id;
    this.hitMasks.prepare(this.shuffle.items,(): boolean => session === this.hitSession && id === this.shuffle.id && this.interactionReady);
  }

  private async openAt(x: number, y: number): Promise<void> {
    const startedAt: number = Date.now();
    const revision: number = ++this.hitRevision, shuffleId: string = this.shuffle.id;
    const session: number = this.hitSession;
    const visible = (): boolean => session === this.hitSession && shuffleId === this.shuffle.id && this.interactionReady;
    const current = (): boolean => revision === this.hitRevision && visible();
    if (!current()) return;
    const snapshot: PinmonyShuffleSnapshot = this.shuffle;
    const hits: PinmonyShuffleHitPoint[] = shuffleHitCandidates(snapshot,this.canvasWidthVp,this.canvasHeightVp,x,y);
    this.hitMaskUnavailable = false;
    this.hitLoading = hits.length > 0;
    PinmonyRuntimeLog.info('ShuffleHitTrace: event=tap candidates=' + hits.length.toString());
    PinmonyRuntimeLog.info('ShuffleHitTrace: event=point x=' + x.toFixed(2) + ' y=' + y.toFixed(2) +
      ' viewport=' + this.canvasWidthVp.toFixed(2) + 'x' + this.canvasHeightVp.toFixed(2) +
      ' canvas=' + this.shuffle.canvasWidth + 'x' + this.shuffle.canvasHeight);
    try {
    for (const hit of hits) {
      const opaque: boolean | undefined = await this.hitMasks.opaque(hit,visible);
      if (!current()) return;
      PinmonyRuntimeLog.info('ShuffleHitTrace: event=sample layer=' + snapshot.items.findIndex((item: PinmonyShuffleItem): boolean => item.id === hit.item.id) +
        ' u=' + hit.u.toFixed(4) + ' v=' + hit.v.toFixed(4) + ' opaque=' + String(opaque) +
        ' size=' + hit.item.imageWidth + 'x' + hit.item.imageHeight +
        ' hitSize=' + hit.item.hitWidth + 'x' + hit.item.hitHeight +
        ' offset=' + hit.item.offsetX.toFixed(2) + ',' + hit.item.offsetY.toFixed(2) +
        ' scale=' + hit.item.scale.toFixed(4) + ' rotation=' + hit.item.rotation.toFixed(2) +
        ' cutout=' + (!!hit.item.cutoutUrl).toString());
      if (opaque === undefined) {
        this.hitMaskUnavailable = true;
        PinmonyRuntimeLog.info('ShuffleHitTrace: event=mask-unavailable');
        return;
      }
      if (opaque === false) continue;
      if (hit.item.tappable && hit.item.pinId) {
        PinmonyRuntimeLog.info('ShuffleHitTrace: event=open mode=alpha elapsedMs=' + (Date.now() - startedAt).toString());
        this.onPin?.(hit.item.id);
      } else PinmonyRuntimeLog.info('ShuffleHitTrace: event=blocked');
      return;
    }
    } finally { if (current()) this.hitLoading = false; }
  }
  build() {
    Stack() {
      Image(this.coverUrl).width('100%').height('100%').objectFit(ImageFit.Contain).hitTestBehavior(HitTestMode.None)
      if (this.hitLoading) {
        LoadingProgress().width(28).height(28).color($r('app.color.accent')).hitTestBehavior(HitTestMode.None)
      }
      if (this.hitMaskUnavailable) {
        Text(PinmonyI18n.text('pm_unable_to_load_content_please_retry_95306b92',this.uiLanguage))
          .fontSize(14).fontColor($r('app.color.primary_text')).padding(10).borderRadius(10)
          .backgroundColor($r('app.color.surface_muted')).align(Alignment.BottomStart).margin(12)
          .hitTestBehavior(HitTestMode.None)
      }
    }.width(this.canvasWidthVp).height(this.canvasHeightVp).clip(true)
      .accessibilityText(this.pinLabel)
      .onClick((event: ClickEvent) => { this.openAt(event.x,event.y); }, 8)
  }
}
