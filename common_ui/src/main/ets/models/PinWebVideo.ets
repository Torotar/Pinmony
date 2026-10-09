export interface PinWebVideoSource { url: string; kind: string; }
export interface PinWebVideo { pinId: string; sources: PinWebVideoSource[]; width: number; height: number; duration: number; }
