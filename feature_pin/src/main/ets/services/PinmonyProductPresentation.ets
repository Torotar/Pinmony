import { PinmonyCarouselItem } from '../models/PinmonyDetail';
interface DescriptionComponent { type?: string; stringContent?: string; pointsContent?: string[]; }
interface ProductImage { url?: string; width?: number; height?: number; }
interface ProductImageEntry { canonicalImage?: ProductImage; }
interface ProductMetadata { image_736x?: ProductImageEntry[]; }
interface ProductRichMetadata { products?: ProductMetadata[]; }
interface FormattedDescription { components?: DescriptionComponent[]; }
interface ProductLinkDomain { name?: string; }
interface ProductPin {
  entityId?: string; id?: string; formattedCloseupDescription?: FormattedDescription;
  link?: string; mobileLink?: string; trackedLink?: string; utmLink?: string; affiliateLink?: string;
  linkDomain?: ProductLinkDomain;
  richMetadata?: ProductRichMetadata;
}
interface ProductResponse { errors?: Object[]; data?: ProductData; }
interface ProductData { v3GetPinQueryv2?: ProductResult; }
interface ProductResult { data?: ProductPin; }
export interface ProductPresentation { description: string; source: string; sourceLabel: string; images: PinmonyCarouselItem[]; }

// Text only: never evaluate returned markup or turn description links into controls.
export function readProductPresentation(body: string, pinId: string): ProductPresentation | undefined {
  if (body.length > 1024 * 1024) return undefined;
  try {
    const response: ProductResponse = JSON.parse(body) as ProductResponse;
    const pin: ProductPin | undefined = response.data?.v3GetPinQueryv2?.data;
    if (response.errors?.length || !pin || String(pin.entityId || pin.id) !== pinId) return undefined;
    const parts: string[] = [];
    const components: DescriptionComponent[] | undefined = pin.formattedCloseupDescription?.components;
    if (Array.isArray(components)) components.slice(0, 100).forEach((item: DescriptionComponent): void => {
      if (item?.type === 'formatted_description_paragraph_component' && typeof item.stringContent === 'string')
        parts.push(item.stringContent.trim());
      if (item?.type === 'formatted_description_points_component' && Array.isArray(item.pointsContent))
        parts.push(item.pointsContent.slice(0, 100).filter((point: string): boolean => typeof point === 'string')
          .map((point: string): string => '• ' + point.trim()).join('\n'));
    });
    const source: string = [pin.link, pin.mobileLink, pin.trackedLink, pin.utmLink, pin.affiliateLink]
      .find((url: string | undefined): boolean => typeof url === 'string' && url.length <= 2000 &&
        /^https:\/\/[^\s\\/@:]+(?:[/?#]|$)/i.test(url) &&
        !/^https:\/\/(?:[^/]+\.)?(?:pinterest\.com|pinimg\.com|pin\.it)(?:[/?#]|$)/i.test(url)) || '';
    const images: PinmonyCarouselItem[] = [];
    const products: ProductMetadata[] | undefined = pin.richMetadata?.products;
    if (Array.isArray(products)) products.slice(0, 10).forEach((product: ProductMetadata): void => {
      if (!Array.isArray(product?.image_736x)) return;
      product.image_736x.slice(0, 20).forEach((entry: ProductImageEntry): void => {
        const image: ProductImage | undefined = entry?.canonicalImage;
        if (!image || typeof image.url !== 'string' || image.url.length > 2000 ||
          !/^https:\/\/i\.pinimg\.com\/[^\s?#\\]+$/i.test(image.url) ||
          typeof image.width !== 'number' || typeof image.height !== 'number' ||
          !Number.isFinite(image.width) || !Number.isFinite(image.height) ||
          image.width <= 0 || image.height <= 0 || image.width > 50000 || image.height > 50000 || images.length >= 20 ||
          images.some((item: PinmonyCarouselItem): boolean => item.imageUrl === image.url)) return;
        images.push({ id: 'product-' + images.length.toString(), imageUrl: image.url,
          imageWidth: image.width, imageHeight: image.height, title: '' });
      });
    });
    return { images: images, description: parts.filter((part: string): boolean => !!part).join('\n\n').slice(0, 12000), source: source,
      sourceLabel: source ? (typeof pin.linkDomain?.name === 'string' ? pin.linkDomain.name.trim().slice(0, 180) : '') || source.split('/')[2] : '' };
  } catch (_) { return undefined; }
}
