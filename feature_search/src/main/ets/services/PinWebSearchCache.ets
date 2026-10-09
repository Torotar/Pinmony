import { PinWebSearchSnapshot } from '../models/PinWebSearch';

export interface PinWebSearchCacheEntry {
  snapshot: PinWebSearchSnapshot;
  scrollOffset: number;
}

// Search discovery and each results route have separate runtime snapshots.
export class PinWebSearchCache {
  private entries: Map<string, PinWebSearchCacheEntry> = new Map<string, PinWebSearchCacheEntry>();

  put(snapshot: PinWebSearchSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.pageKey || snapshot.apiError || snapshot.apiBusy ||
        snapshot.discoveryError || snapshot.discoveryBusy ||
        (snapshot.quiz && (snapshot.quiz.busy || !!snapshot.quiz.error))) return;
    this.entries.delete(snapshot.pageKey);
    this.entries.set(snapshot.pageKey, { snapshot: snapshot, scrollOffset: scrollOffset });
    if (this.entries.size > 10) this.entries.delete(this.entries.keys().next().value);
  }

  get(pageKey: string): PinWebSearchCacheEntry | undefined {
    const entry: PinWebSearchCacheEntry | undefined = this.entries.get(pageKey);
    if (entry) {
      this.entries.delete(pageKey);
      this.entries.set(pageKey, entry);
    }
    return entry;
  }

  updateScrollOffset(pageKey: string, offset: number): void {
    const entry: PinWebSearchCacheEntry | undefined = this.entries.get(pageKey);
    if (entry) entry.scrollOffset = Math.max(0, offset);
  }

  clear(): void { this.entries.clear(); }
}
