import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hashCacheString } from 'common_foundation';
import { PinmonyBoardInvitation } from 'feature_inbox';

interface PinmonyNoticeRecoveryRecord {
  token: string;
  account: string;
  origin: string;
  target: string;
  savedAt: number;
  invitation?: PinmonyBoardInvitation;
}

// Keep the preceding slot during publication, so a failed replacement remains recoverable.
// No credentials or message body is saved.
export class PinmonyInboxNoticeRecovery {
  private static storage: preferences.Preferences | undefined = undefined;
  private static ready: Promise<void> = Promise.resolve();
  private static queue: Promise<void> = Promise.resolve();
  private static revision: number = 0;

  static initialize(context: common.UIAbilityContext): void {
    PinmonyInboxNoticeRecovery.ready = preferences.getPreferences(context, { name: 'pinmony_notice_target' })
      .then((store: preferences.Preferences): void => { PinmonyInboxNoticeRecovery.storage = store; })
      .catch((): void => { PinmonyInboxNoticeRecovery.storage = undefined; });
  }

  static async save(token: string, accountId: string, origin: string, target: string,
    invitation?: PinmonyBoardInvitation): Promise<void> {
    const revision: number = PinmonyInboxNoticeRecovery.revision;
    const record: PinmonyNoticeRecoveryRecord = { token: token, account: hashCacheString(accountId),
      origin: origin, target: target, savedAt: Date.now(), invitation: invitation };
    const operation: Promise<void> = PinmonyInboxNoticeRecovery.queue.then(async (): Promise<void> => {
      await PinmonyInboxNoticeRecovery.ready;
      if (revision !== PinmonyInboxNoticeRecovery.revision) return;
      const store: preferences.Preferences | undefined = PinmonyInboxNoticeRecovery.storage;
      if (!store) throw new Error('notice-storage-unavailable');
      const previous: preferences.ValueType = await store.get('target', '');
      await store.put('previous', typeof previous === 'string' && previous.length <= 8192 ? previous : '');
      await store.put('target', JSON.stringify(record));
      await store.flush();
    });
    PinmonyInboxNoticeRecovery.queue = operation.catch((): void => {});
    return operation;
  }

  static async read(token: string, accountId: string, origin: string): Promise<PinmonyNoticeRecoveryRecord | undefined> {
    const revision: number = PinmonyInboxNoticeRecovery.revision;
    await PinmonyInboxNoticeRecovery.ready;
    await PinmonyInboxNoticeRecovery.queue;
    try {
      let raw: preferences.ValueType | undefined = await PinmonyInboxNoticeRecovery.storage?.get('target', '');
      if (typeof raw !== 'string' || !raw || raw.length > 8192 || (JSON.parse(raw) as PinmonyNoticeRecoveryRecord)?.token !== token) {
        raw = await PinmonyInboxNoticeRecovery.storage?.get('previous', '');
      }
      if (revision !== PinmonyInboxNoticeRecovery.revision || typeof raw !== 'string' || raw.length > 8192) return undefined;
      const record: PinmonyNoticeRecoveryRecord = JSON.parse(raw) as PinmonyNoticeRecoveryRecord;
      if (!record || record.token !== token || record.account !== hashCacheString(accountId) || record.origin !== origin ||
        !Number.isFinite(record.savedAt) || record.savedAt > Date.now() || Date.now() - record.savedAt > 24 * 60 * 60 * 1000 ||
        typeof record.target !== 'string') return undefined;
      if (/^\d{1,40}$/.test(record.target)) return record;
      const item: PinmonyBoardInvitation | undefined = record.invitation;
      if (!item || item.status !== 'new' || typeof item.boardId !== 'string' || !/^\d{1,30}$/.test(item.boardId) ||
        item.invitedUser !== accountId || typeof item.boardUrl !== 'string' || !item.boardUrl.startsWith(origin + '/') ||
        typeof item.boardName !== 'string' || typeof item.inviter !== 'string' || typeof item.inviterAvatar !== 'string' ||
        typeof item.createdAt !== 'string' || record.target !== 'invite:' + item.boardId + ':' + item.invitedUser + ':' + item.createdAt) return undefined;
      return record;
    } catch (_) { return undefined; }
  }

  static clear(): void {
    PinmonyInboxNoticeRecovery.revision++;
    PinmonyInboxNoticeRecovery.queue = PinmonyInboxNoticeRecovery.queue.then(async (): Promise<void> => {
      await PinmonyInboxNoticeRecovery.ready;
      await PinmonyInboxNoticeRecovery.storage?.delete('target');
      await PinmonyInboxNoticeRecovery.storage?.delete('previous');
      await PinmonyInboxNoticeRecovery.storage?.flush();
    }).catch((): void => {});
  }

  static consume(token: string): void {
    PinmonyInboxNoticeRecovery.queue = PinmonyInboxNoticeRecovery.queue.then(async (): Promise<void> => {
      await PinmonyInboxNoticeRecovery.ready;
      try {
        for (const key of ['target', 'previous']) {
          const raw: preferences.ValueType | undefined = await PinmonyInboxNoticeRecovery.storage?.get(key, '');
          if (typeof raw !== 'string' || !raw || raw.length > 8192) continue;
          const record: PinmonyNoticeRecoveryRecord = JSON.parse(raw) as PinmonyNoticeRecoveryRecord;
          if (record?.token === token) await PinmonyInboxNoticeRecovery.storage?.delete(key);
        }
        await PinmonyInboxNoticeRecovery.storage?.flush();
      } catch (_) { /* Expired or corrupt records cannot authorize a navigation. */ }
    }).catch((): void => {});
  }
}
