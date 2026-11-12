import { taskpool, util } from '@kit.ArkTS';

// Keep this module isolated: task threads do not initialize UI or application services.
@Concurrent
function decodeCacheJson(text: string): Object | string | number | boolean | null {
  return JSON.parse(text) as Object | string | number | boolean | null;
}

@Concurrent
function encodeCacheJson(data: Object | string | number | boolean | null): ArrayBuffer {
  const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(data));
  if (bytes.byteLength > 2 * 1024 * 1024) throw new Error('cache-size-limit');
  return bytes.buffer as ArrayBuffer;
}

export async function parseCacheJson<T>(text: string): Promise<T> {
  return await taskpool.execute(new taskpool.Task(decodeCacheJson, text), taskpool.Priority.LOW) as T;
}

export async function stringifyCacheJson(data: Object | string | number | boolean | null): Promise<ArrayBuffer> {
  return await taskpool.execute(new taskpool.Task(encodeCacheJson, data), taskpool.Priority.LOW) as ArrayBuffer;
}
