import { PinmonyDetailSnapshot, PinmonyDetailAction, PinmonyRelatedPin } from '../models/PinmonyDetail';

const MAX_DETAIL_CACHE_ENTRIES: number = 10;

/** Retain presentation only; old control IDs must never authorize actions. */
export function retainDetailPresentation(current: PinmonyDetailSnapshot,
  previous: PinmonyDetailSnapshot | undefined): PinmonyDetailSnapshot {
  if (!previous || current.pinUrl !== previous.pinUrl || previous.dataSource !== 'api' ||
      (previous.kind !== 'cached' && !previous.actionsRetained &&
       !previous.commentsRetained && !previous.relatedRetained)) return current;
  if (!current.imageStageReady && previous.actions.length > 0) {
    current.actions = previous.actions.map((item: PinmonyDetailAction): PinmonyDetailAction => ({
      id: item.id, kind: item.kind, label: item.label, countText: item.countText,
      selected: item.selected, enabled: false
    }));
    current.actionsRetained = true;
  }
  if (!current.interactionsSettled && previous.commentsAvailable) {
    current.commentPreview = previous.commentPreview;
    current.commentEmpty = previous.commentEmpty;
    current.commentsAvailable = previous.commentsAvailable;
    current.commentsRetained = true;
  }
  if (current.related.length === 0 && !current.relatedEnded && previous.related.length > 0) {
    current.related = previous.related;
    current.relatedRetained = true;
  }
  return current;
}

export interface PinmonyDetailCacheEntry {
  identity: string;
  expiresAt: number;
  detail: PinmonyDetailSnapshot;
  scrollOffset: number;
}

export class PinmonyDetailCache {
  private entries: PinmonyDetailCacheEntry[] = [];

  clear(): void { this.entries = []; }

  get(identity: string): PinmonyDetailCacheEntry | undefined {
    this.entries = this.entries.filter((entry: PinmonyDetailCacheEntry): boolean => entry.expiresAt > Date.now());
    const index: number = this.entries.findIndex((entry: PinmonyDetailCacheEntry): boolean =>
      entry.identity === identity);
    if (index < 0) return undefined;
    const entry: PinmonyDetailCacheEntry = this.entries.splice(index, 1)[0];
    this.entries.push(entry);
    return entry;
  }

  put(identity: string, detail: PinmonyDetailSnapshot, scrollOffset: number): void {
    if (!identity || !detail || !detail.pinUrl) return;
    this.remove(identity);
    const cachedDetail: PinmonyDetailSnapshot = {
      kind: 'cached',
      session: 0,
      dataSource: detail.dataSource,
      pinUrl: detail.pinUrl,
      aiLabel: detail.aiLabel, originalImageUrl: detail.originalImageUrl,
      imageUrl: detail.imageUrl,
      imageWidth: detail.imageWidth,
      imageHeight: detail.imageHeight,
      title: detail.title,
      description: detail.description,
      creator: detail.creator,
      creatorAvatar: detail.creatorAvatar, creatorUrl: detail.creatorUrl,
      sourceLabel: detail.sourceLabel, sourceUrl: detail.sourceUrl,
      commentPreview: detail.commentPreview, commentsAvailable: detail.commentsAvailable,
      commentEmpty: detail.commentEmpty, commentLoading: false,
      imageStageReady: detail.imageStageReady, imageLoaded: detail.imageLoaded, interactionsSettled: detail.interactionsSettled,
      relatedEnded: detail.relatedEnded,
      relatedLoading: detail.relatedLoading,
      relatedError: detail.relatedError,
      carousel: detail.carousel,
      isVideo: detail.isVideo,
      mediaKind: detail.mediaKind,
      // No request runs while displaying a retained parent. Offer a fresh read instead of a spinner.
      mediaLoading: false,
      mediaError: detail.mediaError,
      videoError: detail.isVideo ? '视频地址需要重新读取' : '',
      actions: detail.actions.map((item: PinmonyDetailAction, index: number): PinmonyDetailAction => ({
        id: `cached-${identity}-action-${index}`,
        kind: item.kind,
        label: item.label,
        countText: item.countText,
        enabled: false,
        selected: item.selected
      })),
      related: detail.related.map((item: PinmonyRelatedPin, index: number): PinmonyRelatedPin => ({
        id: `cached-${identity}-related-${index}`,
        pinUrl: item.pinUrl,
        imageUrl: item.imageUrl,
        images: item.images,
        title: item.title,
        imageWidth: item.imageWidth,
        imageHeight: item.imageHeight
      }))
    };
    this.entries.push({
      expiresAt: Date.now() + 300000,
      identity: identity,
      detail: cachedDetail,
      scrollOffset: Math.max(0, scrollOffset)
    });
    while (this.entries.length > MAX_DETAIL_CACHE_ENTRIES) this.entries.shift();
  }

  updateScrollOffset(identity: string, scrollOffset: number): void {
    const entry: PinmonyDetailCacheEntry | undefined = this.get(identity);
    if (!entry) return;
    entry.scrollOffset = Math.max(0, scrollOffset);
  }

  remove(identity: string): void {
    const index: number = this.entries.findIndex((entry: PinmonyDetailCacheEntry): boolean =>
      entry.identity === identity);
    if (index >= 0) this.entries.splice(index, 1);
  }

  size(): number {
    return this.entries.length;
  }
}
