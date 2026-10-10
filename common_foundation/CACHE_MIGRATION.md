# Cache Layer

`common_foundation` exports `LruCache`, `DiskCache`, `buildCacheKey`, `stableSerialize`, `ApiCache`, and `CACHE_TTL`.
The caller must obtain the current account identifier from authenticated session state and pass `context.cacheDir` to
`ApiCache`; never store cookies, access tokens, or other credentials in cached payloads.

## Home Integration

The current home request is event-driven by the hidden ArkWeb bridge, so the app restores the disk snapshot before
binding the current session and writes each validated `state` message afterward. The in-memory `cachedHome` field
remains the presentation state; restored controls are disabled until a current bridge snapshot binds them.

```ts
import { ApiCache, buildCacheKey, CACHE_TTL } from 'common_foundation';
import { PinmonyHomeSnapshot } from 'feature_home';

interface HomeCacheRecord {
  snapshot: PinmonyHomeSnapshot;
}

const apiCache: ApiCache = new ApiCache(context.cacheDir);
const key: string = buildCacheKey(accountId, 'home_feed', { pageKey });
const cached: HomeCacheRecord | null = apiCache.get<HomeCacheRecord>(key, CACHE_TTL.homeFeed);
if (cached) store.cachedHome = validateCacheRecord(cached, pageKey)?.snapshot;
// Existing Web bridge/request flow continues. After its page, session, category,
// and business response checks pass:
apiCache.put(key, { snapshot: validatedSnapshot }, CACHE_TTL.homeFeed);
```

`readThrough` remains the option for Promise-based fetchers: it publishes memory/disk data immediately and refreshes in
the background. Do not wrap this event-driven Web bridge in a second fetcher that would duplicate its network request.
The background response must pass the existing request-generation, session, route, category, and response validation
before it is written. Cached content is for display; it does not restore actionable controls.

## Integration Paths

- `common_foundation/Index.ets` and `common_foundation/src/main/ets/cache/*.ets` provide the shared implementation.
- `entry/src/main/ets/pages/Index.ets` initializes the cache from the host `UIAbilityContext`, restores account-scoped
  snapshots after explicit login evidence, persists validated home states, and clears data on session invalidation.
- `feature_home/src/main/ets/stores/PinmonyHomeStore.ets` remains the in-memory presentation state; no ArkUI component
  or layout code needs cache logic.

## Runtime Audit Events

Exported diagnostics include the following cache acceptance evidence. Filter the application log for `HomeCache:` and
`CacheAudit:`; account names, cache keys, URLs, and cached payloads are not logged.

- `lookup ... status=memory|disk|miss|expired|corrupt ageMs=... elapsedMs=...` records the lookup result, disk age,
  and synchronous lookup duration. A cold restart should report `disk`; a lookup beyond the home TTL should report
  `expired`.
- `snapshot restored ... actionsReady=false` confirms an eligible cached presentation was restored while actions
  remain gated. `current session snapshot committed ... sinceRestoreMs=...` records replacement by validated current
  session state, and `current session state actionsReady=true ...` records the action-gate transition.
- `refresh failed snapshotRetained=true actionsReady=false` records offline/failure retention without treating cached
  content as current-session data.
- `account identity changed ... preserving disk partitions` records an account boundary without exposing either
  identity. `clear ... filesRemoved=...` records persistent cache cleanup on session invalidation or logout.
- `snapshot persisted ... elapsedMs=... ttlMs=...` records write duration and TTL. `CacheAudit: memory lru eviction`
  records capacity eviction. `CacheAudit: disk write committed elapsedMs=... ttlMs=...` confirms that a disk write
  reached the atomic rename boundary. Exercise LRU ordering, stable parameter hashing, in-flight request dedupe,
  and the temporary-file cleanup contract with `node scripts/check-cache-consistency.cjs`.

## Acceptance Metrics

The static check proves the source contract only. For device acceptance, export the runtime log and inspect these
metrics without exposing account names, cache keys, URLs, credentials, or payloads:

- `lookup` status distribution: cold restart should produce `disk`, a warm lookup may produce `memory`, and a lookup
  after `ttlMs` should produce `expired`.
- `snapshot restored ... actionsReady=false` must precede `current session state actionsReady=true`; no cached
  snapshot may enable actions before current-session data is validated.
- `CacheAudit: disk write committed` must have finite non-negative `elapsedMs`; no `disk snapshot write failed` or
  `corrupt` status should appear during the normal path.
- A repeated identical fetch should produce one in-flight request and one committed value; after logout,
  `clear ... filesRemoved=...` must appear and a subsequent authenticated account must not restore the previous
  account's snapshot.

## Offline read-only preview

After an authenticated home snapshot is committed, the app persists only a non-plaintext partition fingerprint, the validated home
route, and the commit time. The offline marker is written to the same `context.cacheDir/api_cache` disk cache as the snapshot,
with `AppStorage` retained only as a warm-process fast path. The marker is retained longer than the home snapshot so an expired
snapshot can be classified explicitly. If the home document fails while the marker still points to a snapshot within `CACHE_TTL.homeFeed`,
the app may enter `OfflineCache: preview entered actionsReady=false`. This is a presentation mode, not an authenticated session:
`homeActionsReady` stays false and home category switching, pagination, refresh, save, download, and share are blocked with
`reason=offline-preview`. A current authentication callback exits the mode. An expired or invalid snapshot must emit
`OfflineCache: expired` or a validation failure and leave the preview closed.
