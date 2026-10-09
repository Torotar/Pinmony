import { PinImageSources, PinWebVideo } from 'common_ui';


export interface PinWebDetailAction {
  id: string;
  kind: string;
  label: string;
  countText: string;
  enabled: boolean;
  selected: boolean;
}

export interface PinWebRelatedPin {
  id: string;
  pinUrl: string;
  imageUrl: string;
  images?: PinImageSources;
  title: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinWebCarouselItem {
  id: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
}

export interface PinWebCarousel {
  pinId: string;
  items: PinWebCarouselItem[];
}

export interface PinWebDetailSnapshot {
  aiLabel?: string;
  originalImageUrl?: string;
  carousel?: PinWebCarousel;
  isVideo?: boolean;
  video?: PinWebVideo;
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
  actions: PinWebDetailAction[];
  related: PinWebRelatedPin[];
}

export { PinWebVideoSource, PinWebVideo } from 'common_ui';
