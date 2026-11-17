import { image } from '@kit.ImageKit';

export interface PinmonyDetailSiblingCover {
  identity: number;
  bitmap: image.PixelMap;
}

export interface PinmonyDetailSiblingMotionHost {
  ready: (step: number) => boolean;
  visible: () => boolean;
  pin: () => string;
  width: () => number;
  capture: () => Promise<image.PixelMap>;
  cover: (cover: PinmonyDetailSiblingCover | undefined) => void;
  frame: (current: number, previous: number) => void;
  animate: (duration: number, update: () => void, finish: () => void) => void;
  commit: (step: number) => void;
}

// Only presentation timing and one temporary capture; no extra live detail or navigation layer.
export class PinmonyDetailSiblingMotion {
  busy: boolean = false;
  private revision: number = 0;
  private timer: number = -1;
  private origin: string = '';
  private step: number = 0;
  private waiting: boolean = false;
  private committed: boolean = false;
  private capturePending: boolean = false;
  private bitmap: image.PixelMap | undefined = undefined;
  private readonly host: PinmonyDetailSiblingMotionHost;
  constructor(host: PinmonyDetailSiblingMotionHost) { this.host = host; }

  private release(bitmap: image.PixelMap): void { bitmap.release().catch((): void => {}); }

  cancel(): void {
    this.revision++;
    clearTimeout(this.timer); this.timer = -1;
    this.busy = false; this.waiting = false; this.committed = false; this.origin = ''; this.step = 0;
    const bitmap: image.PixelMap | undefined = this.bitmap;
    this.bitmap = undefined;
    this.host.cover(undefined);
    this.host.frame(0, 0);
    // Detach the Image before releasing its native pixel buffer. This callback owns only that buffer.
    if (bitmap) setTimeout((): void => this.release(bitmap), 32);
  }

  private skipCapture(revision: number): void {
    if (revision !== this.revision) return;
    const step: number = this.step;
    const valid: boolean = this.host.visible() && this.origin === this.host.pin() && this.host.ready(step);
    this.cancel();
    // Missing capture must not block navigation or expose an empty cover.
    if (valid) this.host.commit(step);
  }

  start(step: number): void {
    if (this.busy || (step !== 1 && step !== -1) || !this.host.visible() || !this.host.ready(step)) return;
    // Keep at most one native snapshot request outstanding, including after a timed-out capture.
    if (this.capturePending) { this.host.commit(step); return; }
    this.cancel();
    this.busy = true; this.step = step; this.origin = this.host.pin();
    this.host.frame(0, 0);
    const revision: number = this.revision;
    this.timer = setTimeout((): void => this.skipCapture(revision), 400);
    this.capturePending = true;
    this.capture(revision);
  }

  private async capture(revision: number): Promise<void> {
    let bitmap: image.PixelMap;
    try { bitmap = await this.host.capture(); } catch (_) { this.capturePending = false; this.skipCapture(revision); return; }
    this.capturePending = false;
    if (revision !== this.revision) { this.release(bitmap); return; }
    if (!this.host.visible() || this.origin !== this.host.pin() || !this.host.ready(this.step)) {
      this.release(bitmap); this.cancel(); return;
    }
    this.bitmap = bitmap;
    this.host.cover({ identity: revision, bitmap: bitmap });
  }

  covered(identity: number): void {
    if (identity !== this.revision || !this.busy || !this.bitmap || this.committed) return;
    if (!this.host.visible() || this.origin !== this.host.pin() || !this.host.ready(this.step)) { this.cancel(); return; }
    clearTimeout(this.timer);
    this.waiting = true;
    this.committed = true;
    this.timer = setTimeout((): void => { if (identity === this.revision) this.cancel(); }, 600);
    this.host.commit(this.step);
  }

  present(): void {
    if (!this.busy) return;
    if (!this.waiting) { this.cancel(); return; }
    if (this.host.pin() === this.origin) return;
    if (!this.host.visible() || this.host.width() <= 0) { this.cancel(); return; }
    clearTimeout(this.timer);
    this.waiting = false;
    const revision: number = this.revision;
    const pin: string = this.host.pin();
    const distance: number = this.step * this.host.width();
    this.host.frame(distance, 0);
    this.timer = setTimeout((): void => {
      if (revision !== this.revision) return;
      this.timer = -1;
      if (!this.host.visible() || pin !== this.host.pin()) { this.cancel(); return; }
      this.host.animate(280, (): void => this.host.frame(0, -distance), (): void => {
        if (revision === this.revision) this.cancel();
      });
    }, 16);
  }
}
