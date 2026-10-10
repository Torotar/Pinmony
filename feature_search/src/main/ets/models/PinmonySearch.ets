import { PinmonyVideo } from 'common_ui';
export interface PinmonySearchCategory {
  targetUrl?: string;
  imageUrl?: string;
  backgroundColor?: string;
  id: string;
  label: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinmonySearchFilterOption {
  id: string;
  label: string;
  group: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinmonySearchFilterSnapshot {
  status?: string;
  options: PinmonySearchFilterOption[];
  loading: boolean;
  error: string;
}

export interface PinmonySearchSuggestion {
  query?: string;
  historyType?: string;
  deletable?: boolean;
  deleting?: boolean;
  id: string;
  label: string;
  enabled: boolean;
}

export interface PinmonySearchResult {
  id: string;
  kind: string;
  title: string;
  subtitle: string;
  targetUrl: string;
  imageUrl: string;
  video?: PinmonyVideo;
  imageWidth: number;
  imageHeight: number;
  enabled: boolean;
}

export interface PinmonySearchHero {
  targetUrl?: string;
  id: string;
  title: string;
  subtitle: string;
  imageUrl: string;
  enabled: boolean;
}

export interface PinmonySearchIdea {
  targetUrl?: string;
  id: string;
  title: string;
  imageUrl: string;
  enabled: boolean;
}

export interface PinmonySearchIdeaSection {
  targetUrl?: string;
  id: string;
  eyebrow: string;
  title: string;
  actionId: string;
  items: PinmonySearchIdea[];
}

export interface PinmonySearchSnapshot {
  suggestionBusy?: boolean;
  suggestionError?: string;
  inputReady?: boolean;
  quiz?: PinmonySearchQuiz;
  discoveryApi?: boolean;
  discoveryBusy?: boolean;
  discoveryError?: string;
  discoveryActive?: boolean;
  discoveryEnded?: boolean;
  api?: boolean;
  apiError?: string;
  apiBusy?: boolean;
  apiActive?: boolean;
  apiEnded?: boolean;
  kind: string;
  session: number;
  pageKey: string;
  query: string;
  placeholder: string;
  selectedCategory: string;
  categories: PinmonySearchCategory[];
  suggestions: PinmonySearchSuggestion[];
  heroes: PinmonySearchHero[];
  ideaSections: PinmonySearchIdeaSection[];
  results: PinmonySearchResult[];
}

export interface PinmonySearchQuizTopic {
  id: string;
  query: string;
  imageUrl: string;
}
export interface PinmonySearchQuizCard {
  imageWidth?: number;
  imageHeight?: number;
  id: string;
  title: string;
  imageUrl: string;
  targetUrl: string;
  selected: boolean;
}
export interface PinmonySearchQuiz {
  entryTitle?: string;
  canMore: boolean;
  mode: string;
  title: string;
  eyebrow: string;
  pickerTitle: string;
  submitLabel: string;
  topics: PinmonySearchQuizTopic[];
  cards: PinmonySearchQuizCard[];
  count: number;
  busy: boolean;
  error: string;
}
