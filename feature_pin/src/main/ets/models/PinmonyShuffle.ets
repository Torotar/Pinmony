export interface PinmonyShuffleEffect {
  kind: string;
  value: Object;
}

export interface PinmonyShuffleItem {
  id: string;
  itemType: number;
  pinId?: string;
  pinUrl?: string;
  imageUrl?: string;
  cutoutUrl?: string;
  cutoutBounds?: PinmonyShuffleCutoutBounds;
  imageWidth: number;
  imageHeight: number;
  hitWidth?: number;
  hitHeight?: number;
  hitMask?: string;
  offsetX: number;
  offsetY: number;
  scale: number;
  rotation: number;
  tappable: boolean;
  hidden: boolean;
  alpha: number;
  effects: PinmonyShuffleEffect[];
}

export interface PinmonyShuffleCutoutBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface PinmonyShuffleSnapshot {
  coordinateWidth?: number;
  canvasWidth: number;
  canvasHeight: number;
  id: string;
  backgroundColor: string;
  items: PinmonyShuffleItem[];
  motionEffect: Object | undefined;
}
