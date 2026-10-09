import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

function stableValue(value: Object | string | number | boolean | null): string {
  if (value === null || typeof value !== 'object') {
    const serialized: string | undefined = JSON.stringify(value);
    if (serialized === undefined) throw new Error('params must be JSON serializable');
    return serialized;
  }
  if (Array.isArray(value)) {
    return '[' + value.map((item: Object | string | number | boolean | null): string => stableValue(item)).join(',') + ']';
  }
  const record: Record<string, Object | string | number | boolean | null> = value as Record<string,
    Object | string | number | boolean | null>;
  const keys: string[] = Object.keys(record).sort();
  return '{' + keys.map((key: string): string => JSON.stringify(key) + ':' + stableValue(record[key])).join(',') + '}';
}

export function stableSerialize(params: Object | string | number | boolean | null): string {
  return stableValue(params);
}

export function hashCacheString(text: string): string {
  const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
  const md = cryptoFramework.createMd('MD5');
  md.updateSync({ data: bytes });
  const digest: Uint8Array = md.digestSync().data;
  let hash: string = '';
  for (let index: number = 0; index < digest.length; index++) {
    hash += digest[index].toString(16).padStart(2, '0');
  }
  return hash;
}

export function buildCacheKey(accountId: string, resourceType: string,
  params: Object | string | number | boolean | null): string {
  return accountId + '_' + resourceType + '_' + hashCacheString(stableSerialize(params));
}
