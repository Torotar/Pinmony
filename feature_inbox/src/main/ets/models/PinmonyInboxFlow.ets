export interface PinmonyInboxNewsCard {
  id: string;
  kind: string;
  title: string;
  image: string;
  imageWidth: number;
  imageHeight: number;
  target: string;
}
export interface InboxFlowUser {
  id: string;
  name: string;
  avatar: string;
  avatarColorIndex?: number;
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
  directContact?: boolean;
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
  recipientRestricted?: boolean;
  messageBusy?: boolean;
  canUnsubscribePin?: boolean;
  unsubscribedPin?: boolean;
  newsHidden?: boolean;
  newsUndoing?: boolean;
  newsId?: string;
  newsCards?: PinmonyInboxNewsCard[];
  newsEnded?: boolean;
  newsScrollOffset?: number;
  blocked?: boolean;
  blockedUserId?: string;
  blockRevision?: number;
}
