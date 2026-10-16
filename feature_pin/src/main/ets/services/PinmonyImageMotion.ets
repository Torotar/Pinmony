export interface ImagePanBounds { x: number; y: number; }
export interface ImageFling { x: number; y: number; decay: number; seconds: number; }

export function imagePanBounds(width: number, height: number, imageWidth: number, imageHeight: number, scale: number): ImagePanBounds {
  if (width <= 0 || height <= 0 || scale <= 1) return { x: 0, y: 0 };
  const fit: number = imageWidth > 0 && imageHeight > 0 ? Math.min(width / imageWidth, height / imageHeight) : 1;
  return { x: Math.max(0, ((imageWidth > 0 ? imageWidth * fit : width) * scale - width) / 2),
    y: Math.max(0, ((imageHeight > 0 ? imageHeight * fit : height) * scale - height) / 2) };
}

export function imageFling(x: number, y: number): ImageFling {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return { x: 0, y: 0, decay: 1, seconds: 0 };
  const speed: number = Math.sqrt(x * x + y * y);
  if (speed < 200) return { x: 0, y: 0, decay: 1, seconds: 0 };
  // A drag coefficient is the fraction of velocity retained after one second.
  // Convert it to exponential decay; faster releases retain more momentum.
  const drag: number = speed > 5000 ? 0.03 : speed > 3000 ? 0.02 : 0.01;
  const decay: number = -Math.log(drag);
  return { x: x, y: y, decay: decay,
    seconds: Math.min(3, Math.log(speed / 10) / decay) };
}

// Integral of velocity v(t)=v0*exp(-decay*t), in viewport units.
export function imageFlingDistance(velocity: number, decay: number, seconds: number): number {
  return velocity / decay * (1 - Math.exp(-decay * Math.max(0, seconds)));
}
