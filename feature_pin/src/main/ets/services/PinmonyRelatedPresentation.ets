import { PinImageSources } from 'common_ui';
import { PinmonyRelatedPin, PinmonyRelatedTopic } from '../models/PinmonyDetail';

interface RelatedImage { url: string; width: number; height: number; }
interface RelatedPin {
  id: string; type: string; images: Record<string, RelatedImage>;
  title?: string; grid_title?: string; description?: string;
}
interface FormattedTitle { format?: string; args?: Object[]; }
interface RelatedTopic { id?: string; type?: string; title?: FormattedTitle; cover_images?: Record<string, RelatedImage>[]; action?: TopicAction; }
interface TopicAction { url?: string; }
interface RelatedStory { id?: string; type?: string; story_type?: string; title?: FormattedTitle; objects?: RelatedTopic[]; }
interface RelatedResource { status: string; data: RelatedPin[]; bookmark?: string; error?: Object; code?: number; }
interface RelatedResponse { resource_response: RelatedResource; }
export interface RelatedPresentation { pins: PinmonyRelatedPin[]; ended: boolean; bookmark?: string; }

// Keep only the confirmed search query; discard transient HAR/site tracking parameters.
export function relatedTopicSearchUrl(value: string, pinUrl: string): string {
  if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pinUrl) || typeof value !== 'string' || value.length > 8192) return '';
  const origin: string = pinUrl.slice(0, pinUrl.indexOf('/', 8));
  const path: string = value.startsWith(origin + '/') ? value.slice(origin.length) : value;
  if (!/^\/search\/pins\/\?[^#\s]*$/.test(path)) return '';
  const matches: string[] = path.slice(path.indexOf('?') + 1).split('&').filter((part: string): boolean => part.startsWith('q='));
  if (matches.length !== 1) return '';
  try {
    const query: string = decodeURIComponent(matches[0].slice(2).replace(/\+/g, ' ')).trim();
    return query && query.length <= 300 && !/[\u0000-\u001f\u007f]/.test(query) ? origin + '/search/pins/?q=' + encodeURIComponent(query) : '';
  } catch (_) { return ''; }
}

function storyCard(story: RelatedStory, pinUrl: string): PinmonyRelatedPin | undefined {
  if (story.type !== 'story' || story.story_type !== 'BUBBLE_ONE_COL' || !Array.isArray(story.objects) ||
      typeof story.id !== 'string' || !story.id || story.id.length > 200 ||
      typeof story.title?.format !== 'string' || !story.title.format.trim() || story.title.args?.length) return undefined;
  const topics: PinmonyRelatedTopic[] = [];
  for (const topic of story.objects.slice(0, 12)) {
    const target: string = relatedTopicSearchUrl(topic?.action?.url || '', pinUrl);
    if (topic?.type !== 'explorearticle' || typeof topic.id !== 'string' || !topic.id || topic.id.length > 200 ||
        !target || typeof topic.title?.format !== 'string' || !topic.title.format.trim() || topic.title.args?.length ||
        topics.some((item: PinmonyRelatedTopic): boolean => item.id === topic.id)) continue;
    const sizes: Record<string, RelatedImage> | undefined = topic.cover_images?.[0];
    let image: RelatedImage | undefined;
    for (const tier of ['474x', '400x', '236x', '736x']) {
      const candidate: RelatedImage | undefined = sizes?.[tier];
      if (candidate && /^https:\/\/(?:[a-z0-9-]+\.)*pinimg\.com\//i.test(candidate.url) && candidate.url.length <= 2000 &&
          Number.isFinite(candidate.width) && candidate.width > 0 && candidate.width <= 20000 &&
          Number.isFinite(candidate.height) && candidate.height > 0 && candidate.height <= 20000) { image = candidate; break; }
    }
    if (image) topics.push({ id: topic.id, title: topic.title.format.trim().slice(0, 160), imageUrl: image.url, targetUrl: target });
  }
  return topics.length ? { id: 'story:' + story.id, kind: 'topics', topics: topics, pinUrl: '',
    imageUrl: topics[0].imageUrl, imageWidth: 1, imageHeight: 1, title: story.title.format.trim().slice(0, 160) } : undefined;
}

/** Validated native recommendation data. Mutation readiness is separate. */
export function readRelatedPresentation(body: string, pinUrl: string): RelatedPresentation | undefined {
  if (!/^https:\/\/(?:www|uk)\.pinterest\.com\/pin\/\d+\/$/.test(pinUrl) || body.length > 1000000) return undefined;
  try {
    const resource: RelatedResource = (JSON.parse(body) as RelatedResponse).resource_response;
    if (!resource || resource.status !== 'success' || resource.error ||
        (typeof resource.code === 'number' && resource.code !== 0) || !Array.isArray(resource.data)) return undefined;
    const pins: PinmonyRelatedPin[] = [];
    for (const pin of resource.data.slice(0, 24)) {
      if (pin?.type === 'story') {
        const story: PinmonyRelatedPin | undefined = storyCard(pin as Object as RelatedStory, pinUrl);
        if (story && !pins.some((item: PinmonyRelatedPin): boolean => item.id === story.id)) pins.push(story);
        continue;
      }
      if (!pin || pin.type !== 'pin' || !/^\d+$/.test(String(pin.id))) continue;
      const target: string = pinUrl.slice(0, pinUrl.indexOf('/', 8)) + '/pin/' + pin.id + '/';
      if (target === pinUrl || pins.some((item: PinmonyRelatedPin): boolean => item.pinUrl === target)) continue;
      const sizes: Record<string, RelatedImage> = pin.images || {};
      let selected: RelatedImage | undefined;
      const images: PinImageSources = {};
      for (const tier of ['474x', '236x', '564x', '736x', 'orig']) {
        const image: RelatedImage | undefined = sizes[tier];
        if (!image || !/^https:\/\/[^\s]+$/i.test(image.url) || image.url.length > 2000) continue;
        images[tier] = { url: image.url };
        if (!selected && Number.isFinite(image.width) && image.width > 0 && image.width <= 20000 &&
            Number.isFinite(image.height) && image.height > 0 && image.height <= 20000) selected = image;
      }
      if (!selected) continue;
      const title: string = typeof pin.grid_title === 'string' ? pin.grid_title :
        typeof pin.title === 'string' ? pin.title : typeof pin.description === 'string' ? pin.description : '';
      pins.push({ id: 'api:' + pin.id, pinUrl: target, imageUrl: selected.url,
        imageWidth: selected.width, imageHeight: selected.height, images: images, title: title.trim().slice(0, 160) });
    }
    if (resource.data.length > 0 && pins.length === 0) return undefined;
    const bookmark: string = typeof resource.bookmark === 'string' && resource.bookmark.length <= 4096 ? resource.bookmark : '';
    return { pins: pins, bookmark: bookmark, ended: !bookmark || bookmark === '-end-' || resource.data.length === 0 };
  } catch (_) { return undefined; }
}
