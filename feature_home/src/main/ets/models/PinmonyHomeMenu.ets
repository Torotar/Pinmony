export interface PinmonyHomeMenuOption {
  id: string;
  label: string;
  enabled: boolean;
}

export interface PinmonyHomeMenuState {
  session: number;
  pinUrl: string;
  loading: boolean;
  busy: boolean;
  error: string;
  feedback: string;
  options: PinmonyHomeMenuOption[];
  actions: PinmonyHomeMenuOption[];
}
