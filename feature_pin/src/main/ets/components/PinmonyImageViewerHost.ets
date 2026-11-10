import { PinmonyImageViewer } from './PinmonyImageViewer';
import { PinmonyImageViewerSession } from '../services/PinmonyImageViewerSession';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyViewerSystemBars } from '../services/PinmonyViewerSystemBars';
import { common } from '@kit.AbilityKit';

@Component
export struct PinmonyImageViewerHost {
  @ObjectLink session: PinmonyImageViewerSession;
  @Prop active: boolean = true;
  @State private measured: boolean = false;
  private hostRevision: number = 0;
  private systemBarOwner: number = 0;
  private systemBarContext: common.Context | undefined = undefined;

  aboutToAppear(): void {
    this.hostRevision = this.session.revision;
    const context = this.getUIContext().getHostContext();
    this.systemBarContext = context;
    if (context) this.systemBarOwner = PinmonyViewerSystemBars.acquire(context);
  }
  aboutToDisappear(): void {
    const context: common.Context | undefined = this.systemBarContext;
    if (context) PinmonyViewerSystemBars.release(this.systemBarOwner, context);
    this.systemBarOwner = 0;
    this.systemBarContext = undefined;
    this.session.hostGone(this.hostRevision);
  }

  private onViewerTransition(expanded: number): void {
    if (!this.session.current(this.hostRevision)) return;
    const context: common.Context | undefined = this.systemBarContext;
    if (expanded === 0 && this.systemBarOwner !== 0 && context) {
      PinmonyViewerSystemBars.release(this.systemBarOwner, context);
      this.systemBarOwner = 0;
    }
    this.session.transition(this.hostRevision, expanded);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.session.request && this.measured) {
        PinmonyImageViewer({ detail: this.session.request.detail,
          imageUrl: this.session.request.imageUrl, previewUrl: this.session.request.previewUrl,
          origin: this.session.origin, originRadius: this.session.request.sourceRadius,
          closing: this.session.closing, active: this.active,
          actionsReady: this.session.request.actionsReady || false,
          onReady: () => this.session.rendered(this.hostRevision),
          onTransition: (expanded: number) => this.onViewerTransition(expanded),
          onClosed: () => this.session.finish(this.hostRevision),
          onClose: () => this.session.close(),
          onImageChange: this.session.request.onImageChange,
          onAction: this.session.request.onAction, onDownload: this.session.request.onDownload,
          onSave: this.session.request.onSave, onControlsChange: this.session.request.onControlsChange })
      }
    }.width('100%').height('100%').id(this.session.hostId)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onAreaChange((_old: Area, area: Area) => {
        if (!this.measured && this.session.measure(this.getUIContext(), this.hostRevision)) this.measured = true;
        PinmonyRuntimeLog.info('ViewerHost: stage=viewport width=' + Math.round(Number(area.width)) +
          ' height=' + Math.round(Number(area.height)));
      })
  }
}
