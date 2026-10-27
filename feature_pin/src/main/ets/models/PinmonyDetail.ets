import { PinImageSources, PinmonyVideo } from 'common_ui';
import { PinmonyShuffleSnapshot } from './PinmonyShuffle';


export interface PinmonyDetailAction {
  id: string;
  kind: string;
  label: string;
  countText: string;
  enabled: boolean;
  selected: boolean;
}

export interface PinmonyRelatedTopic {
  id: string;
  title: string;
  imageUrl: string;
  targetUrl: string;
}

export interface PinmonyRelatedPin {
  kind?: string;
  topics?: PinmonyRelatedTopic[];
  id: string;
  pinUrl: string;
  imageUrl: string;
  images?: PinImageSources;
  title: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinmonyCarouselItem {
  video?: PinmonyVideo;
  id: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
}

export interface PinmonyCarousel {
  freeScroll?: boolean;
  pinId: string;
  items: PinmonyCarouselItem[];
}

export interface PinmonyDetailSnapshot {
  shuffleId?: string;
  shuffleLoading?: boolean;
  shuffleError?: string;
  shuffle?: PinmonyShuffleSnapshot;
  priceText?: string;
  richDescription?: string;
  affiliateDisclosure?: string;
  sourceName?: string;
  creatorVerified?: boolean;
  autoplayWifi?: boolean;
  autoplayCellular?: boolean;
  aiLabel?: string;
  originalImageUrl?: string;
  carousel?: PinmonyCarousel;
  isVideo?: boolean;
  video?: PinmonyVideo;
  videoError?: string;
  mediaLoading?: boolean;
  mediaError?: string;
  mediaKind?: string;
  dataSource?: string;
  commentPreview?: string;
  commentLoading?: boolean;
  commentError?: string;
  commentsAvailable?: boolean;
  commentEmpty?: boolean;
  imageStageReady?: boolean;
  imageLoaded?: boolean;
  interactionsSettled?: boolean;
  timingEvent?: string;
  timingDuration?: number;
  error?: string;
  retryable?: boolean;
  mediaUnsupported?: boolean;
  relatedLoading?: boolean;
  relatedError?: string;
  relatedEnded?: boolean;
  actionsRetained?: boolean;
  commentsRetained?: boolean;
  relatedRetained?: boolean;
  kind: string;
  session: number;
  pinUrl: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
  description: string;
  creator: string;
  creatorAvatar: string;
  creatorUrl?: string;
  sourceLabel: string;
  sourceUrl?: string;
  actions: PinmonyDetailAction[];
  related: PinmonyRelatedPin[];
}

export interface PinmonyMediaReadResult { operation: number; status: string; error: string; }

export { PinmonyVideoSource, PinmonyVideo } from 'common_ui';
