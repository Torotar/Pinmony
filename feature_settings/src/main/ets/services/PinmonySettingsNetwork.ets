import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply, PinmonyNetworkContext, PinmonyPublishImageUpload, PIN_BUSINESS_PIN_READ_ENABLED, NetworkManager, readNativeSearchProductRoute } from 'common_network';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
function profileRelayUser(id: string): string {
  const value: string = 'User:' + id, alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result: string = '';
  for(let i: number = 0;i < value.length;i += 3){
    const a: number = value.charCodeAt(i), b: number = i + 1 < value.length ? value.charCodeAt(i + 1) : 0, c: number = i + 2 < value.length ? value.charCodeAt(i + 2) : 0;
    result += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (b >> 4)] + (i + 1 < value.length ? alphabet[((b & 15) << 2) | (c >> 6)] : '=') + (i + 2 < value.length ? alphabet[c & 63] : '=');
  }
  return result;
}
interface NativeSearchEnvelope { options: Record<string, Object | null>; context: Record<string,string>; }
interface PinmonyGraphQuery {
  queryHash: string;
  variables: Object;
}

export class PinmonySettingsNetwork {
  private readonly transport: PinmonyNativeNetwork;
  constructor(transport: PinmonyNativeNetwork) { this.transport = transport; }
async requestBusinessProfileSettings(job: PinmonyNetworkJob, session: () => PinmonyBusinessSessionContext,
    profileUrl: string, userId: string, viewer: string, allowed: string[], permissions: string[], ownerCurrent: () => boolean): Promise<PinmonyNetworkReply> {
    const captured: PinmonyBusinessSessionContext = session();let permitted: boolean = false;
    try {
      const path: string = job.page.slice(captured.origin.length), username: string = path.split('/')[1];
      const settingsHandler: boolean = job.headers['X-Pinterest-Pws-Handler'] === 'www/index.js' || job.headers['X-Pinterest-Pws-Handler'] === 'www/settings/permissions.js' && job.headers['X-Pinterest-Source-Url'] === '/settings/permissions/' || job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js' && /^\/board\/\d{1,40}\/edit\/$/.test(job.headers['X-Pinterest-Source-Url'] || '');
      const basic: boolean = PIN_BUSINESS_PIN_READ_ENABLED && captured.authenticated && !!captured.accountId && ownerCurrent() && /^\/[A-Za-z0-9_]+\/$/.test(path) && job.page === profileUrl && job.page === captured.origin + path && job.headers['X-Requested-With'] === 'XMLHttpRequest' && job.headers['X-Pinterest-AppState'] === 'active' && job.epoch === captured.generation && job.id.startsWith('native_profile_settings_') && job.headers['Accept'] === 'application/json' && settingsHandler;
      const digits = (v: Object | null | undefined): boolean => typeof v === 'string' && /^\d{1,40}$/.test(v as string);
      if(job.url === captured.origin + '/_/graphql/') {
        const q: PinmonyGraphQuery = JSON.parse(job.body) as PinmonyGraphQuery,v: Record<string,Object> = q.variables as Record<string,Object>;
        const graph: boolean = basic && job.headers['X-Pinterest-Source-Url'] === path && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' && Object.keys(q).length === 2 && !!v && !Array.isArray(v) && Object.keys(v).length === 1;
        if(['369b31865237e1a2f57f1879be69a6c01ee4d6d2806cc4c624d73baea9546b08','3480bae441bb3f3e6109f1731c42df4ca90e4f8ed5a1272573cf6f52607bb772'].includes(q.queryHash))permitted = graph && digits(userId) && v['userId'] === userId;
        if(['aac6989e67cb8913e620879f06b197c7edee2e17bbf17bc73228a7a3ff560bfd','077b1f0647c0a60d022d8dd228b21a5081440f703589da0cab5f497e2447665f'].includes(q.queryHash))permitted = basic &&
          job.headers['X-Pinterest-Source-Url'] === path && job.method === 'POST' && job.headers['Content-Type'] === 'application/json' &&
          Object.keys(q).length === 2 && !!v && !Array.isArray(v) && Object.keys(v).length === 3 && digits(userId) &&
          (q.queryHash === '077b1f0647c0a60d022d8dd228b21a5081440f703589da0cab5f497e2447665f' ? v['userId'] === userId && (v['count'] === 10 || v['count'] === 50) : v['id'] === profileRelayUser(userId) && v['count'] === 10) && typeof v['cursor'] === 'string' &&
          (v['cursor'] as string).length > 0 && (v['cursor'] as string).length <= 8192;
        else if(['5e6f83666a4e4fbd33b6c78f26f80166c097f4164e666b6e408b4bb62cb8c1e5','84f6cda9933f7aa2786ff803f5c7a7bc31af0392a37434f830fd7e2602c994c0'].includes(q.queryHash))permitted = graph && digits(viewer) && digits(v['followee']) && v['followee'] !== viewer && allowed.includes('follow:' + v['followee']);
        else if(q.queryHash === '7f7aa5597fc53cb10b582e1d45cac2e61336be40dde57f95a9f022fb83806e81') {
          const input: Record<string,Object> = v['input'] as Record<string,Object>;
          permitted = graph && permissions.includes('own') && userId === viewer && digits(viewer) && !!input && !Array.isArray(input) && Object.keys(input).length === 8 && ['firstName','lastName','about','websiteUrl','username','impressumUrl'].every((k: string): boolean => typeof input[k] === 'string' && (input[k] as string).length <= 2000) && /^[A-Za-z0-9_]+$/.test(input['username'] as string) && input['impressumUrl'] === '' && Array.isArray(input['pronouns']) && !(input['pronouns'] as string[]).length && Array.isArray(input['additionalWebsiteUrls']) && !(input['additionalWebsiteUrls'] as string[]).length;
        }
      }else {
        const get: boolean = job.method === 'GET', jsonBody: boolean = job.headers['Content-Type'] === 'application/json' && job.url.endsWith('/update/');
        let f: RegExpMatchArray | null = null; let e: NativeSearchEnvelope;
        if (jsonBody) { const body: Record<string,Object> = JSON.parse(job.body) as Record<string,Object>; e = body['data'] as NativeSearchEnvelope; }
        else { f = (get ? job.url.slice(job.url.indexOf('?') + 1) : job.body).match(/^source_url=([^&]+)&data=([^&]+)$/); e = JSON.parse(decodeURIComponent(f ? f[2].replace(/\+/g,' ') : '')) as NativeSearchEnvelope; }
        const o: Record<string,Object | null> = e.options;
        const source: string = jsonBody ? (JSON.parse(job.body) as Record<string,Object>)['source_url'] as string : f ? decodeURIComponent(f[1].replace(/\+/g,' ')) : '', keys: string[] = Object.keys(o),resource: string = job.url.split('?')[0].slice(captured.origin.length);
        const envelope: boolean = basic && (jsonBody || !!f) && job.headers['X-Pinterest-Source-Url'] === source && Object.keys(e).length === 2 && !!e.context && typeof e.context === 'object' && !Array.isArray(e.context) && !Object.keys(e.context).length && !!o && !Array.isArray(o) && (get ? job.body === '' : job.method === 'POST' && (jsonBody || job.headers['Content-Type'] === 'application/x-www-form-urlencoded'));
        const own: boolean = permissions.includes('own') && userId === viewer && digits(viewer);
        if(envelope && resource === '/resource/UserResource/get/')permitted = get && source === path && keys.length === 2 && o['username'] === username && o['field_set_key'] === 'profile';
        else if(envelope && resource === '/resource/UserFollowingResource/get/')permitted = get && source === path && (keys.length === 3 || keys.length === 4 && Array.isArray(o['bookmarks']) && (o['bookmarks'] as string[]).length === 1 && typeof (o['bookmarks'] as string[])[0] === 'string' && !!(o['bookmarks'] as string[])[0] && (o['bookmarks'] as string[])[0] !== '-end-' && (o['bookmarks'] as string[])[0].length <= 4096) && keys.every((key: string): boolean => ['username','page_size','explicit_following','bookmarks'].includes(key)) && o['username'] === username && o['page_size'] === 50 && o['explicit_following'] === true;
        else if(envelope && resource === '/resource/UserSettingsResource/get/')permitted = get && own && !keys.length && ['/settings/account-settings/','/settings/profile-visibility/'].includes(source);
        else if(envelope && resource === '/resource/CountriesResource/get/')permitted = get && own && !keys.length && source === '/settings/edit/country-region/';
        else if(envelope && own && ['/resource/BoardResource/get/','/resource/BoardResource/update/'].includes(resource)) {
          const id: string = o['board_id'] as string;
          const board: boolean = digits(id) && allowed.includes('recommend-board:' + id) && source === '/board/' + id + '/edit/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/board/[id]/edit.js';
          permitted = board && (get ? resource === '/resource/BoardResource/get/' && keys.length === 2 && o['field_set_key'] === 'edit' :
            resource === '/resource/BoardResource/update/' && keys.length === 8 && allowed.includes('recommend-board-update:' + JSON.stringify(o)) &&
            typeof o['name'] === 'string' && !!(o['name'] as string).trim() && o['name'] === (o['name'] as string).trim() && (o['name'] as string).length <= 300 &&
            typeof o['description'] === 'string' && (o['description'] as string).length <= 500 && ['public','secret'].includes(o['privacy'] as string) &&
            typeof o['allow_homefeed_recommendations'] === 'boolean' && typeof o['collaborator_invites_enabled'] === 'boolean' && typeof o['collaborator_requests_enabled'] === 'boolean' && o['sensitivity'] === null);
        }
        else if(envelope && resource === '/resource/UserRecentActivityResource/get/')permitted = get && own && source === '/edit/activity/' && keys.length === 2 && o['username'] === 'me' && o['filter_type'] === 'all';
        else if(envelope && resource === '/resource/UserSettingsResource/update/' && !get && own) {
          const fields: string[] = keys.filter((k: string): boolean => !['user_id','surface_tag','user_confirm_skip_passcode'].includes(k)),field: string = fields[0],value: Object | null = o[field];
          permitted = fields.length === 1 && o['surface_tag'] === 'settings' && (field === 'birthdate' ? keys.length === 2 && typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && source === '/settings/edit/birthdate/' : o['user_id'] === viewer && (field === 'opt_in_private_account' ? keys.length === 4 && permissions.includes('privacy') && o['user_confirm_skip_passcode'] === false && typeof value === 'boolean' && source === '/settings/profile-visibility/' : keys.length === 3 && (field === 'exclude_from_search' ? permissions.includes('search') && typeof value === 'boolean' && source === '/settings/profile-visibility/' : field === 'gender' ? ['female','male','unspecified'].includes(value as string) && source === '/settings/edit/gender/' : field === 'custom_gender' ? permissions.includes('custom') && typeof value === 'string' && !!(value as string).trim() && (value as string).length <= 500 && source === '/settings/edit/gender/' : field === 'country' && typeof value === 'string' && allowed.includes('country:' + value) && source === '/settings/edit/country/')));
          // Country source follows the existing country-region route.
          if(field === 'country')permitted = fields.length === 1 && keys.length === 3 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && typeof value === 'string' && /^[A-Z]{2}$/.test(value) && allowed.includes('country:' + value) && source === '/settings/edit/country-region/';
          if (['autoplay_videos_on_wifi_enabled','autoplay_videos_on_cellular_enabled'].includes(field)) permitted = fields.length === 1 && keys.length === 3 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && typeof value === 'boolean' && source === '/settings/permissions/';
          if (field === 'allow_mentions' || field === 'messaging_permissions') {
            const base: boolean = fields.length === 1 && keys.length === 4 && o['surface_tag'] === 'settings' && o['user_id'] === viewer && o['user_confirm_skip_passcode'] === false;
            if (field === 'allow_mentions') permitted = base && source === '/settings/edit/mentions/' && [0,1,2].includes(value as number) && allowed.includes('social-mentions:' + value);
            else {
              const choices: Record<string,Object> = value as Record<string,Object>, groups: string[] = choices && !Array.isArray(choices) ? Object.keys(choices) : [];
              const group: string = groups[0], level: Object = choices?.[group];
              const route: string = group === '0' ? 'friends' : group === '1' ? 'followers' : group === '2' ? 'following' : group === '4' ? 'others' : '';
              permitted = base && groups.length === 1 && !!route && source === '/settings/messages/' + route + '/' && [0,1,2].includes(level as number) && (group !== '4' || level !== 0) && allowed.includes('social-message:' + group + ':' + level);
            }
          }
          if (source === '/settings/permissions/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/settings/permissions.js') {
            const socialFields: string[] = keys.filter((k: string): boolean => !['surface_tag','user_confirm_skip_passcode'].includes(k));
            const socialKeys: string[] = ['comments_disabled','shopping_rec_disabled','allow_idea_pin_downloads','commentSettings'];
            const socialOnly: boolean = socialFields.length >= 1 && socialFields.every((k: string): boolean => socialKeys.includes(k)) && keys.length === socialFields.length + 2 && o['surface_tag'] === 'settings' && o['user_confirm_skip_passcode'] === false;
            if (socialOnly) {
              const settings: Object | null = o['commentSettings'];
              const settingsObject: Record<string,Object | null> = settings as Record<string,Object | null>;
              permitted = socialFields.every((k: string): boolean => k !== 'comments_disabled' && k !== 'shopping_rec_disabled' && k !== 'allow_idea_pin_downloads' || typeof o[k] === 'boolean') &&
                (!settings || !!settingsObject && !Array.isArray(settingsObject) && Object.keys(settingsObject).length <= 2 && Object.keys(settingsObject).every((k: string): boolean => ['comments_phrase_filter_list_enabled','pinner_comments_phrase_filter_list_enabled'].includes(k) && typeof settingsObject[k] === 'boolean'));
            }
          }
        }else if(envelope && resource === '/resource/ApiResource/get/') {
          const data: Record<string,Object> = o['data'] as Record<string,Object>,url: string = o['url'] as string;
          permitted = keys.length === 1 && get && own && url === '/v3/settings/notifications/' && source === path;
          if(get && own && source === path + '_saved/' && keys.length === 2 && url === '/v3/users/me/boards/soft_deleted/' && data && Object.keys(data).length === 1) {
            const fields: string[] = data['fields'] as string[];
            permitted = Array.isArray(fields) && fields.join(',') === 'board.image_cover_url,board.id,board.name,board.pin_count,board.section_count,board.url';
          }
          if (!get && source === path && keys.length === 3 && data && !Array.isArray(data) &&
            url === '/v3/users/' + username + '/boards/following/' && data['explicit_following'] === true &&
            data['page_size'] === 12 && Object.keys(data).length === 3 &&
            JSON.stringify(data['fields']) === JSON.stringify(['board.id','board.name','board.image_cover_url','board.followed_by_me','board.type','board.images[236x]','board.image_cover_hd_url','board.pin_count','board.board_order_modified_at','board.url','board.owner()','user.username'])) {
            const bookmarks: string[] = o['bookmarks'] as string[];
            permitted = Array.isArray(bookmarks) && bookmarks.length === 1 && typeof bookmarks[0] === 'string' && !!bookmarks[0] && bookmarks[0].length <= 4096;
          }
          if(keys.length === 2 && data && !Array.isArray(data)) {
            if(get && !Object.keys(data).length)permitted = (url === '/v3/users/settings/' && own && [path,'/settings/permissions/','/settings/edit/birthdate/','/settings/messages/','/settings/edit/mentions/'].includes(source)) || own && url === '/v3/users/settings/gen_ai/' && source === '/edit/gen-ai-interests/';
            if(get && own && source === '/settings/permissions/' && url === '/v3/aggregated_comments/features/' && Object.keys(data).length === 1 && data['user'] === viewer) permitted = true;
            else if(!get)permitted = source === path && url === '/v3/users/' + username + '/boards/following/' && data['explicit_following'] === true && data['page_size'] === 12 && Object.keys(data).length === 3 && JSON.stringify(data['fields']) === JSON.stringify(['board.id','board.name','board.image_cover_url','board.followed_by_me','board.type','board.images[236x]','board.image_cover_hd_url','board.pin_count','board.board_order_modified_at','board.url','board.owner()','user.username']);
            if(get && own && url === '/v3/users/blocked' && source === '/settings/blocked-accounts/') permitted = Object.keys(data).length === 1 && data['q'] === '';
          }
        }else if(envelope && resource === '/resource/ApiResource/delete/' && !get && own && keys.length === 1 && source === '/settings/blocked-accounts/') {
          const target: RegExpMatchArray | null = (o['url'] as string || '').match(/^\/v3\/users\/(\d{1,40})\/block\/$/);
          permitted = !!target && target[1] !== viewer && allowed.includes('social-unblock:' + target[1]);
        }else if(envelope && resource === '/resource/ApiResource/create/' && !get && own && keys.length === 2) {
          const data: Record<string,Object> = o['data'] as Record<string,Object>;
          if(o['url'] === '/v3/settings/notifications/' && source === path && data && Object.keys(data).length === 1 && typeof data['updated_settings'] === 'string' && (data['updated_settings'] as string).length < 1000) {
            const choices: Record<string,Object>[] = JSON.parse(data['updated_settings'] as string) as Record<string,Object>[];
            const c: Record<string,Object> = choices[0];
            permitted = Array.isArray(choices) && choices.length === 1 && !!c && Object.keys(c).length === 4 && typeof c['value'] === 'boolean' && ['push','email','news'].includes(c['type'] as string) && allowed.includes('notification:' + c['type'] + ':' + c['section'] + ':' + c['option']);
          }else if(o['url'] === '/v3/users/settings/' && source === '/edit/gen-ai-interests/' && data && Object.keys(data).length === 2 && data['gen_ai_topics_update_source'] === 'hf_tuner') {
            const ids: string[] = (data['gen_ai_topics_opt_in'] || data['gen_ai_topics_opt_out']) as string[];
            permitted = Array.isArray(ids) && ids.length > 0 && ids.length <= 80 && ids.every((id: string,i: number): boolean => digits(id) && allowed.includes('topic:' + id) && ids.indexOf(id) === i);
          }else if(o['url'] === '/v3/pins/bulk/move/' && source === path && data && Object.keys(data).length === 2) {
            const ids: string[] = data['pin_ids'] as string[];permitted = digits(data['board_id']) && allowed.includes('board:' + data['board_id']) && Array.isArray(ids) && ids.length > 0 && ids.length <= 100 && ids.every((id: string,i: number): boolean => digits(id) && allowed.includes('organize:' + id) && ids.indexOf(id) === i);
          }
        }else if(envelope && resource === '/resource/ApiResource/update/' && !get && own && source === path + '_saved/' && keys.length === 1) {
          const target: RegExpMatchArray | null = (o['url'] as string || '').match(/^\/v3\/boards\/(\d{1,40})\/restore\/$/);
          permitted = !!target && allowed.includes('restore-board:' + target[1]);
        }else if(envelope && resource === '/resource/ApiResource/update/' && !get && own && source === '/edit/activity/' && keys.length === 2) {
          const data: Record<string,Object> = o['data'] as Record<string,Object>,id: string = data?.['pin'] as string;
          permitted = digits(id) && allowed.includes('pin:' + id) && !!data && data['feedback_type'] === 4 && data['through_id'] === id && ((o['url'] === '/v3/pfy/' + id + '/feedback/' && Object.keys(data).length === 4 && data['rec_reason_type'] === 4) || (o['url'] === '/v3/pfy/' + id + '/feedback/undo/' && Object.keys(data).length === 3));
        }else if(envelope && resource === '/resource/BoardsResource/get/' && get && own && source === path) {
          permitted = keys.every((k: string): boolean => ['privacy_filter','sort','field_set_key','filter_stories','username','page_size','group_by','include_archived','filter_all_pins','bookmarks'].includes(k)) && keys.length >= 9 && keys.length <= 10 && o['privacy_filter'] === 'all' && o['sort'] === 'custom' && o['field_set_key'] === 'profile_grid_item' && o['filter_stories'] === true && o['username'] === username && o['page_size'] === 25 && o['group_by'] === 'mix_public_private' && o['include_archived'] === true && o['filter_all_pins'] === false && (!keys.includes('bookmarks') || Array.isArray(o['bookmarks']) && (o['bookmarks'] as string[]).length === 1 && typeof (o['bookmarks'] as string[])[0] === 'string' && (o['bookmarks'] as string[])[0].length <= 8192);
        }else if(envelope && resource === '/resource/BoardResource/create/' && !get && own && source === path)permitted = keys.length === 2 && typeof o['name'] === 'string' && !!(o['name'] as string).trim() && o['name'] === (o['name'] as string).trim() && (o['name'] as string).length <= 300 && ['public','secret'].includes(o['privacy'] as string);
        else if(envelope && resource === '/resource/ApiResource/update/' && !get && own && source === '/settings/permissions/' && job.headers['X-Pinterest-Pws-Handler'] === 'www/settings/permissions.js') {
          const data: Record<string,Object | null> = o['data'] as Record<string,Object | null>, featureMap: Record<string,Object | null> = data?.['feature_map'] as Record<string,Object | null>;
          permitted = keys.length === 3 && o['send_as_json'] === true && o['url'] === '/v3/aggregated_comments/features/' && !!data && Object.keys(data).length === 3 && data['user'] === viewer && data['user_confirm_skip_passcode'] === false && !!featureMap && !Array.isArray(featureMap) && Object.keys(featureMap).length >= 1 && Object.keys(featureMap).length <= 4 && Object.keys(featureMap).every((k: string): boolean => ['comments_phrase_filter_list','comments_phrase_filter_list_enabled','pinner_comments_phrase_filter_list','pinner_comments_phrase_filter_list_enabled'].includes(k) && (k.endsWith('_enabled') ? typeof featureMap[k] === 'boolean' && allowed.includes('social:filter:' + (k.startsWith('pinner_') ? 'others' : 'mine') + ':' + String(featureMap[k])) : Array.isArray(featureMap[k]) && (featureMap[k] as Object[]).length <= 100 && (featureMap[k] as Object[]).every((item: Object): boolean => typeof item === 'string' && (item as string).length > 0 && (item as string).length <= 200 && (item as string) === (item as string).trim()) && allowed.includes('social:filter:' + (k.startsWith('pinner_') ? 'others' : 'mine') + ':phrases:' + JSON.stringify(featureMap[k]))));
        }
      }
    }catch (_) {}
    return this.transport.request(job,(): PinmonyNetworkContext => {const actual: PinmonyBusinessSessionContext = session();return {authenticated:permitted && ownerCurrent() && actual.authenticated && actual.accountId === captured.accountId && actual.generation === captured.generation && actual.origin === captured.origin,epoch:captured.generation,page:job.page,userAgent:actual.userAgent};});
  }
}
