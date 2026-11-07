export interface PinmonyBoardInvitation {
  boardId: string;
  boardUrl: string;
  boardName: string;
  imageUrl: string;
  inviter: string;
  inviterUsername?: string;
  invitedUsername?: string;
  inviterAvatar: string;
  inviterAvatarColorIndex?: number;
  invitedName?: string;
  invitedAvatarColorIndex?: number;
  invitedUser: string;
  invitedAvatar: string;
  createdAt: string;
  status: string;
}
export interface PinmonyBoardInvitations {
  token: number;
  page: string;
  loading: boolean;
  busy: boolean;
  uncertain: boolean;
  error: string;
  feedback: string;
  items: PinmonyBoardInvitation[];
}
