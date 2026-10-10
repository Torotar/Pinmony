import { LruCache } from 'common_foundation';
import { PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';

export interface PinmonyDetailReadCachePorts {
  detailPin: () => string;
  currentPin: () => string;
  pinIdentity: (url: string) => string;
  isAuthenticated: () => boolean;
  hasNativeBackTarget: () => boolean;
  markJourney: (event: string) => void;
}

// Keeps retained comments/related reads presentation-only and session-bound.
export class PinmonyDetailReadCache {
  private readonly cache: LruCache<string> = new LruCache<string>(24, 300000);
  private retainedPin: string = '';
  private readonly ports: PinmonyDetailReadCachePorts;
  constructor(ports: PinmonyDetailReadCachePorts) { this.ports = ports; }

  clear(): void { this.cache.clear(); this.retainedPin = ''; }
  setPin(pin: string): void { this.retainedPin = this.ports.pinIdentity(pin); }
  getPin(): string { return this.retainedPin; }

  key(url: string): string {
    return url.replace(/([?&])_=[0-9]+(?=&|$)/g, '$1').replace(/[?&]$/, '').replace('?&', '?').replace(/&&/g, '&');
  }

  store(job: PinmonyNetworkJob, reply: PinmonyNetworkReply): void {
    if (reply.status !== 200 || !!reply.error || job.method !== 'GET' || reply.body.length >= 1000000 ||
        !/\/resource\/(RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url)) return;
    this.cache.put(this.key(job.url), reply.body);
    this.ports.markJourney('return.read.cache.stored');
  }

  retained(job: PinmonyNetworkJob): PinmonyNetworkReply | undefined {
    if (!this.retainedPin || this.retainedPin !== this.ports.pinIdentity(this.ports.detailPin()) ||
        !this.ports.isAuthenticated() || this.ports.hasNativeBackTarget() || job.method !== 'GET' || job.body !== '' ||
        !/\/resource\/(RelatedModulesResource|UnifiedCommentsPreviewResource)\/get\//.test(job.url)) return undefined;
    const body: string | null = this.cache.get(this.key(job.url));
    if (!body) return undefined;
    this.ports.markJourney('return.read.cache.hit');
    return { id: job.id, epoch: job.epoch, page: job.page, url: job.url, status: 200, body, headers: {}, error: '' };
  }
}
