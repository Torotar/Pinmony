import { PinWebInboxSnapshot } from '../models/PinWebInbox';

export interface PinWebInboxCacheEntry {
  snapshot: PinWebInboxSnapshot;
  scrollOffset: number;
}

export class PinWebInboxCache {
  private entries: Map<string, PinWebInboxCacheEntry> = new Map<string, PinWebInboxCacheEntry>();
  private sections: Map<string, string> = new Map<string, string>();

  put(snapshot: PinWebInboxSnapshot, scrollOffset: number): void {
    if (snapshot.kind !== 'state' || !snapshot.pageUrl) return;
    this.entries.set(snapshot.pageUrl + snapshot.section, { snapshot: snapshot, scrollOffset: Math.max(0, scrollOffset) });
    this.sections.set(snapshot.pageUrl, snapshot.section);
    if (this.entries.size > 8) this.entries.delete(this.entries.keys().next().value);
  }

  get(pageUrl: string, section: string = ''): PinWebInboxCacheEntry | undefined {
    return this.entries.get(pageUrl + (section || this.sections.get(pageUrl) || 'messages'));
  }

  clear(): void { this.entries.clear(); this.sections.clear(); }
}
