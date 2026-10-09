export interface PinWebProfileAction {
  id: string;
  kind: string;
  label: string;
  enabled: boolean;
}

export interface PinWebBoard {
  id: string;
  targetUrl?: string;
  title: string;
  covers: string[];
  pinCount: string;
  updated: string;
}

export interface PinWebCreatedPin {
  id: string;
  targetUrl?: string;
  title: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinWebOrganizeBoard {
  id: string;
  title: string;
  imageUrl: string;
  secret: boolean;
  enabled: boolean;
}

export interface PinWebOrganizeSnapshot {
  phase: string;
  selectedIds: string[];
  boards: PinWebOrganizeBoard[];
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  hasMore: boolean;
  uncertain: boolean;
}

export interface PinWebProfileSnapshot {
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
  actions: PinWebProfileAction[];
  boards: PinWebBoard[];
  createdPins: PinWebCreatedPin[];
  contentLoading?: boolean;
  contentLoadingMore?: boolean;
  contentError?: string;
  unorganizedPins?: PinWebCreatedPin[];
  unorganizedLoading?: boolean;
  unorganizedError?: string;
  unorganizedHasMore?: boolean;
  unorganizedFeedback?: string;
  organize?: PinWebOrganizeSnapshot;
}

export interface PinWebPublishOption {
  id: string;
  kind: string;
  group: string;
  groupLabel: string;
  label: string;
  enabled: boolean;
}

export interface PinWebPublishSnapshot {
  kind: string;
  session: number;
  profileUrl: string;
  title: string;
  options: PinWebPublishOption[];
}
