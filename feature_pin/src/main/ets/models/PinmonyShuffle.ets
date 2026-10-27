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
  imageWidth: number;
  imageHeight: number;
  offsetX: number;
  offsetY: number;
  scale: number;
  rotation: number;
  tappable: boolean;
  hidden: boolean;
  alpha: number;
  effects: PinmonyShuffleEffect[];
}

export interface PinmonyShuffleSnapshot {
  canvasWidth: number;
  canvasHeight: number;
  id: string;
  backgroundColor: string;
  items: PinmonyShuffleItem[];
  motionEffect: Object | undefined;
}
