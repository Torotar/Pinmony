import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { audio } from '@kit.AudioKit';
import { PinWebVideo } from '../models/PinWebVideo';

export interface PinWebPlaybackState {
  phase: string;
  position: number;
  duration: number;
  rendered: boolean;
  buffering: boolean;
  muted: boolean;
  error: string;
}

export class PinWebVideoPlayback {
  private player: media.AVPlayer | undefined = undefined;
  private video: PinWebVideo | undefined = undefined;
  private surface: string = '';
  private generation: number = 0;
  private failedGeneration: number = -1;
  private sourceIndex: number = 0;
  private active: boolean = true;
  private wanted: boolean = false;
  private timer: number = -1;
  private changed: (state: PinWebPlaybackState) => void;
  private releaseTask: Promise<void> = Promise.resolve();
  private state: PinWebPlaybackState = { phase: 'idle', position: 0, duration: 0, rendered: false,
    buffering: false, muted: false, error: '' };
  constructor(changed: (state: PinWebPlaybackState) => void) { this.changed = changed; }

  private notify(): void {
    this.changed({ phase: this.state.phase, position: this.state.position, duration: this.state.duration,
      rendered: this.state.rendered, buffering: this.state.buffering, muted: this.state.muted, error: this.state.error });
  }

  private clearTimer(): void { if (this.timer >= 0) clearTimeout(this.timer); this.timer = -1; }

  setVideo(video: PinWebVideo): void {
    this.release(); this.video = video; this.sourceIndex = 0;
    this.state = { phase: 'idle', position: 0, duration: video.duration, rendered: false,
      buffering: false, muted: false, error: '' }; this.notify();
  }

  setSurface(surface: string): void {
    this.surface = surface;
    if (this.wanted && this.active && !this.player && this.state.phase === 'idle') this.open(0);
  }

  setActive(active: boolean): void {
    this.active = active;
    if (!active) {
      this.wanted = false; this.clearTimer();
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

  toggle(): void {
    if (!this.active || this.state.phase === 'loading') return;
    const player: media.AVPlayer | undefined = this.player;
    if (player?.state === 'playing') {
      this.wanted = false; player.pause().catch(() => {}); return;
    }
    this.wanted = true;
    if (!player || this.state.phase === 'error') { if (this.surface) this.open(0); return; }
    if (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed') {
      if (player.state === 'completed') player.seek(0, media.SeekMode.SEEK_CLOSEST);
      const token: number = this.generation;
      player.play().catch(() => this.fail(token));
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

  private fail(token: number): void {
    if (token !== this.generation || this.failedGeneration === token) return;
    this.failedGeneration = token; this.clearTimer();
    if (this.video && this.sourceIndex + 1 < this.video.sources.length && this.active) {
      this.open(this.sourceIndex + 1); return;
    }
    this.state.phase = 'error'; this.state.buffering = false; this.state.rendered = false;
    this.state.error = '视频播放失败，可能是网络或格式不兼容'; this.wanted = false;
    this.generation++;
    const player: media.AVPlayer | undefined = this.player; this.player = undefined;
    if (player) this.releaseTask = player.release().catch(() => {});
    this.notify();
  }

  private async open(index: number): Promise<void> {
    const video: PinWebVideo | undefined = this.video;
    if (!video || !video.sources[index] || !this.surface) return;
    const token: number = ++this.generation;
    const old: media.AVPlayer | undefined = this.player; this.player = undefined;
    this.clearTimer(); this.sourceIndex = index;
    this.state.phase = 'loading'; this.state.rendered = false; this.state.buffering = false; this.state.error = '';
    this.state.position = 0; this.notify();
    try {
      if (old) await old.release().catch(() => {});
      await this.releaseTask;
      if (token !== this.generation) return;
      if (token !== this.generation) return;
      const player: media.AVPlayer = await media.createAVPlayer();
      if (token !== this.generation) { await player.release(); return; }
      this.player = player;
      this.timer = setTimeout(() => this.fail(token), 15000);
      player.on('audioInterrupt', (event: audio.InterruptEvent) => {
        if (token !== this.generation) return;
        if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE || event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
          this.wanted = false; this.clearTimer();
          if (player.state === 'playing') player.pause().catch(() => {});
        }
      });
      player.on('error', (_error: BusinessError) => this.fail(token));
      player.on('timeUpdate', (position: number) => {
        if (token !== this.generation) return; this.state.position = position; this.notify();
      });
      player.on('durationUpdate', (duration: number) => {
        if (token !== this.generation) return; this.state.duration = duration; this.notify();
      });
      player.on('startRenderFrame', () => {
        if (token !== this.generation) return;
        this.clearTimer(); this.state.rendered = true; this.state.buffering = false; this.notify();
      });
      player.on('bufferingUpdate', (type: media.BufferingInfoType, _value: number) => {
        if (token !== this.generation) return;
        if (type === media.BufferingInfoType.BUFFERING_START) this.state.buffering = true;
        if (type === media.BufferingInfoType.BUFFERING_END) this.state.buffering = false;
        this.notify();
      });
      player.on('stateChange', (phase: string) => {
        if (token !== this.generation) return;
        if (phase === 'initialized') {
          try {
            player.surfaceId = this.surface;
            player.prepare().catch(() => this.fail(token));
          } catch (_) { this.fail(token); }
        } else if (phase === 'prepared') {
          this.state.duration = player.duration > 0 ? player.duration : video.duration;
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          try { player.setVolume(this.state.muted ? 0 : 1); } catch (_) {}
          this.state.phase = 'prepared';
          if (this.wanted && this.active) player.play().catch(() => this.fail(token));
          else this.clearTimer();
          this.notify();
        } else if (phase === 'playing' || phase === 'paused' || phase === 'completed') {
          this.state.phase = phase;
          if (phase !== 'playing') { this.wanted = false; this.clearTimer(); }
          if (phase === 'playing' && !this.active) { this.wanted = false; player.pause().catch(() => {}); }
          this.notify();
        } else if (phase === 'error') this.fail(token);
      });
      player.url = video.sources[index].url;
    } catch (_) { this.fail(token); }
  }

  release(): void {
    this.generation++; this.clearTimer(); this.wanted = false;
    const old: media.AVPlayer | undefined = this.player; this.player = undefined;
    if (old) this.releaseTask = old.release().catch(() => {});
  }
}
