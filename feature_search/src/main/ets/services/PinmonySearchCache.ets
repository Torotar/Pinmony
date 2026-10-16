import { PinmonySearchSnapshot } from '../models/PinmonySearch';

export interface PinmonySearchCacheEntry {
  snapshot: PinmonySearchSnapshot;
  scrollOffset: number;
}

// Search discovery and each results route have separate runtime snapshots.
export class PinmonySearchCache {
  private entries: Map<string, PinmonySearchCacheEntry> = new Map<string, PinmonySearchCacheEntry>();
  private heroPositions: Map<string, string> = new Map<string, string>();

  rememberHero(snapshot: PinmonySearchSnapshot, id: string): void {
    if (!snapshot.pageKey || !snapshot.heroes.some((hero): boolean => hero.id === id)) return;
    this.heroPositions.delete(snapshot.pageKey);
    this.heroPositions.set(snapshot.pageKey, id);
    if (this.heroPositions.size > 10) this.heroPositions.delete(this.heroPositions.keys().next().value);
  }

  heroPosition(pageKey: string): string { return this.heroPositions.get(pageKey) || ''; }

  put(snapshot: PinmonySearchSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.pageKey || snapshot.apiError || snapshot.apiBusy ||
        snapshot.discoveryError || snapshot.discoveryBusy ||
        (snapshot.quiz && (snapshot.quiz.busy || !!snapshot.quiz.error))) return;
    this.entries.delete(snapshot.pageKey);
    this.entries.set(snapshot.pageKey, { snapshot: snapshot, scrollOffset: scrollOffset });
    if (this.entries.size > 10) this.entries.delete(this.entries.keys().next().value);
  }

  get(pageKey: string): PinmonySearchCacheEntry | undefined {
    const entry: PinmonySearchCacheEntry | undefined = this.entries.get(pageKey);
    if (entry) {
      this.entries.delete(pageKey);
      this.entries.set(pageKey, entry);
    }
    return entry;
  }

  updateScrollOffset(pageKey: string, offset: number): void {
    const entry: PinmonySearchCacheEntry | undefined = this.entries.get(pageKey);
    if (entry) entry.scrollOffset = Math.max(0, offset);
  }

  clear(): void { this.entries.clear(); this.heroPositions.clear(); }
}
