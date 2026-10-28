import { PinmonyCreatedPin, PinmonyOrganizeSnapshot, PinmonyOrganizeBoard } from './PinmonyProfile';

export interface PinmonyPublishTopic { id: string; text: string; }

export interface PinmonyPublishDraft {
  aiModified?: boolean;
  aiGeneratedPerson?: boolean;
  expiresAt?: number;
  id: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  title: string;
  description: string;
  link: string;
  boardId?: string;
  sectionId?: string;
  topics?: PinmonyPublishTopic[];
  altText?: string;
  allowComments?: boolean;
  allowShopping?: boolean;
  accountCommentsEnabled?: boolean;
  accountShoppingRecommendationsEnabled?: boolean;
  products?: PinmonyCreatedPin[];
  storyPin?: Object;
}

export interface PinmonyPublishFlow extends PinmonyOrganizeSnapshot {
  token: number;
  page: string;
  profile: string;
  kind: string;
  pins: PinmonyCreatedPin[];
  completed: number;
  accountCommentsEnabled?: boolean;
  accountShoppingRecommendationsEnabled?: boolean;
  boardCreated?: boolean;
  productCreated?: boolean;
  photoTitle?: string;
  photoDescription?: string;
  photoLink?: string;
  fromDraftBox?: boolean;
  selectedBoardId?: string;
  selectedSectionId?: string;
  sectionBoardId?: string;
  sections?: PinmonyOrganizeBoard[];
  selectedTopics?: PinmonyPublishTopic[];
  topicDraft?: PinmonyPublishTopic[];
  topicResults?: PinmonyPublishTopic[];
  topicQuery?: string;
  topicLoading?: boolean;
  topicError?: string;
  productResults?: PinmonyCreatedPin[];
  selectedProducts?: PinmonyCreatedPin[];
  productImageId?: string;
  productQuery?: string;
  productSuggestions?: string[];
  productSuggesting?: boolean;
  productMode?: string;
  productLoading?: boolean;
  productError?: string;
  allowComments?: boolean;
  allowShopping?: boolean;
  altText?: string;
  aiModified?: boolean;
  aiGeneratedPerson?: boolean;
  drafts?: PinmonyPublishDraft[];
  draftLoading?: boolean;
  draftError?: string;
  draftId?: string;
  editingDraft?: boolean;
  draftStoryPin?: Object;
  draftSaved?: boolean;
  draftExitRequested?: boolean;
}
