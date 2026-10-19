import { PinmonyI18n } from 'common_foundation';
import { PinmonyBoardFlow } from 'feature_board';
import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob, PinmonyNetworkReply } from 'common_network';

export interface BoardSectionWriteIdentity {
  page: string; board: string; section: string; viewer: string; owner: string; intent: number;
  allIds: string[]; selectedIds: string[]; complete: boolean; targets: string[];
}
interface SectionMoveData { new_section_id?: string; new_board_id: string; old_section_id: string; exclude_pin_ids: string[]; }
interface SectionRenameData { title: string; fields: string[]; }
interface SectionResult { id: string; title: string; type: string; board: SectionWriteUser; }
interface SectionWriteOptions { url: string; data?: SectionMoveData | SectionRenameData; }
interface SectionWriteEnvelope { options: SectionWriteOptions; context: Record<string,string>; }
interface SectionWriteResource { status: string; code: number; endpoint_name: string; data: Object | null; }
interface SectionWriteResponse { resource_response: SectionWriteResource; client_context?: SectionWriteContext; }
interface SectionWriteContext { user?: SectionWriteUser; }
interface SectionWriteUser { id: string; }
export interface BoardSectionWritePorts {
  state: () => PinmonyBoardFlow | undefined; identity: () => BoardSectionWriteIdentity | undefined;
  session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork;
  changed: (flow: PinmonyBoardFlow) => void; confirmed: (action: string, title?: string) => void;
}
export class PinmonyBoardSectionNativeWrites {
  private readonly ports: BoardSectionWritePorts;
  private revision: number = 0; private sequence: number = 0; private job: string = '';
  private cancelWait: (() => void) | undefined = undefined;
  private account: string = ''; private readonly uncertain: Set<string> = new Set<string>();
  constructor(ports: BoardSectionWritePorts) { this.ports = ports; }
  pause(): void {
    this.revision++;if(this.job)this.ports.network().cancel(this.job);this.cancelWait?.();this.cancelWait = undefined;
    if(this.job && this.ports.state()?.busy){const flow: PinmonyBoardFlow = JSON.parse(JSON.stringify(this.ports.state())) as PinmonyBoardFlow;
      flow.busy = false;flow.uncertain = true;flow.error = PinmonyI18n.message("pm_result_not_confirmed_refresh_to_check_it_will_not_be_resubmitted_e8e4eb27");this.ports.changed(flow);}
    this.job = '';
  }
  async submit(action: string, target: string = ''): Promise<void> {
    const identity: BoardSectionWriteIdentity | undefined = this.ports.identity(), original: PinmonyBoardFlow | undefined = this.ports.state(), session: PinmonyBusinessSessionContext = this.ports.session();
    if(!identity || !original || this.job || !session.authenticated || !session.accountId || original.busy || original.loading || original.uncertain || identity.owner !== identity.viewer)return;
    if(!['delete','move','rename'].includes(action) || ['delete','rename'].includes(action) && original.phase !== 'sectionEdit' || action === 'move' && original.phase !== 'targets')return;
    if(action === 'rename' && (!target.trim() || target !== target.trim() || target.length > 100))return;
    const account: string = session.accountId + ':' + session.generation.toString();if(account !== this.account){this.uncertain.clear();this.account = account;}
    const key: string = identity.board + ':' + identity.section;
    if(this.uncertain.has(key)){original.uncertain = true;original.error = PinmonyI18n.message("pm_result_not_confirmed_refresh_to_check_it_will_not_be_resubmitted_e8e4eb27");this.ports.changed(original);return;}
    if(action === 'move' && (!identity.complete || !identity.selectedIds.length || !identity.targets.includes(target) ||
      identity.selectedIds.some((id: string): boolean => !identity.allIds.includes(id)) || new Set(identity.selectedIds).size !== identity.selectedIds.length))return;
    const parts: string[] = target.split(':');
    const targetSection: string = action === 'move' && parts[0] === 'section' ? parts[parts.length - 1] : '';
    const targetBoard: string = targetSection ? (parts.length === 3 ? parts[1] : identity.board) : target;
    if(targetSection && (parts.length !== 2 && parts.length !== 3 || !/^\d{1,30}$/.test(targetBoard) || !identity.targets.includes(targetBoard)))return;
    if(targetSection && (!/^\d{1,30}$/.test(targetSection) || targetSection === identity.section))return;
    const revision: number = this.revision;
    const flow: PinmonyBoardFlow = JSON.parse(JSON.stringify(original)) as PinmonyBoardFlow;flow.busy = true;flow.error = '';this.ports.changed(flow);
    const current = (): boolean => {const s: PinmonyBusinessSessionContext = this.ports.session(), i: BoardSectionWriteIdentity | undefined = this.ports.identity();
      return revision === this.revision && s.authenticated && s.accountId === session.accountId && s.generation === session.generation && s.origin === session.origin &&
        !!i && i.page === identity.page && i.board === identity.board && i.section === identity.section && i.owner === identity.owner && i.viewer === identity.viewer && i.intent === identity.intent && this.ports.state() === flow;};
    const options: SectionWriteOptions = action === 'rename' ? {url:'/v3/board/sections/' + identity.section + '/',data:{title:target,fields:['boardsection.board()','boardsection.id','boardsection.pin_count','boardsection.preview_pins()','boardsection.slug','boardsection.title','boardsection.type']}} : action === 'delete' ? {url:'/v3/board/sections/' + identity.section + '/'} :
      {url:'/v3/boards/' + identity.board + '/bulk/',data:{new_board_id:targetBoard,old_section_id:identity.section,exclude_pin_ids:identity.allIds.filter((id: string): boolean => !identity.selectedIds.includes(id))}};
    if(targetSection && options.data)(options.data as SectionMoveData).new_section_id = targetSection;
    const envelope: SectionWriteEnvelope = {options:options,context:{}}, source: string = '/boardsection/' + identity.section + (action !== 'move' ? '/edit/' : '/organize/repin/');
    const job: PinmonyNetworkJob = {id:'native_board_section_write_' + (++this.sequence).toString(),epoch:session.generation,page:identity.page,
      url:session.origin + '/resource/ApiResource/' + (action === 'rename' ? 'update/' : action === 'delete' ? 'delete/' : 'create/'),method:'POST',
      body:'source_url=' + encodeURIComponent(source) + '&data=' + encodeURIComponent(JSON.stringify(envelope)),
      headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest',
        'X-Pinterest-Pws-Handler':action !== 'move' ? 'www/boardsection/[id]/edit.js' : 'www/boardsection/[id]/organize/add.js'}};
    this.job = job.id;this.uncertain.add(key);
    try {
      const cancelled: Promise<PinmonyNetworkReply | undefined> = new Promise<PinmonyNetworkReply | undefined>((resolve): void => {this.cancelWait = (): void => resolve(undefined);});
      const reply: PinmonyNetworkReply | undefined = await Promise.race([this.ports.network().requestBusinessBoardSectionWrite(job,(): PinmonyBusinessSessionContext => this.ports.session(),identity.board,identity.section,identity.viewer,identity.owner,identity.allIds,identity.selectedIds,identity.complete,identity.targets,current),cancelled]);
      if(!current())return;
      if(!reply || reply.error || reply.status !== 200 || !reply.body || reply.body.length > 6000000)throw new Error('unconfirmed');
      const body: SectionWriteResponse = JSON.parse(reply.body) as SectionWriteResponse, r: SectionWriteResource = body.resource_response;
      if(r?.status !== 'success' || r.code !== 0 || r.endpoint_name !== (action === 'rename' ? 'v3_edit_section' : action === 'delete' ? 'v3_delete_board_section' : 'v3_board_bulk_move') || action !== 'rename' && r.data !== null || body.client_context?.user && body.client_context.user.id !== identity.viewer)throw new Error('business');
      if(action === 'rename'){const d: SectionResult = r.data as SectionResult;if(!d || d.id !== identity.section || d.type !== 'board_section' || d.title !== target || d.board?.id !== identity.board)throw new Error('section');}
      this.uncertain.delete(key);flow.busy = false;this.job = '';this.ports.changed(flow);this.ports.confirmed(action,action === 'rename' ? target : undefined);
    }catch (_) {if(current()){flow.busy = false;flow.uncertain = true;flow.error = PinmonyI18n.message("pm_result_not_confirmed_refresh_to_check_it_will_not_be_resubmitted_e8e4eb27");this.ports.changed(flow);}}
    finally {if(revision === this.revision){this.job = '';this.cancelWait = undefined;}}
  }
}
