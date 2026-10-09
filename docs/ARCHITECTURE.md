# PinWeb 三层模块化架构

## 工程边界

工程采用 HarmonyOS 6.1.1（API 24）Stage 模型。`entry` 是产品定制层的入口 HAP；基础特性层与公共能力层使用 11 个实际 HAR 模块，通过各模块 `Index.ets` 公开接口和 `oh-package.json5` 声明依赖。

低栏点击只通过 `selectNativeRootTab()` 切换对应 ArkUI 根页面，不调用接口、执行 Web 导航或等待网页确认。保留页面快照与滚动；无快照且无加载/错误状态时，由根页实际可见后的页面生命周期延后 80ms 发起首次读取；正常空快照不重复读取，失败保留手动重试。页面内主动刷新、重试及已接入业务操作独立负责读取和必要的后台路由同步。纯画面切换期间，旧 Web 路由、详情和图板回调不能覆盖选中的页签；展示地址与真实会话地址分离，缓存不直接启用操作。

依赖方向为 `entry → feature_* → common_*`，产品层也可直接依赖公共能力。当前特性模块不互相依赖，跨业务导航由产品层协调；公共能力不能引用特性或 entry。`scripts/check-module-architecture.cjs` 检查模块边界、依赖循环和源码归属。

基础架构的静态门禁由 `scripts/check-foundation-architecture.cjs` 统一执行：它检查 11 个 HAR 的公共入口和依赖声明、特性之间无直接依赖、公共层不反向引用产品层、`entry` 只有一个 ArkUI `@Entry`、七个 Store 由产品入口持有、`EntryAbility` 的生命周期事件完整，以及 Remote Communication Kit 只由 `common_network` 持有。该检查只证明源码边界和责任归属；HAP 构建、签名安装、真机生命周期和线上服务仍需独立验证。

## 当前模块

| 层级 | 模块 | 现有内容 |
| --- | --- | --- |
| 产品定制层 | entry | EntryAbility、登录 Web 的挂载、四页签与二级页组合、返回、跨业务协调和系统能力调用 |
| 基础特性层 | feature_home | 首页、三点菜单、首页接口脚本和列表保留 |
| 基础特性层 | feature_search | 搜索、探索问答、接口脚本、缓存与列表保留 |
| 基础特性层 | feature_inbox | 收件箱、会话页面、接口/桥接脚本与缓存 |
| 基础特性层 | feature_profile | 资料、整理、发布选项面板、接口/桥接脚本与缓存 |
| 基础特性层 | feature_pin | 详情、轮播、视频、收藏、评论、编辑、分享与菜单脚本及详情缓存 |
| 基础特性层 | feature_board | 图板页面、数据合同和图板接口脚本 |
| 基础特性层 | feature_settings | 设置、账号管理、个人信息及 SettingsStore |
| 公共能力层 | common_session | 登录证据模型、当前网页登录状态脚本 |
| 公共能力层 | common_ui | 状态页、图板占位组件、共享主题色和图标（包含深色变体） |
| 公共能力层 | common_foundation | 运行日志、凭据脱敏与日志导出 |
| 公共能力层 | common_network | 原生 RCP 传输、受限请求桥接、取消、请求代次与响应传递 |

发布选项面板、原生输入/多选/图板选择、系统照片读取和发布接口服务保留在资料模块，见 PUBLISH_API_NOTES.md。视频播放器仍使用帖子模块自己的媒体合同，未为了分包把业务类型移入公共层。

## Ability 与生命周期

应用采用 Stage 模型，`EntryAbility` 是唯一入口 UIAbility。Ability 生命周期与窗口、ArkUI 内容、网络会话分层管理：`onCreate` 初始化运行日志、PersistentStorage 偏好、Web 引擎与网络预连接；`onWindowStageCreate` 配置主窗口安全区/系统栏并加载 `pages/Index`；`onForeground` 重新同步系统色彩与安全区；`onBackground` 保留页面和 ArkWeb 会话，不把后台视为登出；`onWindowStageDestroy` 移除窗口安全区监听并释放窗口引用；`onDestroy` 关闭共享 RCP Session、移除全局异常观察器并结束 Ability。

每次生命周期事件写入受限的 `AbilityLifecycle` 诊断行，包含事件名、单调递增序号、相对 Ability 启动耗时、相邻事件间隔、WindowStage 是否就绪和 ArkUI 内容是否加载完成。日志不包含 URL、Cookie、账号标识、请求体或响应正文。`content-load-start` 到 `content-load-complete` 的间隔用于观察首个 ArkUI 内容加载耗时；`preconnect-dispatched` 用于确认预连接不会阻塞 Ability 启动；`destroy-start` 后不得再出现业务网络成功或界面更新日志。

生命周期验证要求：冷启动应出现 `create-start → create-complete → window-stage-create → content-load-start → content-load-complete`；切后台/回前台应出现成对的 `background → foreground`，页面、登录状态和滚动位置保持；窗口销毁/重建应出现 `window-stage-destroy → window-stage-create`，不得重复叠加 `avoidAreaChange` 监听；正常退出或 Ability 销毁应出现 `destroy-start → destroy-complete`，共享网络会话关闭一次且没有迟到响应更新界面。使用 `scripts/export-device-logs.ps1` 导出日志后，以 `sequence` 顺序和 `sincePreviousMs` 检查事件顺序与异常间隔。

## ArkUI 页面与状态管理

`entry/src/main/ets/pages/Index.ets` 是唯一的 `@Entry @Component`，负责产品级页面协调。七个特性 Store（Pin、Board、Settings、Profile、Inbox、Search、Home）由 `Index` 以 `@State` 持有；对应 Store 类使用 `@Observed`，页面组件通过 `@Prop` 接收快照或业务状态，组件内部的临时输入、可见性和加载状态使用 `@State`。系统安全区和底栏偏好使用 `@StorageProp` / `@StorageLink`，不把跨业务状态复制到页面局部字段。

四个根页由同一个 `HdsTabs` 和四个 `TabContent` 承载；`selectNativeRootTab()` 只更新原生展示状态、`activeTab` 与 `tabsController.changeIndex()`，根页 `animationDuration(0)`，不重建 Index 或 Store。低栏不承担 API 接入、Web 导航或网络确认。根页快照、分页代次和滚动由所属 Store/缓存保留；没有快照且无加载/错误时，页面可见区域回调延后 80ms 发起首次读取；页面内重试/刷新通过 `requestRootPage()` 独立绑定后台同源上下文。纯画面切换时 `nativeRootOnly` 保持原生展示权，迟到的 Web 导航/详情/图板事件不能改变页签；`nativeDisplayAddress()` 使用展示地址，实际会话校验仍使用控制器真实路由。首页预取、搜索自动补页和资料触底分页不因纯切换启动；用户正文滚动或业务操作才可恢复读取。缓存只负责展示，不直接开启操作。二级详情打开或显式业务路由读取释放展示保护，继续原有请求代次、取消及地址校验；二级页面和 Sheet 仍在 Tabs 上方，返回按 Sheet → 二级页 → 根页收敛。ArkWeb 保持挂载和完整视口，仅业务返回使用真实历史文档保留；缺少资料地址的同会话回调不清空缓存，明确账号变化、会话失效或退出才清理。

`aboutToAppear()` 初始化缓存并绑定 Store 的导航回调、ShareBridge 和业务状态回调；`aboutToDisappear()` 解除这些回调，调用两个原生网络对象的 `invalidate()`，暂停详情预取并清理 Snackbar、请求归属、定时器和面板状态。`onPageShow()` 恢复前台视频/首页恢复任务，`onPageHide()` 停止视频、暂停预取、取消详情读取。隐藏的 ArkWeb 仍保持挂载以保留登录会话；网页 `onPageBegin` 会废弃旧请求代次，`onPageEnd` 再同步导航和认证状态。

页面层写入 `PageLifecycle` 诊断行：`about-to-appear`、`about-to-disappear`、`page-show`、`page-hide`、`root-tabs-appear`、`root-tabs-disappear`、`root-tab-click`、`root-tab-request`、`web-page-begin` 和 `web-page-end`。日志只包含事件序号、相对耗时、活动根 Tab、根页可见性和二级层级摘要，不包含 URL、账号、Cookie、请求体或响应正文。验证时检查：冷启动出现 `about-to-appear → page-show → root-tabs-appear`；根 Tab 点击只产生目标 Tab 事件且 `Index/Store` 实例不重复；进入详情/图板/会话/设置后 `rootVisible=false`，返回后恢复原 `activeTab` 和滚动位置；`about-to-disappear` 后不再出现旧桥接回调或旧网络结果。设备日志中的 `sequence` 应严格递增，`sincePreviousMs` 用于定位异常长间隔；HAP 构建和静态脚本只能证明源码/编译，不等同于真机页面验收。

导出日志后可运行 `node scripts/analyze-page-lifecycle.cjs <runtime-log>`。重点指标是：`sequence-contiguous=PASS`、`startup-order=PASS`、`activeTabs` 包含实际访问的根 Tab、`rootHiddenEvents` 在进入二级页时大于 0，以及 `maxSincePreviousMs` 是否对应可解释的后台或网络等待；脚本没有找到事件时只能记为“未验证”，不能用旧日志推断新 HAP 已生效。

## 网络请求与并发生命周期

`common_network` 使用共享 RCP `Session` 和 `RequestScheduler`。调度器最多同时执行 8 个任务，网络协调器最多保留 12 个在途请求；首页/搜索首屏为 HIGH，普通读取和分页为 NORMAL，详情预取和标题补充为 LOW。每个请求携带受限的 ID、文档 epoch 和完整当前页面，凭据读取、派发、响应、Set-Cookie 同步和业务回调前都会重新验证请求归属。

页面切换、返回、后台、登出或页面销毁通过请求级取消和 `invalidate()` 废弃当前代次。GET 只对确认的 429/5xx 和既有瞬态传输错误最多重试 2 次；POST 写请求不自动重放。迟到响应返回 `cancelled` 或被业务上下文丢弃，不更新 Store。`NetworkTrace: lifecycle=` 日志记录请求开始、结束、取消、失效和拒绝，以及在途数量，不包含 URL、Cookie、账号或响应正文。

验证网络层时运行 `scripts/check-native-network.cjs` 和 `scripts/analyze-network-runtime.cjs <runtime-log>`：检查静态约束、GET 重试与 POST 抑制、`pending <= 12`、调度 `active <= 8`、页面离开后的 `invalidate` 归零和主要请求的完成覆盖。静态检查与 HAP 构建不能证明真机网络、Pinterest 服务或签名安装行为。

## 缓存与数据一致性

共享缓存能力位于 `common_foundation`：`ApiCache` 先读内存 LRU，再读磁盘 JSON；磁盘写入先落到同目录临时文件，
关闭文件后通过原子重命名提交，避免进程中断留下可解析但不完整的快照。`CacheKey` 对参数对象递归排序后哈希，
并把当前账号范围纳入键前缀；缓存 TTL 由资源类型集中定义。`readThrough` 只用于 Promise 型读取，事件驱动的
ArkWeb 首页继续由 `Index` 在桥接响应通过会话、页面、分类和业务校验后显式写入，避免重复请求。

缓存只负责展示保留：恢复的首页快照、搜索/收件箱/资料快照和详情快照不能恢复可操作控件；首页必须等当前会话快照
通过校验后才将 `homeActionsReady` 置为 true。会话失效或登出清理内存和持久化缓存，账号切换只清理当前展示内存，
保留按账号隔离的磁盘分区。`HomeCache:` 记录恢复、当前会话替换、操作门禁、失败保留和清理数量，`CacheAudit:` 记录
LRU 淘汰、磁盘原子提交耗时和 TTL；运行日志不记录缓存键、账号、URL 或缓存正文。使用
`node scripts/check-cache-consistency.cjs` 检查原子提交、稳定键、读写顺序、在途去重、操作门禁和登出清理，设备日志
再按 `common_foundation/CACHE_MIGRATION.md` 的指标验证冷启动、TTL、离线保留和账号隔离。

首页另有离线只读预览：在线确认并提交首页快照后，仅持久化非明文账号分区指纹、已校验首页路由和写入时间；标记与快照一起写入 `context.cacheDir/api_cache`，进程内 `AppStorage` 仅作快速路径。网络失败且快照仍在
首页 TTL 内时进入预览，展示快照但保持 `authStatus` 非 authenticated、`homeActionsReady=false`；分类切换、分页、刷新、
收藏、下载和分享均记录 `reason=offline-preview` 并阻止。预览不等同于登录，会话重新确认后退出；过期或校验失败不恢复预览。

## 登录和接口

可见 Web 只用于登录，登录后保留同一隐藏 ArkWeb 会话。现有业务接口脚本经 `useNativeTransport` 注入适配后，资源和 GraphQL 请求由 `common_network` 的 Remote Communication Kit（RCP）执行；网站自身的 fetch/XHR、认证探测和首页标题 HTML 读取仍在 Web 内执行。业务参数构造、原始 JSON 映射和业务成功校验沿用所属特性的既有脚本，没有将这些校验改写为通用网络成功判断。

这些资源不是 Pinterest 官方开放 API；项目没有原生 OAuth 或独立令牌生命周期。凭据的持久归属仍是 ArkWeb；原生每次请求由 `common_session` 按目标 URL 读取 Cookie，仅在原生内存中用于该次请求。Cookie、Authorization 和 CSRF 请求头不经 JS Proxy 传输，CSRF 在原生从当前 Cookie 重建。原生响应的 Set-Cookie 按完整属性写回 WebCookieManager，不返回给 JS，不另建 Cookie 缓存。

只接受当前登录会话、文档 epoch、完整页面地址和已登记的 Pinterest HTTPS 接口路径；取消、导航、明确会话失效和页面销毁会废弃旧请求。禁止自动重定向，避免向未知地址发送凭据；同源登录重定向交给现有登录证据观察器，普通 401/403 或网络失败不推断登出。读取与写入均不自动重试，不以传输成功替代各业务响应校验。原生失败不回退 Web。

`common_network/src/main/ets/PinWebNetworkScript.ets` 中 `PIN_NATIVE_NETWORK_ENABLED=true` 为当前默认。显式改为 false 并重新构建可手动恢复当前业务脚本的 Web fetch 传输，不改变业务接口开关或启用未接入操作。详细范围和设备验收见 [`NATIVE_NETWORK_NOTES.md`](NATIVE_NETWORK_NOTES.md)。

## 产品协调与后续扩展

`entry/src/main/ets/app/` 持有底栏后台同步脚本、JS Proxy 和导航历史。分享、分享面板及帖子菜单注入脚本已移入帖子模块，面板消息合同也在帖子模块中。

首页、搜索、收件箱、资料、图板、帖子各自新增 `stores/PinWeb*Store.ets`，通过 `@Observed` 管理 139 个已迁移字段，包括内容、加载/错误、分页操作代次、缓存及滚动位置。产品层以 `@State` 持有各 Store，并直接访问 `this.profileStore.profileCache` 等属性。不能在 ArkUI struct 中使用兼容 getter/setter：本项目 Hvigor 编译产物曾丢弃这些访问器，导致运行时缓存为 undefined。导航相关字段在普通 Store 类中使用访问器通知产品层，回调于 appear 绑定、disappear 解除。

`Index.ets` 仍负责原有跨业务编排、结果移交和导航副作用。现有接口请求构造和数据映射仍在特性的脚本中，本轮没有额外创建只有名字的 Repository，也没有宣称完成全部业务逻辑的纯 ArkTS 重写。

四个根页内容、分页与滚动保留，根页不播放转场；二级页保留现有转场、HDS 标题栏和安全区合同。

文字发送、爱心、屏蔽、举报、删除更新、通知设置、粉丝/关注、资料编辑、发布及设置各入口，以所属业务说明和当前实现确认接入范围。未来按需补充内容与接口，未接入操作保持现有无操作规则；架构包含某功能不代表线上能力已实现。

### Index 协调职责首轮收敛（2026-10-08）

Index 继续持有七个 Store、同一 Web 控制器和四个真实 TabContent。文档启动脚本通过 entry/app/PinWebScriptRegistry.ets 按原有 24 条顺序组合，Index 每个实例只构造一次脚本列表；开关、scriptRules、原生传输适配与 Proxy 名称不变。

feature_search/controllers/PinWebSearchController.ets 接管搜索快照验收、结果保留/合并、缓存、输入/提交、分类/主题/结果意图、筛选、灵感操作和分页读取。控制器使用 Index 持有的同一 PinWebSearchStore；PinWebSearchPorts 由特性导出，产品层实现真实文档准备、导航、面板显示和反馈回调。控制器不引用 entry 或其他特性，不持有 WebviewController，也不复制产品状态。产品返回路径及展示路由/真实文档门禁继续由 Index 负责。

搜索延后任务归控制器自己的 PinWebTaskRegistry。切页、后台、明确会话清理及 Index 销毁会废弃输入/筛选/读取代次并取消定时器；等待 Promise 会被收敛，不在恢复后继续派发旧筛选读取。被取消的筛选加载结束并提供真实取消状态，避免永久加载。输入就绪、结果操作就绪及缓存展示的区别保持。

entry/app/PinWebSystemActions.ets 适配剪贴板、外部链接、日志导出、图片选择/JPEG 编码和下载目录/回调；业务门禁、响应确认及统一分享面板继续由原调用方负责。Index 销毁后，尚未完成的下载目录选择不能再启动下载或显示旧页面反馈。该类没有新增业务分享入口，现有原生分享面板合同不变。

尚未迁移的首页、资料、收件箱、图板、帖子及产品会话/导航协调仍在原位置。本轮验证和后续阶段见 [首轮验收记录](reviews/INDEX_COORDINATION_REFACTOR_20261008.md) 与 [优化方案](INDEX_COORDINATION_REFACTOR_PLAN.md)。

## 路径和验证

`scripts/module-source-map.json` 记录迁移前后源码路径。现有回归通过 `scripts/source-files.cjs` 解析历史路径，实际读取迁移后的唯一源码；备份及恢复脚本没有修改。带哈希校验的历史恢复工具可能拒绝覆盖本轮结构，不能强制执行。

使用 DevEco Studio 的 OHPM 更新本地模块依赖后，通过原有 Hvigor 命令构建 entry HAP。静态回归、HAP 构建、签名安装、真机 UI 和 Pinterest 线上验证分别报告；构建不证明线上请求和设备交互正常。

`scripts/check-compiled-store-access.cjs` 必须在 HAP 编译后运行，读取真实 Hvigor 输出，防止再次出现“源码/模拟检查通过，但 ArkUI 编译后访问器缺失”的问题。旧的独立方法测试使用 `readLegacySourceFileSync` 将直接 Store 路径投影到其平面模拟宿主；新的 Store 与编译产物检查始终读取原始源码和真实编译输出。

账号管理新增 feature_settings/stores/PinWebSettingsStore.ets，负责设置内层级、读取与保存状态、错误和请求 token；Index 只负责会话请求编排。详细合同见 [账号管理说明](ACCOUNT_SETTINGS_API_NOTES.md)。
