import { PinmonyI18n } from 'common_foundation';
import { PinmonyDetailAction, PinmonyDetailSnapshot } from '../models/PinmonyDetail';

// Current authenticated app session only: evidence is a validated write result.
// Reopening the original Pin can create a fresh document without savedRead's map.
export class PinmonyConfirmedSaves {
  private states: Map<string, boolean> = new Map<string, boolean>();
  private copies: Map<string, string> = new Map<string, string>();
  private boards: Map<string, string> = new Map<string, string>();
  clear(): void { this.states.clear(); this.copies.clear(); this.boards.clear(); }
  confirm(identity: string, saved: boolean, copyId: string = '', boardName: string = ''): void {
    if (!identity) return;
    this.states.set(identity, saved);
    if (!saved) { this.copies.delete(identity); this.boards.delete(identity); }
    else if (/^\d+$/.test(copyId) && copyId !== identity) this.copies.set(identity, copyId);
    if (saved && boardName) this.boards.set(identity, boardName.slice(0, 300));
  }
  copyId(identity: string): string { return this.copies.get(identity) || ''; }
  known(identity: string): boolean { return this.states.has(identity); }
  isSaved(identity: string): boolean {
    return this.states.get(identity) === true;
  }
  actions(identity: string, actions: PinmonyDetailAction[]): PinmonyDetailAction[] {
    const saved: boolean | undefined = this.states.get(identity);
    if (saved === undefined) return actions;
    return actions.map((item: PinmonyDetailAction): PinmonyDetailAction => {
      if (item.kind !== 'save') return item;
      return { id: item.id, kind: item.kind, label: saved ? this.boards.get(identity) || PinmonyI18n.message("pm_saved_471dd4d7") : PinmonyI18n.message("pm_save_60a53514"),
        countText: item.countText, enabled: item.enabled, selected: saved };
    });
  }
  apply(identity: string, detail: PinmonyDetailSnapshot): PinmonyDetailSnapshot {
    return {
      kind: detail.kind, session: detail.session, pinUrl: detail.pinUrl,
      aiLabel: detail.aiLabel, originalImageUrl: detail.originalImageUrl,
      imageUrl: detail.imageUrl, imageWidth: detail.imageWidth, imageHeight: detail.imageHeight,
      title: detail.title, description: detail.description, creator: detail.creator,
      creatorAvatar: detail.creatorAvatar, creatorUrl: detail.creatorUrl,
      sourceLabel: detail.sourceLabel, sourceUrl: detail.sourceUrl,
      actions: this.actions(identity, detail.actions), related: detail.related, dataSource: detail.dataSource,
      relatedLoading: detail.relatedLoading, relatedError: detail.relatedError, relatedEnded: detail.relatedEnded,
      commentPreview: detail.commentPreview, commentLoading: detail.commentLoading, commentError: detail.commentError,
      commentsAvailable: detail.commentsAvailable, commentEmpty: detail.commentEmpty,
      imageStageReady: detail.imageStageReady, imageLoaded: detail.imageLoaded, interactionsSettled: detail.interactionsSettled,
      actionsRetained: detail.actionsRetained, commentsRetained: detail.commentsRetained, relatedRetained: detail.relatedRetained,
      carousel: detail.carousel, isVideo: detail.isVideo, video: detail.video, videoError: detail.videoError,
      mediaLoading: detail.mediaLoading, mediaError: detail.mediaError, mediaKind: detail.mediaKind,
      timingEvent: detail.timingEvent, timingDuration: detail.timingDuration,
      error: detail.error, retryable: detail.retryable, mediaUnsupported: detail.mediaUnsupported
    };
  }
}
