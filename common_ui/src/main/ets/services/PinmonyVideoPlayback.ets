import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audio } from '@kit.AudioKit';
import { PinmonyVideo, PinmonyVideoFileLease, PinmonyVideoFileReader } from '../models/PinmonyVideo';

let nextPlaybackTraceId: number = 0;

export interface PinmonyPlaybackState {
  phase: string;
  position: number;
  duration: number;
  rendered: boolean;
  buffering: boolean;
  muted: boolean;
  error: string;
  failureSummary?: string;
  loadingStage?: string;
}

export class PinmonyVideoPlayback {
  private readonly traceId: number = ++nextPlaybackTraceId;
  private player: media.AVPlayer | undefined = undefined;
  private video: PinmonyVideo | undefined = undefined;
  private surface: string = '';
  private generation: number = 0;
  private failedGeneration: number = -1;
  private sourceIndex: number = 0;
  private active: boolean = true;
  private wanted: boolean = false;
  private timer: number = -1;
  private errorTimer: number = -1;
  private pendingErrorCode: number = 0;
  private pendingErrorStage: string = 'player';
  private waitStage: string = 'create';
  private candidateStarted: number = 0;
  private candidateFailures: string[] = [];
  private fileAttempted: boolean = false;
  private usingFile: boolean = false;
  private localFile: PinmonyVideoFileLease | undefined;
  private changed: (state: PinmonyPlaybackState) => void;
  private trace: ((event: string) => void) | undefined;
  private readonly fileReader: PinmonyVideoFileReader | undefined;
  private releaseTask: Promise<void> = Promise.resolve();
  private state: PinmonyPlaybackState = { phase: 'idle', position: 0, duration: 0, rendered: false,
    buffering: false, muted: false, error: '' };
  constructor(changed: (state: PinmonyPlaybackState) => void, trace?: (event: string) => void,
    fileReader?: PinmonyVideoFileReader) {
    this.changed = changed; this.trace = trace; this.fileReader = fileReader;
  }

  private record(event: string): void {
    if (this.trace) this.trace('playerId=' + this.traceId.toString() + ' generation=' + this.generation.toString() + ' ' + event);
  }

  private notify(): void {
    this.changed({ phase: this.state.phase, position: this.state.position, duration: this.state.duration,
      rendered: this.state.rendered, buffering: this.state.buffering, muted: this.state.muted, error: this.state.error,
      failureSummary: this.state.failureSummary, loadingStage: this.state.loadingStage });
  }

  private clearTimer(): void { if (this.timer >= 0) clearTimeout(this.timer); this.timer = -1; }
  private clearErrorTimer(): void {
    if (this.errorTimer >= 0) clearTimeout(this.errorTimer);
    this.errorTimer = -1; this.pendingErrorCode = 0; this.pendingErrorStage = 'player';
  }

  private waiting(stage: string): void {
    this.waitStage = stage;
    this.state.loadingStage = stage;
    this.record('event=waiting stage=' + stage + ' candidate=' + this.sourceIndex.toString());
    this.notify();
  }

  private armTimer(token: number, stage: string): void {
    this.clearTimer(); this.waiting(stage);
    this.timer = setTimeout(() => this.fail(token, this.waitStage, 0, true), 15000);
  }

  private playerError(token: number, stage: string, code: number = 0): void {
    if (token !== this.generation || this.failedGeneration === token) {
      // A late code remains diagnostic evidence for its original generation, never a new UI result.
      if (Number.isFinite(code) && code !== 0)
        this.record('event=late-error callbackGeneration=' + token.toString() + ' stage=' + stage + ' code=' + code.toString());
      return;
    }
    const errorCode: number = Number.isFinite(code) ? code : 0;
    // A rejected operation can report 5400102 after the player has already failed.
    // Keep its code as a bounded fallback; the player's underlying media error wins.
    if (errorCode !== 0 && (errorCode !== 5400102 || stage === 'player')) {
      this.fail(token, stage, errorCode); return;
    }
    if (errorCode !== 0) {
      this.pendingErrorCode = errorCode; this.pendingErrorStage = stage;
      this.record('event=error-code-deferred stage=' + stage + ' code=' + errorCode.toString());
    } else if (this.errorTimer < 0) this.pendingErrorStage = stage;
    if (this.errorTimer >= 0) return;
    this.clearTimer();
    this.record('event=error-code-wait stage=' + stage + ' candidate=' + this.sourceIndex.toString());
    this.state.phase = 'loading'; this.notify();
    this.errorTimer = setTimeout(() => this.fail(token, this.pendingErrorStage, this.pendingErrorCode), 200);
  }

  setVideo(video: PinmonyVideo): void {
    this.release(); this.video = video; this.sourceIndex = 0;
    this.state = { phase: 'idle', position: 0, duration: video.duration, rendered: false,
      buffering: false, muted: false, error: '' }; this.notify();
  }

  private openInitial(): void {
    this.candidateFailures = []; this.state.failureSummary = ''; this.fileAttempted = false;
    const mp4: number = this.video ? this.video.sources.findIndex((source) => source.kind === 'mp4') : -1;
    if (this.fileReader && mp4 >= 0) {
      this.fileAttempted = true;
      this.record('event=source-selected kind=mp4-file reason=detail-native-transport');
      this.open(mp4, true);
    } else this.open(0);
  }

  setSurface(surface: string): void {
    this.surface = surface;
    if (this.wanted && this.active && !this.player && this.state.phase === 'idle') this.openInitial();
  }

  setActive(active: boolean): void {
    this.active = active;
    if (!active) {
      if (this.state.phase === 'loading') { this.stop(); return; }
      this.wanted = false; this.clearTimer(); this.clearErrorTimer();
      if (this.player?.state === 'playing') this.player.pause().catch(() => {});
    }
  }

  stop(): void {
    this.release();
    this.state.phase = 'idle'; this.state.rendered = false; this.state.buffering = false;
    this.state.position = 0; this.state.error = ''; this.notify();
  }

  start(): void {
    if (this.player?.state === 'playing' || this.wanted || this.state.phase === 'error') return;
    this.toggle();
  }

  retry(): void {
    if (!this.active || !this.video || !this.surface || this.state.phase === 'loading') return;
    this.record('event=retry reason=user');
    this.wanted = true; this.openInitial();
  }

  toggle(): void {
    if (!this.active || this.state.phase === 'loading') return;
    const player: media.AVPlayer | undefined = this.player;
    if (player?.state === 'playing') {
      this.wanted = false; player.pause().catch(() => {}); return;
    }
    this.wanted = true;
    if (!player || this.state.phase === 'error') { if (this.surface) this.openInitial(); return; }
    if (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed') {
      if (player.state === 'completed') player.seek(0, media.SeekMode.SEEK_CLOSEST);
      const token: number = this.generation;
      if (!this.state.rendered) this.armTimer(token, 'first-frame');
      player.play().catch((error: BusinessError) => this.playerError(token, 'play', error.code));
    }
  }

  seek(position: number): void {
    const player: media.AVPlayer | undefined = this.player;
    if (player && ['prepared', 'playing', 'paused', 'completed'].includes(player.state) && this.state.duration > 0) {
      try { player.seek(Math.max(0, Math.min(position, this.state.duration)), media.SeekMode.SEEK_CLOSEST); } catch (_) {}
    }
  }

  mute(): void {
    this.state.muted = !this.state.muted;
    if (this.player && ['prepared', 'playing', 'paused', 'completed'].includes(this.player.state)) {
      try { this.player.setVolume(this.state.muted ? 0 : 1); } catch (_) {}
    }
    this.notify();
  }

  private fail(token: number, stage: string = 'player', code: number = 0, timedOut: boolean = false): void {
    if (token !== this.generation || this.failedGeneration === token) return;
    const errorCode: number = Number.isFinite(code) ? code : 0;
    const kind: string = this.video?.sources[this.sourceIndex]?.kind === 'hls' ? 'HLS' : 'MP4';
    this.record('event=failed stage=' + stage + ' candidate=' + this.sourceIndex.toString() + ' code=' + errorCode.toString() +
      ' reason=' + (timedOut ? 'timeout' : 'error') + ' elapsedMs=' + Math.max(0, Date.now() - this.candidateStarted).toString());
    const reason: string = stage === 'download' ? '文件读取失败' :
      timedOut ? (stage === 'prepare' ? '准备超时' : stage === 'first-frame' ? '画面加载超时' : '初始化超时') :
      errorCode === 5400103 ? '媒体读取失败' : errorCode === 5400106 ? '格式不支持' :
      errorCode >= 5411008 && errorCode <= 5411010 ? '安全连接失败' : '播放失败';
    this.candidateFailures.push(kind + '：' + reason + (errorCode ? '（' + errorCode.toString() + '）' : ''));
    this.state.failureSummary = this.candidateFailures.slice(-4).join('；');
    this.failedGeneration = token; this.clearTimer(); this.clearErrorTimer();
    const mp4: number = this.video ? this.video.sources.findIndex((source) => source.kind === 'mp4') : -1;
    const remoteReadFailure: boolean = errorCode === 5400103 || errorCode === 5400104 ||
      errorCode >= 5411001 && errorCode <= 5411010 || timedOut && (stage === 'prepare' || stage === 'initialize');
    if (!this.usingFile && !this.fileAttempted && this.fileReader && mp4 >= 0 && remoteReadFailure && this.active) {
      this.fileAttempted = true;
      this.record('event=file-fallback reason=remote-read code=' + errorCode.toString());
      this.open(mp4, true); return;
    }
    if (!this.usingFile && this.video && this.sourceIndex + 1 < this.video.sources.length && this.active) {
      this.open(this.sourceIndex + 1); return;
    }
    this.state.phase = 'error'; this.state.buffering = false; this.state.rendered = false;
    this.state.error = stage === 'download' ? (errorCode === 1007900035 ?
      '视频安全连接失败，请检查网络或代理后重试' : '视频文件读取失败，请检查网络或代理后重试') :
      errorCode === 5400106 ? '当前视频格式不受支持，请重新读取视频地址' :
      errorCode >= 5411008 && errorCode <= 5411010 ? '视频安全连接失败，请检查网络或代理后重试' :
      errorCode >= 5411001 && errorCode <= 5411007 ? '视频网络请求失败，请检查连接后重试' :
      errorCode === 5400103 ? '视频媒体读取失败，请检查网络或代理后重试' :
      timedOut || errorCode === 5400104 ? (stage === 'prepare' ? '视频准备超时，请重试播放' :
        stage === 'first-frame' ? '视频画面加载超时，请重试播放' : '播放器初始化超时，请重试播放') :
        '视频播放失败，请重试或重新读取地址';
    this.wanted = false;
    this.record('event=candidates-exhausted count=' + this.candidateFailures.length.toString());
    this.generation++;
    this.disposePlayer();
    this.notify();
  }

  private disposePlayer(): void {
    const player: media.AVPlayer | undefined = this.player; this.player = undefined;
    const lease: PinmonyVideoFileLease | undefined = this.localFile; this.localFile = undefined;
    this.releaseTask = this.releaseTask.then(async () => {
      if (player) await player.release().catch(() => {});
      if (lease) lease.release();
    });
  }

  private async open(index: number, useFile: boolean = false): Promise<void> {
    const video: PinmonyVideo | undefined = this.video;
    if (!video || !video.sources[index] || !this.surface) return;
    const token: number = ++this.generation;
    if (this.fileReader) this.fileReader.cancel();
    this.disposePlayer(); this.usingFile = useFile;
    this.clearTimer(); this.clearErrorTimer(); this.sourceIndex = index;
    this.candidateStarted = Date.now();
    if (index === 0 && !useFile) { this.candidateFailures = []; this.state.failureSummary = ''; this.fileAttempted = false; }
    this.record('event=opening candidate=' + index.toString() + ' kind=' + (useFile ? 'mp4-file' : video.sources[index].kind));
    this.state.phase = 'loading'; this.state.rendered = false; this.state.buffering = false; this.state.error = '';
    this.state.position = 0; this.notify();
    try {
      await this.releaseTask;
      if (token !== this.generation) return;
      if (useFile && this.fileReader) {
        this.waiting('download');
        const lease: PinmonyVideoFileLease = await this.fileReader.load(video.sources[index].url);
        if (token !== this.generation || !this.active) { lease.release(); return; }
        this.localFile = lease;
        this.record('event=file-source-ready bytes=' + lease.size.toString());
      }
      this.armTimer(token, 'create');
      const player: media.AVPlayer = await media.createAVPlayer();
      if (token !== this.generation) { await player.release(); return; }
      this.player = player;
      this.waiting('initialize');
      player.on('audioInterrupt', (event: audio.InterruptEvent) => {
        if (token !== this.generation) return;
        if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE || event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
          if (this.state.phase === 'loading') { this.stop(); return; }
          this.wanted = false; this.clearTimer();
          if (player.state === 'playing') player.pause().catch(() => {});
        }
      });
      player.on('error', (error: BusinessError) => this.playerError(token, 'player', error.code));
      player.on('timeUpdate', (position: number) => {
        if (token !== this.generation) return; this.state.position = position; this.notify();
      });
      player.on('durationUpdate', (duration: number) => {
        if (token !== this.generation) return; this.state.duration = duration; this.notify();
      });
      player.on('startRenderFrame', () => {
        if (token !== this.generation || this.errorTimer >= 0) return;
        this.record('event=first-frame candidate=' + index.toString());
        this.clearTimer(); this.state.rendered = true; this.state.buffering = false; this.notify();
      });
      player.on('bufferingUpdate', (type: media.BufferingInfoType, _value: number) => {
        if (token !== this.generation) return;
        if (type === media.BufferingInfoType.BUFFERING_START) this.state.buffering = true;
        if (type === media.BufferingInfoType.BUFFERING_END) this.state.buffering = false;
        this.notify();
      });
      player.on('stateChange', (phase: string) => {
        if (token !== this.generation || this.errorTimer >= 0 && phase !== 'error') return;
        if (['idle', 'initialized', 'prepared', 'playing', 'paused', 'completed', 'error', 'released'].includes(phase))
          this.record('event=state phase=' + phase + ' candidate=' + index.toString());
        if (phase === 'initialized') {
          try {
            player.surfaceId = this.surface;
            this.waiting('prepare');
            player.prepare().catch((error: BusinessError) => this.playerError(token, 'prepare', error.code));
          } catch (error) { this.playerError(token, 'surface', (error as BusinessError).code); }
        } else if (phase === 'prepared') {
          this.state.duration = player.duration > 0 ? player.duration : video.duration;
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          try { player.setVolume(this.state.muted ? 0 : 1); } catch (_) {}
          this.state.phase = 'prepared';
          if (this.wanted && this.active) {
            // Preserve the candidate's overall deadline while accurately naming the blocked stage.
            if (this.timer < 0) this.armTimer(token, 'first-frame'); else this.waiting('first-frame');
            player.play().catch((error: BusinessError) => this.playerError(token, 'play', error.code));
          }
          else this.clearTimer();
          this.notify();
        } else if (phase === 'playing' || phase === 'paused' || phase === 'completed') {
          this.state.phase = phase;
          if (phase !== 'playing') { this.wanted = false; this.clearTimer(); }
          if (phase === 'playing' && !this.active) { this.wanted = false; player.pause().catch(() => {}); }
          this.notify();
        } else if (phase === 'error') this.playerError(token, 'player');
      });
      if (useFile && this.localFile) player.fdSrc = { fd: this.localFile.fd, offset: 0, length: this.localFile.size };
      else player.url = video.sources[index].url;
    } catch (error) {
      if (useFile && this.waitStage === 'download') this.fail(token, 'download', (error as BusinessError).code);
      else this.playerError(token, 'open', (error as BusinessError).code);
    }
  }

  release(): void {
    this.generation++; this.clearTimer(); this.clearErrorTimer(); this.wanted = false;
    if (this.fileReader) this.fileReader.cancel();
    this.disposePlayer();
  }
}
