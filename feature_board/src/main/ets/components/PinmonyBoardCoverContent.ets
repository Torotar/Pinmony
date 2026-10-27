import { PinmonyActionNotice } from 'common_ui';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardCoverState, PinmonyBoardPin, PinmonyBoardCoverCrop } from '../models/PinmonyBoardDetail';
import { boardCoverCrop } from '../services/PinmonyBoardCoverGeometry';

@Component
export struct PinmonyBoardCoverContent {
  @StorageLink('pinmonyLanguage') private uiLanguage: string = 'zh';
  @Prop @Watch('syncCrop') cover: PinmonyBoardCoverState;
  @Prop locked: boolean = false;
  onAction: (action: string, value: string) => void = () => {};
  onReady: (ready: boolean) => void = () => {};
  @State private frameSide: number = 300;
  @State private cropLeft: number = 0;
  @State private cropTop: number = 0;
  @State private previewFailed: boolean = false;
  @State private loaded: boolean = false;
  @State private previewRevision: number = 0;
  private previewId: string = '';
  private startLeft: number = 0;
  private startTop: number = 0;
  private dragging: boolean = false;
  private copy(key: string): string { return PinmonyI18n.text(key,this.uiLanguage); }
  private selected(): PinmonyBoardPin | undefined { return this.cover.pins.find((p: PinmonyBoardPin): boolean => p.id === this.cover.selected?.pinId); }
  private previewPins(): PinmonyBoardPin[] { const pin: PinmonyBoardPin | undefined = this.selected();return pin ? [pin] : []; }
  aboutToAppear(): void { this.syncCrop(); }
  private syncCrop(): void {
    const pin: PinmonyBoardPin | undefined = this.selected();
    if(this.previewId !== (pin?.id || '')){this.previewId = pin?.id || '';this.loaded = false;this.previewFailed = false;this.onReady(false);}
    if(!this.dragging){this.cropLeft = this.cover.selected?.cropX || 0;this.cropTop = this.cover.selected?.cropY || 0;}
  }
  private displayScale(): number { const pin: PinmonyBoardPin | undefined = this.selected();return pin ? this.frameSide/Math.min(pin.imageWidth,pin.imageHeight) : 1; }
  private move(dx: number, dy: number, commit: boolean): void {
    const pin: PinmonyBoardPin | undefined = this.selected();if(!pin || this.locked || this.cover.status === 'uncertain' || !this.loaded)return;
    const crop: PinmonyBoardCoverCrop = boardCoverCrop(pin,this.startLeft-dx/this.displayScale(),this.startTop-dy/this.displayScale());
    this.cropLeft = crop.cropX;this.cropTop = crop.cropY;
    if(commit)this.onAction('coverCrop',JSON.stringify(crop));
  }
  @Builder
  private preview() {
    Stack({alignContent:Alignment.TopStart}) {
      ForEach(this.previewPins(),(pin: PinmonyBoardPin) => {
        Image(pin.previewImageUrl || pin.imageUrl)
          .width(pin.imageWidth*this.displayScale()).height(pin.imageHeight*this.displayScale())
          .objectFit(ImageFit.Fill).position({x:-this.cropLeft*this.displayScale(),y:-this.cropTop*this.displayScale()})
          .draggable(false)
          .onComplete((): void => {if(this.previewId === pin.id){this.loaded = true;this.previewFailed = false;this.onReady(!this.dragging);}})
          .onError((): void => {if(this.previewId === pin.id){this.loaded = false;this.previewFailed = true;this.onReady(false);}})
      },(pin: PinmonyBoardPin): string => pin.id+':'+this.previewRevision)
      if(this.selected() && !this.loaded && !this.previewFailed) { LoadingProgress().width(32).height(32).align(Alignment.Center) }
    }.width('100%').height(this.frameSide).clip(true).borderRadius(20).backgroundColor($r('app.color.surface_muted'))
      .onAreaChange((_old: Area, area: Area): void => {const side: number = Number(area.width);if(side > 0)this.frameSide = side;})
      .gesture(PanGesture({fingers:1,direction:PanDirection.All})
        .onActionStart((): void => {this.dragging = true;this.startLeft = this.cropLeft;this.startTop = this.cropTop;this.onReady(false);})
        .onActionUpdate((event: GestureEvent): void => {this.move(event.offsetX,event.offsetY,false);})
        .onActionEnd((event: GestureEvent): void => {this.dragging = false;this.move(event.offsetX,event.offsetY,true);this.onReady(this.loaded);})
        .onActionCancel((): void => {this.dragging = false;this.cropLeft = this.cover.selected?.cropX || 0;this.cropTop = this.cover.selected?.cropY || 0;this.onReady(this.loaded);}))
      .accessibilityText(this.copy('pm_board_cover_drag'))
  }
  build() {
    Column({space:16}) {
      if(this.selected()) {
        this.preview()
        Text(this.copy(this.previewFailed ? 'pm_board_cover_image_failed' : 'pm_board_cover_drag'))
          .fontSize(14).fontColor($r('app.color.secondary_text')).width('100%').textAlign(TextAlign.Center)
      }
      if(this.cover.status === 'saving' || this.cover.status === 'verifying') {
        Row({space:8}) {
          LoadingProgress().width(24).height(24)
          Text(this.copy(this.cover.status === 'saving' ? 'pm_board_cover_saving' : 'pm_board_cover_verifying')).fontColor($r('app.color.secondary_text'))
        }
      }
      if(this.cover.error) {
        PinmonyActionNotice({ message: PinmonyI18n.render(this.cover.error,this.uiLanguage),
          actionText: this.copy(this.cover.status === 'uncertain' ? 'pm_board_cover_check' : 'pm_retry_b8784c8d'),
          actionEnabled: !this.locked && !this.cover.loading,
          onAction: (): void => {this.onAction(this.cover.status === 'uncertain' ? 'coverCheck' : 'coverRetry','');} })
      }
      if(this.cover.pins.length > 0) {
      Text(this.copy('pm_board_cover_pins')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_text')).width('100%')
      Flex({wrap:FlexWrap.Wrap,justifyContent:FlexAlign.Start,alignItems:ItemAlign.Start}) {
        ForEach(this.cover.pins,(pin: PinmonyBoardPin) => {
          Image(pin.previewImageUrl || pin.imageUrl).width('31%').aspectRatio(pin.imageWidth/pin.imageHeight).constraintSize({maxHeight:200})
            .objectFit(ImageFit.Cover).borderRadius(16).draggable(false).margin({right:'2%',bottom:12})
            .border({width:this.cover.selected?.pinId === pin.id ? 3 : 0,color:$r('app.color.primary_text')})
            .enabled(!this.locked && this.cover.status !== 'uncertain')
            .onClick((): void => {
              if(this.cover.selected?.pinId !== pin.id || this.previewFailed)this.onReady(false);
              if(this.cover.selected?.pinId === pin.id && this.previewFailed){this.previewRevision++;this.previewFailed = false;this.loaded = false;}
              this.onAction('coverSelect',pin.id);
            })
            .accessibilityText(this.copy('pm_board_cover_choose')).accessibilitySelected(this.cover.selected?.pinId === pin.id)
        },(pin: PinmonyBoardPin): string => pin.id+':'+(this.cover.selected?.pinId === pin.id)+':'+this.uiLanguage)
      }.width('100%')
      }
      if(this.cover.loading) { LoadingProgress().width(28).height(28) }
      if(this.cover.hasMore && !this.cover.loading && !this.cover.error && !this.locked && this.cover.status !== 'uncertain') {
        Row().width('100%').height(1)
          .onVisibleAreaChange([0,1],(visible: boolean,ratio: number): void => {if(visible && ratio > 0)this.onAction('coverMore','');})
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
