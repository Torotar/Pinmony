import { PinWebVideo } from 'common_ui';
export interface PinWebSearchCategory {
  targetUrl?: string;
  imageUrl?: string;
  backgroundColor?: string;
  id: string;
  label: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinWebSearchFilterOption {
  id: string;
  label: string;
  group: string;
  selected: boolean;
  enabled: boolean;
}

export interface PinWebSearchFilterSnapshot {
  status?: string;
  options: PinWebSearchFilterOption[];
  loading: boolean;
  error: string;
}

export interface PinWebSearchSuggestion {
  query?: string;
  historyType?: string;
  deletable?: boolean;
  deleting?: boolean;
  id: string;
  label: string;
  enabled: boolean;
}

export interface PinWebSearchResult {
  id: string;
  kind: string;
  title: string;
  subtitle: string;
  targetUrl: string;
  imageUrl: string;
  video?: PinWebVideo;
  imageWidth: number;
  imageHeight: number;
  enabled: boolean;
}

export interface PinWebSearchHero {
  id: string;
  title: string;
  subtitle: string;
  imageUrl: string;
  enabled: boolean;
}

export interface PinWebSearchIdea {
  targetUrl?: string;
  id: string;
  title: string;
  imageUrl: string;
  enabled: boolean;
}

export interface PinWebSearchIdeaSection {
  targetUrl?: string;
  id: string;
  eyebrow: string;
  title: string;
  actionId: string;
  items: PinWebSearchIdea[];
}

export interface PinWebSearchSnapshot {
  suggestionBusy?: boolean;
  suggestionError?: string;
  inputReady?: boolean;
  quiz?: PinWebSearchQuiz;
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
  categories: PinWebSearchCategory[];
  suggestions: PinWebSearchSuggestion[];
  heroes: PinWebSearchHero[];
  ideaSections: PinWebSearchIdeaSection[];
  results: PinWebSearchResult[];
}

export interface PinWebSearchQuizTopic {
  id: string;
  query: string;
  imageUrl: string;
}
export interface PinWebSearchQuizCard {
  imageWidth?: number;
  imageHeight?: number;
  id: string;
  title: string;
  imageUrl: string;
  targetUrl: string;
  selected: boolean;
}
export interface PinWebSearchQuiz {
  entryTitle?: string;
  canMore: boolean;
  mode: string;
  title: string;
  eyebrow: string;
  pickerTitle: string;
  submitLabel: string;
  topics: PinWebSearchQuizTopic[];
  cards: PinWebSearchQuizCard[];
  count: number;
  busy: boolean;
  error: string;
}
