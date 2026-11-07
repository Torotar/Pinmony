export interface PinmonyInboxItem {
  id: string;
  title: string;
  subtitle: string;
  activityUserId?: string;
  activityFollowed?: boolean;
  activityBusy?: boolean;
  activityUncertain?: boolean;
  outgoing?: boolean;
  usernames?: string[];
  imageUrl: string;
  profileUrl?: string;
  enabled: boolean;
  timeLabel?: string;
  updatedAt?: string;
  unread?: boolean;
  unreadCount?: number;
  moreId?: string;
  subdued?: boolean;
}

export interface PinmonyInboxSnapshot {
  contextEpoch?: number;
  kind: string;
  session: number;
  pageUrl: string;
  section: string;
  updateLabel: string;
  inboxLabel: string;
  emptyTitle: string;
  emptyDescription: string;
  homeLabel: string;
  homeId: string;
  composeLabel: string;
  composeId: string;
  contactsLabel: string;
  items: PinmonyInboxItem[];
  contacts: PinmonyInboxItem[];
  activities?: PinmonyInboxItem[];
  activityLoading?: boolean;
  activityError?: string;
  dataSource?: string;
  hasMore?: boolean;
  moreLoading?: boolean;
  moreError?: string;
  contactsDataSource?: string;
  contactsLoading?: boolean;
  contactsError?: string;
  messagesLabel?: string;
  readLabel?: string;
  unreadLabel?: string;
  apiError?: string;
}

