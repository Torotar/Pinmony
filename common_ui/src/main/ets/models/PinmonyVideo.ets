export interface PinmonyVideoSource { url: string; kind: string; }
export interface PinmonyVideo { pinId: string; sources: PinmonyVideoSource[]; width: number; height: number; duration: number; readRevision?: number; }

export interface PinmonyVideoFileLease { fd: number; size: number; release: () => void; }
export interface PinmonyVideoFileReader {
  load: (source: string) => Promise<PinmonyVideoFileLease>;
  cancel: () => void;
}
