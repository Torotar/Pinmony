export interface PinmonyBoardPin {
  favorite?: boolean;
  id: string;
  pinUrl: string;
  imageUrl: string;
  previewImageUrl?: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
  cancelled?: boolean;
  creatorName?: string;
  duration?: string;
}

export interface PinmonyBoardDetail {
  favoriteOnly?: boolean;
  canFilterFavorites?: boolean;
  nativeAccountGeneration?: number;
  nativeWriteIntent?: number;
  nativeVersion?: number;
  nativeRecoveryVersion?: number;
  nativeReadsReady?: boolean;
  flow?: PinmonyBoardFlow;
  following?: boolean;
  followBusy?: boolean;
  canFollow?: boolean;
  editable?: boolean;
  featured?: boolean;
  featuredCreators?: PinmonyBoardCreator[];
  featuredCreator?: boolean;
  sponsored?: boolean;
  ownerVerified?: boolean;
  sectionCount?: number;
  sections?: PinmonyBoardSection[];
  sectionsError?: string;
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
  postOperationLoading?: boolean;
  ready: boolean;
  error: string;
  hasMore: boolean;
  pins: PinmonyBoardPin[];
}

export interface PinmonyBoardTarget {
  hasSections?: boolean;
  secret?: boolean;
  enabled: boolean;
  id: string;
  title: string;
  imageUrl: string;
}

export interface PinmonyBoardFlow {
  cover?: PinmonyBoardCoverState;
  coverImage?: string;
  coverPreview?: PinmonyBoardCoverPreview;
  targetBoardId?: string;
  targetSections?: PinmonyBoardSection[];
  phase: string;
  sectionId?: string;
  sectionTitle?: string;
  refreshing?: boolean;
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

export interface PinmonyBoardCoverPreview {
  imageUrl: string;
  width: string;
  height: string;
  left: string;
  top: string;
}

export interface PinmonyBoardCoverCrop {
  pinId: string;
  cropX: number;
  cropY: number;
  width: number;
  height: number;
  scale: number;
}

export interface PinmonyBoardCoverState {
  adjusting?: boolean;
  pins: PinmonyBoardPin[];
  selected?: PinmonyBoardCoverCrop;
  loading: boolean;
  hasMore: boolean;
  status: string;
  error: string;
}

export interface PinmonyBoardChatPeer { id: string; name: string; avatar: string; username: string; }
export interface PinmonyBoardCreator { id: string; name: string; avatar: string; url: string; verified: boolean; }

export interface PinmonyBoardSection { id: string; title: string; pinCount?: number; images: string[]; pins?: PinmonyBoardPin[]; }
