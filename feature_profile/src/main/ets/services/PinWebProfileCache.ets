import { PinWebProfileSnapshot } from '../models/PinWebProfile';

export interface PinWebProfileCacheEntry {
  snapshot: PinWebProfileSnapshot;
  scrollOffset: number;
}

// Runtime presentation cache. Bridge control IDs are never restored as live actions.
export class PinWebProfileCache {
  private entry: PinWebProfileCacheEntry | undefined = undefined;

  put(snapshot: PinWebProfileSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.profileUrl || snapshot.contentLoading ||
        snapshot.contentError || snapshot.organize) return;
    this.entry = { snapshot: snapshot, scrollOffset: Math.max(0, scrollOffset) };
  }

  get(profileUrl: string, section: string): PinWebProfileCacheEntry | undefined {
    if (this.entry?.snapshot.profileUrl !== profileUrl || this.entry.snapshot.section !== section) return undefined;
    return this.entry;
  }

  clear(): void { this.entry = undefined; }
}
