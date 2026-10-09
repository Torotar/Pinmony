# 未整理 Pin 与归板接口

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](NATIVE_NETWORK_NOTES.md)。


默认开启 `PinWebProfileOrganizeScript.ets` 中的 `PIN_PROFILE_ORGANIZE_ENABLED`。所有请求在当前 ArkWeb 同源会话执行；不导入 HAR 的 Cookie、账号 ID 或凭据。属于网站内部接口，不是官方 API/OAuth。

- 帖子收藏面板的“个人资料”：`RepinResource/create/`，提交当前 `pin_id`、当前会话 `user_id` 和可取得的 tracking，不提交 `board_id`。成功必须匹配 `v3_repin_handler`、code 0、返回副本 ID、`board.layout=quick_saves` 和当前用户的 pinner ID。保留原有正常图板收藏和名称建议。
- 我的 → 已收藏下方“未整理的点子”：`BoardlessPinsResource/get/`，使用 `field_set_key: mobile`、`redux_normalize_feed: true`、当前用户的 `userId`，支持 bookmarks 分页、去重和同游标重试。仅在 UserResource 确认当前用户拥有此资料页后加载，Pin 必须属于当前用户。
- 整理 → 多选/全选 → 下一步：选择的是已收藏的副本 ID。全选针对已加载条目；向下滚动到底部自动加载后续 Pin，不显示加载更多按钮。图板列表也在滑到底部时自动分页，错误保留重试按钮。无选中项时下一步禁用。
- 归板列表：`BoardsResource/get/`，按 HAR 的 `privacy_filter: all`、`sort: custom`、`profile_grid_item`、`filter_stories: true`、`page_size: 25`、`group_by: mix_public_private`、`include_archived: true`、`filter_all_pins: false` 和当前 username 请求；支持分页。只启用有 write 权限且未归档的图板，保留私密标识。
- 整理页无图板名称建议；底部保留创建图板，手动名称和公开/私密选择使用已确认的 `BoardResource/create/`。创建成功且确认可写权限后，自动将当前选中的已收藏 Pin 批量移动到返回的新图板 ID。两步共用提交锁；移动成功后关闭整理页，失败保留已选 Pin 和已创建图板，不把创建成功视为整理成功。
- 批量归板：`ApiResource/create/` → `/v3/pins/bulk/move/`，`data: { board_id, pin_ids }`。HAR 的成功响应 data 为 null，依据 status success、code 0、endpoint_name v3_move_pins 确认，然后重新读取未整理列表和资料页图板列表；不在“未整理的点子”下面显示整理成功提示。
- “个人资料”入口使用带回转箭头的历史记录 SVG，居中于 44vp 底块，以 primary_text 资源着色适应深浅色。
- 页面、用户、页签、会话变化时拒绝过期操作及迟到响应。写入期间锁定按钮和返回；网络/格式/超时等无法确认结果时禁止重发，关闭后强制重新读取列表。HTTP 200 或请求发出均不等于业务成功。

## 手动撤回

设置 `PIN_PROFILE_ORGANIZE_ENABLED=false` 可关闭未整理区域和整理流程。帖子收藏面板的个人资料入口也受这个开关控制。不会自动回退 DOM 数据。

修改前文件快照位于 `backups/profile-organize-before-20261001/`。`restore.ps1` 默认仅核验，`-Apply` 才恢复。先完整核验旧快照/当前集成文件哈希，拒绝覆盖后续修改；新加文件保留但不再引用。

本次交互调整前的独立快照位于 `backups/profile-organize-refinement-before-20261001/`，同样先核验、按需传 `-Apply`。更早的集成快照会拒绝覆盖此次后续修改。

## 验证

`scripts/check-profile-organize.cjs` 检查身份、分页去重和重试、多选、可写权限（数组/文本）、精确移动参数、防重复写入、无确定结果禁止重发、创建和过期响应。`check-post-extensions.cjs` 覆盖个人资料 quick_saves 请求及响应校验；资料页和根底栏回归也通过。

HAP 构建确认编译和打包。Pinterest 在线写入、手机滚动/返回/安全区及浅深色视觉仍需设备验证。项目没有签名配置。

## 四页切换中的资料保留（2026-10-02）
资料的运行时展示缓存同时用于切换底栏后返回。返回已创建页使用当前会话内确认的同源地址；资料操作等待新桥接标识，旧操作 ID 不会因展示恢复而启用。完成的用户资料、图板列表、分页及未整理 Pin 列表可保留；未整理读取中或整理子流程离页时仍废弃旧状态。认证路由、主动刷新和原写入后的失效处理保留，未增加任何写入或自动重试。开关、回退策略和原 guard 快照不变。四页保留与资料保留/下拉刷新/整理检查均需通过；实机返回及在线写入仍需另行验收。
