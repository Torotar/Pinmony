import { PinmonyTaskRegistry } from 'common_foundation';

export interface PinmonyReturnPorts {
  isCurrent: (token: number) => boolean;
  isPending: (target: string) => boolean;
  isHome: (target: string) => boolean;
  isBoard: (target: string) => boolean;
  documentMatches: (target: string) => boolean;
  runScript: (script: string) => Promise<string>;
  useHistory: (target: string) => boolean;
  load: (target: string, token: number) => void;
  confirm: (target: string, bindDetail: boolean) => void;
  cancelHistory: () => void;
  mark: (event: string) => void;
}

// Product navigation stays in entry. Delayed recovery belongs to one return
// generation; it never replays business operations or owns account data.
export class PinmonyReturnCoordinator {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private navigationTarget: string = '';
  private navigationStarted: boolean = false;
  navigationBegun(url: string): void {
    if (this.navigationTarget && url.split('#')[0] === this.navigationTarget.split('#')[0]) this.navigationStarted = true;
  }

  private readonly ports: PinmonyReturnPorts;
  constructor(ports: PinmonyReturnPorts) { this.ports = ports; }

  cancel(): void {
    this.generation++;
    this.navigationTarget = ''; this.navigationStarted = false;
    this.tasks.invalidate();
  }

  schedule(callback: () => void, delayMs: number): void {
    this.tasks.timeout(callback, delayMs);
  }

  private async runScript(script: string): Promise<string> {
    return await this.ports.runScript(script);
  }

  synchronize(target: string, token: number, canReuseHome: boolean, departedPin: boolean): void {
    this.cancel();
    this.navigationTarget = target;
    const startedAt: number = Date.now();
    const generation: number = this.generation;
    const current: () => boolean = (): boolean => generation === this.generation && this.ports.isCurrent(token);
    const load: () => void = (): void => { if (current()) this.ports.load(target, token); };
    if (canReuseHome && this.ports.isHome(target) && this.ports.documentMatches(target)) {
      this.runScript('location.href === ' + JSON.stringify(target) +
        ' && typeof window.PinmonyHomeRefresh === "function" ? (window.PinmonyHomeRefresh(), true) : false')
        .then((result: string): void => {
          if (!current()) return;
          if (result === 'true' || result === '"true"') {
            this.ports.confirm(target, false);
            this.ports.mark('return.document.reused');
          } else load();
        }).catch(load);
    } else if (departedPin && this.ports.isBoard(target)) {
      this.ports.mark('return.native.route.direct');
      load();
      return;
    } else if (!this.ports.useHistory(target)) {
      this.ports.mark('return.history.missing');
      load(); return;
    } else this.ports.mark('return.history.used');
    const check = (): void => {
      if (!current() || !this.ports.isPending(target)) return;
      if (this.navigationStarted && Date.now() - startedAt < 6000) {
        this.ports.mark('return.history.progress');
        this.schedule(check, 1000); return;
      }
      this.ports.cancelHistory();
      this.ports.mark('return.history.fallback');
      this.runScript('location.href === ' + JSON.stringify(target))
        .then((result: string): void => {
          if (!current() || !this.ports.isPending(target)) return;
          if ((result === 'true' || result === '"true"') && this.ports.documentMatches(target)) {
            this.ports.confirm(target, true);
            this.ports.mark('return.document.confirmed');
          } else load();
        }).catch((): void => { if (current() && this.ports.isPending(target)) load(); });
    };
    this.schedule(check, 2500);
  }
}
