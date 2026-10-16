import { PinmonyVideo } from 'common_ui';
export interface PinmonyHomeImageRecovery { pinUrl: string; imageUrl: string; revision: number; }
export interface PinmonyHomeTab {
  id: string;
  label: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinmonyHomeBoard {
  id: string;
  name: string;
  pinCount: number;
  thumbnailUrl: string;
}

export interface PinmonyHomePin {
  id: string;
  pinUrl: string;
  imageUrl: string;
  video?: PinmonyVideo;
  imageWidth: number;
  imageHeight: number;
  title: string;
  hasMore: boolean;
  saved?: boolean;
}

export interface PinmonyHomeSnapshot {
  kind: string;
  contextEpoch?: number;
  session: number;
  pageKey: string;
  selectedTab: string;
  tabs: PinmonyHomeTab[];
  board?: PinmonyHomeBoard;
  pins: PinmonyHomePin[];
  error?: string;
  dataSource?: string;
  loadingMore?: boolean;
  refreshing?: boolean;
  endReached?: boolean;
  sourceError?: string;
  categorySourceFailure?: boolean;
}

export interface PinmonyHomeTitle {
  kind: string;
  session: number;
  pageKey: string;
  pinUrl: string;
  title: string;
}
