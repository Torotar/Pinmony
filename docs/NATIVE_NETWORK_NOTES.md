# 原生网络与会话适配

2026-10-07：预连接与业务请求共用同一 RCP Session。NetworkTrace: connection-context 记录 sharedSession、Session generation、preconnect 状态和距预连接启动的时间；不新增连接、重试或绕过 TLS。此诊断不能证明同一 TCP/TLS 连接复用或握手加速。

## 当前实现（2026-10-05）

当前入口 HAP 依赖 `common_network` HAR。该模块通过 Remote Communication Kit 的 `rcp.Session` 执行接口请求，依赖 `common_session` 的 `PinWebSessionCredentials` 获取本次请求所需的运行时凭据。

首页、详情、图板、资料、整理、收件箱更新/联系人/会话、帖子操作、搜索、搜索探索、问答、视频源与轮播的已有 API 脚本在注入时使用 `useNativeTransport` 适配。它只替换应用自己脚本中的直接 fetch 调用，不接管网站的网络流量，不改变这些脚本的业务参数、分页、有效性校验和响应映射。帖子扩展、编辑等通过现有 PostApi.request 发起请求的功能共用已适配传输。

网站自身请求、登录状态探测、首页标题 HTML 读取及下载/原生 AVPlayer 使用原有路径。接口首屏读取初始化资源缓存时不需要额外原生请求；该缓存不代表本次网络请求已成功。

发布新增 FindPinImagesResource 读取，以及严格校验参数的 PinResource/create：仅 scraped 或 uploaded、真实图板 ID、对应图片 URL 或 Base64 及一致的别名字段。普通请求体上限仍为 256 KiB，只有照片/网站 Pin 创建允许不超过 34 MiB 的编码请求体；入口桥接有 36 MiB 上限，图片原文件另限 4 MiB。图片数据仅临时内存使用，不进入日志和持久化存储。发布当前要求原生传输开启，不通过 Web 自动回退或重放。详见 [发布说明](PUBLISH_API_NOTES.md)。

## 共享会话与调度（2026-10-05）

`common_network` 通过 `NetworkManager` 持有应用生命周期内复用的单例 `rcp.Session`。业务请求统一进入 `RequestScheduler`，最多同时执行 8 个任务；最多 12 个请求保留在当前网络协调器中，取消和页面切换仍按请求级 `rcp.Session.cancel(request)` 处理。`EntryAbility.onCreate` 对 `https://www.pinterest.com` 发起一次 `connectOnly` 预连接，失败只静默结束；`onDestroy` 调用 `NetworkManager.destroy()` 关闭共享 Session。应用仍没有独立凭据存储或官方 Pinterest API。

首页和搜索首屏请求使用 HIGH 优先级，包含书签/游标的分页请求使用 NORMAL，详情预取和标题补充使用 LOW。优先级只影响原生传输调度，不改变业务参数、分页游标或展示映射。

## 会话和生命周期

2026-10-08 重绑定修正：同一完整页面被绑定到新 native epoch 时，JS 立即取消旧 epoch 的已发送只读任务，使 Promise 结束而非继续等待 20 秒。只有此路径的 AbortError 标记 pinWebEpochChanged；详情基础读取可在同一当前 Pin 内恢复一次，普通超时/取消仍保持失败或离页结果。已发送写任务不在此绑定步骤中取消或重发，其响应仍遵循原生严格归属校验。证书域名不匹配保留平台证书校验、明确错误提示及手动重试，不能视作普通连接抖动或登录失效。

原生侧逐请求按目标 HTTPS URL 从 WebCookieManager 读取 Cookie，并构建 Cookie、CSRF、Origin、Referer 和当前 Web 的 User-Agent。不会把桌面 HAR 凭据写入代码；不会新建凭据持久化存储。桥接移除 Cookie、Authorization 和 X-CSRFToken 请求头，回传内容不包含 Set-Cookie；业务 JSON 仍进入原有同文档业务映射流程。

Web 适配器等待当前登录证据确认后发送排队请求。每个请求携带唯一 ID、文档 epoch 和完整当前地址。原生侧在读取凭据前、发请求前、接收响应后以及同步响应 Cookie 时验证归属。导航、登出证据和销毁时取消请求；应用销毁才关闭共享 Session。旧文档、旧地址和取消后结果不能重新更新界面或会话。响应 Cookie 使用完整 Set-Cookie 属性写回 ArkWeb，不能按逗号拆分带 Expires 的属性。

自动重定向关闭。已确认的同源登录跳转 URL 交给现有 AuthScript 观察器；非 JSON 的 401/403、网络错误和未知重定向保持实际请求失败，不自动登出。网络成功后仍由每个业务脚本判断服务端业务成功。

账号管理新增 CountriesResource 读取及 UserSettingsResource 的 birthdate、gender、custom_gender、country 以及 opt_in_private_account、exclude_from_search 单字段更新，通过原生 RCP 与当前 ArkWeb 会话执行；写入白名单不包含密码、邮箱或账号停用/删除。合同见 [账号管理接口说明](ACCOUNT_SETTINGS_API_NOTES.md)。

## 限制与错误

2026-10-08 详情读取例外：PinResource、RelatedModulesResource、UnifiedCommentsPreviewResource 的 GET 连接超时为 4 秒、传输超时为 5 秒，最多重试一次。请求进入协调器后超过 12 秒，在各归属校验点停止接受或继续请求；此检查包含排队与凭据读取时间，不是强制中断所有阶段的墙钟定时器。仍属于当前页面且超过期限时回传 timeout，离页或代次失效时回传 cancelled，避免将真实超时误作可自动重发的取消。其他资源与 POST 的既有规则保留。

目标固定为 `https://www.pinterest.com` 的现有 resource/GraphQL 路径，原生不会成为任意 URL 代理。只接受 GET/POST，限制请求体、请求头、桥接消息和响应大小，调度器最多同时执行 8 个任务，当前协调器最多保留 12 个请求。连接超时 10 秒、传输超时 20 秒；业务已有更短超时和 AbortController 继续有效。

请求失败不回退 DOM 或 Web fetch，不自动重放写操作。未接入按钮仍无操作；本次没有实现文字发送、屏蔽、举报、通知设置或其他未来接口。

统一重试只处理 GET：HTTP 429/5xx 和既有瞬态超时、SSL、接收错误最多重试 2 次，等待使用 300ms 基数的指数退避并加入 0-200ms 抖动；POST 写操作不自动重放，重试耗尽的失败以异常结束。重试提示回调执行后会再次校验文档代次、会话和请求归属；如果页面已切换或会话已失效，则跳过下一次请求。主动取消（1007900992）和页面切换不会重试。

首页帖子详情预取与点击基础读取使用同一个共享 Session，并通过请求级取消保留独立生命周期；`requestPinRead` 仅允许已有 auth_web_main_pin 的 PinResource GET，同样逐请求读取 Cookie 并校验认证与业务归属。点击移交只允许原完整页面到指定 Pin 地址的一次文档代次切换（也覆盖 onPageBegin 先于 getUrl 更新的窗口），其他路由、第二次文档切换、返回、后台或账号清理均废弃。普通业务/写请求不使用该例外，继续严格匹配完整地址与 epoch。资源参数与详情读取一致，最多两条预取并发；请求标识 `detail_prefetch_` 将读取标为 LOW 后台预取，GET 重试规则保持不变，但不弹前台重试提示。预取缓存仅保留校验后的展示字段。被点击的在途/即时读取另保留白名单业务字段供当前详情文档首条读取消费，排除 client_context 和未知顶层字段；消费或打开流程结束后释放，不持久化响应或凭据。具体有效期与媒体边界见 [详情说明](../DETAIL_API_NOTES.md)。

原始网络异常、URL、请求体、Cookie、CSRF 和响应不会写入日志。通用错误无法独立证明凭据过期，不显示登录成功或写入成功。

原生回传在 Web 中构造标准 `Response`，提供 `Headers`、响应体流、`bodyUsed`、独立 `clone()` 及原请求 URL，兼容现有 fetch 观察器；响应头仅回传 Content-Type、Content-Language、Cache-Control，不包含 Set-Cookie。普通对象模拟 json/text/clone 不满足标准 fetch 合同，会使依赖响应头或响应体的观察器失败。

设置退出新增唯一允许的 `UserSessionResource/delete` POST：固定已捕获的 settings 来源和 handler、disable_auth_failure_redirect=true、空 context。登录 create/get 及其他 session 选项拒绝，POST 不重试。由原生协调器直接校验退出业务成功，成功才清理状态和进入登录页；抓包 client_context 的旧已登录字段不作为退出失败判定。详见 [退出说明](SESSION_LOGOUT_NOTES.md)。Web 文档进入前进后退保留时，桥接废弃传输 epoch、取消并清理所有 pending 请求，恢复后由当前认证绑定新 epoch，完成内容由各特性保留而非重放请求。

运行日志还包含 `ActionTrace` 和 `NetworkTrace`：前者记录原生按钮类别及脱敏参数长度，后者记录资源类别、HTTP 方法、请求体字节数、请求头数量、重试次数、响应状态、耗时、桥接投递和失败阶段。不会记录按钮参数正文、Cookie、账号标识或响应正文。由此可以区分“没有收到点击”“点击已发出但请求失败”“HTTP 已返回但业务映射失败”“响应已返回但页面切换后被丢弃”。

网络协调器另外写入 `NetworkTrace: lifecycle=` 诊断行，事件包括 `start`、`finish`、`cancel`、`invalidate` 和 `reject`。每行只包含请求代次、在途 `pending` 数、已创建请求 `jobs` 数、取消集合数量，以及受限的资源类别、方法、HTTP 状态或错误分类。`invalidate` 行包含清理前的 `pendingBefore`，清理完成后的 `pending=0 jobs=0` 用于确认页面切换、后台或销毁已释放请求；`finish` 用于确认每个请求最终进入成功或错误分类。不会记录请求 URL、请求体、Cookie、账号标识或响应正文。

联网故障诊断仅记录固定请求阶段、SDK 数字错误码、HTTP 状态码、已允许的资源类型及响应是否以 JSON 结构开头；不记录参数、账号标识、响应内容或凭据。收到 HTTP 响应仍不代表业务成功。

## 手动回退

将 `common_network/src/main/ets/PinWebNetworkScript.ets` 的 `PIN_NATIVE_NETWORK_ENABLED` 改为 false，重新构建。适配器恢复应用原有 Web fetch 路径，业务 API 开关及其禁止自动回退规则保持不变。不改受保护历史快照或强制执行旧恢复脚本。

## 验证边界

`scripts/check-native-network.cjs` 使用合成凭据和模拟 RCP，覆盖路径/会话校验、单例 Session、优先级调度、GET 429/5xx 重试、connectOnly 预连接、原生 Cookie/CSRF 构建、Cookie 回写、等待登录、观察器链、取消、迟到响应、取消期间读取凭据、HTTP 403 及首页实际映射。原业务回归继续覆盖接口参数和操作校验；HAP 构建检查 SDK 类型与打包。

设备日志可运行 `node scripts/analyze-network-runtime.cjs <runtime-log>`。重点指标是 `pendingLimit=PASS`（协调器不超过 12 个在途请求）、`schedulerLimit=PASS`（调度器不超过 8 个同时执行）、`invalidateZero=PASS`（每次失效后在途和请求句柄归零）以及 `finish` 是否覆盖主要 `start`。若日志没有对应事件，脚本只报告“未观测”，不能用静态检查代替真机证据。

联网真机仍须验证：网页登录后首屏与分页；搜索 POST；收藏/编辑等已接入写操作只执行一次；快速切换页面与返回；离线/超时；响应 Cookie 更新；明确会话失效；四页滚动、安全区与深浅色。原生请求的 User-Agent、Cookie 可用性和网站接受情况必须以该验收结果为准。仓库未配置签名，不把离线检查或未签名 HAP 称为线上验收完成。

设置推荐新增 UserRecentActivityResource 首屏读取，AI 主题使用现有 ApiResource 路径并校验业务响应与回读。私密账号更新只接受 user_confirm_skip_passcode=false，不开放跳过家长验证。

### 2026-10-07 搜索原生准入修复

运行日志显示 SearchTabResource/get 和 AdvancedTypeaheadResource/get 被原生资源允许列表拒绝；现已补齐两个资源，限定 GET get 且请求体为空。登录状态、完整页面地址、文档 epoch、外域和重复请求校验保持原规则；POST get 及 create/update/delete 均拒绝。check-native-network.cjs 新增真实搜索脚本经 useNativeTransport → JS Proxy → acceptsNetworkJob → 原生 RCP 模拟响应的集成回归，覆盖内容映射、禁止网页回退及无效请求不派发。离线模拟不能证明线上成功；需新真机日志确认派发、业务成功及 UI 内容。

2026-10-08 生命周期优化：后台阻止业务原生新请求，并取消 GET/Resource get（含 POST get）的在途读取与桥接未发送任务；已发送写请求不自动重放，保留当前结果校验。网页自身请求仍不接管。前台仅为当前可见根页或详情恢复必要的读取，保留成功内容；后台废弃根页等待任务，准备等待上限 12 秒。NetworkTrace lifecycle=suspend/resume/deferred 与 BusinessLifecycle 记录脱敏状态；NavigationFailureTrace 记录当前失败的 epoch/目标/准备/前后台，未推断 ERR_FAILED 根因。真机挂起与恢复、线上操作仍需验收。

2026-10-08 主图状态补正：真实加载回调可将 timeout/failed 阶段升级为 loaded，仍校验 Pin、图片地址与呈现代次；迟到的当前图片完成证据不再被后续快照覆盖为未加载。超时本身不代表加载成功，不修改图片源或超时阈值。

2026-10-08 返回准备合并：详情返回根页时先登记同一完整目标的准备任务，根页首次内容需求加入该任务，避免再次加载。后台撤销原生排队及凭据准备中的未发送写请求；已发送图片上传保留当前结果校验，恢复不重新注册或上传。离线回归覆盖返回任务共享、12 秒等待上限、后台读取取消和上传不重放。
