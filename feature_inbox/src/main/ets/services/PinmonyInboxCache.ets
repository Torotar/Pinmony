import { PinmonyInboxSnapshot } from '../models/PinmonyInbox';

export interface PinmonyInboxCacheEntry {
  snapshot: PinmonyInboxSnapshot;
  scrollOffset: number;
}

export class PinmonyInboxCache {
  private entries: Map<string, PinmonyInboxCacheEntry> = new Map<string, PinmonyInboxCacheEntry>();
  private sections: Map<string, string> = new Map<string, string>();

  put(snapshot: PinmonyInboxSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.pageUrl) return;
    this.entries.set(snapshot.pageUrl + snapshot.section, { snapshot: snapshot, scrollOffset: Math.max(0, scrollOffset) });
    this.sections.set(snapshot.pageUrl, snapshot.section);
    if (this.entries.size > 8) this.entries.delete(this.entries.keys().next().value);
  }

  get(pageUrl: string, section: string = ''): PinmonyInboxCacheEntry | undefined {
    return this.entries.get(pageUrl + (section || this.sections.get(pageUrl) || 'messages'));
  }

  clear(): void { this.entries.clear(); this.sections.clear(); }
}
