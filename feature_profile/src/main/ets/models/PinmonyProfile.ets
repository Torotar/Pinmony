export interface PinmonyProfileAction {
  id: string;
  kind: string;
  label: string;
  enabled: boolean;
}

export interface PinmonyBoard {
  id: string;
  targetUrl?: string;
  title: string;
  covers: string[];
  collaboratorAvatars?: string[];
  pinCount: string;
  updated: string;
}

export interface PinmonyCreatedPin {
  id: string;
  targetUrl?: string;
  title: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinmonyOrganizeBoard {
  id: string;
  title: string;
  imageUrl: string;
  secret: boolean;
  enabled: boolean;
}

export interface PinmonyOrganizeSnapshot {
  phase: string;
  selectedIds: string[];
  boards: PinmonyOrganizeBoard[];
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  hasMore: boolean;
  uncertain: boolean;
}

export interface PinmonyProfileSnapshot {
  kind: string;
  session: number;
  profileUrl: string;
  section: string;
  displayName: string;
  handle: string;
  avatarUrl: string;
  business?: boolean;
  isOwn?: boolean;
  about?: string;
  website?: string;
  followers: string;
  following: string;
  actions: PinmonyProfileAction[];
  boards: PinmonyBoard[];
  createdPins: PinmonyCreatedPin[];
  contentLoading?: boolean;
  contentLoadingMore?: boolean;
  contentError?: string;
  unorganizedPins?: PinmonyCreatedPin[];
  unorganizedLoading?: boolean;
  unorganizedError?: string;
  unorganizedHasMore?: boolean;
  unorganizedFeedback?: string;
  organize?: PinmonyOrganizeSnapshot;
}

export interface PinmonyPublishOption {
  id: string;
  kind: string;
  group: string;
  groupLabel: string;
  label: string;
  enabled: boolean;
}

export interface PinmonyPublishSnapshot {
  kind: string;
  session: number;
  profileUrl: string;
  title: string;
  options: PinmonyPublishOption[];
}
