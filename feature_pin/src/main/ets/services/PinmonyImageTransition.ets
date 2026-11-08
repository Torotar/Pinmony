import { UIContext } from '@kit.ArkUI';

export interface ImageFlightRect { x: number; y: number; width: number; height: number; }
// Both Pin and comment photos use the same visual (post-transform) coordinate space.
export function measureImageFlightOrigin(ui: UIContext, sourceId: string, rootId: string): ImageFlightRect {
  try {
    const source = ui.getComponentUtils().getRectangleById(sourceId);
    const sourceNode = ui.getFrameNodeById(sourceId);
    const rootNode = ui.getFrameNodeById(rootId);
    if (!sourceNode || !rootNode) return { x: 0, y: 0, width: 0, height: 0 };
    const sourcePosition = sourceNode.getPositionToWindowWithTransform();
    const rootPosition = rootNode.getPositionToWindowWithTransform();
    return { x: sourcePosition.x - rootPosition.x, y: sourcePosition.y - rootPosition.y,
      width: ui.px2vp(source.size.width), height: ui.px2vp(source.size.height) };
  } catch (_) { return { x: 0, y: 0, width: 0, height: 0 }; }
}
export interface PinmonyDetailEntryPhoto { pinUrl: string; imageUrl: string; x: number; y: number; width: number; height: number; imageWidth?: number; imageHeight?: number; returnPageOnly?: boolean; }
export function imageContainRect(width: number, height: number, imageWidth: number, imageHeight: number): ImageFlightRect {
  const ratio: number = imageWidth > 0 && imageHeight > 0 ? imageWidth / imageHeight : width / Math.max(1, height);
  const w: number = Math.min(width, height * ratio);
  const h: number = w / ratio;
  return { x: (width - w) / 2, y: (height - h) / 2, width: w, height: h };
}
