import { PinmonyI18n } from 'common_foundation';
import { NotificationCategory, NotificationChannel, NotificationGroup, notificationGlobal } from './PinmonyNotifications';
const CATEGORY_COPY: Record<string, string> = {
  "published_comments": "pm_notify_category_published_comments",
  "published_reactions": "pm_notify_category_published_reactions",
  "published_saves": "pm_notify_category_published_saves",
  "views_and_impressions": "pm_notify_category_views_and_impressions",
  "published_collages": "pm_notify_category_published_collages",
  "saved_pin_comments": "pm_notify_category_saved_pin_comments",
  "saved_pin_mentions": "pm_notify_category_saved_pin_mentions",
  "saved_pin_reminders": "pm_notify_category_saved_pin_reminders",
  "saved_pin_tries": "pm_notify_category_saved_pin_tries",
  "group_board_updates": "pm_notify_category_group_board_updates",
  "group_board_invites": "pm_notify_category_group_board_invites",
  "messages": "pm_notify_category_messages",
  "followers": "pm_notify_category_followers",
  "homefeed_pins": "pm_notify_category_homefeed_pins",
  "pins_picked_for_you": "pm_notify_category_pins_picked_for_you",
  "based_on_activity": "pm_notify_category_based_on_activity",
  "board_recommendations": "pm_notify_category_board_recommendations",
  "search_recommendations": "pm_notify_category_search_recommendations",
  "followee_pins": "pm_notify_category_followee_pins",
  "shadow_followee_pins": "pm_notify_category_shadow_followee_pins",
  "shopping_recommendations": "pm_notify_category_shopping_recommendations",
  "pinterest_announcements": "pm_notify_category_pinterest_announcements",
  "surveys_and_quizzes": "pm_notify_category_surveys_and_quizzes",
  "reports_and_violations_center": "pm_notify_category_reports_and_violations_center",
  "shuffles_activity": "pm_notify_category_shuffles_activity"
};
const GROUP_COPY: Record<string, string> = {
  "pins-you-created": "pm_notify_group_created",
  "pins-you-saved": "pm_notify_group_saved",
  "social": "pm_notify_group_social",
  "recommendations": "pm_notify_group_recommendations",
  "others": "pm_notify_group_other",
  "permissions": "pm_notify_group_delivery",
  "permissions-biz": "pm_notify_group_delivery",
  "created": "pm_notify_group_created",
  "saved": "pm_notify_group_saved",
  "other": "pm_notify_group_other",
  "delivery": "pm_notify_group_delivery",
  "social-activity": "pm_notify_group_social",
  "other-notifications": "pm_notify_group_other",
  "how-you-get-notifications": "pm_notify_group_delivery"
};
// Presentation only. Never derive a write contract or enabled state from translated text.
export class PinmonyNotificationCopy {
  static group(group: NotificationGroup, language: string): string {
    const first: string = group.categories.length ? PinmonyNotificationCopy.option(group.categories[0]) : '';
    const inferred: string = first.startsWith('published_') ? 'created' : first.startsWith('saved_pin_') ? 'saved' :
      ['group_board_updates', 'group_board_invites', 'messages', 'followers'].includes(first) ? 'social' :
      ['homefeed_pins', 'pins_picked_for_you', 'based_on_activity', 'board_recommendations', 'search_recommendations', 'followee_pins', 'shadow_followee_pins', 'shopping_recommendations'].includes(first) ? 'recommendations' :
      ['pinterest_announcements', 'surveys_and_quizzes', 'reports_and_violations_center', 'shuffles_activity'].includes(first) ? 'other' : '';
    const key: string = GROUP_COPY[group.key] || GROUP_COPY[inferred];
    return key ? PinmonyI18n.text(key, language) : group.label;
  }
  private static option(category: NotificationCategory): string {
    return CATEGORY_COPY[category.key] ? category.key : category.channels.find((channel: NotificationChannel): boolean => !!CATEGORY_COPY[channel.option || ''])?.option || '';
  }
  static category(category: NotificationCategory, language: string): string {
    if (category.key === 'global') return PinmonyI18n.text('pm_notify_group_delivery', language);
    const key: string = CATEGORY_COPY[PinmonyNotificationCopy.option(category)];
    return key ? PinmonyI18n.text(key, language) : category.label;
  }
  static channel(channel: NotificationChannel, language: string): string {
    const key: string = channel.channel === 'push' ? 'push' : channel.channel === 'email' ? 'email' : channel.channel === 'news' ? 'news' : '';
    return key ? PinmonyI18n.text('pm_notify_' + key, language) : channel.label;
  }
  static summary(category: NotificationCategory, language: string): string {
    return category.channels.map((channel: NotificationChannel, index: number): string => (language === 'en' && index > 0 ? PinmonyNotificationCopy.channel(channel, language).toLowerCase() : PinmonyNotificationCopy.channel(channel, language)) + ' ' + PinmonyI18n.text(channel.value ? 'pm_notify_on' : 'pm_notify_off', language)).join(language === 'en' ? ', ' : '，');
  }
  static description(category: NotificationCategory, language: string): string {
    const option: string = PinmonyNotificationCopy.option(category);
    const key: string = CATEGORY_COPY[option] ? 'pm_notify_description_' + option : category.key === 'global' ? 'pm_notify_global_description' : '';
    return key ? PinmonyI18n.text(key, language) : category.description;
  }
}
