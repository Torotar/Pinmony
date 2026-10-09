export interface InboxFlowUser {
  id: string;
  name: string;
  avatar: string;
  profileUrl?: string;
  self?: boolean;
}
export interface InboxFlowMessage {
  id: string;
  text: string;
  image: string;
  pinUrl: string;
  createdAt: string;
  own: boolean;
  deleted?: boolean;
  reactions?: string[];
  sender?: InboxFlowUser;
}
export interface PinWebInboxFlowSnapshot {
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
  newsId?: string;
  blocked?: boolean;
  blockedUserId?: string;
  blockRevision?: number;
}
