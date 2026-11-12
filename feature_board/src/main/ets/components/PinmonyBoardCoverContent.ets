import { PinmonyActionNotice, PinmonyCdnImage } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardCoverState, PinmonyBoardPin, PinmonyBoardCoverCrop } from '../models/PinmonyBoardDetail';
import { boardCoverCrop } from '../services/PinmonyBoardCoverGeometry';

interface PinmonyBoardCoverPreviewSource {
  pin: PinmonyBoardPin;
  key: string;
  cropLeft: number;
  cropTop: number;
  cropWidth: number;
  cropHeight: number;
}

@Component
export struct PinmonyBoardCoverContent {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop @Watch('syncCrop') cover: PinmonyBoardCoverState;
  @Prop locked: boolean = false;
  @Prop contentHeightLimit: number = 0;
  @Prop pinsHeightLimit: number = 0;
  @Prop splitLayout: boolean = false;
  pinsScroller: Scroller = new Scroller();
  onPinsScroll: (offset: number) => void = () => {};
  onAction: (action: string, value: string) => void = () => {};
  onReady: (ready: boolean) => void = () => {};
  onPreviewLoading: (loading: boolean) => void = () => {};
  @State private frameSide: number = 300;
  @State private cropLeft: number = 0;
  @State private cropTop: number = 0;
  @State private cropWidth: number = 1;
  @State private cropHeight: number = 1;
  @State private previewFailed: boolean = false;
  @State private loaded: boolean = false;
  @State private previewRevision: number = 0;
  @State private captionHeight: number = 20;
  @State private pinsTitleHeight: number = 28;
  @State private retainedPreview: PinmonyBoardCoverPreviewSource | undefined = undefined;
  private previewPin: PinmonyBoardPin | undefined = undefined;
  private previewId: string = '';
  private startLeft: number = 0;
  private startTop: number = 0;
  private dragging: boolean = false;
  private dragSourceKey: string = '';
  private previewActive: boolean = false;
  private copy(key: string): string { return PinmonyI18n.text(key,this.uiLanguage); }
  private selected(): PinmonyBoardPin | undefined { return this.cover.pins.find((p: PinmonyBoardPin): boolean => p.id === this.cover.selected?.pinId); }
  private sourceKey(pin: PinmonyBoardPin): string { return JSON.stringify([pin.id,pin.previewImageUrl || pin.imageUrl,pin.imageWidth,pin.imageHeight,this.previewRevision]); }
  private previewPins(): PinmonyBoardCoverPreviewSource[] {
    const pin: PinmonyBoardPin | undefined = this.selected();
    const sources: PinmonyBoardCoverPreviewSource[] = [];
    if(this.retainedPreview && pin && this.retainedPreview.key !== this.sourceKey(pin))sources.push(this.retainedPreview);
    if(pin)sources.push({pin:pin,key:this.sourceKey(pin),cropLeft:this.cropLeft,cropTop:this.cropTop,cropWidth:this.cropWidth,cropHeight:this.cropHeight});
    return sources;
  }
  aboutToAppear(): void { this.previewActive = true;this.syncCrop(); }
  aboutToDisappear(): void {
    this.previewActive = false;this.dragging = false;this.dragSourceKey = '';this.previewId = '';this.previewRevision++;
    this.retainedPreview = undefined;this.previewPin = undefined;
    this.onReady(false);this.onPreviewLoading(false);
  }
  private canDrag(): boolean {
    const pin: PinmonyBoardPin | undefined = this.selected();
    return this.previewActive && !!pin && this.previewId === this.sourceKey(pin) && this.loaded && !this.locked && !this.cover.loading &&
      !['uncertain','saving','verifying'].includes(this.cover.status);
  }
  private previewComplete(key: string, success: boolean): void {
    const pin: PinmonyBoardPin | undefined = this.selected();
    if(!this.previewActive || !pin || key !== this.previewId || key !== this.sourceKey(pin))return;
    this.loaded = success;this.previewFailed = !success;this.onPreviewLoading(false);this.onReady(this.canDrag() && !this.dragging);
    if(success)this.retainedPreview = undefined;
  }
  private syncCrop(): void {
    if(!this.previewActive){this.onReady(false);this.onPreviewLoading(false);return;}
    const pin: PinmonyBoardPin | undefined = this.selected();
    const key: string = pin ? this.sourceKey(pin) : '';
    if(this.previewId !== key){
      if(this.loaded && this.previewPin)this.retainedPreview = {pin:this.previewPin,key:this.previewId,
        cropLeft:this.cropLeft,cropTop:this.cropTop,cropWidth:this.cropWidth,cropHeight:this.cropHeight};
      this.previewPin = pin ? JSON.parse(JSON.stringify(pin)) as PinmonyBoardPin : undefined;
      this.previewId = key;this.dragging = false;this.dragSourceKey = '';this.loaded = false;this.previewFailed = false;this.onReady(false);
    }
    if(this.locked || this.cover.loading || ['uncertain','saving','verifying'].includes(this.cover.status)){this.dragging = false;this.dragSourceKey = '';this.onReady(false);}
    if(!pin)this.retainedPreview = undefined;
    if(this.retainedPreview?.key === key){this.loaded = true;this.retainedPreview = undefined;}
    this.onPreviewLoading(!!pin && !this.loaded && !this.previewFailed && !this.retainedPreview);
    if(!this.dragging){this.cropLeft = this.cover.selected?.cropX || 0;this.cropTop = this.cover.selected?.cropY || 0;this.cropWidth = this.cover.selected?.width || 1;this.cropHeight = this.cover.selected?.height || 1;}
    this.onReady(this.canDrag() && !this.dragging);
  }
  private displayScale(): number { return Math.max(this.frameSide/this.cropWidth,this.frameSide*3/5/this.cropHeight); }
  private displayLeft(): number { return (this.frameSide-this.cropWidth*this.displayScale())/2-this.cropLeft*this.displayScale(); }
  private displayTop(): number {
    return (this.frameSide*3/5-this.cropHeight*this.displayScale())/2-this.cropTop*this.displayScale();
  }
  private previewScale(source: PinmonyBoardCoverPreviewSource): number {
    const frozen: PinmonyBoardCoverPreviewSource = this.retainedPreview?.key === source.key ? this.retainedPreview : source;
    return source.key === this.previewId ? this.displayScale() : Math.max(this.frameSide/frozen.cropWidth,this.frameSide*3/5/frozen.cropHeight);
  }
  private previewLeft(source: PinmonyBoardCoverPreviewSource): number {
    const scale: number = this.previewScale(source);
    const frozen: PinmonyBoardCoverPreviewSource = this.retainedPreview?.key === source.key ? this.retainedPreview : source;
    return source.key === this.previewId ? this.displayLeft() : (this.frameSide-frozen.cropWidth*scale)/2-frozen.cropLeft*scale;
  }
  private previewTop(source: PinmonyBoardCoverPreviewSource): number {
    const scale: number = this.previewScale(source);
    const frozen: PinmonyBoardCoverPreviewSource = this.retainedPreview?.key === source.key ? this.retainedPreview : source;
    return source.key === this.previewId ? this.displayTop() : (this.frameSide*3/5-frozen.cropHeight*scale)/2-frozen.cropTop*scale;
  }
  private beginDrag(): void {
    const pin: PinmonyBoardPin | undefined = this.selected();if(!pin || !this.canDrag())return;
    const crop: PinmonyBoardCoverCrop = boardCoverCrop(pin,0,0,5/3);
    // Preserve the visible center when an older square cover is first moved.
    this.startLeft = this.cropLeft+(this.cropWidth-crop.width)/2;
    this.startTop = this.cropTop+(this.cropHeight-crop.height)/2;
    this.dragging = true;this.dragSourceKey = this.sourceKey(pin);this.onReady(false);
  }
  private move(dx: number, dy: number, commit: boolean): void {
    const pin: PinmonyBoardPin | undefined = this.selected();
    if(!pin || !this.dragging || !this.canDrag() || this.dragSourceKey !== this.sourceKey(pin) || !Number.isFinite(dx) || !Number.isFinite(dy))return;
    const target: PinmonyBoardCoverCrop = boardCoverCrop(pin,0,0,5/3);
    const scale: number = Math.max(this.frameSide/target.width,this.frameSide*3/5/target.height);
    const crop: PinmonyBoardCoverCrop = boardCoverCrop(pin,this.startLeft-dx/scale,this.startTop-dy/scale,5/3);
    this.cropLeft = crop.cropX;this.cropTop = crop.cropY;this.cropWidth = crop.width;this.cropHeight = crop.height;
    if(commit)this.onAction('coverCrop',JSON.stringify(crop));
  }
  private finishDrag(dx: number, dy: number): void {
    const pin: PinmonyBoardPin | undefined = this.selected();
    if(!pin || !this.dragging || !this.canDrag() || this.dragSourceKey !== this.sourceKey(pin) || !Number.isFinite(dx) || !Number.isFinite(dy)) {
      this.cancelDrag();return;
    }
    this.move(dx,dy,true);this.dragging = false;this.dragSourceKey = '';this.onReady(this.canDrag());
  }
  private cancelDrag(): void {
    this.dragging = false;this.dragSourceKey = '';this.syncCrop();this.onReady(this.canDrag());
  }
  private resizePreview(width: number): void {
    if(!Number.isFinite(width) || width <= 0 || width === this.frameSide)return;
    if(this.dragging)this.cancelDrag();
    this.frameSide = width;
  }

  private previewWidthLimit(): number | undefined {
    if (!Number.isFinite(this.contentHeightLimit) || this.contentHeightLimit <= 0) return undefined;
    // Keep the 5:3 crop intact and leave room for the caption and its 16vp gap.
    return Math.max(1, this.contentHeightLimit - this.captionHeight - 16) * 5 / 3;
  }
  @Builder
  private preview() {
    Stack({alignContent:Alignment.TopStart}) {
      ForEach(this.previewPins(),(source: PinmonyBoardCoverPreviewSource) => {
        PinmonyCdnImage({url:source.pin.previewImageUrl || source.pin.imageUrl,fit:ImageFit.Fill,
          onDecoded:(): void => {this.previewComplete(source.key,true);},
          onFailure:(): void => {this.previewComplete(source.key,false);}})
          .width(source.pin.imageWidth*this.previewScale(source)).height(source.pin.imageHeight*this.previewScale(source))
          .position({x:this.previewLeft(source),y:this.previewTop(source)})
          .opacity(source.key === this.previewId && !this.loaded && !!this.retainedPreview ? 0 : 1)
          .draggable(false)
      },(source: PinmonyBoardCoverPreviewSource): string => source.key)
    }.width('100%').aspectRatio(5/3).clip(true).borderRadius(20).backgroundColor($r('app.color.surface_muted'))
      .constraintSize({ maxWidth: this.previewWidthLimit() }).align(Alignment.Center)
      .onAreaChange((_old: Area, area: Area): void => {this.resizePreview(Number(area.width));})
      .gesture(PanGesture({fingers:1,direction:PanDirection.All})
        .onActionStart((): void => {this.beginDrag();})
        .onActionUpdate((event: GestureEvent): void => {this.move(event.offsetX,event.offsetY,false);})
        .onActionEnd((event: GestureEvent): void => {this.finishDrag(event.offsetX,event.offsetY);})
        .onActionCancel((): void => {this.cancelDrag();}))
      .accessibilityText(this.copy('pm_board_cover_drag'))
  }
  private coverLayoutColumns(): number {
    // The adjustment-only flow has no candidate list and keeps the full preview width.
    return this.splitLayout && !this.cover.adjusting ? 2 : 1;
  }
  @Builder
  private coverPreview() {
    Column({space:16}) {
      if(this.selected()) {
        this.preview()
        Text(this.copy(this.previewFailed ? 'pm_board_cover_image_failed' : 'pm_board_cover_drag'))
          .fontSize(14).fontColor($r('app.color.secondary_text')).width('100%').textAlign(TextAlign.Center)
          .onAreaChange((_old: Area, area: Area): void => {
            const height: number = Number(area.height);
            if (Number.isFinite(height) && height > 0) this.captionHeight = height;
          })
      } else {
        Stack() {}
          .width('100%').aspectRatio(5/3).borderRadius(20)
          .backgroundColor($r('app.color.surface_muted'))
          .constraintSize({ maxWidth: this.previewWidthLimit() }).align(Alignment.Center)
      }
      if(this.cover.status === 'saving' || this.cover.status === 'verifying') {
        Row({space:8}) {
          LoadingProgress().color($r('app.color.accent')).width(24).height(24)
          Text(this.copy(this.cover.status === 'saving' ? 'pm_board_cover_saving' : 'pm_board_cover_verifying')).fontColor($r('app.color.secondary_text'))
        }
      }
      if(this.cover.error) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.cover.error,this.uiLanguage),
          actionText: this.copy(this.cover.status === 'uncertain' ? 'pm_board_cover_check' : 'pm_retry_b8784c8d'),
          actionEnabled: !this.locked && !this.cover.loading,
          onAction: (): void => {this.onAction(this.cover.status === 'uncertain' ? 'coverCheck' : 'coverRetry','');} })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  private candidate(pin: PinmonyBoardPin) {
    PinmonyCdnImage({url:pin.previewImageUrl || pin.imageUrl,fit:ImageFit.Cover,viewportOnly:true})
      .width('100%').aspectRatio(pin.imageWidth/pin.imageHeight).borderRadius(16).clip(true).draggable(false)
      .border({width:3,color:this.cover.selected?.pinId === pin.id ? $r('app.color.primary_text') : Color.Transparent})
      .enabled(!this.locked && this.cover.status !== 'uncertain')
      .onClick((): void => {
        if(this.cover.selected?.pinId !== pin.id || this.previewFailed)this.onReady(false);
        if(this.cover.selected?.pinId === pin.id && this.previewFailed){this.previewRevision++;this.syncCrop();}
        this.onAction('coverSelect',pin.id);
      })
      .accessibilityText(this.copy('pm_board_cover_choose')).accessibilitySelected(this.cover.selected?.pinId === pin.id)
  }
  @Builder
  private candidateFooter() {
      if(!this.cover.adjusting && this.cover.hasMore && !this.cover.loading && !this.cover.error && !this.locked && this.cover.status !== 'uncertain') {
        Row().width('100%').height(1)
          .onVisibleAreaChange([0,1],(visible: boolean,ratio: number): void => {if(visible && ratio > 0)this.onAction('coverMore','');})
      }
  }
  private candidateColumns(): number {
    return this.coverLayoutColumns() === 2 ? 3 : 2;
  }
  private candidateHeight(): number | undefined {
    return this.coverLayoutColumns() === 2 ? Math.max(1,this.pinsHeightLimit-this.pinsTitleHeight-16) : undefined;
  }
  @Builder
  private coverCandidates() {
    Column({space:16}) {
      if(!this.cover.adjusting) {
        Text(this.copy('pm_board_cover_pins')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
          .onAreaChange((_old: Area,area: Area): void => {
            const height: number = Number(area.height);
            if(Number.isFinite(height) && height > 0)this.pinsTitleHeight = height;
          })
        Refresh({refreshing:this.cover.refreshing === true}) {
        WaterFlow({scroller:this.coverLayoutColumns() === 2 ? this.pinsScroller : undefined,footer:this.candidateFooter}) {
          ForEach(this.cover.pins,(pin: PinmonyBoardPin) => {
            FlowItem() { this.candidate(pin) }.width('100%')
          },(pin: PinmonyBoardPin): string => pin.id)
        }.width('100%').height(this.candidateHeight())
          .columnsTemplate(this.candidateColumns() === 3 ? '1fr 1fr 1fr' : '1fr 1fr').columnsGap(12).rowsGap(12)
          .padding({bottom:this.coverLayoutColumns() === 2 ? 0 : 24}).scrollBar(BarState.Off)
          .constraintSize({minHeight:Math.min(120,this.candidateHeight() ?? 120)}).edgeEffect(EdgeEffect.Spring,{alwaysEnabled:true})
          .nestedScroll({scrollForward:NestedScrollMode.SELF_FIRST,scrollBackward:NestedScrollMode.SELF_FIRST})
          .onDidScroll((): void => {
            if(this.coverLayoutColumns() === 2)this.onPinsScroll(this.pinsScroller.currentOffset().yOffset);
          })
        }.width('100%').height(this.candidateHeight())
          .pullToRefresh(!this.locked && !this.cover.loading && this.cover.status !== 'uncertain')
          .onRefreshing((): void => {this.onAction('coverRefresh','');})
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build() {
    GridRow({columns:this.coverLayoutColumns(),gutter:{x:20,y:16}}) {
      GridCol({span:1}) { this.coverPreview() }
      if(!this.cover.adjusting) {
        GridCol({span:1}) {
          this.coverCandidates()
        }
      }
    }.width('100%').alignItems(ItemAlign.Start)
  }
}
