export interface PinmonyCountry { key: string; name: string; }
export interface PinmonyAccountSettings {
  page: string;
  token: number;
  loading: boolean;
  error: string;
  saved: boolean;
  ready: boolean;
  email: string;
  confirmedEmail: boolean;
  birthdate: string;
  gender: string;
  customGender: string;
  country: string;
  countries: PinmonyCountry[];
  privateProfile: boolean;
  searchPrivacy: boolean;
  canChangePrivacy: boolean;
  canEditSearchPrivacy: boolean;
  autoplayWifi?: boolean;
  autoplayCellular?: boolean;
  topics: PinmonyAiTopic[];
  activities: PinmonyRecentActivity[];
  activityBookmark: string;
  activityHasMore: boolean;
}

export interface PinmonyAiTopic { key: string; text: string; enabled: boolean; }
export interface PinmonyRecentActivity { id: string; title: string; image: string; width: number; height: number; recommendationClosed: boolean; closeUncertain: boolean; }
