export interface PinWebCountry { key: string; name: string; }
export interface PinWebAccountSettings {
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
  countries: PinWebCountry[];
  privateProfile: boolean;
  searchPrivacy: boolean;
  canChangePrivacy: boolean;
  canEditSearchPrivacy: boolean;
  topics: PinWebAiTopic[];
  activities: PinWebRecentActivity[];
  activityBookmark: string;
  activityHasMore: boolean;
}

export interface PinWebAiTopic { key: string; text: string; enabled: boolean; }
export interface PinWebRecentActivity { id: string; title: string; image: string; width: number; height: number; recommendationClosed: boolean; closeUncertain: boolean; }
