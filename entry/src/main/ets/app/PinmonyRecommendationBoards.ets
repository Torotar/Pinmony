import { PinmonyRecommendationBoard } from 'feature_settings';

export interface RecommendationBoardWire {
  type: string; id: string; name: string; owner?: RecommendationBoardOwner;
  description?: string; privacy?: string; pin_count?: number; image_cover_url?: string;
  image_thumbnail_url?: string; images?: Record<string, RecommendationBoardImage[]>;
  board_order_modified_at?: string; last_pinned_to?: string; is_archived?: boolean;
  archived_by_me?: boolean; archived_by_me_at?: string;
  allow_homefeed_recommendations?: boolean; collaborator_invites_enabled?: boolean;
  collaborator_requests_enabled?: boolean;
}
interface RecommendationBoardOwner { id: string; }
interface RecommendationBoardImage { url: string; }
export interface RecommendationBoardChoice { id: string; enabled: boolean; }
export interface RecommendationBoardReadOptions { board_id: string; field_set_key: string; }
export interface RecommendationBoardUpdate {
  board_id: string; name: string; description: string; privacy: string;
  allow_homefeed_recommendations: boolean; collaborator_invites_enabled: boolean;
  collaborator_requests_enabled: boolean; sensitivity: null;
}
export interface RecommendationBoardsQuery {
  privacy_filter: string; sort: string; field_set_key: string; filter_stories: boolean;
  username: string; page_size: number; group_by: string; include_archived: boolean;
  filter_all_pins: boolean; bookmarks?: string[];
}
export function recommendationBoardImage(board: RecommendationBoardWire): string {
  const url: string = board.image_cover_url || board.image_thumbnail_url || board.images?.['170x']?.[0]?.url || board.images?.['236x']?.[0]?.url || '';
  return /^https:\/\/i\.pinimg\.com\/[^\s]+$/.test(url) ? url.slice(0, 4096) : '';
}
export function recommendationBoardRow(board: RecommendationBoardWire): PinmonyRecommendationBoard {
  const timestamp: number = Date.parse(board.last_pinned_to || board.board_order_modified_at || '');
  return { id: board.id, name: board.name.slice(0, 300), image: recommendationBoardImage(board),
    pinCount: Number.isSafeInteger(board.pin_count) && board.pin_count! >= 0 ? board.pin_count! : undefined,
    updatedAt: Number.isFinite(timestamp) && timestamp > 0 && timestamp <= Date.now() ? timestamp : 0 };
}
// Reuse the existing board edit contract. Never supply defaults for missing editable fields.
export function recommendationBoardUpdate(board: RecommendationBoardWire, id: string, viewer: string, enabled: boolean): RecommendationBoardUpdate {
  if (!board || board.type !== 'board' || board.id !== id || board.owner?.id !== viewer || board.is_archived === true || board.archived_by_me === true || !!board.archived_by_me_at ||
    typeof board.name !== 'string' || !board.name.trim() || board.name !== board.name.trim() || board.name.length > 300 ||
    typeof board.description !== 'string' || board.description.length > 500 || !['public', 'secret'].includes(board.privacy || '') ||
    typeof board.allow_homefeed_recommendations !== 'boolean' || typeof board.collaborator_invites_enabled !== 'boolean' ||
    typeof board.collaborator_requests_enabled !== 'boolean') throw new Error('board-edit');
  return { board_id: id, name: board.name, description: board.description, privacy: board.privacy!,
    allow_homefeed_recommendations: enabled, collaborator_invites_enabled: board.collaborator_invites_enabled,
    collaborator_requests_enabled: board.collaborator_requests_enabled, sensitivity: null };
}
