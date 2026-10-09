export interface PinWebComment {
  id: string;
  text: string;
  name: string;
  avatar: string;
  profileUrl?: string;
  createdAt: string;
  type?: string;
  canEdit?: boolean;
  canDelete?: boolean;
  canReply?: boolean;
  imageUrl?: string;
  likeCount?: number;
  liked?: boolean;
  canLike?: boolean;
  busy?: boolean;
  replyCount?: number;
  replies?: PinWebComment[];
  repliesOpen?: boolean;
  repliesLoading?: boolean;
  repliesError?: string;
}

export interface PinWebCommentResult {
  pin: string;
  loading: boolean;
  error: string;
  items: PinWebComment[];
  ended?: boolean;
  actionError?: string;
  busy?: boolean;
  uncertain?: boolean;
  mutationVersion?: number;
}

export interface PinWebSaveBoard {
  id: string;
  name: string;
  imageUrl: string;
  enabled: boolean;
  secret: boolean;
}

export interface PinWebSaveResult {
  pin: string;
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  items: PinWebSaveBoard[];
  shortlist: PinWebSaveBoard[];
  savedId: string;
  savedBoard: string;
  suggestions?: string[];
}

export interface PinWebPostResult {
  objectId?: string;
  kind: string;
  pinUrl: string;
  value: string;
  session: number;
  scope: string;
  platform?: string;
  targetUrl?: string;
  title?: string;
}
