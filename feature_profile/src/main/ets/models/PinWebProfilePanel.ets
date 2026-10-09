export interface PinWebProfilePanelItem {
  id: string;
  name: string;
  avatar: string;
  profileUrl?: string;
  targetUrl?: string;
  covers?: string[];
  pinCount?: string;
  updated?: string;
  following: boolean;
  canFollow?: boolean;
}
export interface PinWebProfilePanel {
  page: string;
  mode: string;
  section: string;
  token: number;
  loading: boolean;
  error: string;
  items: PinWebProfilePanelItem[];
  hasMore?: boolean;
  firstName: string;
  lastName: string;
  about: string;
  website: string;
  username: string;
  avatar: string;
  avatarPreview?: string;
  avatarError?: string;
}
