export interface InboxFlowUser {
  id: string;
  name: string;
  avatar: string;
  profileUrl?: string;
  self?: boolean;
}
export interface InboxFlowBoard {
  id: string;
  title: string;
  url: string;
  images: string[];
  cover: string;
  pinCount?: number;
  sectionCount?: number;
}
export interface InboxFlowMessage {
  id: string;
  text: string;
  image: string;
  imageWidth?: number;
  imageHeight?: number;
  pinUrl: string;
  createdAt: string;
  own: boolean;
  deleted?: boolean;
  reactions?: string[];
  sender?: InboxFlowUser;
  profile?: InboxFlowUser;
  profileImages?: string[];
  board?: InboxFlowBoard;
}
export interface PinmonyInboxFlowSnapshot {
  nativeAccountGeneration?: number;
  writeUncertain?: boolean;
  writeAction?: string;
  writeTarget?: string;
  contextEpoch?: number;
  nativeToken?: number;
  nativeRead?: boolean;
  kind: string;
  pageUrl: string;
  session: number;
  screen: string;
  title: string;
  loading: boolean;
  error: string;
  users: InboxFlowUser[];
  messages: InboxFlowMessage[];
  selectedIds: string[];
  hasMore: boolean;
  conversationId?: string;
  sending?: boolean;
  sentRevision?: number;
  sendError?: string;
  messageBusy?: boolean;
  canUnsubscribePin?: boolean;
  unsubscribedPin?: boolean;
  newsHidden?: boolean;
  newsUndoing?: boolean;
  newsId?: string;
  blocked?: boolean;
  blockedUserId?: string;
  blockRevision?: number;
}
