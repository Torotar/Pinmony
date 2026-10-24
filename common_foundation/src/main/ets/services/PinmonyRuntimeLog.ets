import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { PinmonyLogBuffer } from './PinmonyLogBuffer';

// Append-only persistent diagnostics with bounded memory and export chunks.
// Never export WebView storage, headers or response bodies.
export class PinmonyRuntimeLog {
  private static actionStage: string = 'none';
  private static actionAt: number = 0;
  static recentActionContext(): string {
    return 'stage=' + PinmonyRuntimeLog.actionStage + ' ageMs=' +
      (PinmonyRuntimeLog.actionAt ? Math.max(0, Date.now() - PinmonyRuntimeLog.actionAt).toString() : 'unknown');
  }
  private static readonly MAX_MEMORY_LINES: number = 1000;
  private static path: string = '';
  private static readonly lines: PinmonyLogBuffer = new PinmonyLogBuffer(1000);
  private static pending: string[] = [];
  private static pendingBytes: number = 0;
  private static dropped: number = 0;
  private static flushTimer: number = -1;
  private static writing: Promise<void> | undefined = undefined;
  private static snapshotDirty: boolean = false;
  private static initializing: boolean = false;
  private static restoration: Promise<void> = Promise.resolve();
  private static snapshotRead: Promise<void> = Promise.resolve();
  private static exporting: boolean = false;
  private static clearing: boolean = false;
  private static initializationGeneration: number = 0;
  private static sessionIncomplete: boolean = false;
  private static sessionPath: string = '';
  private static previousPath: string = '';
  private static sessionPersisted: boolean = false;
  private static sessionStartedAt: number = 0;

  static savedStatus(): string {
    return PinmonyRuntimeLog.sessionPersisted && !PinmonyRuntimeLog.sessionIncomplete ? '日志已自动保存在应用内，可导出到文件管理器' :
      '日志自动保存尚未成功，可尝试导出内存中的记录';
  }

  static sanitize(message: string): string {
    return message.replace(/https?:\/\/[^\s"']+/gi, '[url]')
      .replace(/(?:cookie|authorization|csrf|token|password|account_id|user_id)\s*[=:]\s*[^\s,;]+/gi, '[credential]')
      .replace(/\b\d{12,}\b/g, '[id]').replace(/[\r\n]+/g, ' ').slice(0, 800);
  }

  static initialize(filesDir: string): Promise<void> {
    PinmonyRuntimeLog.sessionStartedAt = Date.now();
    PinmonyRuntimeLog.path = filesDir + '/pinweb-runtime.log';
    PinmonyRuntimeLog.sessionPath = filesDir + '/pinweb-session-current.log';
    PinmonyRuntimeLog.previousPath = filesDir + '/pinweb-session-previous.log';
    PinmonyRuntimeLog.sessionPersisted = false;
    PinmonyRuntimeLog.sessionIncomplete = false;
    PinmonyRuntimeLog.initializing = true;
    PinmonyRuntimeLog.lines.clear();
    const generation: number = ++PinmonyRuntimeLog.initializationGeneration;
    PinmonyRuntimeLog.restoration = fs.readText(PinmonyRuntimeLog.path, { length: 4 * 1024 * 1024 }).then((history: string): void => {
      if (generation !== PinmonyRuntimeLog.initializationGeneration) return;
      const current: string[] = PinmonyRuntimeLog.lines.snapshot();
      PinmonyRuntimeLog.lines.clear();
      history.split('\n').filter((line: string): boolean => line.length > 0).slice(-PinmonyRuntimeLog.MAX_MEMORY_LINES)
        .forEach((line: string): void => PinmonyRuntimeLog.lines.push(PinmonyRuntimeLog.sanitize(line)));
      current.forEach((line: string): void => PinmonyRuntimeLog.lines.push(line));
      PinmonyRuntimeLog.info('StartupBoundary: log-history-restored elapsedMs=' +
        (Date.now() - PinmonyRuntimeLog.sessionStartedAt).toString());
    }).catch((): void => {});
    PinmonyRuntimeLog.info('Runtime: application started');
    return PinmonyRuntimeLog.restoration;
  }

  static info(message: string): void { PinmonyRuntimeLog.record('INFO', message); }
  static warn(message: string): void { PinmonyRuntimeLog.record('WARN', message); }
  static error(message: string): void { PinmonyRuntimeLog.record('ERROR', message); }

  static sessionElapsedMs(): number {
    return PinmonyRuntimeLog.sessionStartedAt > 0 ? Date.now() - PinmonyRuntimeLog.sessionStartedAt : 0;
  }

  private static record(level: string, message: string): void {
    const stage: RegExpMatchArray | null = message.match(/^AsyncAction: stage=(share-close|more-close|snackbar-dismiss|snackbar-back)$/);
    if (stage) { PinmonyRuntimeLog.actionStage = stage[1]; PinmonyRuntimeLog.actionAt = Date.now(); }
    const safe: string = PinmonyRuntimeLog.sanitize(message);
    console.info('PinmonyLog: ' + level + ' ' + safe);
    const line: string = new Date().toISOString() + ' ' + level + ' ' + safe;
    PinmonyRuntimeLog.lines.push(line);
    PinmonyRuntimeLog.snapshotDirty = true;
    if (!PinmonyRuntimeLog.path) return;
    // Bound the queue even when storage stalls. Overflow is reported without recursive logging.
    if (PinmonyRuntimeLog.pending.length >= 1000) {
      const removed: string | undefined = PinmonyRuntimeLog.pending.shift();
      if (removed) PinmonyRuntimeLog.pendingBytes -= removed.length * 4;
      PinmonyRuntimeLog.dropped++;
    }
    PinmonyRuntimeLog.pending.push(line);
    PinmonyRuntimeLog.pendingBytes += line.length * 4;
    if (PinmonyRuntimeLog.pending.length >= 64 || PinmonyRuntimeLog.pendingBytes >= 65536) {
      PinmonyRuntimeLog.flush();
    } else if (PinmonyRuntimeLog.flushTimer < 0 && !PinmonyRuntimeLog.writing) {
      PinmonyRuntimeLog.flushTimer = setTimeout((): void => { PinmonyRuntimeLog.flushTimer = -1; PinmonyRuntimeLog.flush(); }, 250);
    }
  }

  static flush(): Promise<void> {
    if (PinmonyRuntimeLog.clearing) return Promise.resolve();
    if (PinmonyRuntimeLog.flushTimer >= 0) clearTimeout(PinmonyRuntimeLog.flushTimer);
    PinmonyRuntimeLog.flushTimer = -1;
    if (PinmonyRuntimeLog.writing) return PinmonyRuntimeLog.writing;
    if (!PinmonyRuntimeLog.path) return Promise.resolve();
    let failed: boolean = false;
    PinmonyRuntimeLog.writing = Promise.resolve().then(async (): Promise<void> => {
      await PinmonyRuntimeLog.restoration;
      await PinmonyRuntimeLog.snapshotRead;
      if (PinmonyRuntimeLog.initializing) {
        await PinmonyRuntimeLog.writeSession('\n--- Application launch ' +
          new Date(PinmonyRuntimeLog.sessionStartedAt).toISOString() + ' ---\n');
        PinmonyRuntimeLog.initializing = false;
      }
      while (PinmonyRuntimeLog.pending.length > 0 || PinmonyRuntimeLog.snapshotDirty) {
        const batch: string[] = PinmonyRuntimeLog.pending;
        PinmonyRuntimeLog.pending = []; PinmonyRuntimeLog.pendingBytes = 0;
        const dropped: number = PinmonyRuntimeLog.dropped; PinmonyRuntimeLog.dropped = 0;
        const snapshot: string = PinmonyRuntimeLog.lines.snapshot().join('\n') + '\n';
        PinmonyRuntimeLog.snapshotDirty = false;
        try {
          const text: string = (dropped > 0 ? 'RuntimeLog: dropped=' + dropped + ' reason=storage-backpressure\n' : '') + batch.join('\n') + '\n';
          if (batch.length > 0 || dropped > 0) await PinmonyRuntimeLog.writeSession(text);
          await PinmonyRuntimeLog.writeFile(PinmonyRuntimeLog.path, snapshot, false);
        } catch (_) {
          failed = true;
          // Session append may already have succeeded: do not replay a partially written batch.
          PinmonyRuntimeLog.sessionPersisted = false;
          PinmonyRuntimeLog.sessionIncomplete = true;
          console.warn('PinmonyLog: persistence failed; memory diagnostics retained');
          break;
        }
      }
    }).catch((): void => {
      failed = true;
      PinmonyRuntimeLog.sessionPersisted = false;
      PinmonyRuntimeLog.sessionIncomplete = true;
      console.warn('PinmonyLog: session initialization failed');
    }).finally((): void => {
      PinmonyRuntimeLog.writing = undefined;
      if (!failed && (PinmonyRuntimeLog.pending.length > 0 || PinmonyRuntimeLog.snapshotDirty) && PinmonyRuntimeLog.flushTimer < 0) {
        PinmonyRuntimeLog.flushTimer = setTimeout((): void => { PinmonyRuntimeLog.flushTimer = -1; PinmonyRuntimeLog.flush(); }, 250);
      }
    });
    return PinmonyRuntimeLog.writing;
  }

  private static async writeFile(path: string, text: string, append: boolean): Promise<number> {
    let file: fs.File | undefined = undefined;
    let total: number = 0;
    let failed: boolean = false;
    try {
      file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | (append ? fs.OpenMode.APPEND : fs.OpenMode.TRUNC));
      for (let start: number = 0; start < text.length;) {
        let end: number = Math.min(start + 65536, text.length);
        const last: number = text.charCodeAt(end - 1);
        if (end < text.length && last >= 0xD800 && last <= 0xDBFF) end--;
        const bytes: Uint8Array = new util.TextEncoder().encodeInto(text.slice(start, end));
        let offset: number = 0;
        while (offset < bytes.byteLength) {
          const written: number = await fs.write(file.fd, bytes.buffer.slice(offset));
          if (written <= 0 || written > bytes.byteLength - offset) throw new Error('Incomplete diagnostics write');
          offset += written;
        }
        total += bytes.byteLength; start = end;
      }
      return total;
    } catch (_) {
      failed = true;
      throw new Error('diagnostics-write-failed');
    } finally {
      try { if (file) await fs.close(file); }
      catch (_) {
        console.warn('PinmonyLog: file close failed');
        if (!failed) throw new Error('diagnostics-close-failed');
      }
    }
  }

  private static async writeSession(text: string): Promise<void> {
    if (!PinmonyRuntimeLog.sessionPath) return;
    try {
    await PinmonyRuntimeLog.writeFile(PinmonyRuntimeLog.sessionPath, text, true);
    PinmonyRuntimeLog.sessionPersisted = true;
    } catch (error) {
      PinmonyRuntimeLog.sessionPersisted = false;
      PinmonyRuntimeLog.sessionIncomplete = true;
      throw new Error('diagnostics-session-write-failed');
    }
  }

  static async clear(): Promise<boolean> {
    if (PinmonyRuntimeLog.exporting || PinmonyRuntimeLog.clearing || !PinmonyRuntimeLog.path) return false;
    PinmonyRuntimeLog.clearing = true;
    try {
      if (PinmonyRuntimeLog.flushTimer >= 0) clearTimeout(PinmonyRuntimeLog.flushTimer);
      PinmonyRuntimeLog.flushTimer = -1;
      await PinmonyRuntimeLog.restoration;
      await PinmonyRuntimeLog.writing;
      PinmonyRuntimeLog.lines.clear();
      PinmonyRuntimeLog.pending = [];
      PinmonyRuntimeLog.pendingBytes = 0;
      PinmonyRuntimeLog.dropped = 0;
      PinmonyRuntimeLog.snapshotDirty = false;
      PinmonyRuntimeLog.actionStage = 'none';
      PinmonyRuntimeLog.actionAt = 0;
      // Truncate only app-owned log files; previously exported documents remain untouched.
      await PinmonyRuntimeLog.writeFile(PinmonyRuntimeLog.previousPath, '', false);
      await PinmonyRuntimeLog.writeFile(PinmonyRuntimeLog.sessionPath, '', false);
      await PinmonyRuntimeLog.writeFile(PinmonyRuntimeLog.path, '', false);
      PinmonyRuntimeLog.initializing = false;
      PinmonyRuntimeLog.sessionPersisted = true;
      PinmonyRuntimeLog.sessionIncomplete = false;
      PinmonyRuntimeLog.info('Runtime: logs cleared');
      return true;
    } catch (_) {
      PinmonyRuntimeLog.sessionPersisted = false;
      PinmonyRuntimeLog.sessionIncomplete = true;
      PinmonyRuntimeLog.warn('Runtime: log clear incomplete');
      return false;
    } finally {
      PinmonyRuntimeLog.clearing = false;
      await PinmonyRuntimeLog.flush();
    }
  }

  static async export(context: common.UIAbilityContext): Promise<boolean> {
    if (PinmonyRuntimeLog.exporting || PinmonyRuntimeLog.clearing) return false;
    PinmonyRuntimeLog.exporting = true;
    try {
      PinmonyRuntimeLog.info('Runtime: log export requested');
      const destinations: string[] = await new picker.DocumentViewPicker(context).save({
        newFileNames: ['Pinmony-runtime-' + new Date().toISOString().replace(/[:.]/g, '-') + '.txt']
      });
      if (!destinations.length) return false;
      await PinmonyRuntimeLog.flush();
      let release: () => void = (): void => {};
      PinmonyRuntimeLog.snapshotRead = new Promise<void>((resolve: () => void): void => { release = resolve; });
      const summary: PinmonyDiagnosticSummary = new PinmonyDiagnosticSummary();
      try {
        await PinmonyRuntimeLog.writeFile(destinations[0],
          'Pinmony application diagnostics (not full system HiLog)\n' +
          '--- Legacy retained history ---\n', false);
        await PinmonyRuntimeLog.copyLog(PinmonyRuntimeLog.previousPath, destinations[0], summary);
        await PinmonyRuntimeLog.writeFile(destinations[0], '\n--- Continuous application history ---\n', true);
        const copied: boolean = await PinmonyRuntimeLog.copyLog(PinmonyRuntimeLog.sessionPath, destinations[0], summary);
        if (!copied || PinmonyRuntimeLog.sessionIncomplete) {
          const memory: string = '\n--- Retained memory after storage failure ---\n' + PinmonyRuntimeLog.lines.snapshot().join('\n') + '\n';
          summary.add(memory);
          await PinmonyRuntimeLog.writeFile(destinations[0], memory, true);
        }
        summary.finish();
        await PinmonyRuntimeLog.writeFile(destinations[0], '\n--- Diagnostic summary ---\n' + summary.result() + '\n', true);
      } finally { release(); }
      PinmonyRuntimeLog.info('Runtime: log export completed');
      return true;
    } catch (_) {
      console.warn('PinmonyLog: export failed; persistent history retained');
      return false;
    } finally { PinmonyRuntimeLog.exporting = false; }
  }

  private static async copyLog(path: string, destination: string, summary: PinmonyDiagnosticSummary): Promise<boolean> {
    let file: fs.File;
    try { file = await fs.open(path, fs.OpenMode.READ_ONLY); } catch (_) { return false; }
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(65536);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      while (true) {
        let read: number;
        try { read = await fs.read(file.fd, buffer); }
        catch (_) { throw new Error('diagnostics-read-failed'); }
        if (!read) break;
        const text: string = decoder.decodeToString(new Uint8Array(buffer, 0, read), { stream: true });
        summary.add(text);
        await PinmonyRuntimeLog.writeFile(destination, text, true);
      }
      const remaining: string = decoder.decodeToString(new Uint8Array(0), { stream: false });
      summary.add(remaining);
      summary.finish();
      if (remaining) await PinmonyRuntimeLog.writeFile(destination, remaining, true);
      return true;
    } finally {
      try { await fs.close(file); }
      catch (_) { throw new Error('diagnostics-close-failed'); }
    }
  }
}

class PinmonyDiagnosticSummary {
  private readonly counts: Record<string, number> = {};
  private pending: string = '';

  constructor() {
    ['total', 'info', 'warn', 'error', 'offlineCache', 'homeCache', 'webMainFrameErrors', 'actionGate', 'photoDownload', 'sharePanel']
      .forEach((key: string): void => { this.counts[key] = 0; });
  }

  add(text: string): void {
    const lines: string[] = (this.pending + text).split('\n');
    // Application records are at most 800 characters; malformed legacy lines
    // must not make the streaming summary retain an unbounded string.
    this.pending = (lines.pop() || '').slice(0, 2048);
    lines.forEach((line: string): void => this.count(line));
  }

  finish(): void { if (this.pending) this.count(this.pending); this.pending = ''; }

  private count(line: string): void {
    if (!line) return;
    this.counts['total']++;
    if (line.includes(' INFO ')) this.counts['info']++;
    if (line.includes(' WARN ')) this.counts['warn']++;
    if (line.includes(' ERROR ')) this.counts['error']++;
    if (line.includes('OfflineCache:')) this.counts['offlineCache']++;
    if (line.includes('HomeCache:')) this.counts['homeCache']++;
    if (line.includes('Web: main frame error')) this.counts['webMainFrameErrors']++;
    if (line.includes('ActionGate:')) this.counts['actionGate']++;
    if (line.includes('PhotoDownload:')) this.counts['photoDownload']++;
    if (line.includes('SharePanel:')) this.counts['sharePanel']++;
  }

  result(): string {
    return Object.keys(this.counts).map((key: string): string => key + '=' + this.counts[key].toString()).join(' ');
  }
}
