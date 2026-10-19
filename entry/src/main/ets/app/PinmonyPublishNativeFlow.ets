import { PinmonyI18n } from 'common_foundation';
import { PinmonyProfileStore, PinmonyPublishFlow, PinmonyPublishPhoto, PinmonyCreatedPin, PinmonyOrganizeBoard } from 'feature_profile';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyRuntimeLog } from 'common_foundation';
import { PinmonySharePublishClient, PinmonySharePublishClientPorts, PinmonySharePublishOwner, PinmonyBusinessRejection } from './PinmonySharePublishClient';
interface Image {
    url: string;
}
interface User {
    id: string;
    type: string;
    username: string;
}
interface Board {
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
    title?: string;
    destination_url?: string;
    board?: Board;
    pinner?: User;
    is_repin?: boolean;
    images?: Record<string, Image>;
}
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
    private readonly store: PinmonyProfileStore;
    private revision: number = 0;
    private account: string = '';
    private generation: number = -1;
    private origin: string = '';
    private viewer: string = '';
    private flow: PinmonyPublishFlow | undefined = undefined;
    private candidates: Candidate[] = [];
    private unknown: Set<string> = new Set();
    private writeKey: string = '';
    constructor(ports: PinmonyPublishNativePorts) { this.ports = ports; this.store = ports.store(); this.client = new PinmonySharePublishClient(ports); }
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
    pause(): void { if (this.flow?.busy) {
        this.flow.uncertain = true;
        if (this.writeKey)
            this.unknown.add(this.writeKey);
        this.flow.error = PinmonyI18n.message('操作结果未确认，请关闭后刷新核对，勿重复提交');
    } if (this.flow) {
        if (this.flow.loading && !this.flow.error)
            this.flow.error = PinmonyI18n.message('读取已暂停，请返回重试');
        this.flow.busy = false;
        this.flow.loading = false;
        this.commit();
    } this.revision++; this.client.cancel(); const session: PinmonyBusinessSessionContext = this.ports.session(); if (!session.authenticated || session.accountId !== this.account || session.generation !== this.generation) {
        this.flow = undefined;
        this.candidates = [];
        this.viewer = '';
    } }
    close(): void { this.pause(); this.flow = undefined; this.candidates = []; this.writeKey = ''; this.viewer = ''; }
    private owner(mode: string, page: string): PinmonySharePublishOwner { return { page: page, mode: mode, objectId: '', viewer: this.viewer, contacts: [], boards: this.flow?.boards.filter((b: PinmonyOrganizeBoard): boolean => b.enabled).map((b: PinmonyOrganizeBoard): string => b.id) || [] }; }
    private web(value: string | undefined): string { return typeof value === 'string' && value.length <= 4096 && /^https?:\/\/[^\s/@?#]+(?:[/?#][^\s]*)?$/.test(value) ? value : ''; }
    private async read(name: string, verb: string, options: Object, source: string, handler: string, revision: number, menu: boolean = false): Promise<Response> {
        const page: string = this.flow?.page || this.ports.page(), mode: string = this.flow?.kind === 'board' ? 'create-board' : this.flow?.kind || 'create-board';
        const raw: string = await this.client.request(this.owner(mode, page), name, verb, options, source, handler, (): boolean => this.current(revision, menu));
        const p: Response = JSON.parse(raw) as Response, r: Resource = p.resource_response;
        if (!r || r.status !== 'success' || r.code !== 0 || r.error || !r.data || p.client_context?.is_authenticated === false || this.viewer && p.client_context?.user && p.client_context.user.id !== this.viewer) {
            if (r?.status === 'failure' && typeof r.code === 'number' && r.code !== 0)
                throw new PinmonyBusinessRejection(PinmonyI18n.message('网站拒绝了本次操作'));
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
            this.store.publishTitle = PinmonyI18n.message('创建');
            this.store.publishOptions = [
                { id: 'native-website', kind: 'website', group: 'create', groupLabel: PinmonyI18n.message('创建'), label: PinmonyI18n.message('网站'), enabled: true },
                { id: 'native-photo', kind: 'photo', group: 'create', groupLabel: PinmonyI18n.message('创建'), label: PinmonyI18n.message('照片'), enabled: true },
                { id: 'native-board', kind: 'board', group: 'add', groupLabel: PinmonyI18n.message('添加'), label: PinmonyI18n.message('图板'), enabled: true }
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
            this.flow.loading = false;
            this.commit();
            return true;
        }
        catch (_) {
            if (this.current(revision)) {
                this.flow.loading = false;
                this.flow.error = PinmonyI18n.message('无法确认当前账号，请返回刷新后重试');
                this.commit();
            }
            return false;
        }
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
        return undefined; return { id: b.id, title: b.name.trim().slice(0, 100), imageUrl: this.web(b.image_cover_hd_url || b.image_cover_url), secret: b.privacy === 'secret', enabled: Array.isArray(b.access) && b.access.includes('write') && !b.archived_by_me && !b.archived_by_me_at }; }
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
                f.error = PinmonyI18n.message('图板读取失败，请重试');
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
                f.error = PinmonyI18n.message('读取图片失败，请重试');
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
        f.busy = true;
        f.error = '';
        this.commit();
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
                f.feedback = PinmonyI18n.message('图板已创建');
                if (f.kind === 'board') {
                    f.completed = 1;
                    f.phase = 'done';
                    f.busy = false;
                    this.commit();
                    this.ports.done();
                    return;
                }
                this.commit();
                if (!mapped.enabled)
                    throw new PinmonyBusinessRejection('图板已创建，但没有发布权限，请选择其他图板');
            }
            const selected: Candidate[] = this.candidates.filter((c: Candidate): boolean => !c.done && f.selectedIds.includes(c.pin.id));
            if (!target?.enabled || !selected.length)
                throw new PinmonyBusinessRejection('请选择图片和可写入的图板');
            for (const c of selected) {
                if (!this.current(revision))
                    return;
                this.writeKey = JSON.stringify(['pin', target.id, c.pin.imageUrl, c.link, c.pin.title]);
                if (this.unknown.has(this.writeKey))
                    throw new Error('previous-unknown');
                const photo: boolean = f.kind === 'photo', options: CreatePinOptions = { boardId: target.id, board_id: target.id, description: c.pin.title, guid: '', imageBase64: photo ? c.base64 : '', image_base64: photo ? c.base64 : '', imageUrl: photo ? '' : c.pin.imageUrl, image_url: photo ? '' : c.pin.imageUrl, link: photo ? '' : c.link, method: photo ? 'uploaded' : 'scraped' };
                const p: Response = await this.read('PinResource', 'create', options, '/pin/create/' + (photo ? 'uploaded' : 'pinbuilder') + '/', 'www/pin/create/[method].js', revision);
                if (!this.current(revision))
                    return;
                const d: Data = p.resource_response.data;
                if (p.resource_response.endpoint_name !== 'v3_create_pin_handler' || d.type !== 'pin' || !/^\d{1,40}$/.test(d.id || '') || d.board?.id !== target.id || d.pinner?.id !== this.viewer || d.is_repin !== false || !d.images || !Object.keys(d.images).some((key: string): boolean => !!this.web(d.images![key]?.url)))
                    throw new Error('pin-unconfirmed');
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
                f.uncertain = !(error instanceof PinmonyBusinessRejection);
                if (f.uncertain && this.writeKey)
                    this.unknown.add(this.writeKey);
                f.error = (f.completed ? PinmonyI18n.message('已确认发布 ') + f.completed.toString() + ' 张。' : '') + (f.uncertain ? '操作结果未确认，请关闭后刷新核对，勿重复提交' : (error as Error).message);
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
    async action(action: string, value: string, secret: boolean): Promise<void> {
        const f: PinmonyPublishFlow | undefined = this.flow, revision: number = this.revision;
        if (!f || !this.current(revision) || !this.viewer || f.loading || f.busy || f.uncertain)
            return;
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
        else if (action === 'back') {
            f.phase = f.phase === 'create' ? (f.kind === 'board' ? 'done' : 'boards') : f.phase === 'boards' ? 'select' : f.kind === 'photo' ? 'photo' : 'website';
            f.error = '';
        }
        else if (action === 'move' && f.phase === 'boards') {
            const b: PinmonyOrganizeBoard | undefined = f.boards.find((b: PinmonyOrganizeBoard): boolean => b.id === value && b.enabled);
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
