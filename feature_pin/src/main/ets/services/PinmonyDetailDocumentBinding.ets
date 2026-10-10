import { PinmonyNetworkContext } from 'common_network';

export interface PinmonyDetailDocumentBindingPorts {
  enabled: () => boolean;
  expectedPin: () => string;
  detailPin: () => string;
  pinIdentity: (url: string) => string;
  detailPresentationOnly: () => boolean;
  actionsReady: () => boolean;
  openingToken: () => number;
  isAuthenticated: () => boolean;
  isForeground: () => boolean;
  hasNativeBackTarget: () => boolean;
  nativeRootOnly: () => boolean;
  rootTabGuardTarget: () => number;
  detailReturnedToRoot: () => boolean;
  businessSuspended: () => boolean;
  networkContext: () => PinmonyNetworkContext;
  runJavaScript: (script: string) => Promise<string>;
  schedule: (callback: () => void, delayMs: number) => number;
  cancel: (id: number) => void;
  markJourney: (event: string) => void;
  warn: (message: string) => void;
}

// Binds the hidden current Pin document without granting action readiness.
// Every asynchronous continuation revalidates the opening token and full page context.
export class PinmonyDetailDocumentBinding {
  private readonly ports: PinmonyDetailDocumentBindingPorts;
  private binding: string = '';
  private probeTimer: number = -1;

  constructor(ports: PinmonyDetailDocumentBindingPorts) { this.ports = ports; }

  reset(): void {
    this.binding = '';
    if (this.probeTimer !== -1) this.ports.cancel(this.probeTimer);
    this.probeTimer = -1;
  }

  clearBinding(): void { this.binding = ''; }

  bindCurrentDetailDocument(url: string): void {
    const expected: string = this.ports.expectedPin();
    const context: PinmonyNetworkContext = this.ports.networkContext();
    if (this.ports.detailPresentationOnly() || !this.ports.enabled() || !context.authenticated ||
        this.ports.nativeRootOnly() || this.ports.rootTabGuardTarget() >= 0 ||
        this.ports.hasNativeBackTarget() || !this.ports.pinIdentity(expected) ||
        this.ports.pinIdentity(url) !== this.ports.pinIdentity(expected) || context.page !== url) return;
    const binding: string = this.ports.openingToken().toString() + ':' + context.epoch.toString() + ':' + url;
    if (this.binding === binding) return;
    this.binding = binding;
    this.refreshDetailDocumentBinding(url, context.epoch, this.ports.openingToken(), binding, 0);
    this.ports.markJourney('document.transport.bind');
  }

  probeDetailDocument(url: string, token: number, attempt: number): void {
    if (token !== this.ports.openingToken() || this.ports.detailPin() !== url ||
        this.ports.detailPresentationOnly() || this.ports.actionsReady() || this.ports.hasNativeBackTarget() ||
        this.ports.nativeRootOnly() || this.ports.detailReturnedToRoot() || this.ports.businessSuspended() ||
        !this.ports.isForeground() || !this.ports.isAuthenticated()) return;
    this.probeTimer = -1;
    const context: PinmonyNetworkContext = this.ports.networkContext();
    if (context.page === url) this.bindCurrentDetailDocument(url);
    if (attempt >= 60) { this.ports.markJourney('document.transport.wait.timeout'); return; }
    this.probeTimer = this.ports.schedule(() => this.probeDetailDocument(url, token, attempt + 1), 200);
  }

  private refreshDetailDocumentBinding(url: string, epoch: number, token: number, binding: string, attempt: number): void {
    const context: PinmonyNetworkContext = this.ports.networkContext();
    if (attempt > 0 && this.ports.actionsReady()) return;
    if (this.binding !== binding || token !== this.ports.openingToken() || !context.authenticated ||
        context.epoch !== epoch || context.page !== url || this.ports.detailPresentationOnly() ||
        this.ports.hasNativeBackTarget() || this.ports.nativeRootOnly() || this.ports.businessSuspended() ||
        !this.ports.isForeground() || this.ports.detailReturnedToRoot() ||
        this.ports.pinIdentity(url) !== this.ports.pinIdentity(this.ports.detailPin())) return;
    const bindingFailed = (): void => {
      if (this.binding !== binding || token !== this.ports.openingToken()) return;
      if (attempt < 3) this.ports.schedule(() => this.refreshDetailDocumentBinding(url, epoch, token, binding, attempt + 1), 250 * (attempt + 1));
      else {
        this.binding = '';
        this.ports.warn('Pinmony: detail document binding unavailable');
      }
    };
    try {
      this.ports.runJavaScript('location.href === ' + JSON.stringify(url) +
        ' && window.PinmonyNetwork && window.PinmonyDetailRefresh ? (window.PinmonyNetwork.bind(' +
        epoch.toString() + ',' + JSON.stringify(url) + '), window.PinmonyDetailRefresh(true), true) : false')
        .then((result: string) => {
          if (this.binding !== binding || token !== this.ports.openingToken()) return;
          if (result === 'true' || result === '"true"') this.ports.markJourney('document.transport.confirmed');
          if (!this.ports.actionsReady() && attempt < 3) {
            this.ports.schedule(() => this.refreshDetailDocumentBinding(url, epoch, token, binding, attempt + 1), 250 * (attempt + 1));
          } else if (attempt === 3 && result !== 'true' && result !== '"true"') {
            this.binding = '';
            this.ports.markJourney('document.transport.not-ready');
          }
        }).catch(bindingFailed);
    } catch (_) { bindingFailed(); }
  }
}
