// Local scheduling estimates only. No account, cursor or content is retained.
export class PinmonyHomePaginationWindow {
  private scope: string = '';
  private startedAt: number = -1;
  private startedCount: number = 0;
  private readMs: number = 1800;
  private viewportAt: number = -1;
  private viewportLast: number = -1;
  private pinsPerSecond: number = 0;

  observe(scope: string, count: number, loading: boolean, failed: boolean, now: number): void {
    if (scope !== this.scope) {
      this.scope = scope;
      this.readMs = 1800;
      this.pause();
    }
    if (loading && this.startedAt < 0) {
      this.startedAt = now;
      this.startedCount = count;
    } else if (!loading && this.startedAt >= 0) {
      if (!failed && count > this.startedCount) {
        const elapsed: number = Math.min(6000, Math.max(600, now - this.startedAt));
        // React promptly to a slow page; decay gradually after faster pages.
        this.readMs = Math.max(elapsed, this.readMs * 0.75 + elapsed * 0.25);
      }
      this.startedAt = -1;
    }
  }

  viewport(last: number, now: number): void {
    const elapsed: number = now - this.viewportAt;
    const advanced: number = last - this.viewportLast;
    if (this.viewportAt >= 0 && elapsed >= 100 && elapsed <= 2000 && advanced > 0) {
      const rate: number = Math.min(24, advanced * 1000 / elapsed);
      this.pinsPerSecond = Math.max(rate, this.pinsPerSecond * 0.7 + rate * 0.3);
    } else if (elapsed > 2000 || advanced < 0) {
      this.pinsPerSecond = 0;
    }
    // Coalesce callbacks within one frame instead of losing their distance.
    if (this.viewportAt < 0 || elapsed >= 100 || advanced < 0) {
      this.viewportAt = now;
      this.viewportLast = last;
    }
  }

  reserve(visible: number, minimum: number, now: number): number {
    const rate: number = now - this.viewportAt <= 2000 ? this.pinsPerSecond : 0;
    return Math.min(36, Math.max(minimum, visible * 2, Math.ceil(rate * (this.readMs + 400) / 1000)));
  }

  diagnostic(now: number): string {
    const rate: number = now - this.viewportAt <= 2000 ? this.pinsPerSecond : 0;
    return ' readMs=' + Math.round(this.readMs).toString() + ' pinsPerSecond=' + rate.toFixed(1);
  }

  pause(): void {
    this.startedAt = -1;
    this.viewportAt = -1;
    this.viewportLast = -1;
    this.pinsPerSecond = 0;
  }
}
