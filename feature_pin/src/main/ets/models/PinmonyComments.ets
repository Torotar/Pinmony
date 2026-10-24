export interface PinmonyComment {
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
  replies?: PinmonyComment[];
  repliesOpen?: boolean;
  repliesLoading?: boolean;
  repliesError?: string;
  canTranslate?: boolean;
  translationLoading?: boolean;
  translatedText?: string;
  translationVisible?: boolean;
  translationError?: string;
}

export interface PinmonyCommentResult {
  pin: string;
  loading: boolean;
  error: string;
  items: PinmonyComment[];
  ended?: boolean;
  actionError?: string;
  busy?: boolean;
  uncertain?: boolean;
  mutationVersion?: number;
}

export interface PinmonySaveBoard {
  hasSections?: boolean;
  id: string;
  name: string;
  imageUrl: string;
  enabled: boolean;
  secret: boolean;
}

export interface PinmonySaveResult {
  targetBoardId?: string;
  uncertain?: boolean;
  targetSections?: PinmonySaveBoard[];
  pin: string;
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  items: PinmonySaveBoard[];
  shortlist: PinmonySaveBoard[];
  savedId: string;
  savedBoard: string;
  suggestions?: string[];
}

export interface PinmonyPostResult {
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

export interface PinmonySaveOperationResult {
  operation: number;
  status: string;
  error: string;
}
