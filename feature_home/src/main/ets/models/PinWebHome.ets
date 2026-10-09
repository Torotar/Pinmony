import { PinWebVideo } from 'common_ui';
export interface PinWebHomeTab {
  id: string;
  label: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinWebHomeBoard {
  id: string;
  name: string;
  pinCount: number;
  thumbnailUrl: string;
}

export interface PinWebHomePin {
  id: string;
  pinUrl: string;
  imageUrl: string;
  video?: PinWebVideo;
  imageWidth: number;
  imageHeight: number;
  title: string;
  hasMore: boolean;
  saved?: boolean;
}

export interface PinWebHomeSnapshot {
  kind: string;
  session: number;
  pageKey: string;
  selectedTab: string;
  tabs: PinWebHomeTab[];
  board?: PinWebHomeBoard;
  pins: PinWebHomePin[];
  error?: string;
  dataSource?: string;
  loadingMore?: boolean;
  refreshing?: boolean;
  endReached?: boolean;
  sourceError?: string;
  categorySourceFailure?: boolean;
}

export interface PinWebHomeTitle {
  kind: string;
  session: number;
  pageKey: string;
  pinUrl: string;
  title: string;
}
