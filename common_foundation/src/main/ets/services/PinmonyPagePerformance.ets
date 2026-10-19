import { PinmonyRuntimeLog } from './PinmonyRuntimeLog';

export type PinmonyPageStage = 'visible' | 'cache-visible' | 'document-ready' | 'content-ready';
export type PinmonyPageCounter = 'read' | 'cancel';
export type PinmonySecondaryPage = 'detail' | 'board' | 'chat' | 'share';
export type PinmonySecondaryStage = 'content-ready' | 'image-ready' | 'component-ready';
class SecondarySample {
  readonly identity: string;
  readonly sequence: number;
  readonly started: number;
  readonly stages: Set<string> = new Set<string>();
  constructor(identity: string, sequence: number, started: number) { this.identity = identity; this.sequence = sequence; this.started = started; }
}
class PageSample {
  readonly reason: 'tab' | 'return';
  readonly started: number;
  readonly tab: number;
  readonly sequence: number;
  readonly stages: Set<string> = new Set<string>();
  reads: number = 0;
  cacheRestored: boolean = false;
  cancelledTasks: number = 0;
  constructor(tab: number, sequence: number, started: number, reason: 'tab' | 'return') {
    this.tab = tab; this.sequence = sequence; this.started = started; this.reason = reason;
  }
}
// Product-level timings contain enums and numbers only, never routes or identities.
export class PinmonyPagePerformance {
  private active: PageSample | undefined = undefined;
  private sequence: number = 0;
  private readonly durations: Map<string, number[]> = new Map<string, number[]>();
  private readonly secondary: Map<PinmonySecondaryPage, SecondarySample> = new Map<PinmonySecondaryPage, SecondarySample>();
  private readonly now: () => number;
  private readonly log: (message: string) => void;
  constructor(now: () => number = (): number => Date.now(), log: (message: string) => void =
    (message: string): void => PinmonyRuntimeLog.info(message)) { this.now = now; this.log = log; }
  begin(tab: number, reason: 'tab' | 'return'): void {
    if (!Number.isInteger(tab) || tab < 0 || tab > 3) return;
    this.active = new PageSample(tab, ++this.sequence, this.now(), reason);
    this.log('PagePerf: event=begin tab=' + tab + ' sequence=' + this.sequence + ' reason=' + reason);
  }
  mark(tab: number, stage: PinmonyPageStage): void {
    const sample: PageSample | undefined = this.active;
    if (!sample || sample.tab !== tab || sample.stages.has(stage) || sample.cacheRestored && stage === 'document-ready') return;
    sample.stages.add(stage);
    const elapsed: number = Math.max(0, this.now() - sample.started);
    const key: string = tab + ':' + stage;
    let history: number[] | undefined = this.durations.get(key);
    if (!history) { history = []; this.durations.set(key, history); }
    if (history.length >= 64) history.shift();
    history.push(elapsed);
    const ordered: number[] = history.slice().sort((a: number, b: number): number => a - b);
    this.log('PagePerf: event=' + stage + ' tab=' + tab + ' sequence=' + sample.sequence + ' elapsedMs=' + elapsed +
      ' samples=' + ordered.length + ' p50Ms=' + ordered[Math.ceil(ordered.length * 0.5) - 1] +
      ' p95Ms=' + ordered[Math.ceil(ordered.length * 0.95) - 1]);
  }
  restoreHome(): boolean {
    if (!this.active || this.active.tab !== 0 || this.active.reason !== 'return' || this.active.stages.has('content-ready')) return false;
    this.active.cacheRestored = true;
    this.mark(0, 'visible');
    this.mark(0, 'cache-visible');
    this.mark(0, 'content-ready');
    return true;
  }
  count(tab: number, event: PinmonyPageCounter, count: number = 1): void {
    const sample: PageSample | undefined = this.active;
    if (!sample || sample.tab !== tab) return;
    if (!Number.isInteger(count) || count <= 0) return;
    if (event === 'read') sample.reads += count;
    else sample.cancelledTasks += count;
    this.log('PagePerf: event=' + event + ' tab=' + tab + ' sequence=' + sample.sequence + ' reads=' + sample.reads + ' cancelledTasks=' + sample.cancelledTasks);
  }
  beginSecondary(page: PinmonySecondaryPage, identity: string): void {
    if (!identity) return;
    this.secondary.set(page, new SecondarySample(identity, ++this.sequence, this.now()));
    this.log('PagePerf: event=begin page=' + page + ' sequence=' + this.sequence);
  }
  markSecondary(page: PinmonySecondaryPage, identity: string, stage: PinmonySecondaryStage): void {
    const sample: SecondarySample | undefined = this.secondary.get(page);
    if (!sample || sample.identity !== identity || sample.stages.has(stage)) return;
    sample.stages.add(stage);
    const elapsed: number = Math.max(0, this.now() - sample.started), key: string = page + ':' + stage;
    let history: number[] | undefined = this.durations.get(key);
    if (!history) { history = []; this.durations.set(key, history); }
    if (history.length >= 64) history.shift();
    history.push(elapsed);
    const ordered: number[] = history.slice().sort((a: number, b: number): number => a - b);
    this.log('PagePerf: event=' + stage + ' page=' + page + ' sequence=' + sample.sequence + ' elapsedMs=' + elapsed +
      ' samples=' + ordered.length + ' p50Ms=' + ordered[Math.ceil(ordered.length * 0.5) - 1] +
      ' p95Ms=' + ordered[Math.ceil(ordered.length * 0.95) - 1]);
  }
  cancel(): void {
    if (this.active) this.log('PagePerf: event=end tab=' + this.active.tab + ' sequence=' + this.active.sequence);
    this.active = undefined;
    this.secondary.clear();
  }
}
