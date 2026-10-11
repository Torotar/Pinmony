import { PinmonyTaskRegistry, PinmonyRuntimeLog } from 'common_foundation';
class ReadinessWaiter {
  readonly current: () => boolean;
  readonly ready: () => boolean;
  readonly failed: () => boolean;
  readonly resolve: (ready: boolean) => void;
  deadline: number = -1;
  constructor(current: () => boolean, ready: () => boolean, failed: () => boolean, resolve: (ready: boolean) => void) {
    this.current = current; this.ready = ready; this.failed = failed; this.resolve = resolve;
  }
}
// State commits wake waiters; each intent owns one deadline, with no interval polling.
export class PinmonyReadinessGate {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private readonly waiters: Set<ReadinessWaiter> = new Set<ReadinessWaiter>();
  wait(current: () => boolean, ready: () => boolean, failed: () => boolean, deadlineMs: number): Promise<boolean> {
    return new Promise<boolean>((resolve: (ready: boolean) => void): void => {
      const waiter: ReadinessWaiter = new ReadinessWaiter(current, ready, failed, resolve);
      this.waiters.add(waiter);
      waiter.deadline = this.tasks.timeout((): void => this.finish(waiter, false, 'timeout'), deadlineMs);
      this.check(waiter);
    });
  }
  private finish(waiter: ReadinessWaiter, ready: boolean, outcome: string): void {
    if (!this.waiters.delete(waiter)) return;
    this.tasks.cancelTimeout(waiter.deadline);
    PinmonyRuntimeLog.info('Readiness: outcome=' + outcome + ' pending=' + this.waiters.size.toString());
    waiter.resolve(ready);
  }
  private check(waiter: ReadinessWaiter): void {
    try {
      if (!waiter.current()) this.finish(waiter, false, 'stale');
      else if (waiter.ready()) this.finish(waiter, true, 'ready');
      else if (waiter.failed()) this.finish(waiter, false, 'failure');
    } catch (_) { this.finish(waiter, false, 'failure'); }
  }
  notify(): void { this.waiters.forEach((waiter: ReadinessWaiter): void => this.check(waiter)); }
  cancel(): void { this.waiters.forEach((waiter: ReadinessWaiter): void => this.finish(waiter, false, 'cancel')); this.tasks.invalidate(); }
  pendingCount(): number { return this.waiters.size; }
}
