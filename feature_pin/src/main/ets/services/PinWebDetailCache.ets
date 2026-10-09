import { PinWebDetailSnapshot, PinWebDetailAction, PinWebRelatedPin } from '../models/PinWebDetail';

const MAX_DETAIL_CACHE_ENTRIES: number = 10;

/** Retain presentation only; old control IDs must never authorize actions. */
export function retainDetailPresentation(current: PinWebDetailSnapshot,
  previous: PinWebDetailSnapshot | undefined): PinWebDetailSnapshot {
  if (!previous || current.pinUrl !== previous.pinUrl || previous.dataSource !== 'api' ||
      (previous.kind !== 'cached' && !previous.actionsRetained &&
       !previous.commentsRetained && !previous.relatedRetained)) return current;
  if (!current.imageStageReady && previous.actions.length > 0) {
    current.actions = previous.actions.map((item: PinWebDetailAction): PinWebDetailAction => ({
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

export interface PinWebDetailCacheEntry {
  identity: string;
  expiresAt: number;
  detail: PinWebDetailSnapshot;
  scrollOffset: number;
}

export class PinWebDetailCache {
  private entries: PinWebDetailCacheEntry[] = [];

  clear(): void { this.entries = []; }

  get(identity: string): PinWebDetailCacheEntry | undefined {
    this.entries = this.entries.filter((entry: PinWebDetailCacheEntry): boolean => entry.expiresAt > Date.now());
    const index: number = this.entries.findIndex((entry: PinWebDetailCacheEntry): boolean =>
      entry.identity === identity);
    if (index < 0) return undefined;
    const entry: PinWebDetailCacheEntry = this.entries.splice(index, 1)[0];
    this.entries.push(entry);
    return entry;
  }

  put(identity: string, detail: PinWebDetailSnapshot, scrollOffset: number): void {
    if (!identity || !detail || !detail.pinUrl) return;
    this.remove(identity);
    const cachedDetail: PinWebDetailSnapshot = {
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
      carousel: detail.carousel,
      isVideo: detail.isVideo,
      mediaKind: detail.mediaKind,
      mediaLoading: detail.isVideo === true || detail.mediaLoading === true,
      mediaError: detail.mediaError,
      videoError: detail.isVideo ? '视频地址需要重新读取' : '',
      actions: detail.actions.map((item: PinWebDetailAction, index: number): PinWebDetailAction => ({
        id: `cached-${identity}-action-${index}`,
        kind: item.kind,
        label: item.label,
        countText: item.countText,
        enabled: false,
        selected: item.selected
      })),
      related: detail.related.map((item: PinWebRelatedPin, index: number): PinWebRelatedPin => ({
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
    const entry: PinWebDetailCacheEntry | undefined = this.get(identity);
    if (!entry) return;
    entry.scrollOffset = Math.max(0, scrollOffset);
  }

  remove(identity: string): void {
    const index: number = this.entries.findIndex((entry: PinWebDetailCacheEntry): boolean =>
      entry.identity === identity);
    if (index >= 0) this.entries.splice(index, 1);
  }

  size(): number {
    return this.entries.length;
  }
}
