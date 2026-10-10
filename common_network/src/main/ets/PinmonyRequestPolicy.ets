import { PinmonyRuntimeLog } from 'common_foundation';

export const PIN_REQUEST_PROTECTION_ENABLED: boolean = true;
export const PIN_RATE_LIMIT_BASE_MS: number = 30000;

export interface PinmonyRequestPermit {
  allowed: boolean;
  probe: boolean;
  generation: number;
}

// Process-local only: no credentials, request parameters or account identifiers.
// Page changes must not erase a server-requested cooldown.
export class PinmonyRequestPolicy {
  private until: number = 0;
  private incidents: number = 0;
  private generation: number = 0;
  private probing: boolean = false;
  private readonly now: () => number;

  constructor(now: () => number = (): number => Date.now()) { this.now = now; }

  remainingMs(): number { return Math.max(0, this.until - this.now()); }
  allowsSpeculativeRequests(): boolean { return this.until === 0; }

  canSend(permit: PinmonyRequestPermit): boolean {
    return permit.allowed && (this.until === 0 ||
      (permit.probe && permit.generation === this.generation && this.remainingMs() === 0));
  }

  acquire(read: boolean, speculative: boolean = false): PinmonyRequestPermit {
    const permit: PinmonyRequestPermit = { allowed: true, probe: false, generation: this.generation };
    if (!PIN_REQUEST_PROTECTION_ENABLED || this.until === 0) return permit;
    if (this.remainingMs() > 0 || this.probing || !read || speculative) {
      permit.allowed = false;
      PinmonyRuntimeLog.info('RequestPolicy: paused remainingMs=' + this.remainingMs().toString());
      return permit;
    }
    this.probing = true; permit.probe = true;
    PinmonyRuntimeLog.info('RequestPolicy: cooldown-ended probe=true');
    return permit;
  }

  rateLimited(headers: Record<string, string | string[] | undefined>): void {
    if (!PIN_REQUEST_PROTECTION_ENABLED) return;
    let delay: number = -1;
    const key: string | undefined = Object.keys(headers).find((name: string): boolean => name.toLowerCase() === 'retry-after');
    const raw: string | string[] | undefined = key ? headers[key] : undefined;
    const value: string | undefined = typeof raw === 'string' ? raw :
      Array.isArray(raw) && raw.length === 1 ? raw[0] : undefined;
    if (typeof value === 'string' && value.length <= 128 && !/[\r\n]/.test(value)) {
      const trimmed: string = value.trim();
      if (/^\d+$/.test(trimmed)) delay = Number(trimmed) * 1000;
      else {
        const date: number = Date.parse(trimmed);
        if (Number.isFinite(date)) delay = Math.max(0, date - this.now());
      }
    }
    this.incidents = Math.min(5, this.incidents + 1);
    const fallback: number = Math.min(300000, PIN_RATE_LIMIT_BASE_MS * Math.pow(2, this.incidents - 1));
    // Never shorten a valid server delay. Zero/past dates still get a local safety interval.
    const wait: number = Number.isFinite(delay) && delay > 0 ? delay : fallback;
    this.until = Math.max(this.until, this.now() + wait);
    this.generation++; this.probing = false;
    PinmonyRuntimeLog.warn('RequestPolicy: cooldown-start remainingMs=' + this.remainingMs().toString() +
      ' source=' + (delay > 0 ? 'server' : 'fallback'));
  }

  finish(permit: PinmonyRequestPermit, status: number): void {
    if (!permit.probe || permit.generation !== this.generation) return;
    this.probing = false;
    if (status >= 200 && status < 300) {
      this.until = 0; this.incidents = 0; this.generation++;
      PinmonyRuntimeLog.info('RequestPolicy: recovery-complete');
    } else this.rateLimited({});
  }
}
