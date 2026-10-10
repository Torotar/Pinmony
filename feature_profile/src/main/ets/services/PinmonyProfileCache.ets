import { PinmonyProfileSnapshot } from '../models/PinmonyProfile';

export interface PinmonyProfileCacheEntry {
  snapshot: PinmonyProfileSnapshot;
  scrollOffset: number;
}

// Runtime presentation cache. Bridge control IDs are never restored as live actions.
export class PinmonyProfileCache {
  private entry: PinmonyProfileCacheEntry | undefined = undefined;

  put(snapshot: PinmonyProfileSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.profileUrl || snapshot.contentLoading ||
        snapshot.contentError || snapshot.organize) return;
    this.entry = { snapshot: snapshot, scrollOffset: Math.max(0, scrollOffset) };
  }

  get(profileUrl: string, section: string): PinmonyProfileCacheEntry | undefined {
    if (this.entry?.snapshot.profileUrl !== profileUrl || this.entry.snapshot.section !== section) return undefined;
    return this.entry;
  }

  clear(): void { this.entry = undefined; }
}
