export interface PinmonyBoardPin {
  id: string;
  pinUrl: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
  cancelled?: boolean;
}

export interface PinmonyBoardDetail {
  flow?: PinmonyBoardFlow;
  editable?: boolean;
  featured?: boolean;
  subtitle?: string;
  description?: string;
  headerImage?: string;
  collaborator?: boolean;
  chatMemberCount?: number;
  chatPeer?: PinmonyBoardChatPeer;
  canContribute?: boolean;
  collaboratorAvatars?: string[];
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
  pins: PinmonyBoardPin[];
}

export interface PinmonyBoardTarget {
  enabled: boolean;
  id: string;
  title: string;
  imageUrl: string;
}

export interface PinmonyBoardFlow {
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
  pins: PinmonyBoardPin[];
  targets: PinmonyBoardTarget[];
  saved: string[];
  hasMore: boolean;
}

export interface PinmonyBoardChatPeer { id: string; name: string; avatar: string; username: string; }
