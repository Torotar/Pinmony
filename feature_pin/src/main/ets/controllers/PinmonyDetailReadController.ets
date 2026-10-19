import { PinmonyI18n } from 'common_foundation';
import { PinmonyTaskRegistry, PinmonyRuntimeLog } from 'common_foundation';
import { PinmonyPinStore } from '../stores/PinmonyPinStore';
import { PinmonyDetailSnapshot, PinmonyDetailAction, PinmonyRelatedPin } from '../models/PinmonyDetail';
import { PIN_DETAIL_API_ENABLED } from '../services/PinmonyDetailApiScript';
import { retainDetailPresentation } from '../services/PinmonyDetailCache';
export interface PendingDetailLike { id: string; pinUrl: string; session: number; selected: boolean; countText: string; }

export interface PinmonyDetailReadControllerPorts {
  nativeRootOnly: () => boolean;
  detailReturnedToRoot: () => boolean;
  nativeBackTarget: () => string;
  nativePinRoute: () => string;
  setNativePinRoute: (value: string) => void;
  pendingDetailLike: () => PendingDetailLike | undefined;
  setPendingDetailLike: (value: PendingDetailLike | undefined) => void;
  detailOpenedAt: () => number;
  detailCommentsMeasured: () => boolean;
  setDetailCommentsMeasured: (value: boolean) => void;
  detailRelatedMeasured: () => boolean;
  setDetailRelatedMeasured: (value: boolean) => void;
  detailImageLoadedUrl: () => string;
  document: () => string;
  addressKey: (value: string) => string;
  currentPinUrl: () => string;
  mark: (event: string, once?: boolean, duration?: number) => void;
  pinIdentity: (value: string) => string;
  showMessage: (value: string) => void;
  restoreCachedDetail: (value: string) => boolean;
  hasProfile: () => boolean;
  clearProfile: () => void;
  externalSourceUrl: (value: string) => string;
  profileUrlFromAddress: (value: string) => string;
  withDetailLike: (detail: PinmonyDetailSnapshot, id: string, selected: boolean, count: string) => PinmonyDetailSnapshot;
  syncDetailImageStage: () => void;
  updateSearchPinTitle: (pin: string, title: string) => void;
  updateHomePinTitle: (pin: string, title: string) => void;
  runScript: (script: string) => Promise<string>;
  foreground: () => boolean;
}

export class PinmonyDetailReadController {
  private readonly tasks: PinmonyTaskRegistry = new PinmonyTaskRegistry();
  private generation: number = 0;
  private refreshTimer: number = -1;
  private readonly store: PinmonyPinStore;
  private readonly ports: PinmonyDetailReadControllerPorts;
  constructor(store: PinmonyPinStore, ports: PinmonyDetailReadControllerPorts) { this.store = store; this.ports = ports; }
  pause(): void { this.generation++; this.tasks.invalidate(); this.refreshTimer = -1; }

  updateDetail(value: string): void {
    if (!this.ports.foreground()) return;
    if (this.store.detailPresentationOnly) return;
    if (this.ports.nativeRootOnly() || this.ports.detailReturnedToRoot()) return;
    if (this.ports.nativeBackTarget()) {
      try {
        if (this.ports.addressKey(this.ports.document()) !== this.ports.addressKey(this.ports.nativeBackTarget())) return;
      } catch (_) { return; }
    }
    try {
      const message: PinmonyDetailSnapshot = JSON.parse(value) as PinmonyDetailSnapshot;
      if (!message || !Number.isInteger(message.session) || message.session < 0 || typeof message.pinUrl !== 'string') return;
      if (message.kind === 'timing') {
        if (message.session === this.store.detailSession && message.pinUrl === this.store.detailPin &&
            message.pinUrl === this.ports.currentPinUrl() && typeof message.timingEvent === 'string' &&
            /^(comments|related|base|interactions)\.[a-z.]{1,64}$/.test(message.timingEvent) && typeof message.timingDuration === 'number' &&
            message.timingDuration >= 0 && message.timingDuration <= 60000)
          this.ports.mark(message.timingEvent, false, message.timingDuration);
        return;
      }
      if (this.store.detailOpeningPin &&
          this.ports.pinIdentity(message.pinUrl) !== this.ports.pinIdentity(this.store.detailOpeningPin)) return;
      if (PIN_DETAIL_API_ENABLED && message.kind === 'apiPending') {
        if (this.ports.pinIdentity(message.pinUrl) !== this.ports.pinIdentity(this.ports.currentPinUrl()) ||
            message.session < this.store.detailSession) return;
        this.store.detailSession = message.session;
        this.ports.setNativePinRoute(this.ports.pinIdentity(message.pinUrl));
        this.store.detailPin = message.pinUrl;
        if (!this.store.detail) this.store.detailOpeningPin = message.pinUrl;
        this.store.detailApiError = message.error || '';
        this.store.detailApiRetryable = message.retryable !== false;
        this.store.detailMediaUnsupported = message.mediaUnsupported === true;
        return;
      }
      if (message.kind === 'flowClosed') {
        if (message.session === this.store.detailSession && message.pinUrl === this.store.detailPin) {
          this.store.detailWebFlow = false;
        }
        return;
      }
      if (message.kind === 'actionUnchanged') {
        if (message.session === this.store.detailSession && message.pinUrl === this.store.detailPin) {
          this.ports.setPendingDetailLike(undefined);
          if (PIN_DETAIL_API_ENABLED) {
            this.ports.showMessage(message.error || PinmonyI18n.message("pm_like_not_confirmed_please_retry_840b5e22"));
            this.ports.runScript('window.PinmonyDetailRefresh && window.PinmonyDetailRefresh()')
              .catch(() => PinmonyRuntimeLog.warn('Pinmony: detail refresh unavailable'));
            return;
          }
          this.store.detailImageFailedPin = message.pinUrl;
          this.store.detail = undefined;
          this.store.detailActionsReady = false;
          this.ports.showMessage(PinmonyI18n.message("pm_like_did_not_take_effect_returned_to_the_detail_session_e201c241"));
        }
        return;
      }
      if (message.kind === 'unsupported') {
        const identity: string = this.ports.pinIdentity(message.pinUrl);
        if (identity && identity === this.ports.pinIdentity(this.ports.currentPinUrl())) {
          if (this.store.detail && this.ports.pinIdentity(this.store.detail.pinUrl) === identity && !this.store.detailActionsReady) {
            this.store.detailSession = Math.max(this.store.detailSession, message.session);
            this.store.detailPin = message.pinUrl;
            return;
          }
          if (this.ports.restoreCachedDetail(message.pinUrl)) {
            this.store.detailSession = message.session;
            return;
          }
        }
      }
      if (message.kind === 'closed' || message.kind === 'unsupported') {
        if (message.kind === 'closed' && this.ports.currentPinUrl()) return;
        if (!message.pinUrl || this.ports.pinIdentity(message.pinUrl) === this.ports.pinIdentity(this.ports.currentPinUrl())) {
          if (message.pinUrl && (this.ports.hasProfile())) this.ports.clearProfile();
          this.ports.setPendingDetailLike(undefined);
          if (this.store.detailPin !== message.pinUrl) this.store.detailImageFailedPin = '';
          this.store.detail = undefined;
          this.store.detailActionsReady = false;
          this.store.detailWebFlow = false;
          this.store.detailPin = message.pinUrl;
          this.store.detailSession = message.session;
        }
        return;
      }
      if ((message.kind !== 'state' && message.kind !== 'apiPending' && message.kind !== 'apiFailed') || !this.ports.pinIdentity(message.pinUrl)) return;
      if (PIN_DETAIL_API_ENABLED && message.dataSource !== 'api') return;
      if (this.ports.pinIdentity(message.pinUrl) !== this.ports.pinIdentity(this.ports.currentPinUrl())) {
        if (this.refreshTimer >= 0) return;
        const generation: number = this.generation;
        const page: string = this.ports.document();
        const token: number = this.store.detailOpeningToken;
        this.refreshTimer = this.tasks.timeout(() => {
          this.refreshTimer = -1;
          if (generation !== this.generation || !this.ports.foreground() || page !== this.ports.document() ||
              token !== this.store.detailOpeningToken || this.ports.nativeRootOnly() || this.ports.detailReturnedToRoot()) return;
          this.ports.runScript('window.PinmonyDetailRefresh && window.PinmonyDetailRefresh()')
            .catch(() => PinmonyRuntimeLog.warn('Pinmony: detail refresh unavailable'));
        }, 250);
        return;
      }
      if (!Number.isInteger(message.session) || message.session < 1 || message.session < this.store.detailSession || !message.imageUrl ||
          !/^https:\/\//i.test(message.imageUrl) ||
          !Array.isArray(message.actions) || message.actions.length > 100 || !Array.isArray(message.related) || message.related.length > 2000) return;
      this.ports.setNativePinRoute(this.ports.pinIdentity(message.pinUrl));
      if (this.ports.hasProfile()) this.ports.clearProfile();
      if (this.store.detailPin && this.ports.pinIdentity(message.pinUrl) !== this.ports.pinIdentity(this.store.detailPin)) {
        this.ports.setPendingDetailLike(undefined);
        this.store.detailWebFlow = false;
        this.store.detailImageFailedPin = '';
      }
      this.store.detailSession = message.session;
      this.store.detailPin = message.pinUrl;
      const actions: PinmonyDetailAction[] = message.actions.filter((item: PinmonyDetailAction): boolean =>
        !!item && typeof item.id === 'string' && typeof item.kind === 'string' && typeof item.label === 'string' && !!item.id && !!item.kind && !!item.label);
      const related: PinmonyRelatedPin[] = message.related.filter((item: PinmonyRelatedPin): boolean =>
        !!item && typeof item.id === 'string' && typeof item.pinUrl === 'string' && typeof item.imageUrl === 'string' && !!item.id && !!item.pinUrl && !!item.imageUrl);
      const sourceUrl: string = this.ports.externalSourceUrl(message.sourceUrl || '');
      let nextDetail: PinmonyDetailSnapshot = {
        kind: 'state', session: message.session, pinUrl: message.pinUrl,
        aiLabel: message.aiLabel === '由 AI 修改' ? message.aiLabel : '',
        originalImageUrl: /^https:\/\/i\.pinimg\.com\//.test(message.originalImageUrl || '') ? message.originalImageUrl : message.imageUrl,
        imageUrl: message.imageUrl, imageWidth: message.imageWidth || 0,
        imageHeight: message.imageHeight || 0, title: message.title || '',
        description: message.description || '', creator: message.creator || '',
        creatorAvatar: message.creatorAvatar || '', creatorUrl: this.ports.profileUrlFromAddress(message.creatorUrl || ''),
        sourceLabel: sourceUrl ? (message.sourceLabel || '') : '', sourceUrl: sourceUrl || undefined,
        actions: actions, related: related, dataSource: message.dataSource,
        relatedLoading: message.relatedLoading, relatedError: message.relatedError,
        relatedEnded: message.relatedEnded, commentPreview: message.commentPreview,
        commentLoading: message.commentLoading === true, commentError: message.commentError || '',
        commentsAvailable: message.commentsAvailable === true,
        commentEmpty: message.commentEmpty === true, imageStageReady: message.imageStageReady === true, imageLoaded: message.imageLoaded === true,
        interactionsSettled: message.interactionsSettled === true,
        mediaLoading: message.mediaLoading === true, mediaError: message.mediaError || '',
        mediaKind: message.mediaKind === 'video' || message.mediaKind === 'carousel' ? message.mediaKind : '',
        carousel: message.carousel && message.carousel.pinId === this.ports.pinIdentity(message.pinUrl) &&
          Array.isArray(message.carousel.items) && message.carousel.items.length > 0 &&
          message.carousel.items.every((item): boolean => !!item.id &&
            /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(item.imageUrl) &&
            item.imageWidth > 0 && item.imageHeight > 0) ? message.carousel : undefined,
        isVideo: message.isVideo === true, videoError: message.videoError || '',
        video: message.video && message.video.pinId === this.ports.pinIdentity(message.pinUrl) &&
          (message.video.readRevision === undefined || Number.isInteger(message.video.readRevision) &&
           message.video.readRevision >= 0 && message.video.readRevision < 1000000) &&
          Array.isArray(message.video.sources) && message.video.sources.length > 0 &&
          message.video.sources.every((source): boolean => typeof source.url === 'string' &&
            /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\/videos\//i.test(source.url) &&
            (source.kind === 'hls' || source.kind === 'mp4')) ? message.video : undefined
      };
      nextDetail = retainDetailPresentation(nextDetail, this.store.detail);
      const pending: PendingDetailLike | undefined = this.ports.pendingDetailLike();
      if (pending) {
        if (pending.session !== message.session || pending.pinUrl !== message.pinUrl) {
          this.ports.setPendingDetailLike(undefined);
        } else {
          const like: PinmonyDetailAction | undefined = actions.find((item: PinmonyDetailAction): boolean =>
            item.id === pending.id && item.kind === 'like');
          if (like && like.selected === pending.selected) {
            this.ports.setPendingDetailLike(undefined);
          } else if (like) {
            nextDetail = this.ports.withDetailLike(nextDetail, pending.id, pending.selected, pending.countText);
          } else {
            this.ports.setPendingDetailLike(undefined);
          }
        }
      }
      nextDetail.actions = this.store.confirmedSaves.actions(this.ports.pinIdentity(message.pinUrl), nextDetail.actions);
      if (PIN_DETAIL_API_ENABLED && this.ports.detailOpenedAt() > 0) {
        const timing: string = ' openId=' + this.store.detailOpeningToken.toString() + ' elapsedMs=' +
          (Date.now() - this.ports.detailOpenedAt()).toString();
        if (!this.ports.detailCommentsMeasured() && !nextDetail.commentsRetained &&
            nextDetail.commentsAvailable && !nextDetail.commentLoading) {
          this.ports.setDetailCommentsMeasured(true);
          PinmonyRuntimeLog.info('DetailTrace: comments ' + (nextDetail.commentError ? 'failed' : 'ready') + timing);
        }
        if (!this.ports.detailRelatedMeasured() && !nextDetail.relatedRetained && !nextDetail.relatedLoading &&
            (nextDetail.relatedError || nextDetail.relatedEnded || nextDetail.related.length > 0)) {
          this.ports.setDetailRelatedMeasured(true);
          PinmonyRuntimeLog.info('DetailTrace: related ' + (nextDetail.relatedError ? 'failed' : 'ready') + timing +
            ' count=' + nextDetail.related.length.toString());
        }
      }
      // The native Image completion callback is the authoritative visual
      // result. Preserve it when the validated snapshot reuses the same URL;
      // the Web bridge may arrive later or be unavailable after navigation.
      if (!nextDetail.imageLoaded && this.ports.detailImageLoadedUrl() === nextDetail.imageUrl &&
          this.ports.pinIdentity(nextDetail.pinUrl) === this.ports.pinIdentity(this.store.detailPin)) {
        nextDetail.imageStageReady = true;
        nextDetail.imageLoaded = true;
        PinmonyRuntimeLog.info('DetailTrace: main image visual state reused openId=' +
          this.store.detailOpeningToken.toString());
      }
      this.store.detail = nextDetail;
      if (PIN_DETAIL_API_ENABLED && nextDetail.imageWidth > 0 && nextDetail.imageHeight > 0) {
        const ratio: number = nextDetail.imageHeight / nextDetail.imageWidth;
        PinmonyRuntimeLog.info('DetailTrace: main image metrics openId=' +
          this.store.detailOpeningToken.toString() + ' width=' + nextDetail.imageWidth.toString() +
          ' height=' + nextDetail.imageHeight.toString() + ' ratio=' + ratio.toFixed(4));
      }
      this.store.detailApiError = '';
      this.store.detailOpeningPin = '';
      if (!this.store.detailActionsReady) PinmonyRuntimeLog.info('DetailTrace: current actions ready openId=' + this.store.detailOpeningToken.toString() + ' elapsedMs=' +
        (Date.now() - this.ports.detailOpenedAt()).toString());
      this.store.detailActionsReady = true;
      this.ports.mark('current.snapshot.committed');
      if (nextDetail.imageStageReady) {
        this.ports.mark('interactions.started');
        const like: PinmonyDetailAction | undefined = nextDetail.actions.find((item: PinmonyDetailAction): boolean => item.kind === 'like');
        this.ports.mark(like && like.countText ? 'like.count.confirmed' : 'like.count.unavailable');
        if (like?.enabled) this.ports.mark('like.action.ready');
      }
      if (nextDetail.commentLoading) this.ports.mark('comments.loading');
      else if (!nextDetail.commentsRetained && nextDetail.commentsAvailable) this.ports.mark(nextDetail.commentError ? 'comments.failed' :
        nextDetail.commentEmpty ? 'comments.empty' : 'comments.committed');
      if (nextDetail.interactionsSettled) this.ports.mark('interactions.settled');
      if (nextDetail.relatedLoading) this.ports.mark('related.loading');
      else if (message.relatedError || message.relatedEnded || related.length > 0)
        this.ports.mark(message.relatedError ? 'related.failed' : related.length ? 'related.committed' : 'related.empty');
      this.ports.syncDetailImageStage();
      this.store.detailCache.put(this.ports.pinIdentity(message.pinUrl), nextDetail, this.store.detailScrollOffset);
      this.store.detailPrefetch.remove(message.pinUrl);
      this.ports.updateSearchPinTitle(message.pinUrl, nextDetail.title);
      this.ports.updateHomePinTitle(message.pinUrl, nextDetail.title);
    } catch (error) {
      PinmonyRuntimeLog.warn('Pinmony: invalid Pin detail state');
    }
  }


}
