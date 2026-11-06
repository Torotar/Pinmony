export interface PinmonyProfilePanelItem {
  id: string;
  name: string;
  avatar: string;
  privateProfile?: boolean;
  followerCount?: number;
  profileUrl?: string;
  username?: string;
  targetUrl?: string;
  covers?: string[];
  pinCount?: string;
  updated?: string;
  following: boolean;
  canFollow?: boolean;
  followStateKnown?: boolean;
  blocked?: boolean;
}
export interface PinmonyProfilePanel {
  page: string;
  mode: string;
  section: string;
  token: number;
  loading: boolean;
  refreshing?: boolean;
  error: string;
  items: PinmonyProfilePanelItem[];
  query?: string;
  nextCursor?: string;
  scrollOffset?: number;
  searchOpen?: boolean;
  searchScrollOffset?: number;
  hasMore?: boolean;
  moreLoading?: boolean;
  moreError?: string;
  firstName: string;
  lastName: string;
  about: string;
  website: string;
  username: string;
  avatar: string;
  avatarPreview?: string;
  avatarError?: string;
  avatarBusy?: boolean;
  avatarAction?: string;
}
