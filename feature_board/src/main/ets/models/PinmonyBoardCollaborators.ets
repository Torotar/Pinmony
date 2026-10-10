export interface PinmonyBoardCollaborator {
  id: string;
  name: string;
  username: string;
  avatar: string;
  status: string;
}
export interface PinmonyBoardCollaborators {
  owner?: boolean;
  canInvite?: boolean;
  token: number;
  page: string;
  phase: string;
  loading: boolean;
  busy: boolean;
  uncertain: boolean;
  error: string;
  feedback: string;
  permission: number;
  invites: boolean;
  users: PinmonyBoardCollaborator[];
  suggestions: PinmonyBoardCollaborator[];
}
