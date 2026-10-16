import { PinmonyBoardDetail, PinmonyBoardPin, PinmonyBoardSection } from '../models/PinmonyBoardDetail';

export function boardSectionPreviewImages(section: PinmonyBoardSection): string[] {
  const images: string[] = [];
  const previews: string[] = (section.pins || []).map((pin: PinmonyBoardPin): string => pin.imageUrl);
  const source: string[] = (section.images || []).length >= previews.length ? section.images || [] : previews;
  source.forEach((url: string): void => {
    if (/^https:\/\/i\.pinimg\.com\//i.test(url) && !images.includes(url) && images.length < 2) images.push(url);
  });
  return images;
}

export function boardVisiblePins(board: PinmonyBoardDetail): PinmonyBoardPin[] {
  if (board.flow?.phase === 'ideas' || board.flow?.phase === 'section') return board.flow.pins;
  const result: PinmonyBoardPin[] = board.pins.slice();
  (board.sections || []).forEach((section): void => {
    (section.pins || []).forEach((pin: PinmonyBoardPin): void => {
      if (!result.some((item: PinmonyBoardPin): boolean => item.id === pin.id)) result.push(pin);
    });
  });
  return result;
}
