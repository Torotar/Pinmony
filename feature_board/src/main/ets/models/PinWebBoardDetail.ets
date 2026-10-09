export interface PinWebBoardPin {
  id: string;
  pinUrl: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
}

export interface PinWebBoardDetail {
  flow?: PinWebBoardFlow;
  editable?: boolean;
  memberAvatar?: string;
  nextPage?: string;
  revision?: number;
  kind: string;
  session: number;
  pageKey: string;
  boardId: string;
  title: string;
  pinCount: string;
  privacy?: string;
  ownerName: string;
  ownerAvatar: string;
  ownerUrl?: string;
  loading: boolean;
  loadingMore: boolean;
  refreshing?: boolean;
  ready: boolean;
  error: string;
  hasMore: boolean;
  pins: PinWebBoardPin[];
}

export interface PinWebBoardTarget {
  enabled: boolean;
  id: string;
  title: string;
  imageUrl: string;
}

export interface PinWebBoardFlow {
  phase: string;
  loading: boolean;
  busy: boolean;
  uncertain: boolean;
  error: string;
  description: string;
  privacy: string;
  recommend: boolean;
  invites: boolean;
  requests: boolean;
  pins: PinWebBoardPin[];
  targets: PinWebBoardTarget[];
  saved: string[];
  hasMore: boolean;
}
