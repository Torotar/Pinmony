import { PinmonyRuntimeLog } from 'common_foundation';

// Per-open, process-local timing only. Never accepts URLs, Pin IDs or content.
export class PinmonyDetailTrace {
  private id: number = 0;
  private startedAt: number = 0;
  private lastAt: number = 0;
  private seen: string[] = [];

  begin(id: number, clickedAt: number, event: string = 'click.accepted'): void {
    this.id = id; this.startedAt = clickedAt; this.lastAt = clickedAt; this.seen = [];
    this.mark(event);
  }

  current(): number { return this.id; }

  mark(event: string, once: boolean = true, duration: number = -1): void {
    if (!this.id || !/^[a-zA-Z0-9_.=-]{1,96}$/.test(event) || (once && this.seen.includes(event))) return;
    const now: number = Date.now();
    if (once) this.seen.push(event);
    PinmonyRuntimeLog.info('DetailJourney: openId=' + this.id.toString() + ' event=' + event +
      ' elapsedMs=' + Math.max(0, now - this.startedAt).toString() +
      ' gapMs=' + Math.max(0, now - this.lastAt).toString() +
      (duration >= 0 ? ' durationMs=' + duration.toString() : ''));
    this.lastAt = now;
  }

  close(): void { this.mark('cancelled'); this.id = 0; this.seen = []; }
}
