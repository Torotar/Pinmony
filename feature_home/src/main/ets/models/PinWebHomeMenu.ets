export interface PinWebHomeMenuOption {
  id: string;
  label: string;
  enabled: boolean;
}

export interface PinWebHomeMenuState {
  session: number;
  pinUrl: string;
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  options: PinWebHomeMenuOption[];
  actions: PinWebHomeMenuOption[];
}
