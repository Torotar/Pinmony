# 搜索数据源选择与撤回

2026-10-07：快照 inputReady 仅在当前搜索输入与提交方法安装后为真。输入/提交不再等待发现内容，仍校验页面、会话及最新意图；结果操作和分页继续要求 actionsReady。旧快照恢复和新文档准备清除输入就绪。

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](NATIVE_NETWORK_NOTES.md)。


## 当前方案（2026-10-07）

搜索分类/主题导航在发起前登记完整目标地址及读取代次，禁用旧操作会话；根页读取和后续输入准备在 12 秒准备窗口内合并同一目标任务，即使网页导航回调已清除 pending 标记也不再次加载。不同查询地址、切页代次变化、准备超时或失败不复用旧任务；完成后主动刷新仍可重新读取。日志 `RootTabTrace: page-read-joined` 仅表示共用准备，不表示业务完成。

按用户要求，搜索 DOM 数据读取及控件操作已从活动源码移除。默认接口开关保持开启；接口失败、空结果或未支持类型均不回退 DOM。接口依赖当前 ArkWeb 网站会话，经 common_network 原生 RCP 执行，不是 Pinterest 官方开放 API，也没有原生 OAuth。

- 结果及横向分类：保留 BaseSearchResource/get；结果来自 results，分类来自首屏 rankedGuides，分页复用当前请求参数及 bookmark，保留取消与迟到响应防护。
- 输入联想与最近搜索：接入 AdvancedTypeaheadResource/get，参数采用搜索.har 确认的 richResults、limit 8、num_recent_queries 20、pin_scope pins、recent_queries_tags、term 与 autocomplete_request_surface 0。输入防抖 250ms，只采用当前页面及最新输入的成功 data.items；新输入取消旧请求，换页/清理取消在途请求。结果页未编辑时不主动读历史；普通历史删除采用下文 2026-10-07 删除搜索.har 确认的合同，个人历史删除未接入。
- 输入与提交：输入值保存在搜索桥接状态，不读写网页 input，不派发网页 input/change/Enter/submit。提交和联想点击按原生输入值同步后台 /search/pins/?q= 路由，由已有结果接口读取；隐藏 ArkWeb 不显示业务网页。
- 提示词：保留 ApiResource/get 代理 /v3/search/ghost_queries/，正常缺席保持空提示。
- 搜索发现：以本次 HAR 的 SearchTabResource/get 替换旧持久化 GraphQL 查询。首屏 options 为空；slp_search_recommendation 映射主题、文字、四张 image_medium_url 封面及 action.url；slp_immersive_header.objects 的图板 name、image_cover_hd_url 提供轮播数据，不再读取网页轮播 DOM。轮播目的图板交互未接入，继续保持原有无操作合同。
- 发现分页仅在响应返回非结束 bookmark 时派发 bookmarks；重复游标或 -end- 结束。该 HAR 仅捕获一次 SearchTabResource 首屏，分页请求形状和线上行为仍需补充抓包/真机验收。刷新成功替换旧内容，正常空响应清空旧主题；加载与失败保留已有展示，不能启用旧会话操作。
- 筛选列表保留已有 /v3/filters/ 接口响应读取，移除 __PWS_INITIAL_PROPS__ DOM JSON 读取与网页筛选控件匹配/点击。当前原生未接入筛选提交继续无操作，不由本次抓包推断颜色、价格或 AI 筛选写法。
- 灵感选图与推荐结果保留已接入接口，不改布局、根页导航、分享、账号或隐私设置。

## 撤回与开关

PIN_SEARCH_API_ENABLED、PIN_SEARCH_UI_API_ENABLED、PIN_SEARCH_DISCOVERY_API_ENABLED 均默认 true。关闭开关不再恢复 DOM；已有受保护备份与恢复脚本未修改。如用户要求撤回，应先核对对应备份、运行恢复校验，不能绕过哈希检查或覆盖后续改动。

## 验证

运行 check-search-api、check-search-ui-api、check-search-bridge、check-search-discovery-api，以及输入/返回、主题导航、下拉刷新、根页上下文和原生网络相关回归。新检查覆盖防抖、最新输入、重复建议过滤、旧查询/清理后的迟到响应、资源成功校验、发现轮播/主题映射、分页游标、失败保留与空结果。静态检查和 unsigned HAP 不证明签名安装、真机 UI 或 Pinterest 线上行为。

以下为历史增量记录；涉及 DOM 操作、旧 GraphQL 发现页和手动关闭开关恢复 DOM 的描述，已由上述当前方案替代。

## 灵感推荐与类型筛选（2026-10-01）

- 独立开关 `PIN_SEARCH_QUIZ_API_ENABLED` 默认开启。`UserExperienceResource/get/` 请求 placement 1000269、当前搜索词；有效 quiz/related_query_items 才展示推荐模块，无数据隐藏，失败独立重试。
- 选图使用 `BaseSearchResource/get/` 的主题词、scope pins、page_size 25、enable_promoted_pins false。选图列表按 BaseSearchResource 的 bookmark 加载更多，重复游标结束；最多选 10 张，查看结果通过 ApiResource 调用 /v3/batch/related/pins/，client_type 118、所选 pin_ids、prepend_seed_pins false。仅呈现接口结果；返回清理选择，页面变化取消旧请求。推荐结果仅首批，尚未重放未抓到的后续分页。
- 筛选选项仍来自 /v3/filters/；已确认的类型选项直接导航到对应 scope：pins/videos/boards/users/buyable_pins，BaseSearchResource 直接请求和分页。名称来自接口，仅识别已知类型名称或 scope ID；其他筛选保留原操作桥接，不猜测价格、颜色参数。
- 图板和用户结果按各自接口字段映射；无接口内容不回退 DOM。视频 Pin 显示接口时长，当前可见卡片静音自动播放，未出首帧或播放失败保留封面，点击沿用当前详情路径；商品显示真实 Pin 封面。播放生命周期见 [视频说明](VIDEO_PLAYBACK_API_NOTES.md)。
- 手动关闭 PIN_SEARCH_QUIZ_API_ENABLED 并重建重启可单独移除灵感推荐；类型接口读取随 PIN_SEARCH_API_ENABLED 撤回。
- 验证：check-search-quiz-api.cjs、check-search-api.cjs、check-search-bridge.cjs、check-search-ui-api.cjs、check-search-discovery-api.cjs；unsigned HAP 构建。在线会话与手机交互待实机验收。

### 灵感模块失败修正（2026-10-01）

- 灵感请求补齐抓包中的 X-Pinterest-Pws-Handler、X-Pinterest-Source-Url、X-Pinterest-AppState 和 Accept，并增加请求时间戳；不复制 HAR 内的 Cookie 或平台标识。
- 观察当前搜索词及路由对应的 UserExperienceResource fetch/XHR 成功 JSON，复用已有接口数据并取消重复请求。旧路由、已关闭模块与迟到失败不得覆盖当前状态；正常无模块响应保持隐藏。
- HTTP 状态、超时、非 JSON、非成功状态和解析异常分别提供诊断，不再统称读取失败；失败重试继续调用接口，不回退 DOM。
- 回归包含请求头、网页成功响应接管、迟到 403、非 JSON 和正常缺席。真实设备失败原因仍需在线响应确认；筛选器此次未修改。

### 灵感子页返回与布局（2026-10-01）

- 顶部返回与系统返回均退出当前灵感子流程；进行中的接口请求可被返回取消，旧响应不得重新打开选图页。根 onBackPress 优先处理灵感子流程，随后才处理普通搜索返回。
- 此阶段的独立全屏选图布局已由下文 2026-10-04 半模态布局替代。
- 无真实标题的 Pin 保留图片卡片并隐藏标题行，不显示“标题暂不可用”。已移除内容加载文字，仍保留加载进度与错误重试。
- 回归覆盖忙碌时返回取消与空标题卡片；构建不替代真机返回、滑动、安全区和深浅色验收。

- 返回补充修正：原生 returnFromSearchQuiz 立即退出子页，后台按当前页面取消接口状态；不依赖桥接返回值或旧 session。等待后台确认期间屏蔽迟到子页快照。选图和结果面板按剩余高度布局，背景延伸至系统安全区，内容保留实际上下 inset。回归 scripts/check-search-quiz-return.cjs 验证桥接失败时仍可返回及页面隔离。

### 普通搜索结果返回与首屏补页
- 顶部采用独立的原生返回按钮，置于搜索框上层；结果页显式加载同域 /search/，不依赖网页历史是否包含该入口。带 q 的 /search/ 地址也按结果路由处理。清理旧原生搜索态与历史 pending；系统返回结束输入焦点后执行同一路径。
- 搜索结果 page_size 25；首屏实际结果少于 20 张、发现主题少于 6 组时使用真实下一页游标补足，最多自动补 3 页。请求中、错误、末页或灵感子页不触发补页；仍可按正常滚动继续分页。
- 对照首页全宽全高容器，移除结果瀑布流左右外留白；灵感子页卡片延伸到横向边缘，标题仍保留内边距，保留系统手势安全区。底栏几何保持原样。
- 回归 check-search-result-return.cjs 和 check-search-initial-fill.cjs；在线分页数量、返回与边缘视觉仍需真机验证。

### 搜索底部边缘、标题栏与首屏时序补充
- 按用户最新要求，搜索与灵感子页取消底部手势 inset 及底部内容留白，内容延伸到屏幕底边；不改变状态栏顶部保护，也不改变其他页面的安全区。
- 标题栏改为 Row：44vp 返回按钮、layoutWeight 搜索框、44vp 筛选按钮，各自独立布局，不再用 Stack 对齐两个图标。HDS 自带返回图标保持隐藏，顶部原生返回动作沿用现有返回协调器。
- 普通结果路由也复用当前网页首屏 BaseSearchResource 成功 JSON，可取消重复的原生请求并替换早到空结果；迟到原生空结果不可覆盖网页已成功内容。只将无 bookmarks 的网页请求视为首屏，避免空分页冒充空首屏；支持 fetch Request body 的观察。普通 /search/?q 地址主动请求 pins；特殊筛选仍等待已确认参数。
- apiActive 区分尚未成功读取与成功空结果；输入词尚未提交时显示搜索提示，不显示空结果。此处均为接口读取，不回退 DOM。
- 回归覆盖网页首屏接管、迟到空响应、Request 请求体及分页隔离；真实设备间歇问题是否消失仍需在线验证。

### 四页切换保留（2026-10-02）
按完整搜索地址继续保留发现内容、已提交搜索结果和滚动位置。底栏搜索返回最近确认的结果地址时校验同源与搜索路径；普通搜索入口仍使用网站底栏操作。结果和发现接口 pause 取消在途请求但保留成功结果与游标；筛选、灵感子流程和控件标识仍按原机制失效。完整文档重载会重新请求，加载/失败期间原生保留同一搜索上下文的已读卡片并禁用旧操作，成功空结果覆盖缓存；保留旧结果时重试走当前接口。认证路由清空缓存。默认接口、无自动 DOM 回退、各独立开关与原 guard 快照未改动。回归 check-root-page-retention.cjs 与搜索 API/发现/桥接/返回检查；在线和设备行为需另行确认。

### 搜索分类与灵感半模态（2026-10-04）

- 搜索分类在搜索框下方横向显示真实接口标签和封面；点击使用已校验同源地址与 `term` 导航，仍须当前页面操作就绪。缺少 `rankedGuides` 时不编造标签。
- “优化你的创意”入口为结果瀑布流首个独占一行的 FlowItem（混合结果为 ListItem），关闭按钮使用叉号；入口与图片结果共用 Scroller，随结果一起滑动。
- 点击入口图片通过 `bindSheet` 展示高度 85% 的底部半模态，保留遮罩下的搜索框、分类与结果。使用系统 Sheet 标题栏和关闭按钮：选图标题缩短为“选择灵感（最多10张）”，结果标题为“灵感结果”；正文两列图片，底部固定“查看结果”。没有候选主题标签及“更多创意”按钮。图片和 FlowItem 显式绑定正文单列宽度，按接口长宽比布局、不限制图片比例，使用 Contain 完整呈现缩略图；首次加载动画在正文 Stack 中居中；上滑翻页时保持已有图片，加载动画放在 WaterFlow 的底部 footer，随列表滚动。滚动到底使用真实游标分页，最多选择 10 张。结果仍使用已接入相关 Pin 接口。
- 面板打开时关闭根页下拉刷新；返回立即清理原生选择并保留入口，后台取消在途请求，迟到子流程快照继续屏蔽。半模态内容保留实际底部手势 inset；此前灵感全屏和取消其底部 inset 的描述不再适用。根页底栏几何未修改。
- 验证覆盖分类映射、分页保留、路由隔离、同源点击门控、灵感选择与返回、半模态绑定和滚动内容归属。静态检查与 unsigned HAP 不等于真机滑动、安全区、深浅色或线上接口验收。

### 2026-10-07 搜索原生准入修复

运行日志显示 SearchTabResource/get 和 AdvancedTypeaheadResource/get 被原生资源允许列表拒绝；现已补齐两个资源，限定 GET get 且请求体为空。登录状态、完整页面地址、文档 epoch、外域和重复请求校验保持原规则；POST get 及 create/update/delete 均拒绝。check-native-network.cjs 新增真实搜索脚本经 useNativeTransport → JS Proxy → acceptsNetworkJob → 原生 RCP 模拟响应的集成回归，覆盖内容映射、禁止网页回退及无效请求不派发。离线模拟不能证明线上成功；需新真机日志确认派发、业务成功及 UI 内容。

2026-10-07 搜索操作修复：原生提交搜索先登记完整目标与准备代次，再加载隐藏搜索文档；不再由 JS 提交改变路由而遗漏原生目标。筛选器接通接口返回的已知内容类型 pins/videos/boards/users/buyable_pins，选项按当前页面校验后生成目标，关闭面板再登记导航；未知筛选禁用，不转发 DOM 控件。当前说明中“所有筛选提交无操作”的记录由此替代。日志中的 ERR_FAILED 具体原因尚未确认，需新真机日志验收，不声称已消除所有加载失败。

2026-10-07 搜索历史删除：根据删除搜索.har 接入 POST ApiResource/delete，options.url=/v3/search/recent/，提交当前历史原始 query 和 vertical=PIN。仅 recent_query 且 vertical=pins 的普通历史可删除；个人历史未确认，保持禁用。防止并发删除，校验 status=success、code=0、endpoint_name=v3_recent_search_delete 后移除确认条目并重新读取历史；失败保留条目，无自动写重放或 DOM 回退。原始查询和操作标识仅保留当前会话，过时代次/页面响应丢弃。替代此前历史删除未接入说明。静态与构建不能证明真机和线上操作成功。

2026-10-07 搜索输入状态修复：输入面板不随键盘失焦自动关闭，提交/建议选择明确收起，取消恢复完整搜索地址中的已提交关键词；正文按已提交地址选择发现/结果，不按输入草稿切换。每次打开输入面板刷新建议，独立显示建议加载和错误，不显示结果错误冒充历史错误。保留原生接口与删除业务校验、禁止写重放和 DOM 回退；新增 SearchInputTrace 脱敏面板打开日志。真机焦点/键盘/结果与历史操作仍需验收。


### 2026-10-08 搜索业务控制器迁移

搜索快照验收、分页合并、缓存保留/恢复、输入提交、筛选读取与分类/主题/结果操作移入 feature_search/controllers/PinWebSearchController.ets。Index 继续持有同一 PinWebSearchStore，并通过 PinWebSearchPorts 提供真实上下文准备、产品导航和面板显示；所有网页 API 脚本、开关、请求合同及无自动 DOM 回退规则保持。搜索返回与灵感立即关闭仍由产品导航处理。

切页、后台、会话清理及销毁会废弃控制器任务；已取消的输入、筛选等待和迟到读取不得再派发或覆盖新状态。筛选取消结束加载并保留手动重试；刷新取消不会用旧失败覆盖新页面。新增 check-search-controller.cjs 测试真实控制器/Store，原生搜索导航与根页操作检查使用真实产品能力绑定。离线回归和 unsigned HAP 不能证明当前 Pinterest 网站会话请求或手机交互正常。
