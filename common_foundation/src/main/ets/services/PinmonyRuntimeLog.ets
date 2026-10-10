import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

// Bounded diagnostics only. Never export WebView storage, headers or response bodies.
export class PinmonyRuntimeLog {
  private static readonly MAX_MEMORY_LINES: number = 1000;
  private static readonly MAX_SESSION_BYTES: number = 8 * 1024 * 1024;
  private static path: string = '';
  private static lines: string[] = [];
  private static sessionPath: string = '';
  private static previousPath: string = '';
  private static sessionSize: number = 0;
  private static sessionPersisted: boolean = false;
  private static sessionStartedAt: number = 0;

  static savedStatus(): string {
    return PinmonyRuntimeLog.sessionPersisted ? '日志已自动保存在应用内，可导出到文件管理器' :
      '日志自动保存尚未成功，可尝试导出内存中的记录';
  }

  static sanitize(message: string): string {
    return message.replace(/https?:\/\/[^\s"']+/gi, '[url]')
      .replace(/(?:cookie|authorization|csrf|token|password|account_id|user_id)\s*[=:]\s*[^\s,;]+/gi, '[credential]')
      .replace(/\b\d{12,}\b/g, '[id]').replace(/[\r\n]+/g, ' ').slice(0, 800);
  }

  static initialize(filesDir: string): void {
    PinmonyRuntimeLog.sessionStartedAt = Date.now();
    PinmonyRuntimeLog.path = filesDir + '/pinweb-runtime.log';
    PinmonyRuntimeLog.sessionPath = filesDir + '/pinweb-session-current.log';
    PinmonyRuntimeLog.previousPath = filesDir + '/pinweb-session-previous.log';
    try { fs.copyFileSync(PinmonyRuntimeLog.sessionPath, PinmonyRuntimeLog.previousPath); } catch (_) {}
    PinmonyRuntimeLog.sessionSize = 0;
    PinmonyRuntimeLog.sessionPersisted = false;
    PinmonyRuntimeLog.writeSession('Pinmony session diagnostics; credentials and response bodies excluded\n', true);
    try {
      PinmonyRuntimeLog.lines = fs.readTextSync(PinmonyRuntimeLog.path).split('\n').filter((line: string) => line.length > 0)
        .slice(-PinmonyRuntimeLog.MAX_MEMORY_LINES).map((line: string) => PinmonyRuntimeLog.sanitize(line));
    } catch (_) { PinmonyRuntimeLog.lines = []; }
    PinmonyRuntimeLog.info('Runtime: application started');
  }

  static info(message: string): void { PinmonyRuntimeLog.record('INFO', message); }
  static warn(message: string): void { PinmonyRuntimeLog.record('WARN', message); }
  static error(message: string): void { PinmonyRuntimeLog.record('ERROR', message); }

  static sessionElapsedMs(): number {
    return PinmonyRuntimeLog.sessionStartedAt > 0 ? Date.now() - PinmonyRuntimeLog.sessionStartedAt : 0;
  }

  private static record(level: string, message: string): void {
    const safe: string = PinmonyRuntimeLog.sanitize(message);
    console.info('PinmonyLog: ' + level + ' ' + safe);
    const line: string = new Date().toISOString() + ' ' + level + ' ' + safe;
    PinmonyRuntimeLog.writeSession(line + '\n');
    PinmonyRuntimeLog.lines.push(line);
    PinmonyRuntimeLog.lines = PinmonyRuntimeLog.lines.slice(-PinmonyRuntimeLog.MAX_MEMORY_LINES);
    if (!PinmonyRuntimeLog.path) return;
    // Persist immediately so a restart does not lose the last back/dismiss event.
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(PinmonyRuntimeLog.path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, PinmonyRuntimeLog.lines.join('\n') + '\n');
    } catch (_) { console.warn('PinmonyLog: persistence failed'); }
    finally { if (file) { try { fs.closeSync(file); } catch (_) {} } }
  }

  private static writeSession(text: string, truncate: boolean = false): void {
    if (!PinmonyRuntimeLog.sessionPath) return;
    let file: fs.File | undefined = undefined;
    try {
      if (!truncate && PinmonyRuntimeLog.sessionSize + text.length * 4 > PinmonyRuntimeLog.MAX_SESSION_BYTES) {
        fs.copyFileSync(PinmonyRuntimeLog.sessionPath, PinmonyRuntimeLog.previousPath);
        truncate = true;
      }
      if (truncate) PinmonyRuntimeLog.sessionSize = 0;
      file = fs.openSync(PinmonyRuntimeLog.sessionPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE |
        (truncate ? fs.OpenMode.TRUNC : fs.OpenMode.APPEND));
      fs.writeSync(file.fd, text);
      PinmonyRuntimeLog.sessionPersisted = true;
      PinmonyRuntimeLog.sessionSize += text.length * 4;
    } catch (_) {
      PinmonyRuntimeLog.sessionPersisted = false;
      console.warn('PinmonyLog: session persistence failed');
    }
    finally { if (file) { try { fs.closeSync(file); } catch (_) {} } }
  }

  static async export(context: common.UIAbilityContext): Promise<boolean> {
    PinmonyRuntimeLog.info('Runtime: log export requested');
    const destinations: string[] = await new picker.DocumentViewPicker(context).save({
      newFileNames: ['Pinmony-runtime-' + new Date().toISOString().replace(/[:.]/g, '-') + '.txt']
    });
    if (!destinations.length) return false;
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(destinations[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      let session: string = PinmonyRuntimeLog.lines.join('\n');
      try { session = fs.readTextSync(PinmonyRuntimeLog.sessionPath); } catch (_) {}
      let previous: string = '';
      try { previous = fs.readTextSync(PinmonyRuntimeLog.previousPath); } catch (_) {}
      const summary: string = PinmonyRuntimeLog.summary(previous + '\n' + session);
      fs.writeSync(file.fd, 'Pinmony application diagnostics (not full system HiLog)\n' +
        '--- Diagnostic summary ---\n' + summary + '\n' +
        '--- Previous session / segment ---\n' + previous + '\n--- Current session ---\n' + session + '\n');
    } finally { if (file) fs.closeSync(file); }
    PinmonyRuntimeLog.info('Runtime: log export completed');
    return true;
  }

  private static summary(text: string): string {
    const lines: string[] = text.split('\n').filter((line: string) => line.length > 0);
    let info: number = 0;
    let warn: number = 0;
    let error: number = 0;
    let offlineCache: number = 0;
    let homeCache: number = 0;
    let webFailure: number = 0;
    let actionGate: number = 0;
    let photoDownload: number = 0;
    let sharePanel: number = 0;
    lines.forEach((line: string): void => {
      if (line.includes(' INFO ')) info++;
      if (line.includes(' WARN ')) warn++;
      if (line.includes(' ERROR ')) error++;
      if (line.includes('OfflineCache:')) offlineCache++;
      if (line.includes('HomeCache:')) homeCache++;
      if (line.includes('Web: main frame error')) webFailure++;
      if (line.includes('ActionGate:')) actionGate++;
      if (line.includes('PhotoDownload:')) photoDownload++;
      if (line.includes('SharePanel:')) sharePanel++;
    });
    return 'total=' + lines.length.toString() +
      ' info=' + info.toString() + ' warn=' + warn.toString() + ' error=' + error.toString() +
      ' offlineCache=' + offlineCache.toString() + ' homeCache=' + homeCache.toString() +
      ' webMainFrameErrors=' + webFailure.toString() + ' actionGate=' + actionGate.toString() +
      ' photoDownload=' + photoDownload.toString() + ' sharePanel=' + sharePanel.toString();
  }
}

