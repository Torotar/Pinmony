interface DescriptionComponent { type?: string; stringContent?: string; pointsContent?: string[]; }
interface FormattedDescription { components?: DescriptionComponent[]; }
interface ProductLinkDomain { name?: string; }
interface ProductPin {
  entityId?: string; id?: string; formattedCloseupDescription?: FormattedDescription;
  link?: string; mobileLink?: string; trackedLink?: string; utmLink?: string; affiliateLink?: string;
  linkDomain?: ProductLinkDomain;
}
interface ProductResponse { errors?: Object[]; data?: ProductData; }
interface ProductData { v3GetPinQueryv2?: ProductResult; }
interface ProductResult { data?: ProductPin; }
export interface ProductPresentation { description: string; source: string; sourceLabel: string; }

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
    return { description: parts.filter((part: string): boolean => !!part).join('\n\n').slice(0, 12000), source: source,
      sourceLabel: source ? (typeof pin.linkDomain?.name === 'string' ? pin.linkDomain.name.trim().slice(0, 180) : '') || source.split('/')[2] : '' };
  } catch (_) { return undefined; }
}
