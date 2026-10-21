export interface PinmonyProfileSearchPin {
  id: string;
  image: string;
  title: string;
}

export interface PinmonyProfileSearchSuggestion {
  query: string;
  pins: PinmonyProfileSearchPin[];
  deleting?: boolean;
  deletable?: boolean;
}

export interface PinmonyProfileSearchSnapshot {
  query: string;
  submitted: string;
  editing: boolean;
  loading: boolean;
  error: string;
  suggestions: PinmonyProfileSearchSuggestion[];
  pins: PinmonyProfileSearchPin[];
  ended: boolean;
}
