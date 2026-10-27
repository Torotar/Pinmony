export interface PinmonyProfileAction {
  id: string;
  kind: string;
  label: string;
  enabled: boolean;
}

export interface PinmonyBoard {
  sortable?: boolean;
  mergeable?: boolean;
  secret?: boolean;
  protectedBoard?: boolean;
  id: string;
  targetUrl?: string;
  title: string;
  covers: string[];
  coverAlternatives?: string[];
  collaboratorAvatars?: string[];
  pinCount: string;
  updated: string;
}

export interface PinmonyCreatedPin {
  collageDraft?: boolean;
  id: string;
  targetUrl?: string;
  favorite?: boolean;
  title: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
}

export interface PinmonyOrganizeBoard {
  hasSections?: boolean;
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
  suggestionTitle?: string;
  suggestionWriting?: boolean;
  suggestionUnavailableIds?: string[];
  suggestions?: PinmonyBoard[];
  suggestionError?: string;
  hubMode?: string;
  hubFavorite?: boolean;
  hubCreated?: boolean;
  boardSort?: string;
  showAllPins?: boolean;
  visibilityBusy?: boolean;
  visibilityError?: string;
  boardSortBusy?: boolean;
  boardSortPending?: string;
  boardSortError?: string;
  contextEpoch?: number;
  nativeOwn?: boolean;
  nativeVersion?: number;
  nativeInvalidation?: number;
  contentHasMore?: boolean;
  kind: string;
  session: number;
  profileUrl: string;
  section: string;
  displayName: string;
  handle: string;
  avatarUrl: string;
  coverUrl?: string;
  business?: boolean;
  isOwn?: boolean;
  about?: string;
  website?: string;
  monthlyViews?: number;
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
