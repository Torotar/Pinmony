import { PinmonyPublishFlow, PinmonyCreatedPin, PinmonyPublishTopic } from 'feature_profile';
import { PinmonyStoryPublish, PinmonyDraftUpload } from './PinmonyStoryPublish';
import { PinmonySharePublishClient, PinmonySharePublishOwner } from './PinmonySharePublishClient';

interface PinmonyDraftBlock { block_type?: number; type?: string | number; block_style: Object; image_signature?: string; c2pa_parent_tracking_id?: string | null; tracking_id?: string; text?: string; style?: Object; mentions?: Object[]; }
interface PinmonyDraftPage { blocks: PinmonyDraftBlock[]; layout: number; style: Object; }
interface PinmonyDraftSource { metadata: Object; pages: PinmonyDraftPage[]; draft?: PinmonyDraftOriginal; }
interface PinmonyDraftOriginal { user_mention_tags?: Object[]; ai_disclosures?: number[]; board_id?: string; section_id?: string; }
export interface PinmonyDraftSavedResult { id: string; source: Object; }
export class PinmonyDraftNotSubmittedError extends Error {}
interface PinmonyDraftMetadata { canvas_aspect_ratio: number; pin_title: string; template_type: Object | null; }
interface PinmonyDraftPayload { metadata: Object; pages: PinmonyDraftPage[]; }
interface PinmonyDraftTag { product_id: string; pin_id: string; link: string; status: string; media: PinmonyDraftMedia; }
interface PinmonyDraftMedia { url: string; width: number; height: number; }
interface PinmonyDraftBlockStyle { height: number; width: number; x_coord: number; y_coord: number; }
interface PinmonyDraftTextPosition { x_coord: number; y_coord: number; width: number; height: number; corner_radius: number; }
interface PinmonyDraftTextStyle { font_id: number; hex_color: string; font_size: number; alignment: number; vertical_alignment: number; }
interface PinmonyDraftPageStyle { background_color: string; }
interface PinmonyDraftTopic { id: string; value: string; tagValue: string; }
interface PinmonyDraftData { alt_text?: string; board_id: string | null; board_section_id?: string; description?: string; link?: string; is_comments_allowed: boolean; is_shopping_rec_allowed: boolean; story_pin: string; user_mention_tags: string; topic_tags: string; tagged_products: string | null; ai_disclosures?: number[]; }
interface PinmonyDraftInitialData { board_id: string | null; is_comments_allowed: boolean; is_shopping_rec_allowed: boolean; story_pin: string; topic_tags: string; tagged_products: string | null; }
interface PinmonyDraftInitialOptions { url: string; data: PinmonyDraftInitialData; }
interface PinmonyDraftOptions { url: string; data: PinmonyDraftData; }
interface PinmonyDraftResponse { resource_response: PinmonyDraftResource; client_context?: PinmonyDraftContext; }
interface PinmonyDraftResource { status: string; code: number; endpoint_name: string; data: string; error?: Object; }
interface PinmonyDraftContext { is_authenticated?: boolean; user?: PinmonyDraftUser; }
interface PinmonyDraftUser { id: string; }

// Website draft contracts captured in the supplied creation HARs. Never replay a write.
function draftFields(value: Object | undefined, names: string[]): Record<string,Object> {
  const result: Record<string,Object> = {};
  const source: Record<string,Object | null> = (value || {}) as Record<string,Object | null>;
  names.forEach((name: string): void => { if (source[name] !== undefined && source[name] !== null) result[name] = source[name] as Object; });
  return result;
}
export async function savePinmonyDraft(client: PinmonySharePublishClient, story: PinmonyStoryPublish, owner: PinmonySharePublishOwner, flow: PinmonyPublishFlow, base64: string, current: () => boolean): Promise<PinmonyDraftSavedResult> {
  let submitted: boolean = false;
  try { return await savePinmonyDraftInternal(client,story,owner,flow,base64,current,(): void => { submitted = true; }); }
  catch (_) { if (!submitted) throw new PinmonyDraftNotSubmittedError('draft-not-submitted'); throw new Error('draft-unconfirmed'); }
}
async function savePinmonyDraftInternal(client: PinmonySharePublishClient, story: PinmonyStoryPublish, owner: PinmonySharePublishOwner, flow: PinmonyPublishFlow, base64: string, current: () => boolean, onSubmit: () => void): Promise<PinmonyDraftSavedResult> {
  let payload: PinmonyDraftPayload;
  let original: PinmonyDraftOriginal | undefined;
  if (flow.editingDraft) {
    if (!flow.draftStoryPin || !/^\d{1,40}$/.test(flow.draftId || '')) throw new Error('draft-source');
    const source: PinmonyDraftSource = JSON.parse(JSON.stringify(flow.draftStoryPin)) as PinmonyDraftSource;
    original = source.draft;
    if (!source.metadata || !Array.isArray(source.pages) || !source.pages.length || source.pages.length > 20) throw new Error('draft-pages');
    const metadata: Record<string,Object> = draftFields(source.metadata,['canvas_aspect_ratio','pin_title','template_type']);
    metadata['pin_title'] = flow.photoTitle || '';
    payload = { metadata: metadata, pages: source.pages.map((page: PinmonyDraftPage): PinmonyDraftPage => {
      if (!Array.isArray(page.blocks) || page.blocks.length > 50) throw new Error('draft-blocks');
      return { layout: page.layout, style: draftFields(page.style,['background_color']), blocks: page.blocks.map((block: PinmonyDraftBlock): PinmonyDraftBlock => {
        const kind: number = block.block_type ?? (typeof block.type === 'number' ? block.type : -1);
        if (![0,2].includes(kind)) throw new Error('unsupported-draft-block');
        return { type: kind, block_style: draftFields(block.block_style,['height','width','x_coord','y_coord','rotation','corner_radius']), image_signature: block.image_signature, c2pa_parent_tracking_id: block.c2pa_parent_tracking_id, tracking_id: block.tracking_id, text: block.text, style: kind === 0 ? draftFields(block.style,['font_id','hex_color','font_size','alignment','vertical_alignment']) : undefined, mentions: block.mentions || undefined };
      }) };
    }) };
  } else {
    const upload: PinmonyDraftUpload = await story.uploadDraftImage(base64,owner.page,owner.viewer,current);
    const metadata: PinmonyDraftMetadata = {canvas_aspect_ratio:upload.width / upload.height,pin_title:flow.photoTitle || '',template_type:null};
    const blockStyle: PinmonyDraftBlockStyle = {height:100,width:100,x_coord:0,y_coord:0};
    const pageStyle: PinmonyDraftPageStyle = {background_color:'#000000'};
    const block: PinmonyDraftBlock = {type:2,block_style:blockStyle,image_signature:upload.signature,c2pa_parent_tracking_id:null,tracking_id:upload.uploadId};
    const textPosition: PinmonyDraftTextPosition = {x_coord:4.27,y_coord:46.82,width:91.46,height:26.35,corner_radius:0};
    const textStyle: PinmonyDraftTextStyle = {font_id:6,hex_color:'#FFFFFF',font_size:36,alignment:1,vertical_alignment:0};
    const textBlock: PinmonyDraftBlock = {type:0,block_style:textPosition,style:textStyle,text:''};
    const page: PinmonyDraftPage = {blocks:[block,textBlock],layout:7,style:pageStyle};
    payload = {metadata:metadata,pages:[page]};
  }
  const products: PinmonyCreatedPin[] = flow.selectedProducts || [];
  if (products.length > 10 || products.some((pin: PinmonyCreatedPin): boolean => !story.selectable(pin))) throw new Error('draft-products');
  const tags: PinmonyDraftTag[] = products.map((pin: PinmonyCreatedPin): PinmonyDraftTag => ({product_id:pin.id,pin_id:pin.id,link:pin.targetUrl || '',status:'created',media:{url:pin.imageUrl,width:pin.imageWidth,height:pin.imageHeight}}));
  const topics: PinmonyDraftTopic[] = (flow.selectedTopics || []).map((topic: PinmonyPublishTopic): PinmonyDraftTopic => ({id:topic.id,value:topic.text,tagValue:topic.text}));
  const data: PinmonyDraftData = {alt_text:flow.altText || '',board_id:flow.selectedBoardId || null,board_section_id:flow.selectedSectionId || '',description:flow.photoDescription || '',link:flow.photoLink || '',is_comments_allowed:flow.allowComments !== false,is_shopping_rec_allowed:flow.allowShopping !== false,story_pin:JSON.stringify(payload),user_mention_tags:JSON.stringify(original?.user_mention_tags || []),topic_tags:JSON.stringify(topics),tagged_products:tags.length ? JSON.stringify(tags) : null};
  if (!data.board_section_id) data.board_section_id = undefined;
  if (!flow.editingDraft) {
    if (!data.alt_text) data.alt_text = undefined;
    if (!data.description) data.description = undefined;
    if (!data.link) data.link = undefined;
  }
  const ai: number[] = (original?.ai_disclosures || []).filter((n: number): boolean => n !== 1 && n !== 2);
  if (flow.aiModified ?? original?.ai_disclosures?.includes(1)) ai.push(1);
  if (flow.aiGeneratedPerson ?? original?.ai_disclosures?.includes(2)) ai.push(2);
  if (flow.editingDraft) data.ai_disclosures = ai;
  if (!current()) throw new Error('stale');
  const initial: PinmonyDraftInitialData = {board_id:data.board_id,is_comments_allowed:data.is_comments_allowed,is_shopping_rec_allowed:data.is_shopping_rec_allowed,story_pin:data.story_pin,topic_tags:data.topic_tags,tagged_products:data.tagged_products};
  const initialOptions: PinmonyDraftInitialOptions = {url:'/v3/storypins/drafts/',data:initial};
  const existingOptions: PinmonyDraftOptions = {url:'/v3/storypins/drafts/' + (flow.draftId || '') + '/',data:data};
  const createOptions: PinmonyDraftOptions = {url:'/v3/storypins/drafts/',data:data};
  const extra: boolean = !!data.alt_text || !!data.description || !!data.link || !!data.board_section_id;
  const options: PinmonyDraftInitialOptions | PinmonyDraftOptions = flow.editingDraft ? existingOptions : extra ? createOptions : initialOptions;
  onSubmit();
  const response: PinmonyDraftResponse = JSON.parse(await client.request(owner,'ApiResource',flow.editingDraft ? 'update' : 'create',options,'/pin-creation-tool/','www/pin-creation-tool.js',current)) as PinmonyDraftResponse;
  const result: PinmonyDraftResource = response.resource_response;
  if (!current() || response.client_context?.is_authenticated === false || response.client_context?.user && response.client_context.user.id !== owner.viewer || !result || result.status !== 'success' || result.code !== 0 || result.error || result.endpoint_name !== (flow.editingDraft ? 'v3_update_story_pin_draft' : 'v3_create_story_pin_draft') || typeof result.data !== 'string' || !/^\d{1,40}$/.test(result.data) || flow.editingDraft && result.data !== flow.draftId) throw new Error('draft-unconfirmed');
  if (!flow.editingDraft && ai.length > 0) {
    data.ai_disclosures = ai;
    owner.objectId = result.data;
    const updateOptions: PinmonyDraftOptions = {url:'/v3/storypins/drafts/' + result.data + '/',data:data};
    const updated: PinmonyDraftResponse = JSON.parse(await client.request(owner,'ApiResource','update',updateOptions,'/pin-creation-tool/','www/pin-creation-tool.js',current)) as PinmonyDraftResponse;
    const r: PinmonyDraftResource = updated.resource_response;
    if (!current() || updated.client_context?.is_authenticated === false || updated.client_context?.user && updated.client_context.user.id !== owner.viewer || !r || r.status !== 'success' || r.code !== 0 || r.error || r.endpoint_name !== 'v3_update_story_pin_draft' || r.data !== result.data) throw new Error('draft-ai-unconfirmed');
  }
  const saved: PinmonyDraftSource = {metadata:payload.metadata,pages:payload.pages,draft:{board_id:flow.selectedBoardId,section_id:data.board_section_id,ai_disclosures:ai,user_mention_tags:original?.user_mention_tags || []}};
  return {id:result.data,source:saved};
}
