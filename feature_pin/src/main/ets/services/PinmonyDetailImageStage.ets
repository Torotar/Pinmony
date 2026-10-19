import { PinmonyI18n } from 'common_foundation';
import { PinmonyDetailSnapshot } from '../models/PinmonyDetail';

export interface PinmonyDetailImageStagePorts {
  enabled: () => boolean;
  detail: () => PinmonyDetailSnapshot | undefined;
  actionsReady: () => boolean;
  openingToken: () => number;
  hasNativeBackTarget: () => boolean;
  runScript: (script: string) => Promise<string>;
  schedule: (callback: () => void, delayMs: number) => number;
  cancel: (id: number) => void;
  markJourney: (event: string) => void;
  setError: (message: string) => void;
}

export class PinmonyDetailImageStage {
  private readonly ports: PinmonyDetailImageStagePorts;
  private binding: string = '';
  private signalKey: string = '';
  private attempts: number = 0;
  private deadline: number = -1;
  private retryTimers: number[] = [];

  constructor(ports: PinmonyDetailImageStagePorts) { this.ports = ports; }

  sync(loadedUrl: string, failedUrl: string): void {
    const detail: PinmonyDetailSnapshot | undefined = this.ports.detail();
    if (!this.ports.enabled() || !detail || !this.ports.actionsReady() ||
        (detail.imageStageReady && loadedUrl !== detail.imageUrl)) return;
    const binding: string = this.ports.openingToken().toString() + ':' + detail.session.toString() + ':' + detail.imageUrl;
    if (binding !== this.binding) {
      this.clearTimers();
      this.binding = binding;
      this.signalKey = '';
      this.attempts = 0;
      this.ports.markJourney('main.image.bound');
      this.deadline = this.ports.schedule(() => {
        if (binding === this.binding && !this.ports.detail()?.imageStageReady) this.signal('timeout');
      }, 2500);
    }
    if (loadedUrl === detail.imageUrl) this.signal('loaded');
    else if (failedUrl === detail.imageUrl) this.signal('failed');
  }

  clearDeadline(): void {
    if (this.deadline !== -1) this.ports.cancel(this.deadline);
    this.deadline = -1;
  }

  reset(): void {
    this.clearTimers();
    this.binding = '';
    this.signalKey = '';
    this.attempts = 0;
  }

  signal(outcome: string): void {
    const detail: PinmonyDetailSnapshot | undefined = this.ports.detail();
    if (!detail || !this.ports.actionsReady() || this.ports.hasNativeBackTarget() ||
        (detail.imageStageReady && outcome !== 'loaded') ||
        this.signalKey === this.binding + ':' + outcome || !this.binding) return;
    const binding: string = this.binding;
    const token: number = this.ports.openingToken();
    this.signalKey = binding + ':' + outcome;
    this.attempts++;
    const bridgeFailed = (): void => {
      if (!this.isCurrent(token, binding)) return;
      this.signalKey = '';
      this.ports.markJourney('main.image.bridge.failed');
      this.ports.setError(PinmonyI18n.message('详情连接暂不可用，请重试'));
    };
    try {
      this.ports.runScript('window.PinmonyDetailImageStage && window.PinmonyDetailImageStage(' +
        detail.session.toString() + ',' + JSON.stringify(detail.pinUrl) + ',' + JSON.stringify(detail.imageUrl) + ',' +
        JSON.stringify(outcome) + ')').then((result: string) => {
          if (!this.isCurrent(token, binding)) return;
          if (result === 'true' || result === '"true"') {
            this.ports.markJourney('main.image.stage=' + outcome);
            this.clearDeadline();
          } else {
            this.signalKey = '';
            if (this.attempts < 8) this.retryTimers.push(this.ports.schedule(() => {
              if (this.isCurrent(token, binding)) this.signal(outcome);
            }, 250));
            else {
              this.ports.markJourney('main.image.bridge.unavailable');
              this.ports.setError(PinmonyI18n.message('详情连接尚未就绪，请重试'));
            }
          }
        }).catch(bridgeFailed);
    } catch (_) { bridgeFailed(); }
  }

  private isCurrent(token: number, binding: string): boolean {
    const detail: PinmonyDetailSnapshot | undefined = this.ports.detail();
    return token === this.ports.openingToken() && binding === this.binding && !!detail &&
      binding === token.toString() + ':' + detail.session.toString() + ':' + detail.imageUrl;
  }

  private clearTimers(): void {
    this.clearDeadline();
    for (const timer of this.retryTimers) this.ports.cancel(timer);
    this.retryTimers = [];
  }
}
