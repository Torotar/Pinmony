import { rcp } from '@kit.RemoteCommunicationKit';
import { NetworkManager, Priority } from './PinmonyNativeNetwork';
export interface PinmonyDownloadedImage { data: ArrayBuffer; extension: string; }
export function acceptsImageDownloadUrl(value: string): boolean {return typeof value === 'string' && value.length <= 2048 && /^https:\/\/i\.pinimg\.com\/[^\s\\#]+$/i.test(value);}
export class PinmonyImageDownload {
  private generation: number = 0;private cancelTransfer: (() => void) | undefined = undefined;
  cancel(): void {this.generation++;this.cancelTransfer?.();this.cancelTransfer = undefined;}
  async read(source: string,current: () => boolean): Promise<PinmonyDownloadedImage> {
    this.cancel();if(!acceptsImageDownloadUrl(source) || !current())throw new Error('image-url');
    const generation: number = this.generation,live = (): boolean => generation === this.generation && current();
    let session: rcp.Session;
    try { session = rcp.createSession(); }
    catch (_) { throw new Error('image-session-unavailable'); }
    const request: rcp.Request = new rcp.Request(source,'GET',{'Accept':'image/*','Accept-Encoding':'identity'});
    let status: number = 0,size: number = 0;const chunks: Uint8Array[] = [];
    let timer: number = -1;let cancelled: (() => void) | undefined = undefined;
    request.configuration = {proxy:'system',transfer:{autoRedirect:false,timeout:{connectMs:10000,transferMs:30000}},tracing:{httpEventsHandler:{onStatusCodeReceive:(value: number): void => {status = value;}}}};
    request.destination = (chunk: ArrayBuffer): void => {if(!live() || status !== 200 || size + chunk.byteLength > 32 * 1024 * 1024)throw new Error('image-transfer');chunks.push(new Uint8Array(chunk).slice());size += chunk.byteLength;};
    const interruption: Promise<rcp.Response> = new Promise<rcp.Response>((_resolve,reject) => {cancelled = (): void => {try {session.cancel(request);}catch (_) {}reject(new Error('image-cancelled'));};timer = setTimeout((): void => {cancelled?.();},30000);});
    this.cancelTransfer = cancelled;
    try {
      const response: rcp.Response = await Promise.race([NetworkManager.enqueue(Priority.NORMAL,async (): Promise<rcp.Response> => {if(!live())throw new Error('image-cancelled');return session.fetch(request);}),interruption]);
      if(!live() || response.statusCode !== 200 || !size)throw new Error('image-response');
      const data: Uint8Array = new Uint8Array(size);let offset: number = 0;chunks.forEach((chunk: Uint8Array): void => {data.set(chunk,offset);offset += chunk.length;});
      let extension: string = '';
      if(data[0] === 255 && data[1] === 216 && data[2] === 255)extension = 'jpg';
      else if(data[0] === 137 && data[1] === 80 && data[2] === 78 && data[3] === 71 && data[4] === 13 && data[5] === 10 && data[6] === 26 && data[7] === 10)extension = 'png';
      else if(data[0] === 71 && data[1] === 73 && data[2] === 70 && data[3] === 56)extension = 'gif';
      else if(data[0] === 82 && data[1] === 73 && data[2] === 70 && data[3] === 70 && data[8] === 87 && data[9] === 69 && data[10] === 66 && data[11] === 80)extension = 'webp';
      else if(data[4] === 102 && data[5] === 116 && data[6] === 121 && data[7] === 112 && data[8] === 97 && data[9] === 118 && data[10] === 105 && (data[11] === 102 || data[11] === 115))extension = 'avif';
      if(!extension)throw new Error('image-format');
      const result: PinmonyDownloadedImage = {data:data.buffer as ArrayBuffer,extension:extension};return result;
    }finally {clearTimeout(timer);if(generation === this.generation)this.cancelTransfer = undefined;try {session.close();}catch (_) {}}
  }
}
