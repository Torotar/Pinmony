# 帖子操作接口与手动撤回

2026-10-05 分阶段加载：正式主图阶段完成/失败/超时后更新点赞数并启动评论预览；评论成功、空、失败或不可用后才读取首批推荐。点赞评论框架立即显示，未确认数值留空且占位操作禁用；真实空预览隐藏，不用文字为空判断图片评论不存在。请求、元信息等待和业务校验新增脱敏时间事件，详见 [详情说明](../DETAIL_API_NOTES.md)。阶段调度不改变写操作、分享面板或会话合同。

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](NATIVE_NETWORK_NOTES.md)。


## 默认方案

详情页的点赞、评论、收藏、三点菜单和来源入口现在完全由当前 Pin 的接口数据和原生动作列表提供。接口快照会丢弃网页 DOM 识别出的对应动作，点赞通过 `ApiResource/create`，评论通过 `UnifiedComments*Resource`，收藏通过图板列表与 `RepinResource` 完成；详情菜单由 `detailMoreOpen/read/close` 读取，来源由 PinResource 的外部 HTTPS 链接字段生成，原生桥接不要求网页按钮存在。接口失败不回退 DOM 操作。

2026-10-05 评论预览首请求：从当前同源资源 fetch 与 XMLHttpRequest 请求学习有效 X-App-Version；详情 handler 只接受来源 Pin 匹配当前页面、已有 PinResource/RelatedModules/UnifiedComments 读取上的 www/pin/[id].js，不沿用 index/search/repin 或其他 Pin 的 handler。当前初始会话 JSON 的版本读取继续有效。仅 UnifiedCommentsPreviewResource GET 在版本或 handler 缺失时最多等待 2 秒；等待绑定完整地址、路由代次、当前 Pin 和预览实例，页面切换/重置/取消时不发请求。超时保留错误并提供评论预览独立重试，不重新读取详情、推荐或自动重放 403/写操作。没有复制抓包版本或凭据，其他业务与分享面板合同保持原样。两份运行日志的 3 次 403 均为 headerCount=4、8 次成功均为 6，是排查线索，不能证明全部拒绝原因；新版本线上结果仍需设备复测。

2026-10-02 用户复测收藏后的首次侧边返回仍退出；尚未确认根因。HAR 共 157 个请求、无 HTTP 4xx/5xx，BoardPickerBoardsResource 和 RepinResource 业务成功；不代表原生返回安全。增加 PinWebReturn 诊断日志，仅记录详情/根返回、面板关闭、撤销提示和页面生命周期，不记录 URL、账号、Cookie 或令牌。未连接 hdc 设备；需要复现时 HiLog/崩溃日志才能区分系统关闭和进程崩溃。评论无头像的字母改成居中的主题灰色圆底。

2026-10-02 高图底部操作区排查：浮动 HdsTabs 原来在登录后的帖子/面板上仍挂载，靠动画隐藏和延迟 hitTest 状态切换。现在只在 nativeRootTabsVisible 且没有待打开帖子时挂载；帖子/收藏/分享等子流程不保留底部隐藏控件树。根页仍保留 100vp 承载高度、56vp 栏高、28vp 底距及按滚动隐藏逻辑，返回根页重新挂载。标题栏不改动。该修改排除隐藏底部区域的触摸及返回干扰；HAR 无法证明 ArkUI 命中目标，仍需设备复测高图首次点击、短图、收藏侧边返回及四个页签。

2026-10-02 首次触摸与收藏返回继续排查：未连接 hdc 设备，HAR 不包含原生退出/崩溃日志，不能确认系统退出根因。按用户要求已撤回替换标题栏的尝试，恢复原 HdsNavigation/NavPathStack 与 HDS 标题栏，不把该处认定为问题原因。按钮仍按实时快照就绪状态启用，不放宽 Pin/session 校验。首次点击和收藏后的侧边返回问题尚未真机确认解决。

2026-10-02 收藏返回再次修正：用户 HAR 的 RepinResource 业务响应为 success/code 0/v3_repin_handler，并包含收藏副本与图板。HAR 只能确认网站请求，不包含原生退出原因。根返回移除“双返回 terminateSelf”路径；无上一页时消耗返回并停留根页，不自动结束 Ability，避免 Sheet/HDS 重复返回导致应用主动退出。详情与面板优先处理逻辑保持。新增 check-post-save-return.cjs 覆盖重复根返回、详情返回、面板优先和异步迟到状态；真实侧边手势及崩溃仍需设备日志验证。既有快照不改动。

2026-10-02 返回与点击修正：详情页 HDS 返回先交给当前面板处理；收藏/分享及系统 Sheet 关闭清除根页退出计时并短暂拦截同一次返回传播。异步根返回在调用网页检查后复核当前详情/面板，不能用过时状态退出应用。详情按钮重建键包含操作就绪状态；已禁用标题栏滚动效果的详情页取消额外滚动联动。静态检查与编译不代表首次点击、侧边手势已在设备上验证；既有 guarded snapshots 保持原样。

2026-10-01 新增收藏面板“个人资料”快速收藏入口，不传 board_id，业务响应必须是当前用户的 quick_saves 副本。与未整理列表/整理归板的接入说明及独立备份见 [`PROFILE_ORGANIZE_API_NOTES.md`](PROFILE_ORGANIZE_API_NOTES.md)。

### 2026-10-01 已确认接口扩展

2026-10-02 用户提供的“三点菜单收藏”HAR 中，`BoardPickerBoardsResource/get/` 返回 HTTP 200，使用 `source_url=/pin/{id}/repin/` 和 `X-Pinterest-Pws-Handler: www/pin/[id]/repin.js`。图板列表请求显式使用该 handler，覆盖其他路由捕获的值；PinResource 继续使用详情 handler。现有 field_set_key、shortlist_length、shortlist_suggestions、pin_id、运行时 user_id 与抓包结构一致。仅采用请求合同，不复制抓包 Cookie、CSRF、用户 ID 或令牌。手机上的 403 是否消失仍需联网复测。

`PinWebPostExtensionsScript.ets` 的 `PIN_POST_EXTENSIONS_ENABLED=true`，与帖子主开关一起启用。此次修改前快照在 `backups/post-extensions-before-20261001/`，运行其 `restore.ps1` 先核验，传 `-Apply` 才恢复；不覆盖旧备份的哈希保护。

收藏 HAR 还携带 `X-App-Version`。帖子请求从当前同源资源请求头或当前初始会话 JSON 的 `client_context.app_version` 取得版本，仅在值有效时发送，不硬编码抓包版本。图板请求继续使用独立 repin handler。403 可能仍有其他网络或服务端原因，离线合同检查不证明该补齐已解决实机拒绝。

- 评论聚合 ID 优先从当前 Pin 匹配的 Relay 初始 JSON `data.v3GetPinQueryv2.data.aggregatedPinData.entityId` 取得，缺少时使用已确认的当前接口参数/详情字段，不拿 URL Pin ID 替代。仅解析 script 内 JSON，不执行网站脚本或扫描评论 DOM。
- 评论预览：`UnifiedCommentsPreviewResource/get/` → `unified_comment`；空结果不虚构内容。完整列表：`UnifiedCommentsResource/get/`，文字与 `userdiditdata` 图片评论分别映射。下一页使用 `resource_response.bookmark`，缺少时读取 `resource.options.bookmarks[0]`，终止/重复游标结束；失败保留旧条目并重试同一游标。
- 展开回复：`AggregatedCommentReplyFeedResource/get/`，`objectId` 使用父评论 ID。只接入已确认的首批回复；未确认的回复分页明确提示，不发猜测请求。
- 文字评论与回复点赞：`ApiResource/create/` 或 `delete/` → `/v3/aggregated_comments/{commentId}/react/`，`reaction_type: 1`。业务 endpoint、code 与响应评论 ID 同时确认后重新读取列表或回复，不伪造缺失的点赞数量。2026-10-04依据新增HAR接入文字发布/编辑/删除、图片体验上传/发布/点赞/删除及图片体验文字回复，详见 [评论写入说明](COMMENT_WRITE_API_NOTES.md)。
- 图板面板：`BoardPickerBoardsResource/get/`，使用当前会话 PinResource JSON 的登录用户 ID，按 `all_boards` 和 `boards_shortlist` 呈现名称/封面，权限来自 `access`。首页菜单已读到当前 Pin 且同一会话已确认用户 ID 时，直接复用该菜单的接口数据，不重复读取 PinResource；关闭菜单或页面变化后不能复用。缺失时按完整详情参数读取 PinResource。错误标明帖子信息或图板列表读取阶段；非 JSON 的 401/403 只说明请求被拒绝，不据此判定登出或要求重新登录。初次读取失败显示紧凑错误与手动重试，不展示空的全屏图板列表。图板数量较多时的分页/搜索未确认。创建名称建议可用已抓取的 GraphQL queryHash 请求 `boardTitleSuggestions`；哈希失效不影响手动输入名称。
- 创建图板：`BoardResource/create/`，公开 `privacy: public`，私密 `privacy: secret`。服务器返回名称、ID、隐私及业务成功后确认创建；重名等业务错误使用服务端消息。2026-10-02 按用户要求，创建确认后自动用返回的图板 ID 收藏当前 Pin；仅收藏业务确认后发送 `saveReady` 关闭收藏面板并提供撤销提示。收藏失败保留面板和已创建图板，同名同隐私再次提交只重试收藏，不重复创建；不自动重试写入。空图板原生列表保留灰色缩略图。历史 guarded snapshots 保持原样。
- 收藏：`RepinResource/create/`，使用当前 Pin、当前用户、可写图板 ID 及运行时 tracking。确认目标图板和返回收藏 Pin ID 后记录在当前 Web 会话内存中。
- 取消收藏：`PinResource/delete/`，仅使用本次会话通过收藏响应取得的副本 ID，绝不提交原 Pin ID。暂不推断进入应用前已有收藏的副本 ID，也不跨 Web 文档持久化映射。只允许取消当前记录的最近一次收藏；其他已有收藏继续在网站管理。
- 查看更少：`ApiResource/update/` → `/v3/pfy/{id}/feedback/`，`feedback_type: 10`。查看更多与撤销使用独立 see_more / see_more/undo 请求。查看更多成功后详情中显示“撤销”入口；查看更少的撤销尚未确认，不提供猜测操作。
- 详细了解 AI 标签：仅在当前网页菜单提供该项时打开用户给定的官方帮助链接；不是数据请求。菜单可见选项仍来自当前网页。
- 评论、图板面板操作绑定当前 Pin 和面板实例；重复写入锁定，离开/关闭丢弃迟到响应。已发送的写入无法靠关闭界面取消，关闭时不会伪报结果。网络异常不自动重放写操作，不回退 DOM 数据。

验证：`scripts/check-post-extensions.cjs` 覆盖 Relay ID、图片评论、分页重试/去重、回复、反应刷新、图板列表、私密创建、重名错误、收藏副本删除、撤销和过期状态；既有帖子、详情、首页菜单回归一起运行。编译与模拟不证明 Pinterest 当前在线接口或手机手势可用。

`services/PinWebPostApiScript.ets` 的 `PIN_POST_API_ENABLED = true`。请求在当前 ArkWeb 网页会话中执行；凭据只从当前 cookie 临时读取，不保存桌面抓包凭据。它是 Pinterest 网站内部接口，不是官方 API/OAuth。

- 默认联系人：`ShareSuggestionsResource/get/` → `resource_response.data`。
- 用户搜索：`ShareSuggestionsTypeaheadResource/get/` → `resource_response.data.items`。新关键词废弃旧结果，发送绑定本次面板、Pin 和返回的用户 ID。
- 分享链接：`/_/graphql/`，观察当前 Pin 网页实际分享请求和 JSON 响应，复用当前 queryHash、变量结构和渠道字段类型，不固定电脑端哈希。渠道 10/12/5/6/9 分别对应打开分享、复制、Facebook、Messenger、X。WhatsApp/短信只使用已确认的通用分享渠道 10，不猜独立编号。短链接不可用时明确提示，允许使用当前详情 JSON 中 Pin ID 对应的原链接，不回到 DOM 数据。复制只在系统剪贴板完成后确认。
- 手机平台：识别并区分 Facebook、Messenger、X、WhatsApp、短信，图标只显示一层。缺少 href 不再禁用平台。当前网页提供了完整 HTTPS 分享目标时尝试 `openLink(appLinkingOnly: true)`；未提供目标或系统没有对应 App Linking 时交给 Share Kit 显示实际安装且支持链接分享的应用，提示用户选择所点击的平台。当前 SDK 普通 Share Kit 不支持按任意显示名称直接指定应用，不猜 Android 包名，也不绕过系统选择发送消息。没有目标应用不声称已唤起或已发送。
- 响应异常：非 JSON、超时、网络错误转为可读错误和真实重试；不显示原始 SyntaxError。允许采集当前网页返回的联系人接口 JSON，仍不读取 DOM 联系人作为数据回退。
- 发送：`ConversationsResource/create/`。成功必须有本次 Pin 的实际消息和匹配的收件人，409/4372 等业务错误显示服务端原因，不把 HTTP 200 或点击发出当作成功。
- 点赞：`ApiResource/create/` → `/v3/pins/{id}/react/`。确认返回 Pin 后更新选中状态；取消点赞尚未抓取，已点赞按钮禁用。缺少接口反应状态/追踪参数时禁用，不以 DOM 的选中态替代。
- 评论：`UnifiedCommentsResource/get/`，原生列表使用接口聚合 ID，不拿 URL Pin ID 代替。缺少 ID 显示不可用；默认扩展读取图片/文字评论、游标分页、展开回复和评论点赞/取消点赞。发表评论仍未确认；详见本文件新增扩展说明。
- 下载：使用当前详情 JSON 中实际提供的图片地址，优先 orig，随后 736x/474x；不改写 URL 猜原图。调用 ArkWeb `startDownload`，沿用目录选择和下载完成/失败回调。
- 更多/更少：`ApiResource/update/` → `see_more/` 和 `see_more/undo/`。允许当前网页实际提供的菜单项发起第一次反馈，无需先捕获网页反馈请求。提交当前 Pin ID，附带匹配当前 Pin JSON 或同源实际反馈请求中可取得的 tracking_params/client_tracking_params、through_id、rec_reason_type、source；不补造缺失值。缺少追踪字段不直接禁用，服务端拒绝时显示实际原因并恢复可点击。成功必须同时匹配业务 endpoint_name、code 0 和响应 Pin ID。查看更多提交 see_more，撤销查看更多单独提交 see_more/undo；查看更少使用已确认的 /v3/pfy/{PinID}/feedback/ 和 feedback_type: 10。该精简参数请求仍需联网设备验证服务端接受情况。

首页菜单按用户明确指定的自定义配置呈现：Messenger、WhatsApp、消息、Facebook、X，以及下载图片、查看更多、查看更少。菜单打开后直接读取当前 Pin 的 `PinResource/get/`，不跳转详情页。首页分享优先使用当前会话捕获的匹配查询；缺少捕获时使用用户提供的分享 queryHash 和当前 Pin 变量，服务端拒绝时沿用已明确提示的当前 Pin 原链接处理，不把哈希可用性当作已通过在线验证。平台点击交给已有 App Linking / Share Kit 路径，不能按任意名称保证直接打开指定应用。

详情三点菜单的可见项由当前 Pin 接口数据和已确认能力构造：下载图片、查看更多/查看更少、AI 说明及编辑 Pin；默认排除举报、在应用中打开、拼贴。详情分享采用与首页相同的已有平台配置，并增加复制链接，直接发布原生面板；联系人独立加载，不先打开后台 DOM 分享面板。收藏默认启用本次扩展的图板列表、创建、保存/取消接口；来源链接只打开接口返回且经外部 HTTPS 校验的地址。接口联系人、评论、点赞、发送、反馈失败不自动调用旧 DOM 操作。

尚待联网设备确认：当前 Pinterest PinResource 是否返回反应状态、聚合评论 ID 和完整反馈上下文；网页运行时分享请求是否被捕获、联系人请求是否成功；已安装平台是否支持本机 App Linking 或 Share Kit。缺少上述数据会显示错误或不可用，不声称已验证线上能力。

## 原方案和备份

旧方案在 `backups/post-actions-before-20260930/` 保存本次修改前的 Index、详情桥接/详情接口服务和两份原说明。它已包含此前的主图/推荐 API 接入，不是更早的纯 DOM 详情版本。

旧操作流程：Index 内分享/三点脚本打开并隐藏后台网页面板，读取 DOM 标签、联系人及搜索输入；原生操作按 session/Pin/control ID 点击网页按钮；搜索设置网页 input 并派发 input/change；点赞观察网页选中态并使用原生临时乐观状态；评论打开网页流程。旧方法体继续保留，仅在手动关闭新开关时执行。

快速撤回本次操作方案：把 `PIN_POST_API_ENABLED` 改为 `false`，重新构建并重启。主图/推荐 API 与其他页面不受影响。

完整恢复修改前的文件：

```powershell
& ./backups/post-actions-before-20260930/restore.ps1
& ./backups/post-actions-before-20260930/restore.ps1 -Apply
```

先执行不带参数的校验。恢复脚本检查备份和接入后文件的 SHA256；后续编辑会拒绝覆盖。新增服务/组件/模型会保留为未引用文件，不删除目录。较早 detail/home/search 备份的保护可能因本次修改拒绝恢复，应先撤回本次或单独审核，不能强制覆盖。

2026-09-30 分享修复前的独立备份为 `backups/share-fix-before-20260930/`，同样先运行其 `restore.ps1` 校验，再用 `-Apply` 恢复。若要恢复最初帖子操作方案，先撤回分享修复，再运行 post-actions 的恢复脚本；不更新最初备份的预期哈希来绕过后续编辑保护。

## 验证

2026-10-01 评论排版修复：评论行改为头像、同行用户名/相对时间、正文、小型无底色点赞控件；展开回复入口和子回复缩进。`ForEach` 行标识包含当前评论快照，避免只按 ID 复用后仍保留展开前的行闭包，支持回复加载/展开/收起/点赞状态更新；未变化的轮询快照继续复用行。保留当前原生 Sheet 标题和关闭方式，不新增未接入的发表评论、提交回复或评论菜单。`check-comments-layout.cjs`（可传入 TypeScript 模块路径）和扩展回归验证日期、行更新以及收起/重开已有回复。独立撤回备份 `backups/comments-layout-before-20261001/`；先运行 `restore.ps1`，再以 `-Apply` 恢复。本次 HAP 编译通过，深浅色、大字号和联网设备展开效果仍待验证。

2026-10-01 设备反馈修复：当前 Pin API 数据有效时补齐原生收藏和分享入口，收藏不再依赖 DOM 按钮；已点赞图标保留完整透明度，暗色资源改为更鲜明的红色。评论与图板读取兼容 ArkWeb 的直接 JSON 与再次编码的 JSON 字符串返回，继续验证当前 Pin/面板实例。分享立即显示平台及复制链接，联系人、短链接失败保留明确反馈。独立撤回备份：`backups/detail-device-fix-before-20261001/`；先执行 `restore.ps1` 校验，再加 `-Apply` 恢复，之后才能撤回较早扩展。

`scripts/check-detail-device-fixes.cjs` 验证缺失 DOM 按钮时的入口、分享首次发布/关闭后迟到结果、原生评论/图板两种返回编码及 Pin/面板守卫；TypeScript 不在 Node 模块路径时，首个参数传入 DevEco 的 TypeScript 模块位置。相关七项回归与 entry HAP 构建通过；没有签名配置，未安装到设备，未验证当前 Pinterest 联网返回、浅色/暗色设备显示和系统分享应用行为。

`node scripts/check-post-api.cjs` 覆盖请求格式、当前会话、JSON 列表、搜索乱序、重复写入、拒收错误、发送结果验证、关面板后迟到响应、缺追踪字段首次反馈、失败重试、反馈响应归属、反馈上下文、评论和关闭开关。相关详情、菜单与搜索桥接检查亦运行。编译打包和离线模拟不证明线上接口、安装、手势、剪贴板、外部应用或下载行为。

2026-09-30 更多/更少修复前备份：`backups/feedback-fix-before-20260930/`。先执行其 `restore.ps1` 校验，再以 `-Apply` 恢复；完整撤回顺序为 feedback-fix → share-fix → post-actions。此次没有启用旧 DOM 操作回退。


已收藏 Pin 的三点菜单“编辑 Pin 图”现支持图板移动、AI 修改标记与确认删除，详见 [EDIT_PIN_API_NOTES.md](EDIT_PIN_API_NOTES.md)。这与取消本次新收藏的 saved 映射流程独立，必须校验当前 Pin pinner 为当前用户。

2026-10-02：增加固定收藏请求/确认、撤销请求/确认诊断事件，供设置页日志导出使用；不记录接口正文、身份或凭据，不改变操作校验及数据来源。

2026-10-03：分享面板的“复制链接”使用 InspiFol 风格链条图标资源；三点菜单面板标题固定为“选项”，网页返回的选项名称和分组不变。

2026-10-02 系统返回修复：三个 HdsSnackBar 的 SnackBarStyleOptions 补充官方 pressBackCallback。提示条接收系统返回时，先校验当前提示实例、关闭提示条，再调用现有 onBackPress 处理面板/详情返回；重复及过期回调不处理，不触发撤销或重试，不改标题栏。日志新增 snackbar system back。check-snackbar-back.cjs 验证顺序、重复/过期、关闭与撤销分离及分享回调；设备侧边返回仍须实测。

2026-10-03：按用户截图将复制链接图标改为 Lucide 官方 link 原始 SVG 路径，保留按钮底色与复制行为。来源 https://lucide.dev/icons/link（ISC）。
