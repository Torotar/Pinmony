export interface NotificationChannel { label: string; value: boolean; channel?: string; section?: string; option?: string; editable?: boolean; }
export interface NotificationChoice { type: string; section: string; option: string; value: boolean; }
// Exact personal-account opt-out contracts observed in 通知接口补充.har.
export function notificationGlobal(type: string, section: string, option: string): boolean {
  return type === 'push' && section === 'settings_push_everything' && option === 'NO_PUSH' ||
    type === 'email' && section === 'settings_email_everything' && option === 'ONLY_REQUIRED' ||
    type === 'news' && section === 'settings_news' && option === 'NONE_IN_APP';
}
// Only combinations confirmed by notification HARs; never infer business-account aliases.
export function notificationWritable(type: string, section: string, option: string): boolean {
  const saved: string[] = ['saved_pin_comments','saved_pin_mentions','saved_pin_reminders','saved_pin_tries'];
  const push: string[] = ['based_on_activity','board_recommendations','followee_pins','followers','group_board_invites','group_board_updates','messages','pins_picked_for_you','published_collages','published_comments','published_reactions','published_saves','search_recommendations','shadow_followee_pins','shopping_recommendations','views_and_impressions'];
  const email: string[] = ['based_on_activity','board_recommendations','followers','group_board_updates','messages','pins_picked_for_you','shopping_recommendations'];
  const news: string[] = ['based_on_activity','board_recommendations','followee_pins','group_board_updates','messages','pins_picked_for_you','published_comments','published_reactions','search_recommendations','shadow_followee_pins','shopping_recommendations','views_and_impressions'];
  return notificationGlobal(type, section, option) ||
    type === 'push' && section === 'settings_push_v2' && (push.includes(option) || saved.includes(option) || option === 'homefeed_pins') ||
    type === 'email' && section === 'settings_email_v2' && (email.includes(option) || ['homefeed_pins','search_recommendations','pinterest_announcements','surveys_and_quizzes','reports_and_violations_center','shuffles_activity'].includes(option)) ||
    type === 'news' && section === 'settings_news_categories' && (news.includes(option) || saved.includes(option) || option === 'homefeed_pins');
}
export interface NotificationCategory { key: string; label: string; description: string; summary: string; channels: NotificationChannel[]; }
export interface NotificationGroup { key: string; label: string; categories: NotificationCategory[]; }
export interface NotificationResult { groups: NotificationGroup[]; error: string; }
