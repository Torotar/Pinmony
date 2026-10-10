export interface ShareSheetOption {
  id: string;
  label: string;
  icon: string;
  enabled: boolean;
  subtitle?: string;
  beforeSection?: boolean;
}

export interface ShareSheetMessage {
  error?: string;
  kind: string;
  session: number;
  pinUrl?: string;
  pinDetail?: boolean;
  title?: string;
  sectionLabel?: string;
  options?: ShareSheetOption[];
  actions?: ShareSheetOption[];
  searchId?: string;
  searchLabel?: string;
  searchActive?: boolean;
  query?: string;
  contacts?: ShareSheetOption[];
  sendId?: string;
  sendLabel?: string;
  feedback?: string;
}

export interface MoreSheetOption {
  id: string;
  label: string;
  subtitle: string;
  icon: string;
  group: number;
  enabled: boolean;
}

export interface MoreSheetMessage {
  kind: string;
  session: number;
  pin: string;
  title?: string;
  options?: MoreSheetOption[];
}

