import { PinmonyJpegDecode, PinmonyJpegLease, acceptsSoftwareJpeg } from 'common_network';

// Prefetch owns leases, never ArkUI nodes or observable page state.
export class PinmonySearchImagePrefetch {
  private readonly leases: Map<string, PinmonyJpegLease> = new Map<string, PinmonyJpegLease>();
  private active: boolean = false;

  setActive(active: boolean): void {
    if (this.active === active) return;
    this.active = active;
    this.leases.forEach((lease: PinmonyJpegLease): void => lease.setActive(active));
  }

  update(urls: string[], limit: number = 8): void {
    const budget: number = Number.isFinite(limit) ? Math.max(8, Math.min(24, Math.floor(limit))) : 8;
    const next: string[] = [];
    urls.forEach((url: string): void => {
      if (next.length < budget && acceptsSoftwareJpeg(url) && !next.includes(url)) next.push(url);
    });
    this.leases.forEach((lease: PinmonyJpegLease, url: string): void => {
      if (!next.includes(url)) { lease.release(); this.leases.delete(url); }
    });
    next.forEach((url: string): void => {
      if (this.leases.has(url)) return;
      const lease: PinmonyJpegLease = PinmonyJpegDecode.acquire(url, this.active, 0);
      this.leases.set(url, lease);
      // Completion changes only the shared cache; it cannot invalidate the feed.
      lease.ready.catch((): void => {});
    });
  }

  clear(): void {
    this.leases.forEach((lease: PinmonyJpegLease): void => lease.release());
    this.leases.clear();
  }
}
