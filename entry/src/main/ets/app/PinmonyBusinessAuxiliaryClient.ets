import { PinmonyBusinessSessionContext } from 'common_session';
import { PinmonyNativeNetwork, PinmonyNetworkJob } from 'common_network';
export interface PinmonyAuxiliaryPorts { session: () => PinmonyBusinessSessionContext; network: () => PinmonyNativeNetwork; }
interface Envelope { options: Object; context: Record<string,string>; }
export class PinmonyAuxiliaryNotSent extends Error {}
export class PinmonyAuxiliaryRejected extends Error {}
export class PinmonyBusinessAuxiliaryClient {
  private readonly ports: PinmonyAuxiliaryPorts;
  private static sequence: number = 0;
  private readonly requests: Set<string> = new Set<string>();
  constructor(ports: PinmonyAuxiliaryPorts) { this.ports = ports; }
  pause(): void { this.requests.forEach((id: string): void => this.ports.network().cancel(id));this.requests.clear(); }
  key(): string {const s: PinmonyBusinessSessionContext = this.ports.session();return s.authenticated && s.accountId ? s.accountId + ':' + s.generation.toString() + ':' + s.origin : '';}
  async request(page: string,resource: string,verb: string,options: Object,mode: string,target: string,live: () => boolean): Promise<string> {
    const s: PinmonyBusinessSessionContext = this.ports.session(),account: string = this.key();
    const id: string = 'native_aux_' + (++PinmonyBusinessAuxiliaryClient.sequence).toString();
    const path: string = page.slice(s.origin.length),envelope: Envelope = {options:options,context:{}};
    const fields: string = 'source_url=' + encodeURIComponent(path) + '&data=' + encodeURIComponent(JSON.stringify(envelope));
    const get: boolean = verb === 'get';
    const job: PinmonyNetworkJob = {id:id,epoch:s.generation,page:page,url:s.origin + '/resource/' + resource + '/' + verb + '/' + (get ? '?' + fields : ''),
      method:get ? 'GET' : 'POST',body:get ? '' : fields,headers:{'Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'XMLHttpRequest','X-Pinterest-Pws-Handler':mode === 'quiz' ? 'www/search/[scope].js' : 'www/index.js','X-Pinterest-Source-Url':path}};
    this.requests.add(id);
    try {
      const reply = await this.ports.network().requestBusinessAuxiliary(job,(): PinmonyBusinessSessionContext => this.ports.session(),mode,target,(): boolean => !!account && account === this.key() && live());
      if(['request-unavailable','background'].includes(reply.error))throw new PinmonyAuxiliaryNotSent('not-sent');
      if(!live() || account !== this.key())throw new Error('stale');
      if(reply.error || reply.status !== 200 || reply.body.length > 6000000)throw new Error('request');
      return reply.body;
    }finally {this.requests.delete(id);}
  }
}
