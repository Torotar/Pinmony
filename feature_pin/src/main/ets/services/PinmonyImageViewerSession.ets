import { UIContext } from '@kit.ArkUI';
import { PinmonyDetailAction, PinmonyDetailSnapshot } from '../models/PinmonyDetail';
import { ImageFlightRect, measureImageFlightOrigin } from './PinmonyImageTransition';
import { PinmonyRuntimeLog } from 'common_foundation';

export interface PinmonyImageViewerRequest {
  owner: string;
  detail: PinmonyDetailSnapshot;
  imageUrl: string;
  previewUrl: string;
  sourceId: () => string;
  sourceRadius: number;
  isCurrent: () => boolean;
  prepareReturn?: () => number;
  onReady: () => void;
  onClosed: () => void;
  onClose?: () => void;
  onImageChange?: (url: string) => void;
  actionsReady?: boolean;
  onAction?: (id: string, kind: string) => void;
  onDownload?: () => void;
  onSave?: () => void;
  onControlsChange?: (visible: boolean) => void;
}

// One presentation lifecycle for every Pin image and comment image entry point.
@Observed
export class PinmonyImageViewerSession {
  visible: boolean = false;
  closing: boolean = false;
  ready: boolean = false;
  revision: number = 0;
  request: PinmonyImageViewerRequest | undefined = undefined;
  origin: ImageFlightRect = { x: 0, y: 0, width: 0, height: 0 };
  private ui: UIContext | undefined = undefined;
  readonly hostId: string = 'pinmony-shared-image-viewer';

  open(request: PinmonyImageViewerRequest): boolean {
    if (this.visible || !request.imageUrl || !request.isCurrent()) return false;
    this.revision++;
    this.request = request;
    this.ready = false; this.closing = false; this.ui = undefined;
    this.origin = { x: 0, y: 0, width: 0, height: 0 };
    this.visible = true;
    PinmonyRuntimeLog.info('ViewerHost: stage=open');
    return true;
  }
  measure(ui: UIContext, revision: number): boolean {
    if (!this.current(revision)) return false;
    this.ui = ui;
    this.origin = measureImageFlightOrigin(ui, this.request!.sourceId(), this.hostId);
    PinmonyRuntimeLog.info('ViewerHost: stage=measured');
    return true;
  }
  current(revision: number): boolean {
    return this.visible && revision === this.revision && !!this.request && this.request.isCurrent();
  }
  rendered(revision: number): void {
    if (!this.current(revision) || this.closing || this.ready) return;
    this.ready = true; this.request!.onReady();
    PinmonyRuntimeLog.info('ViewerHost: stage=rendered');
  }
  close(owner: string = ''): void {
    if (!this.visible || !this.request || owner && owner !== this.request.owner || this.closing) return;
    const request: PinmonyImageViewerRequest = this.request;
    if (!request.isCurrent() || !this.ready || !this.ui) { this.cancel(owner); return; }
    const origin: ImageFlightRect = measureImageFlightOrigin(this.ui, request.sourceId(), this.hostId);
    const shift: number = request.prepareReturn?.() || 0;
    this.origin = { x: origin.x, y: origin.y + shift, width: origin.width, height: origin.height };
    this.closing = true;
    request.onClose?.();
    PinmonyRuntimeLog.info('ViewerHost: stage=closing');
  }
  finish(revision: number): void {
    if (revision !== this.revision || !this.closing) return;
    this.cancel();
  }
  cancel(owner: string = ''): void {
    if (!this.request || owner && owner !== this.request.owner) return;
    const request: PinmonyImageViewerRequest = this.request;
    this.revision++; this.visible = false; this.closing = false; this.ready = false;
    this.request = undefined; this.ui = undefined;
    request.onClosed();
    PinmonyRuntimeLog.info('ViewerHost: stage=closed');
  }
  hostGone(revision: number): void {
    if (revision === this.revision) this.cancel();
  }
}
