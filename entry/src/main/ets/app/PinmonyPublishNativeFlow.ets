import { PinmonyStoryPublish } from './PinmonyStoryPublish';
import { savePinmonyDraft, PinmonyDraftSavedResult, PinmonyDraftNotSubmittedError } from './PinmonyDraftSave';
import { PinmonyI18n } from 'common_foundation';
import { PinmonyProfileStore, PinmonyPublishFlow, PinmonyPublishTopic, PinmonyPublishPhoto, PinmonyCreatedPin, PinmonyOrganizeBoard, PinmonyPublishDraft } from 'feature_profile';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonySharePublishClient, PinmonySharePublishClientPorts, PinmonySharePublishOwner, PinmonyBusinessRejection } from './PinmonySharePublishClient';
interface PublishSectionPreview { image_medium_url?: string; images?: Record<string,Image>; }
interface PublishSection { preview_pins?: PublishSectionPreview[]; id: string; type: string; title: string; board: Board; }
interface PublishSectionsData { fields: string[]; orbac_subject_id: string; }
interface PublishSectionsOptions { url: string; data: PublishSectionsData; }
interface PublishSectionsResource { status: string; code: number; endpoint_name: string; error?: Object; data: PublishSection[]; }
interface PublishSectionsResponse { resource_response: PublishSectionsResource; client_context?: Client; }
interface Image {
    url: string;
    width?: number;
    height?: number;
}
interface PublishSuggestionOptions { field_set_key: string; limit: number; num_recent_queries: number; personal_search_only: boolean; pin_scope: string; recent_queries_tags: string; term: string; autocomplete_request_surface: number; }
interface PublishSuggestionRow { query?: string; display_query?: string; label?: string; }
interface PublishSuggestionData { items?: PublishSuggestionRow[]; }
interface PublishSuggestionResource { status: string; code: number; error?: Object; data?: PublishSuggestionData; }
interface PublishSuggestionResponse { resource_response: PublishSuggestionResource; client_context?: Client; }
interface ProductSearchOptions { enable_promoted_pins: boolean; query: string; scope: string; }
interface ProductFindOptions { url: string; data: ProductFindData; }
interface ProductFindData { url: string; source: string; }
interface ProductResult { id: string; type: string; title?: string; link?: string; images?: Record<string,Image>; }
interface ProductData { results?: ProductResult[]; images?: string[]; title?: string; landing_url?: string; }
interface ProductResponse { resource_response: ProductResource; client_context?: Client; }
interface ProductResource { status: string; code: number; endpoint_name?: string; error?: Object; data?: ProductData; }
interface User {
    id: string;
    type: string;
    username: string;
}
interface Board {
    section_count?: number;
    id: string;
    type: string;
    name: string;
    privacy: string;
    owner?: User;
    access?: string[];
    archived_by_me?: boolean;
    archived_by_me_at?: string;
    image_cover_hd_url?: string;
    image_cover_url?: string;
}
interface Scraped {
    type: string;
    url: string;
    link?: string;
}
interface Data {
    id?: string;
    type?: string;
    username?: string;
    name?: string;
    privacy?: string;
    owner?: User;
    access?: string[];
    archived_by_me?: boolean;
    archived_by_me_at?: string;
    image_cover_hd_url?: string;
    image_cover_url?: string;
    all_boards?: Board[];
    items?: Scraped[];
    results?: PinmonyPublishTopic[];
    comments_disabled?: boolean;
    did_it_disabled?: boolean;
    alt_text?: string;
    description?: string;
    ai_disclosures?: number[];
    title?: string;
    destination_url?: string;
    board?: Board;
    board_section?: Board;
    pinner?: User;
    is_repin?: boolean;
    images?: Record<string, Image>;
}
interface PublishAccountSettings { id: string; comments_disabled?: number; shopping_rec_disabled?: boolean; }
interface PublishAccountEmptyData {}
interface PublishAccountOptions { url: string; data: PublishAccountEmptyData; }
interface PublishAccountResource { status: string; code: number; endpoint_name?: string; error?: Object; data: PublishAccountSettings; }
interface PublishAccountResponse { resource_response: PublishAccountResource; client_context?: Client; }
interface TopicSearchData { language: string; query: string; corpus: string; limit: number; min_level: number; }
interface TopicSearchOptions { url: string; data: TopicSearchData; }
interface TopicWriteData { interest_ids: string[]; data_source: string; zen_source: number; }
interface TopicWriteOptions { url: string; data: TopicWriteData; }
interface AdvancedPinOptions { pin_additional_note: string; alt_text: string; board_id: string; board_section_id: string; description: string; disable_comments: boolean; disable_did_it: boolean; id: string; is_shuffle_remixable: boolean; link: string; shopping_rec_disabled: boolean; title: string; user_mention_tags: string; product_pins: string[]; idea_pin_details_template_type: null; }
interface EditCreatedPinOptions { id: string; board_id: string; board_section_id: string; ai_disclosures: number[]; title: string; description: string; }
interface Resource {
    status: string;
    code: number;
    endpoint_name?: string;
    error?: Object;
    data: Data;
}
interface Response {
    resource_response: Resource;
    client_context?: Client;
}
interface Client {
    is_authenticated?: boolean;
    user?: User;
}
interface DraftImages { images?: Record<string, Image>; }
interface DraftImageBlock { block_type?: number; type?: string; image?: DraftImages; }
interface DraftPage { blocks?: DraftImageBlock[]; }
interface DraftTopic { id: string; value?: string; tagValue?: string; }
interface DraftMetadata { pin_title?: string; }
interface PinmonyDraftTaggedProduct { product_id?: string; pin_id?: string; link?: string; status?: string; media?: Image; }
interface DraftRecord { ai_disclosures?: number[]; created_at?: string; id?: string; pin_title?: string; pin_description?: string; link?: string; board_id?: string; section_id?: string; topic_tags?: DraftTopic[]; tagged_products?: PinmonyDraftTaggedProduct[]; alt_text?: string; is_comments_allowed?: boolean; is_shopping_rec_allowed?: boolean; }
interface DraftData {
    id?: string;
    pages?: DraftPage[];
    metadata?: DraftMetadata;
    draft?: DraftRecord;
}
interface DraftFeedResource { status: string; code: number; endpoint_name?: string; error?: Object; data: DraftData[]; }
interface DraftFeedResponse { resource_response: DraftFeedResource; client_context?: Client; }
interface DraftFields { fields: string[]; page_size: number; user: string; }
interface PublishDraftDeleteOptions { url: string; data: PublishAccountEmptyData; }
interface PublishDraftDeleteResource { status: string; code: number; endpoint_name?: string; error?: Object; data: boolean; }
interface PublishDraftDeleteResponse { resource_response: PublishDraftDeleteResource; client_context?: Client; }
interface DraftRequestOptions { url: string; data: DraftFields; redux_normalize_feed: boolean; }
interface IdentityOptions {
    field_set_key: string;
    username: string;
}
interface BoardOptions {
    filter: string;
    field_set_key: string;
    user_id: string;
}
interface ScrapeOptions {
    url: string;
    source: string;
    appendItems: boolean;
    followRedirects: boolean;
    scrapeMetric: string;
}
interface CreateBoardOptions {
    name: string;
    privacy: string;
}
interface CreatePinOptions {
    boardId: string;
    board_id: string;
    description: string;
    guid: string;
    imageBase64: string;
    image_base64: string;
    imageUrl: string;
    image_url: string;
    link: string;
    method: string;
}
// Media payloads stay private in native memory; the UI snapshot has previews only.
interface Candidate {
    draftId?: string;
    draftStoryPin?: Object;
    pin: PinmonyCreatedPin;
    link: string;
    base64: string;
    done: boolean;
}
export interface PinmonyPublishNativePorts extends PinmonySharePublishClientPorts {
    store: () => PinmonyProfileStore;
    active: () => boolean;
    foreground?: () => boolean;
    page: () => string;
    done: () => void;
}
export class PinmonyPublishNativeFlow {
    private readonly ports: PinmonyPublishNativePorts;
    private readonly client: PinmonySharePublishClient;
    private readonly story: PinmonyStoryPublish;
    private readonly store: PinmonyProfileStore;
    private revision: number = 0;
    private account: string = '';
    private generation: number = -1;
    private origin: string = '';
    private viewer: string = '';
    private flow: PinmonyPublishFlow | undefined = undefined;
    private candidates: Candidate[] = [];
    private unknown: Set<string> = new Set();
    private topicSequence: number = 0;
    private productSequence: number = 0;
    private draftSequence: number = 0;
    private writeKey: string = '';
    constructor(ports: PinmonyPublishNativePorts) { this.ports = ports; this.store = ports.store(); this.client = new PinmonySharePublishClient(ports); this.story = new PinmonyStoryPublish(ports); }
    private bind(): void { const s: PinmonyBusinessSessionContext = this.ports.session(); if (this.account !== s.accountId || this.generation !== s.generation || this.origin !== s.origin) {
        this.unknown.clear();
        this.viewer = '';
        this.account = s.accountId;
        this.generation = s.generation;
        this.origin = s.origin;
    } }
    private current(revision: number, menu: boolean = false, photo: boolean = false): boolean { const s: PinmonyBusinessSessionContext = this.ports.session(); return revision === this.revision && s.authenticated && s.accountId === this.account && s.generation === this.generation && s.origin === this.origin && this.ports.active() && (this.ports.foreground?.() !== false || photo && this.store.publishPicking) && (menu || !!this.flow && this.store.publishFlow?.token === this.flow.token && this.store.publishFlowToken === this.flow.token && this.flow.page === this.ports.page()); }
    private commit(): void { if (this.flow && this.store.publishFlow?.token === this.flow.token && this.store.publishFlowToken === this.flow.token) {
        this.flow.pins = this.candidates.filter((c: Candidate): boolean => !c.done).map((c: Candidate): PinmonyCreatedPin => c.pin);
        this.flow.selectedIds = this.flow.selectedIds.filter((id: string): boolean => this.candidates.some((c: Candidate): boolean => !c.done && c.pin.id === id));
        this.store.publishFlow = JSON.parse(JSON.stringify(this.flow)) as PinmonyPublishFlow;
    } }
    pause(): void { this.productSequence++;if(this.flow?.productLoading){this.flow.productLoading = false;this.flow.productError = PinmonyI18n.message('pm_loading_paused_go_back_and_retry_0ff69868');}this.topicSequence++;if(this.flow?.topicLoading){this.flow.topicLoading = false;this.flow.topicError = PinmonyI18n.message('pm_loading_paused_go_back_and_retry_0ff69868');}if (this.flow?.busy) {
        this.flow.uncertain = true;
        if (this.writeKey)
            this.unknown.add(this.writeKey);
        this.flow.error = PinmonyI18n.message("pm_result_not_confirmed_close_and_refresh_to_check_before_submittin_5d6ac26e");
    } if (this.flow) {
        if (this.flow.loading && !this.flow.error)
            this.flow.error = PinmonyI18n.message("pm_loading_paused_go_back_and_retry_0ff69868");
        this.flow.busy = false;
        this.flow.loading = false;
        this.commit();
    } this.revision++; this.client.cancel(); this.story.cancel(); const session: PinmonyBusinessSessionContext = this.ports.session(); if (!session.authenticated || session.accountId !== this.account || session.generation !== this.generation) {
        this.flow = undefined;
        this.candidates = [];
        this.viewer = '';
    } }
    close(): void { this.pause(); this.flow = undefined; this.candidates = []; this.writeKey = ''; this.viewer = ''; }
    private owner(mode: string, page: string): PinmonySharePublishOwner { return { sections: (this.flow?.sections || []).map((section: PinmonyOrganizeBoard): string => section.id).concat(this.flow?.selectedSectionId || ''), page: page, mode: mode, objectId: '', viewer: this.viewer, topics:this.flow?.selectedTopics?.map((topic: PinmonyPublishTopic): string => topic.id) || [], contacts: [], boards: this.flow?.boards.filter((b: PinmonyOrganizeBoard): boolean => b.enabled).map((b: PinmonyOrganizeBoard): string => b.id) || [] }; }
    private web(value: string | undefined): string { return typeof value === 'string' && value.length <= 4096 && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(value) ? value : ''; }
    private async read(name: string, verb: string, options: Object, source: string, handler: string, revision: number, menu: boolean = false, createdId: string = '', allowEmpty: boolean = false): Promise<Response> {
        const page: string = this.flow?.page || this.ports.page(), mode: string = this.flow?.kind === 'board' ? 'create-board' : this.flow?.kind || 'create-board';
        const owner: PinmonySharePublishOwner = this.owner(mode, page);owner.objectId = createdId;
        const raw: string = await this.client.request(owner, name, verb, options, source, handler, (): boolean => this.current(revision, menu));
        const p: Response = JSON.parse(raw) as Response, r: Resource = p.resource_response;
        if (!r || r.status !== 'success' || r.code !== 0 || r.error || !r.data && !allowEmpty || p.client_context?.is_authenticated === false || this.viewer && p.client_context?.user && p.client_context.user.id !== this.viewer) {
            if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)
                throw new PinmonyBusinessRejection(PinmonyI18n.message("pm_the_website_rejected_this_action_10efc2d0"));
            throw new Error('unconfirmed');
        }
        return p;
    }
    private async identity(revision: number, menu: boolean): Promise<void> {
        const page: string = this.flow?.profile || this.ports.page(), username: string = page.slice(this.origin.length).split('/')[1];
        const options: IdentityOptions = { field_set_key: 'profile', username: username };
        const p: Response = await this.read('UserResource', 'get', options, page.slice(this.origin.length), 'www/index.js', revision, menu), u: Data = p.resource_response.data;
        if (u.type !== 'user' || !/^\d{1,40}$/.test(u.id || '') || u.username !== username || p.client_context?.user?.id !== u.id)
            throw new Error('identity');
        this.viewer = u.id!;
    }
    async menu(current: () => boolean): Promise<boolean> {
        this.pause();
        this.flow = undefined;
        this.bind();
        const revision: number = this.revision;
        try {
            await this.identity(revision, true);
            if (!current() || !this.current(revision, true))
                return false;
            this.store.publishTitle = PinmonyI18n.message("pm_create_cde2cd07");
            this.store.publishOptions = [
                { id: 'native-website', kind: 'website', group: 'create', groupLabel: PinmonyI18n.message("pm_create_cde2cd07"), label: PinmonyI18n.message("pm_website_fb8d739d"), enabled: true },
                { id: 'native-photo', kind: 'photo', group: 'create', groupLabel: PinmonyI18n.message("pm_create_cde2cd07"), label: PinmonyI18n.message("pm_photos_7b50017a"), enabled: true },
                { id: 'native-board', kind: 'board', group: 'add', groupLabel: PinmonyI18n.message("pm_add_7a8a11ea"), label: PinmonyI18n.message("pm_board_bd3f17ee"), enabled: true }
            ];
            return true;
        }
        catch (_) {
            return false;
        }
        finally {
            if (current())
                this.store.publishLoading = false;
        }
    }
    async open(): Promise<boolean> {
        this.pause();
        this.bind();
        this.flow = this.store.publishFlow ? JSON.parse(JSON.stringify(this.store.publishFlow)) as PinmonyPublishFlow : undefined;
        this.candidates = [];
        this.writeKey = '';
        this.viewer = '';
        if (!this.flow)
            return false;
        const revision: number = this.revision;
        try {
            await this.identity(revision, false);
            if (!this.current(revision))
                return false;
            if (this.flow.kind === 'photo') {
                const options: PublishAccountOptions = { url: '/v3/users/settings/', data: {} };
                const raw: string = await this.client.request(this.owner('photo', this.flow.page), 'ApiResource', 'get', options, '/settings/permissions/', 'www/settings/permissions.js', (): boolean => this.current(revision));
                const settings: PublishAccountResponse = JSON.parse(raw) as PublishAccountResponse;
                if (!this.current(revision)) return false;
                if (!settings.resource_response || settings.resource_response.status !== 'success' || settings.resource_response.code !== 0 || settings.resource_response.error || !settings.resource_response.data || settings.client_context?.is_authenticated === false || settings.client_context?.user && settings.client_context.user.id !== this.viewer) throw new Error('publish-account-settings');
                const account: PublishAccountSettings = settings.resource_response.data;
                if (settings.resource_response.endpoint_name !== 'v3_get_user_settings' || account.id !== this.viewer || ![1, 2].includes(account.comments_disabled || 0) || typeof account.shopping_rec_disabled !== 'boolean') throw new Error('publish-account-settings');
                this.flow.accountCommentsEnabled = account.comments_disabled === 1;
                this.flow.accountShoppingRecommendationsEnabled = account.shopping_rec_disabled === false;
                if (!this.flow.accountCommentsEnabled) this.flow.allowComments = false;
                if (!this.flow.accountShoppingRecommendationsEnabled) this.flow.allowShopping = false;
            }
            this.flow.loading = false;
            this.commit();
            if (this.flow.kind === 'photo' && this.flow.phase === 'photo') this.loadDrafts(revision);
            return true;
        }
        catch (_) {
            if (this.current(revision)) {
                this.flow.loading = false;
                this.flow.error = PinmonyI18n.message("pm_unable_to_verify_account_go_back_refresh_and_retry_94555b9f");
                this.commit();
            }
            return false;
        }
    }
    private mapDraft(row: DraftData): PinmonyPublishDraft | undefined {
        const draft = row?.draft;
        if (!draft) return undefined;
        const id = typeof row.id === 'string' && /^\d{1,40}$/.test(row.id) ? row.id : '';
        if (!id || !Array.isArray(row.pages)) return undefined;
        let image: Image | undefined;
        for (const page of row.pages.slice(0, 20)) for (const block of (page?.blocks || []).slice(0, 50)) {
            if (block?.block_type === 2 && block.image?.images) { const candidate = block.image.images['750x'] || block.image.images['736x'] || block.image.images['1200x'] || block.image.images['originals']; if (candidate && this.web(candidate.url)) { image = candidate; break; } }
        }
        if (!image) return undefined;
        const tags: PinmonyPublishTopic[] = [];
        (draft.topic_tags || []).slice(0, 10).forEach((t: DraftTopic): void => { if (/^\d{1,40}$/.test(t?.id || '') && typeof t.value === 'string' && t.value) tags.push({id:t.id, text:(t.tagValue || t.value).slice(0, 500)}); });
        const title = typeof draft.pin_title === 'string' && draft.pin_title ? draft.pin_title : typeof row.metadata?.pin_title === 'string' ? row.metadata.pin_title : '';
        const products: PinmonyCreatedPin[] = [];
        if (Array.isArray(draft.tagged_products)) {
            draft.tagged_products.slice(0, 20).forEach((product: PinmonyDraftTaggedProduct): void => {
                // Captured draft records use pin_id and media, not the UI model fields.
                const productId: string = product?.pin_id || '';
                const media: Image | undefined = product?.media;
                if (!/^\d{1,40}$/.test(productId) || product.status !== 'created' || !media || !this.web(media.url)) return;
                if (products.some((item: PinmonyCreatedPin): boolean => item.id === productId)) return;
                products.push({ id: productId, title: '', imageUrl: this.web(media.url), imageWidth: typeof media.width === 'number' ? media.width : 0, imageHeight: typeof media.height === 'number' ? media.height : 0, targetUrl: this.web(product.link) });
            });
        }
        return { id, aiModified:draft.ai_disclosures?.includes(1), aiGeneratedPerson:draft.ai_disclosures?.includes(2), expiresAt: draft.created_at && Number.isFinite(Date.parse(draft.created_at)) ? Date.parse(draft.created_at) + 30 * 86400000 : undefined, imageUrl: image.url, imageWidth: typeof image.width === 'number' ? image.width : 0, imageHeight: typeof image.height === 'number' ? image.height : 0, title: title.slice(0, 500), description: typeof draft.pin_description === 'string' ? draft.pin_description.slice(0, 800) : '', link: this.web(draft.link), boardId: /^\d{1,40}$/.test(draft.board_id || '') ? draft.board_id : undefined, sectionId: /^\d{1,40}$/.test(draft.section_id || '') ? draft.section_id : undefined, topics: tags, altText: typeof draft.alt_text === 'string' ? draft.alt_text.slice(0, 500) : '', allowComments: typeof draft.is_comments_allowed === 'boolean' ? draft.is_comments_allowed : undefined, allowShopping: typeof draft.is_shopping_rec_allowed === 'boolean' ? draft.is_shopping_rec_allowed : undefined, products, storyPin: row };
    }
    private async deleteDraft(id: string, revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!;
        if (f.draftLoading || !(f.drafts || []).some((draft: PinmonyPublishDraft): boolean => draft.id === id)) return;
        const key: string = 'draft-delete:' + id;
        if (this.unknown.has(key)) return;
        this.writeKey = key; f.busy = true; f.error = ''; this.commit();
        try {
            const owner: PinmonySharePublishOwner = this.owner('photo',f.page); owner.objectId = id;
            const options: PublishDraftDeleteOptions = {url:'/v3/storypins/drafts/' + id + '/',data:{}};
            const raw: string = await this.client.request(owner,'ApiResource','delete',options,'/pin-creation-tool/','www/pin-creation-tool.js',(): boolean => this.current(revision));
            if (!this.current(revision)) return;
            const response: PublishDraftDeleteResponse = JSON.parse(raw) as PublishDraftDeleteResponse;
            const resource: PublishDraftDeleteResource = response.resource_response;
            if (resource?.status === 'failure' && resource.code !== 0) throw new PinmonyBusinessRejection('rejected');
            if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.error || resource.endpoint_name !== 'v3_delete_story_pin_draft' || resource.data !== true || response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== this.viewer) throw new Error('delete-unconfirmed');
            f.drafts = (f.drafts || []).filter((draft: PinmonyPublishDraft): boolean => draft.id !== id);
        } catch (error) {
            if (this.current(revision)) { f.uncertain = !(error instanceof PinmonyBusinessRejection); if(f.uncertain)this.unknown.add(key); f.error = PinmonyI18n.message(f.uncertain ? 'pm_result_not_confirmed_close_and_refresh_to_check_before_submittin_5d6ac26e' : 'pm_the_website_rejected_this_action_10efc2d0'); }
        } finally { if(this.current(revision)) { f.busy = false; this.writeKey = ''; this.commit(); } }
    }
    private async loadDrafts(revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!; const sequence = ++this.draftSequence;
        f.draftLoading = true; f.draftError = ''; this.commit();
        try {
            const options: DraftRequestOptions = { url: '/v3/users/' + this.viewer + '/storypins/drafts/', redux_normalize_feed: true, data: { fields: ['storypinimageblock.block_style','storypinimageblock.block_type','storypinimageblock.c2pa_parent_tracking_id','storypinimageblock.image[750x, 1200x, orig]','storypinimageblock.image_signature','storypinimageblock.type','storypinvideoblock.block_style','storypinvideoblock.block_type','storypinvideoblock.type','storypinvideoblock.video[V_720P]','storypinvideoblock.video_signature','storypindata.id','storypindata.mentioned_users()','storypindata.metadata','storypindata.page_count','storypindata.pages','storypindata.type','storypindata.draft()'], page_size: 50, user: this.viewer } };
            const raw: string = await this.client.request(this.owner('photo', f.page), 'ApiResource','get',options,'/pin-creation-tool/','www/pin-creation-tool.js',(): boolean => this.current(revision) && sequence === this.draftSequence && f.phase === 'photo');
            if (!this.current(revision) || sequence !== this.draftSequence || f.phase !== 'photo') return;
            const p: DraftFeedResponse = JSON.parse(raw) as DraftFeedResponse;
            if (!p.resource_response || p.resource_response.status !== 'success' || p.resource_response.code !== 0 || p.resource_response.error || p.resource_response.endpoint_name !== 'v3_user_story_pin_drafts_feed' || p.client_context?.is_authenticated === false || p.client_context?.user && p.client_context.user.id !== this.viewer) throw new Error('drafts');
            const rows: DraftData[] = p.resource_response.data;
            if (!Array.isArray(rows) || rows.length > 50) throw new Error('drafts');
            f.drafts = []; rows.forEach((row: DraftData): void => { const mapped = this.mapDraft(row); if (mapped) f.drafts!.push(mapped); });
        } catch (_) { if (this.current(revision) && sequence === this.draftSequence) f.draftError = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92'); }
        finally { if (this.current(revision) && sequence === this.draftSequence) { f.draftLoading = false; this.commit(); } }
    }
    photo(token: number, page: string, photo: PinmonyPublishPhoto): boolean {
        if (!this.current(this.revision, false, true) || !this.flow || this.flow.token !== token || this.flow.page !== page || this.flow.kind !== 'photo' || this.flow.busy || this.flow.uncertain || !['photo', 'select'].includes(this.flow.phase) || this.candidates.length >= 10 || !/^file:\/\/media\//.test(photo.uri) || photo.data.length > 5600000 || !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/]+=*$/.test(photo.data))
            return false;
        const id: string = 'photo-' + this.candidates.length.toString();
        this.candidates.push({ pin: { id: id, title: '', imageUrl: photo.uri, imageWidth: 0, imageHeight: 0 }, link: '', base64: photo.data, done: false });
        this.flow.selectedIds.push(id);
        this.flow.phase = 'select';
        this.commit();
        return true;
    }
    private mapBoard(b: Board): PinmonyOrganizeBoard | undefined { if (!b || b.type !== 'board' || !/^\d{1,40}$/.test(b.id) || !b.name?.trim())
        return undefined; return { hasSections:typeof b.section_count === 'number' ? b.section_count > 0 : undefined, id: b.id, title: b.name.trim().slice(0, 100), imageUrl: this.web(b.image_cover_hd_url || b.image_cover_url), secret: b.privacy === 'secret', enabled: Array.isArray(b.access) && b.access.includes('write') && !b.archived_by_me && !b.archived_by_me_at }; }
    private sectionSequence: number = 0;
    private async sections(board: PinmonyOrganizeBoard, revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!;
        const sequence: number = ++this.sectionSequence;
        f.phase = 'sections'; f.sectionBoardId = board.id; f.sections = []; f.loading = true; f.error = ''; this.commit();
        try {
            const data: PublishSectionsData = {fields:['boardsection.board','boardsection.id','boardsection.slug','boardsection.title','boardsection.type','boardsection.preview_pins(limit:1)'],orbac_subject_id:''};
            const options: PublishSectionsOptions = {url:'/v3/board/' + board.id + '/sections/all/',data:data};
            const response: PublishSectionsResponse = JSON.parse(await this.client.request(this.owner('photo',f.page),'ApiResource','get',options,'/pin-creation-tool/','www/pin-creation-tool.js',(): boolean => this.current(revision) && sequence === this.sectionSequence && f.phase === 'sections' && f.sectionBoardId === board.id)) as PublishSectionsResponse;
            const r: PublishSectionsResource = response.resource_response;
            if (!this.current(revision) || sequence !== this.sectionSequence || f.phase !== 'sections' || f.sectionBoardId !== board.id) return;
            if (response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== this.viewer || !r || r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'get_all_boards_sections' || !Array.isArray(r.data) || r.data.length > 500 || !r.data.every((section: PublishSection): boolean => section.type === 'board_section' && /^\d{1,40}$/.test(section.id) && section.board?.id === board.id && typeof section.title === 'string' && !!section.title.trim())) throw new Error('sections');
            f.sections = r.data.map((section: PublishSection): PinmonyOrganizeBoard => ({id:section.id,title:section.title,imageUrl:this.web(section.preview_pins?.[0]?.image_medium_url || section.preview_pins?.[0]?.images?.['236x']?.url),secret:board.secret,enabled:true}));
            if (!f.sections.length) { f.selectedBoardId = board.id; f.selectedSectionId = undefined; f.draftSaved = false; f.phase = 'select'; }
        } catch (_) { if (this.current(revision) && sequence === this.sectionSequence && f.phase === 'sections') f.error = PinmonyI18n.message('pm_unable_to_load_target_sections_please_retry_701b528d'); }
        finally { if (this.current(revision) && sequence === this.sectionSequence) { f.loading = false; this.commit(); } }
    }
    private async boards(revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!;
        f.loading = true;
        f.error = '';
        this.commit();
        try {
            const options: BoardOptions = { filter: 'all', field_set_key: 'profile_grid_item', user_id: this.viewer };
            const p: Response = await this.read('BoardPickerBoardsResource', 'get', options, '/pin/create/' + (f.kind === 'photo' ? 'uploaded' : 'pinbuilder') + '/', 'www/pin/create/[method].js', revision);
            if (!this.current(revision))
                return;
            const items: Board[] | undefined = p.resource_response.data.all_boards;
            if (!Array.isArray(items) || items.length > 2000)
                throw new Error('boards');
            f.boards = [];
            items.forEach((b: Board): void => { const v: PinmonyOrganizeBoard | undefined = this.mapBoard(b); if (v)
                f.boards.push(v); });
        }
        catch (_) {
            if (this.current(revision))
                f.error = PinmonyI18n.message("pm_unable_to_load_boards_please_retry_04bec826");
        }
        finally {
            if (this.current(revision)) {
                f.loading = false;
                this.commit();
            }
        }
    }
    private async scrape(value: string, revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!;
        if (!this.web(value))
            return;
        f.loading = true;
        f.error = '';
        this.commit();
        try {
            const options: ScrapeOptions = { url: value, source: 'pin_create', appendItems: false, followRedirects: true, scrapeMetric: 'www_url_scrape' };
            const p: Response = await this.read('FindPinImagesResource', 'get', options, f.page.slice(this.origin.length), 'www/pin-builder.js', revision), d: Data = p.resource_response.data;
            if (!this.current(revision))
                return;
            if (p.resource_response.endpoint_name !== 'v3_find_image' || !Array.isArray(d.items))
                throw new Error('images');
            this.candidates = d.items.filter((v: Scraped): boolean => v?.type === 'pinnable' && !!this.web(v.url) && !!this.web(v.link || d.destination_url || value)).slice(0, 100).map((v: Scraped, i: number): Candidate => ({ pin: { id: 'scraped-' + i.toString(), title: (d.title || '').trim().slice(0, 2000), imageUrl: this.web(v.url), imageWidth: 0, imageHeight: 0 }, link: this.web(v.link || d.destination_url || value), base64: '', done: false }));
            f.selectedIds = [];
            f.phase = this.candidates.length ? 'select' : 'empty';
        }
        catch (_) {
            if (this.current(revision))
                f.error = PinmonyI18n.message("pm_unable_to_load_images_please_retry_de205818");
        }
        finally {
            if (this.current(revision)) {
                f.loading = false;
                this.commit();
            }
        }
    }
    private async submit(target: PinmonyOrganizeBoard | undefined, name: string, secret: boolean, revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!;
        if (f.kind === 'photo') {
            if (f.accountCommentsEnabled === false) f.allowComments = false;
            if (f.accountShoppingRecommendationsEnabled === false) f.allowShopping = false;
        }
        f.busy = true;
        f.error = '';
        this.commit();
        let photoCreated: boolean = false;
        try {
            if (name) {
                this.writeKey = JSON.stringify(['board', name, secret]);
                if (this.unknown.has(this.writeKey))
                    throw new Error('previous-unknown');
                const options: CreateBoardOptions = { name: name, privacy: secret ? 'secret' : 'public' };
                const p: Response = await this.read('BoardResource', 'create', options, '/board/create/', 'www/board/create.js', revision);
                if (!this.current(revision))
                    return;
                const b: Board = p.resource_response.data as Board, mapped: PinmonyOrganizeBoard | undefined = this.mapBoard(b);
                if (p.resource_response.endpoint_name !== 'v3_create_board' || !mapped || b.name !== name || b.privacy !== options.privacy || b.owner?.id !== this.viewer)
                    throw new Error('board-unconfirmed');
                this.writeKey = '';
                f.boardCreated = true;
                f.boards.push(mapped);
                target = mapped;
                f.phase = 'boards';
                f.feedback = PinmonyI18n.message("pm_board_created_f7d22eaf");
                if (f.kind === 'board') {
                    f.completed = 1;
                    f.phase = 'done';
                    f.busy = false;
                    this.commit();
                    this.ports.done();
                    return;
                }
                if(f.kind === 'photo' && mapped.enabled){f.selectedBoardId = mapped.id;f.selectedSectionId = undefined;f.phase = 'select';f.busy = false;this.commit();return;}
                this.commit();
                if (!mapped.enabled)
                    throw new PinmonyBusinessRejection(PinmonyI18n.message("pm_board_created_but_you_do_not_have_publishing_access_choose_anoth_ca935e3f"));
            }
            const selected: Candidate[] = this.candidates.filter((c: Candidate): boolean => !c.done && f.selectedIds.includes(c.pin.id));
            if (!target?.enabled || !selected.length)
                throw new PinmonyBusinessRejection(PinmonyI18n.message("pm_select_images_and_a_writable_board_422d3694"));
            for (const c of selected) {
                if (!this.current(revision))
                    return;
                this.writeKey = JSON.stringify(['pin', target.id, c.pin.imageUrl, c.link, c.pin.title, f.photoTitle || '', f.photoDescription || '', f.photoLink || '', (f.selectedProducts || []).map((pin: PinmonyCreatedPin): string => pin.id)]);
                if (this.unknown.has(this.writeKey))
                    throw new Error('previous-unknown');
                const photo: boolean = f.kind === 'photo', options: CreatePinOptions = { boardId: target.id, board_id: target.id, description: photo ? f.photoDescription || '' : c.pin.title, guid: '', imageBase64: photo ? c.base64 : '', image_base64: photo ? c.base64 : '', imageUrl: photo ? '' : c.pin.imageUrl, image_url: photo ? '' : c.pin.imageUrl, link: photo ? f.photoLink || '' : c.link, method: photo ? 'uploaded' : 'scraped' };
                const tagged: boolean = photo && !!f.selectedProducts?.length;
                let d: Data;
                if(tagged) {
                    d = await this.story.publish(c.base64,target.id,f,f.page,this.viewer,(): boolean => this.current(revision)) as Data;
                } else {
                const p: Response = await this.read('PinResource', 'create', options, '/pin/create/' + (photo ? 'uploaded' : 'pinbuilder') + '/', 'www/pin/create/[method].js', revision);
                if (!this.current(revision))
                    return;
                d = p.resource_response.data;
                if (p.resource_response.endpoint_name !== 'v3_create_pin_handler' || d.type !== 'pin' || !/^\d{1,40}$/.test(d.id || '') || d.board?.id !== target.id || d.pinner?.id !== this.viewer || d.is_repin !== false || !d.images || !Object.keys(d.images).some((key: string): boolean => !!this.web(d.images![key]?.url)))
                    throw new Error('pin-unconfirmed');

                }
                if(!this.current(revision))return;
                if(photo)photoCreated = true;
                if(photo && ((!tagged && f.photoTitle) || f.aiModified || f.aiGeneratedPerson || !!f.selectedSectionId)) {
                    const options: EditCreatedPinOptions = {id:d.id!,board_id:target.id,board_section_id:f.selectedSectionId || '',ai_disclosures:(d.ai_disclosures || []).filter((id: number): boolean => id !== 1 && id !== 2).concat(f.aiModified ? [1] : []).concat(f.aiGeneratedPerson ? [2] : []),title:f.photoTitle || '',description:f.photoDescription || ''};
                    const edited: Response = await this.read('PinResource','update',options,'/pin/' + d.id + '/','www/pin/[id].js',revision,false,d.id!);
                    if(!this.current(revision))return;
                    const saved: Data = edited.resource_response.data;
                    if(f.selectedSectionId && saved.board_section?.id !== f.selectedSectionId) throw new Error('section-unconfirmed');
                    if(edited.resource_response.endpoint_name !== 'v3_edit_pin' || saved.id !== d.id || saved.board?.id !== target.id || saved.title !== options.title || saved.description !== options.description || !Array.isArray(saved.ai_disclosures) || saved.ai_disclosures.includes(1) !== !!f.aiModified || saved.ai_disclosures.includes(2) !== !!f.aiGeneratedPerson)throw new Error('metadata-unconfirmed');
                    if(tagged)await this.story.confirmProducts(d.id!,target.id,f,f.page,this.viewer,(): boolean => this.current(revision));
                }
                if(photo && !tagged && (f.allowComments === false || f.allowShopping === false || !!f.altText)) {
                    const advanced: AdvancedPinOptions = {pin_additional_note:'',alt_text:f.altText || '',board_id:target.id,board_section_id:f.selectedSectionId || '',description:f.photoDescription || '',disable_comments:f.allowComments === false,disable_did_it:d.did_it_disabled === true,id:d.id!,is_shuffle_remixable:false,link:f.photoLink || '',shopping_rec_disabled:f.allowShopping === false,title:f.photoTitle || '',user_mention_tags:'[]',product_pins:[],idea_pin_details_template_type:null};
                    const response: Response = await this.read('PinResource','update',advanced,'/pin/' + d.id + '/','www/pin/[id].js',revision,false,d.id!);
                    const saved: Data = response.resource_response.data;
                    if(response.resource_response.endpoint_name !== 'v3_edit_pin' || saved.id !== d.id || saved.board?.id !== target.id || saved.alt_text !== advanced.alt_text || saved.comments_disabled !== advanced.disable_comments)throw new Error('advanced-unconfirmed');
                }
                if(photo && f.selectedTopics?.length) {
                    const tags: TopicWriteOptions = {url:'/v3/interest_tagger/pin/' + d.id + '/interests/',data:{interest_ids:f.selectedTopics.map((topic: PinmonyPublishTopic): string => topic.id),data_source:'zen',zen_source:3}};
                    const response: Response = await this.read('ApiResource','create',tags,'/pin-creation-tool/','www/pin-creation-tool.js',revision,false,d.id!,true);
                    if(response.resource_response.endpoint_name !== 'v3_tag_pin_with_interests' || response.resource_response.data !== null)throw new Error('topics-unconfirmed');
                }
                c.done = true;
                c.base64 = '';
                this.writeKey = '';
                f.completed++;
                this.commit();
                PinmonyRuntimeLog.info('PublishNative: item confirmed');
            }
            f.phase = 'done';
            f.busy = false;
            this.candidates = [];
            this.commit();
            this.ports.done();
        }
        catch (error) {
            if (this.current(revision)) {
                f.uncertain = photoCreated || !(error instanceof PinmonyBusinessRejection);
                if (f.uncertain && this.writeKey)
                    this.unknown.add(this.writeKey);
                f.error = (f.completed ? PinmonyI18n.message("pm_confirmed_published_94dca36d") + f.completed.toString() + ' 张。' : '') + (f.uncertain ? '操作结果未确认，请关闭后刷新核对，勿重复提交' : (error as Error).message);
                PinmonyRuntimeLog.info('PublishNative: outcome=' + (f.uncertain ? 'unknown' : 'rejected'));
            }
        }
        finally {
            if (this.current(revision)) {
                f.busy = false;
                this.writeKey = '';
                this.commit();
            }
        }
    }
    private async searchTopics(query: string, language: string): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!, revision: number = this.revision, sequence: number = ++this.topicSequence;
        f.topicQuery = query;f.topicResults = [];f.topicError = '';f.topicLoading = !!query;this.commit();
        if(!query)return;
        try {
            const options: TopicSearchOptions = {url:'/v3/manual_tags/search/',data:{language:language,query:query,corpus:'interests',limit:20,min_level:3}};
            const response: Response = await this.read('ApiResource','get',options,'/pin-creation-tool/','www/pin-creation-tool.js',revision);
            if(!this.current(revision) || sequence !== this.topicSequence || f.phase !== 'topics')return;
            const rows: PinmonyPublishTopic[] | undefined = response.resource_response.data.results;
            if(response.resource_response.endpoint_name !== 'v3_search' || !Array.isArray(rows) || rows.length > 20 || !rows.every((row: PinmonyPublishTopic,index: number): boolean => rows.findIndex((item: PinmonyPublishTopic): boolean => item.id === row.id) === index && typeof row.id === 'string' && /^\d{1,40}$/.test(row.id) && typeof row.text === 'string' && !!row.text && row.text.length <= 500))throw new Error('topics');
            f.topicResults = rows.map((row: PinmonyPublishTopic): PinmonyPublishTopic => ({id:row.id,text:row.text}));
        } catch (_) {if(this.current(revision) && sequence === this.topicSequence)f.topicError = PinmonyI18n.message('pm_unable_to_load_content_please_retry_95306b92');}
        finally {if(this.current(revision) && sequence === this.topicSequence){f.topicLoading = false;this.commit();}}
    }
    private async suggestProducts(query: string): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!, revision: number = this.revision, sequence: number = ++this.productSequence;
        f.productSuggesting = true; f.productSuggestions = []; f.productResults = []; f.productError = ''; f.productLoading = !!query; this.commit();
        if (!query) { f.productLoading = false; this.commit(); return; }
        const current = (): boolean => this.current(revision) && sequence === this.productSequence && f.phase === 'productSearch';
        try {
            const options: PublishSuggestionOptions = {field_set_key:'richResults',limit:8,num_recent_queries:20,personal_search_only:false,pin_scope:'pins',recent_queries_tags:'recent_queries,recent_personal_searches',term:query,autocomplete_request_surface:0};
            const raw: string = await this.client.request(this.owner('photo',f.page),'AdvancedTypeaheadResource','get',options,'/idea-pin-builder/','www/idea-pin-builder.js',current);
            if (!current()) return;
            const response: PublishSuggestionResponse = JSON.parse(raw) as PublishSuggestionResponse;
            const resource: PublishSuggestionResource = response.resource_response;
            if (!resource || resource.status !== 'success' || resource.code !== 0 || resource.error || !Array.isArray(resource.data?.items) || response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== this.viewer) throw new Error('suggestions');
            const labels: string[] = [];
            resource.data!.items!.slice(0,40).forEach((row: PublishSuggestionRow): void => { const label: string = row?.display_query || row?.query || row?.label || ''; if (typeof label === 'string' && label.trim() && label.length <= 300 && !labels.includes(label.trim()) && labels.length < 8) labels.push(label.trim()); });
            f.productSuggestions = labels;
        } catch (_) { if (current()) f.productError = PinmonyI18n.message('pm_publish_product_read_failed'); }
        finally { if (current()) { f.productLoading = false; this.commit(); } }
    }
    private async loadProducts(value: string, link: boolean): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!, revision: number = this.revision, sequence: number = ++this.productSequence;
        f.productSuggesting = false; f.productSuggestions = []; f.productQuery = value;f.productMode = link ? 'link' : 'search';f.productResults = [];f.productError = '';f.productLoading = true;this.commit();
        try {
            const search: ProductSearchOptions = {enable_promoted_pins:false,query:value,scope:'buyable_pins'};
            const find: ProductFindOptions = {url:'/v3/products/find/',data:{url:value,source:'creator'}};
            const current = (): boolean => this.current(revision) && sequence === this.productSequence && ['products','productSearch'].includes(f.phase);
            const raw: string = await this.client.request(this.owner('photo',f.page),link ? 'ApiResource' : 'BaseSearchResource','get',link ? find : search,'/idea-pin-builder/','www/idea-pin-builder.js',current);
            if(!current())return;
            const response: ProductResponse = JSON.parse(raw) as ProductResponse, resource: ProductResource = response.resource_response;
            if(!resource || resource.status !== 'success' || resource.code !== 0 || resource.error || resource.endpoint_name !== (link ? 'v3_find_products' : 'v3_search_pins') || !resource.data || response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== this.viewer)throw new Error('unconfirmed-products');
            const data: ProductData = resource.data, results: PinmonyCreatedPin[] = [];
            if(link) {
                const destination: string = this.web(data.landing_url);
                if(!destination || !Array.isArray(data.images))throw new Error('invalid-product-link');
                data.images.slice(0,40).forEach((url: string,index: number): void => {
                    if(this.web(url) && !results.some((pin: PinmonyCreatedPin): boolean => pin.imageUrl === url))results.push({id:'link-' + index.toString(),title:typeof data.title === 'string' ? data.title.slice(0,500) : '',imageUrl:url,imageWidth:0,imageHeight:0,targetUrl:destination});
                });
            } else {
                if(!Array.isArray(data.results))throw new Error('invalid-product-results');
                data.results.slice(0,50).forEach((item: ProductResult): void => {
                    if(!item || item.type !== 'pin' || typeof item.id !== 'string' || !/^[A-Za-z0-9_-]{1,256}$/.test(item.id) || !item.images)return;
                    const image: Image | undefined = item.images['474x'] || item.images['236x'] || item.images['orig'];
                    if(image && this.web(image.url) && !results.some((pin: PinmonyCreatedPin): boolean => pin.id === item.id))results.push({id:item.id,title:typeof item.title === 'string' ? item.title.slice(0,500) : '',imageUrl:image.url,imageWidth:typeof image.width === 'number' && image.width > 0 ? image.width : 0,imageHeight:typeof image.height === 'number' && image.height > 0 ? image.height : 0,targetUrl:this.web(item.link)});
                });
            }
            f.productResults = results;
            if(link && results.length){f.productImageId = results[0].id;f.productLoading = false;f.phase = 'productImages';this.commit();}
        } catch (_) {
            if(this.current(revision) && sequence === this.productSequence && ['products','productSearch'].includes(f.phase))f.productError = PinmonyI18n.message('pm_publish_product_read_failed');
        } finally {
            if(this.current(revision) && sequence === this.productSequence && ['products','productSearch'].includes(f.phase)){f.productLoading = false;this.commit();}
        }
    }
    private async toggleProduct(value: string, revision: number): Promise<void> {
        const f: PinmonyPublishFlow = this.flow!, selected: PinmonyCreatedPin[] = f.selectedProducts || [];
        if(selected.some((pin: PinmonyCreatedPin): boolean => pin.id === value)) {f.selectedProducts = selected.filter((pin: PinmonyCreatedPin): boolean => pin.id !== value);this.commit();return;}
        const pin: PinmonyCreatedPin | undefined = f.productResults?.find((pin: PinmonyCreatedPin): boolean => pin.id === value);
        if(!pin || selected.length >= 10)return;
        if(this.story.selectable(pin)) {f.selectedProducts = selected.concat([pin]);this.commit();return;}
        if(!/^link-\d+$/.test(pin.id))return;
        this.writeKey = JSON.stringify(['product',pin.imageUrl,pin.targetUrl]);
        if(this.unknown.has(this.writeKey))return;
        f.busy = true;f.productError = '';this.commit();
        try {
            const product: PinmonyCreatedPin = await this.story.createProduct(pin,f.page,this.viewer,(): boolean => this.current(revision));
            if(!this.current(revision))return;
            f.productCreated = true;
            f.selectedProducts = selected.some((p: PinmonyCreatedPin): boolean => p.id === product.id) ? selected : selected.concat([product]);
            f.productResults = (f.productResults || []).map((p: PinmonyCreatedPin): PinmonyCreatedPin => p.id === value ? product : p);
            if(f.phase === 'productImages')f.phase = 'productConfirm';
        }catch(error) {
            if(this.current(revision)) {f.uncertain = !(error instanceof PinmonyBusinessRejection);if(f.uncertain)this.unknown.add(this.writeKey);f.productError = PinmonyI18n.message(f.uncertain ? 'pm_publish_product_unconfirmed' : 'pm_publish_product_read_failed');}
        }finally {if(this.current(revision)){f.busy = false;this.writeKey = '';this.commit();}}
    }
    async action(action: string, value: string, secret: boolean): Promise<void> {
        const f: PinmonyPublishFlow | undefined = this.flow, revision: number = this.revision;
        if (!f || !this.current(revision) || !this.viewer || f.loading && !(action === 'back' && f.phase === 'sections') || f.busy || f.uncertain)
            return;
        if (f.kind === 'photo' && f.phase === 'select' && ['saveDraft','saveDraftExit'].includes(action)) {
            if (!f.selectedBoardId || !f.boards.some((board: PinmonyOrganizeBoard): boolean => board.id === f.selectedBoardId && board.enabled)) {
                f.draftExitRequested = false; f.error = PinmonyI18n.message('pm_publish_draft_choose_board'); this.commit(); return;
            }
            const candidates: Candidate[] = this.candidates.filter((c: Candidate): boolean => !c.done && f.selectedIds.includes(c.pin.id));
            if (!candidates.length) return;
            f.draftExitRequested = false; f.busy = true; f.error = ''; this.writeKey = 'draft-save:' + f.token.toString(); this.commit();
            try {
                const owner: PinmonySharePublishOwner = this.owner('photo',f.page); owner.objectId = f.editingDraft ? f.draftId || '' : '';
                for (const candidate of candidates) {
                    const snapshot: PinmonyPublishFlow = JSON.parse(JSON.stringify(f)) as PinmonyPublishFlow;
                    if (candidate.draftId) { snapshot.editingDraft = true; snapshot.draftId = candidate.draftId; snapshot.draftStoryPin = candidate.draftStoryPin; }
                    owner.objectId = snapshot.editingDraft ? snapshot.draftId || '' : '';
                    const saved: PinmonyDraftSavedResult = await savePinmonyDraft(this.client,this.story,owner,snapshot,candidate.base64,(): boolean => this.current(revision));
                    if (!this.current(revision)) return;
                    candidate.draftId = saved.id; candidate.draftStoryPin = saved.source;
                }
                f.draftSaved = true; f.busy = false; this.writeKey = ''; this.commit();
                f.phase = 'photo'; f.error = ''; f.editingDraft = false; f.draftId = undefined; f.draftStoryPin = undefined;
                await this.loadDrafts(revision);
            } catch (error) {
                if (this.current(revision)) {
                    f.uncertain = !(error instanceof PinmonyDraftNotSubmittedError);
                    if (f.uncertain) this.unknown.add(this.writeKey);
                    f.error = PinmonyI18n.message(f.uncertain ? 'pm_publish_draft_unconfirmed' : 'pm_publish_draft_not_submitted');
                    PinmonyRuntimeLog.warn('DraftSaveTrace: outcome=' + (f.uncertain ? 'unconfirmed' : 'not-submitted'));
                }
            } finally { if (this.current(revision)) { f.busy = false; this.commit(); } }
            return;
        }
        if (f.kind === 'photo' && ['photoFields','advancedFields','doneTopics','removeProduct','toggleProduct','chooseProduct','confirmProductImage','next'].includes(action)) { f.draftSaved = false; f.error = ''; }
        if (f.kind === 'photo' && f.phase === 'photo' && action === 'deleteDraft') { await this.deleteDraft(value,revision); return; }
        if (f.kind === 'photo' && f.phase === 'photo' && action === 'loadDrafts') { if (!f.draftLoading) await this.loadDrafts(revision); return; }
        if (f.kind === 'photo' && f.phase === 'photo' && action === 'openDraft') {
            const draft: PinmonyPublishDraft | undefined = (f.drafts || []).find((item: PinmonyPublishDraft): boolean => item.id === value);
            if (!draft) return;
            const id = 'draft-photo-' + draft.id;
            f.draftId = draft.id; f.editingDraft = true; f.draftStoryPin = draft.storyPin;
            f.aiModified = draft.aiModified; f.aiGeneratedPerson = draft.aiGeneratedPerson;
            f.photoTitle = draft.title; f.photoDescription = draft.description; f.photoLink = draft.link;
            f.selectedBoardId = draft.boardId; f.selectedSectionId = draft.sectionId; f.selectedTopics = (draft.topics || []).slice(); f.topicDraft = (draft.topics || []).slice();
            f.selectedProducts = (draft.products || []).slice(); f.allowComments = f.accountCommentsEnabled === false ? false : draft.allowComments; f.allowShopping = f.accountShoppingRecommendationsEnabled === false ? false : draft.allowShopping; f.altText = draft.altText || '';
            this.candidates = [{ pin: { id: id, title: draft.title, imageUrl: draft.imageUrl, imageWidth: draft.imageWidth, imageHeight: draft.imageHeight }, link: draft.link, base64: '', done: false }];
            f.selectedIds = [id];
            if (f.selectedBoardId && !f.boards.some((board: PinmonyOrganizeBoard): boolean => board.id === f.selectedBoardId)) {
                await this.boards(revision);
                if (!this.current(revision)) return;
            }
            f.phase = 'select'; this.commit(); return;
        }
        if(f.kind === 'photo' && f.phase === 'productSearch' && action === 'suggestProducts') { if(value.length <= 200) await this.suggestProducts(value.trim()); return; }
        if(f.kind === 'photo' && ['products','productSearch'] .includes(f.phase) && action === 'chooseProduct') { await this.toggleProduct(value,revision); if(this.current(revision) && (f.selectedProducts || []).some((pin: PinmonyCreatedPin): boolean => pin.id === value)){ f.phase = 'productConfirm'; this.commit(); } return; }
        if(f.kind === 'photo' && ['products','productSearch','productConfirm'].includes(f.phase) && action === 'doneProducts') {
            if(f.phase !== 'productConfirm' && !(f.selectedProducts || []).length)return;
            f.phase = f.phase === 'productConfirm' ? 'select' : 'productConfirm'; this.commit(); return;
        }
        if(f.kind === 'photo' && f.phase === 'productConfirm' && action === 'addProduct') { f.phase = 'products'; this.commit(); return; }
        if(f.kind === 'photo' && f.phase === 'products' && action === 'openProductSearch') { f.productSuggesting = true; f.productSuggestions = []; f.productResults = []; f.productError = ''; f.phase = 'productSearch'; this.commit(); return; }
        if(f.kind === 'photo' && ['products','productSearch','productConfirm'].includes(f.phase) && action === 'removeProduct') { f.selectedProducts = (f.selectedProducts || []).filter((pin: PinmonyCreatedPin): boolean => pin.id !== value); this.commit(); return; }
        if(f.kind === 'photo' && f.phase === 'photo' && action === 'websiteFromPhoto') { f.fromDraftBox = true; f.kind = 'website'; f.phase = 'website'; this.commit(); return; }
        if(f.kind === 'photo' && f.phase === 'productImages' && action === 'chooseProductImage') {
            if(f.productResults?.some((pin: PinmonyCreatedPin): boolean => pin.id === value && /^link-\d+$/.test(pin.id))){f.productImageId = value;this.commit();}return;
        }
        if(f.kind === 'photo' && f.phase === 'productImages' && action === 'confirmProductImage') {
            if(f.productImageId)await this.toggleProduct(f.productImageId,revision);return;
        }
        if(f.kind === 'photo' && ['products','productSearch'].includes(f.phase) && action === 'toggleProduct') {await this.toggleProduct(value,revision);return;}
        if(f.kind === 'photo' && ['products','productSearch'].includes(f.phase) && action === 'productQuery') {
            this.productSequence++;f.productLoading = false;f.productQuery = '';f.productMode = '';f.productError = '';f.productResults = [];f.productSuggestions = [];f.productSuggesting = f.phase === 'productSearch';this.commit();return;
        }
        if(f.kind === 'photo' && ['products','productSearch'].includes(f.phase) && ['searchProducts','findProduct'].includes(action)) {
            const query: string = value.trim();
            if(action === 'searchProducts' ? query.length <= 200 : !!this.web(query))await this.loadProducts(query,action === 'findProduct');
            return;
        }
        if(f.kind === 'photo' && action === 'topicQuery' && f.phase === 'topics' && value.length <= 200) {
            this.topicSequence++;f.topicQuery = value;f.topicResults = [];f.topicError = '';f.topicLoading = !!value;this.commit();return;
        }
        if(f.kind === 'photo' && action === 'searchTopics' && f.phase === 'topics') {
            try {const input: TopicSearchData = JSON.parse(value) as TopicSearchData;if(typeof input.query !== 'string' || input.query.length > 200 || !['zh-cn','en'].includes(input.language))return;await this.searchTopics(input.query.trim(),input.language);}catch (_) {}return;
        }
        if(f.kind === 'photo' && action === 'toggleTopic' && f.phase === 'topics') {
            const draft: PinmonyPublishTopic[] = f.topicDraft || [];
            const topic: PinmonyPublishTopic | undefined = (f.topicResults || []).concat(draft).find((row: PinmonyPublishTopic): boolean => row.id === value);
            if(topic)f.topicDraft = draft.some((row: PinmonyPublishTopic): boolean => row.id === value) ? draft.filter((row: PinmonyPublishTopic): boolean => row.id !== value) : draft.length < 10 ? draft.concat([topic]) : draft;
            this.commit();return;
        }
        if(f.kind === 'photo' && action === 'doneTopics' && f.phase === 'topics') {this.topicSequence++;f.selectedTopics = (f.topicDraft || []).slice();f.topicLoading = false;f.phase = 'select';this.commit();return;}
        if(f.kind === 'photo' && action === 'advancedFields' && f.phase === 'advanced') {
            try {const settings: PinmonyPublishFlow = JSON.parse(value) as PinmonyPublishFlow;
                if(typeof settings.allowComments !== 'boolean' || typeof settings.allowShopping !== 'boolean' || typeof settings.aiModified !== 'boolean' || typeof settings.aiGeneratedPerson !== 'boolean' || typeof settings.altText !== 'string' || settings.altText.length > 500)return;
                f.allowComments = f.accountCommentsEnabled === false ? false : settings.allowComments;
                f.allowShopping = f.accountShoppingRecommendationsEnabled === false ? false : settings.allowShopping;
                f.aiModified = settings.aiModified;f.aiGeneratedPerson = settings.aiGeneratedPerson;f.altText = settings.altText;this.commit();
            }catch (_) {}return;
        }
        if(f.kind === 'photo' && action === 'photoFields' && f.phase === 'select') {
            try {const fields: PinmonyPublishFlow = JSON.parse(value) as PinmonyPublishFlow;
                if(typeof fields.photoTitle !== 'string' || fields.photoTitle.length > 100 || typeof fields.photoDescription !== 'string' || fields.photoDescription.length > 800 || typeof fields.photoLink !== 'string' || fields.photoLink.length > 4096)return;
                f.photoTitle = fields.photoTitle;f.photoDescription = fields.photoDescription;f.photoLink = fields.photoLink;this.commit();
            } catch (_) {}return;
        }
        if(f.kind === 'photo' && action === 'publish' && f.phase === 'select') {
            const target: PinmonyOrganizeBoard | undefined = f.boards.find((b: PinmonyOrganizeBoard): boolean => b.enabled && b.id === f.selectedBoardId);
            if(target && f.selectedIds.length && (!f.photoLink || this.web(f.photoLink)))await this.submit(target,'',false,revision);return;
        }
        if(f.kind === 'photo' && ['topics','products','advanced'].includes(action) && f.phase === 'select') {if(action === 'topics'){f.topicDraft = (f.selectedTopics || []).slice();f.topicError = '';f.topicResults = [];f.topicQuery = '';}f.phase = action === 'products' && (f.selectedProducts || []).length ? 'productConfirm' : action;this.commit();return;}
        if (action === 'scrape' && f.phase === 'website') {
            await this.scrape(value, revision);
            return;
        }
        if (action === 'toggle' && f.phase === 'select' && this.candidates.some((c: Candidate): boolean => !c.done && c.pin.id === value))
            f.selectedIds = f.selectedIds.includes(value) ? f.selectedIds.filter((id: string): boolean => id !== value) : f.selectedIds.concat([value]);
        else if (action === 'all' && f.phase === 'select') {
            const ids: string[] = this.candidates.filter((c: Candidate): boolean => !c.done).map((c: Candidate): string => c.pin.id);
            f.selectedIds = f.selectedIds.length === ids.length ? [] : ids;
        }
        else if (action === 'next' && f.phase === 'select' && f.selectedIds.length) {
            f.phase = 'boards';
            await this.boards(revision);
            return;
        }
        else if (action === 'retryBoards' && f.phase === 'boards') {
            await this.boards(revision);
            return;
        }
        else if (action === 'createForm' && f.phase === 'boards') {
            f.phase = 'create';
            f.error = '';
        }
        else if (action === 'boards' && f.phase === 'create') {
            f.phase = 'boards';
            f.error = '';
        }
        else if (action === 'chooseSection' && f.phase === 'sections' && !f.loading && !f.error) {
            if (value && !f.sections?.some((section: PinmonyOrganizeBoard): boolean => section.id === value)) return;
            f.selectedBoardId = f.sectionBoardId; f.selectedSectionId = value || undefined; f.draftSaved = false; f.phase = 'select';
        }
        else if (action === 'retrySections' && f.phase === 'sections') { const board: PinmonyOrganizeBoard | undefined = f.boards.find((b: PinmonyOrganizeBoard): boolean => b.id === f.sectionBoardId && b.enabled); if (board) await this.sections(board,revision); return; }
        else if (action === 'back') {
            if (f.fromDraftBox && f.phase === 'website') { f.kind = 'photo'; f.phase = 'photo'; f.fromDraftBox = false; f.error = ''; this.commit(); return; }
            if (f.phase === 'sections') { this.sectionSequence++; f.loading = false; }
            if(['products','productSearch','productConfirm','productImages'].includes(f.phase)){this.productSequence++;f.productLoading = false;}
            if(f.phase === 'topics'){this.topicSequence++;f.topicLoading = false;f.topicDraft = undefined;}
            f.phase = f.phase === 'sections' ? 'boards' : ['productImages','productSearch'].includes(f.phase) ? 'products' : f.phase === 'productConfirm' ? 'select' : f.phase === 'create' ? (f.kind === 'board' ? 'done' : 'boards') : ['boards','topics','products','advanced'].includes(f.phase) ? 'select' : f.kind === 'photo' ? 'photo' : 'website';
            f.error = '';
        }
        else if (action === 'move' && f.phase === 'boards') {
            const b: PinmonyOrganizeBoard | undefined = f.boards.find((b: PinmonyOrganizeBoard): boolean => b.id === value && b.enabled);
            if(f.kind === 'photo' && b) {
                if (b.hasSections === false) { this.sectionSequence++; f.selectedBoardId = b.id; f.selectedSectionId = undefined; f.sections = []; f.sectionBoardId = undefined; f.draftSaved = false; f.phase = 'select'; f.error = ''; this.commit(); }
                else await this.sections(b,revision);
                return;
            }
            if (b && f.selectedIds.length)
                await this.submit(b, '', false, revision);
            return;
        }
        else if (action === 'create' && f.phase === 'create' && value.trim() && value.trim().length <= 100) {
            await this.submit(undefined, value.trim(), secret, revision);
            return;
        }
        else
            return;
        this.commit();
        if (f.phase === 'done')
            this.ports.done();
    }
}
