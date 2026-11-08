import { PinmonyImageViewer } from './PinmonyImageViewer';
import { PinmonyImageViewerSession } from '../services/PinmonyImageViewerSession';
import { PinmonyRuntimeLog } from 'common_foundation';

@Component
export struct PinmonyImageViewerHost {
  @ObjectLink session: PinmonyImageViewerSession;
  @Prop active: boolean = true;
  @State private measured: boolean = false;
  private hostRevision: number = 0;

  aboutToAppear(): void { this.hostRevision = this.session.revision; }
  aboutToDisappear(): void { this.session.hostGone(this.hostRevision); }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.session.request && this.measured) {
        PinmonyImageViewer({ detail: this.session.request.detail,
          imageUrl: this.session.request.imageUrl, previewUrl: this.session.request.previewUrl,
          origin: this.session.origin, originRadius: this.session.request.sourceRadius,
          closing: this.session.closing, active: this.active,
          actionsReady: this.session.request.actionsReady || false,
          onReady: () => this.session.rendered(this.hostRevision),
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
