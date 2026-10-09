import { PinWebDetailAction, PinWebDetailSnapshot } from '../models/PinWebDetail';

// Current authenticated app session only: evidence is a validated write result.
// Reopening the original Pin can create a fresh document without savedRead's map.
export class PinWebConfirmedSaves {
  private states: Map<string, boolean> = new Map<string, boolean>();
  clear(): void { this.states.clear(); }
  confirm(identity: string, saved: boolean): void {
    if (!identity) return;
    this.states.set(identity, saved);
  }
  isSaved(identity: string): boolean {
    return this.states.get(identity) === true;
  }
  actions(identity: string, actions: PinWebDetailAction[]): PinWebDetailAction[] {
    const saved: boolean | undefined = this.states.get(identity);
    if (saved === undefined) return actions;
    return actions.map((item: PinWebDetailAction): PinWebDetailAction => {
      if (item.kind !== 'save') return item;
      return { id: item.id, kind: item.kind, label: saved ? '已收藏' : '收藏',
        countText: item.countText, enabled: item.enabled, selected: saved };
    });
  }
  apply(identity: string, detail: PinWebDetailSnapshot): PinWebDetailSnapshot {
    return {
      kind: detail.kind, session: detail.session, pinUrl: detail.pinUrl,
      aiLabel: detail.aiLabel, originalImageUrl: detail.originalImageUrl,
      imageUrl: detail.imageUrl, imageWidth: detail.imageWidth, imageHeight: detail.imageHeight,
      title: detail.title, description: detail.description, creator: detail.creator,
            creatorAvatar: detail.creatorAvatar, creatorUrl: detail.creatorUrl, sourceLabel: detail.sourceLabel, sourceUrl: detail.sourceUrl,
      actions: this.actions(identity, detail.actions), related: detail.related, dataSource: detail.dataSource,
      relatedLoading: detail.relatedLoading, relatedError: detail.relatedError,
      relatedEnded: detail.relatedEnded, commentPreview: detail.commentPreview,
      carousel: detail.carousel, isVideo: detail.isVideo, video: detail.video, videoError: detail.videoError,
      error: detail.error, retryable: detail.retryable, mediaUnsupported: detail.mediaUnsupported
    };
  }
}
