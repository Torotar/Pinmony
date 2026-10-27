export interface SocialMessageGroup { id: number; levels: number[]; selected: number; }
export interface SocialBlockedUser { id: string; username: string; name: string; image: string; }
export interface SocialPermissions { business: boolean; personal: boolean; mentions?: number; groups: SocialMessageGroup[]; blocked: SocialBlockedUser[]; ready: boolean; blockedReady: boolean; blockedComplete?: boolean; protected: boolean; commentsEnabled?: boolean; shoppingRecommendationsEnabled?: boolean; ideaPinDownloadsEnabled?: boolean; myCommentFilterEnabled?: boolean; otherCommentFilterEnabled?: boolean; myCommentFilterPhrases?: string[]; otherCommentFilterPhrases?: string[]; }
export interface SocialMessageChoice { group: number; level: number; }
export interface SocialSettingsResponse { id: string; is_partner?: boolean; allow_mentions?: number; messaging_permissions?: SocialMessageResponse[]; comments_disabled?: number; shopping_rec_disabled?: boolean; allow_idea_pin_downloads?: boolean; is_parental_control_passcode_enabled?: boolean; is_parental_control_passcode_verification_pending?: boolean; }
export interface SocialCommentFilterResponse { comments_phrase_filter_list?: string[]; comments_phrase_filter_list_enabled?: boolean; pinner_comments_phrase_filter_list?: string[]; pinner_comments_phrase_filter_list_enabled?: boolean; }
export interface SocialMessageResponse { group_id: number; eligible_levels: number[]; selected_level: number; }
export function emptySocialPermissions(): SocialPermissions { return { business: false, personal: false, groups: [], blocked: [], ready: false, blockedReady: false, blockedComplete: false, protected: true }; }
export function socialMessagePath(group: number): string {
  return group === 0 ? 'friends' : group === 1 ? 'followers' : group === 2 ? 'following' : group === 4 ? 'others' : '';
}
export function socialMessageLevel(group: number, level: number): boolean {
  return !!socialMessagePath(group) && [0,1,2].includes(level) && (group !== 4 || level !== 0);
}
