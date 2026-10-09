# 收件箱更新接口

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](docs/NATIVE_NETWORK_NOTES.md)。


收件箱根页面当前分段支持顶部下拉刷新，复用 `PinWebInboxApiRefresh` 重新读取更新、会话和推荐联系人；保留现有分段及原生容器，不进入网页。刷新中禁止重复手势和分段切换，成功、失败、离页或 20 秒超时结束动画；消息分段等待联系人读取结束。聊天等原生子页不使用根页下拉手势。

更新分段默认通过当前 ArkWeb 会话同源请求 `/resource/ApiResource/get/`，options.url 为 `/v3/news_hub/feed/`。请求字段依据用户提供的抓包样本；标题使用 text_mapping 还原，图标使用 header_icon_image_url 或 header_icon_object_ids 对应对象。分页使用 options.bookmarks；空结果、加载、错误分别显示。不会把抓包中的账号信息或条目作为运行时数据。

这是 Pinterest 网页内部接口，不是官方 API 或 OAuth。收件箱根页的更新、会话列表、联系人、分段状态和入口全部来自当前会话的同源资源接口；隐藏 ArkWeb 只保留登录 Cookie、CSRF 和请求上下文，不读取业务 DOM，也不点击网页控件。条目和联系人入口由接口返回的真实 ID 绑定到原生流程，无法确认接口对象时保持不可用，不猜测链接。原生分段切换只重置并读取对应接口，接口失败不回退 DOM。

收件箱接口开关默认启用；关闭后不再提供网页 DOM 回退，页面显示接口不可用状态，便于定位会话或服务端错误。底部导航没有修改。回退快照：`backups/inbox-news-api-before-20260930-230659`。运行其中 restore.ps1 默认只检查，确认后加 -Apply 恢复；后续文件修改会触发拒绝覆盖。

验证：scripts/check-inbox-api.cjs 使用合成响应检查请求、占位标题、分页去重、空态、非法响应、过期请求与开关，不能证明实时服务可用。HAP 编译打包及 Pinterest 实机网络、按钮点击、视觉验收分别报告。

## 推荐联系人接口（2026-10-01）

依据“帖子页接口”对话 01a0f206-2f58-70a3-a981-2ee24603a50e 中用户标为收件箱联系人列表的抓包，接入 `ShareSuggestionsResource/get/`，options 为 `{field_set_key:"default",hide_group_conversations:true}`。响应 endpoint 为 `v3_user_contacts_suggestion`，数组位于 resource_response.data，条目类型为 user_share_suggestion。这是推荐联系人，不是会话列表；不会把 ConversationsResource/create/ 的发送 Pin 操作用作联系人点击。

当前 ArkWeb 同源请求使用实际收件箱根路径 source_url，credentials=same-origin。抓包原请求的 source_url 为 Pin 详情路径，因此收件箱路径下的实时接受情况仍待实机联网核验。仅显示返回的 ID、full_name/username、头像；“打个招呼吧”等提示来自唯一匹配的当前网页联系人行，否则显示接口用户名。姓名、说明保持左对齐。唯一对应网页行存在时转发点击，未匹配时仅展示数据，不猜聊天地址。

联系人有独立加载、空结果、错误与重试状态；错误不回退 DOM 联系人列表。`PIN_INBOX_CONTACTS_API_ENABLED=false` 可手动恢复旧读取方式，与更新接口开关互相独立。离开收件箱根页面会废弃旧请求。第一页推荐列表已接入；联系人分页未接入。

本次接入前快照为 `backups/inbox-contacts-api-before-20261001-094751`。其 restore.ps1 默认检查，-Apply 恢复；校验拒绝覆盖后续改动。恢复到本次修改前仍保留之前的更新流 API，不应强制使用更早的更新接口备份覆盖当前代码。

回归脚本为 scripts/check-inbox-contacts-api.cjs；使用合成数据，不包含抓包账号资料。编译、打包、实机和实时服务验收分别确认。

## 根页面接口读取修正（2026-10-01）
已确认的收件箱根路由在默认接口模式下不再要求网页先出现两个标签、联系人标题或空态标题。缺少网页标签时使用原生分段选择；标签名称是原生导航文案，列表仍只来自实际响应。控件缺失不会创建虚构点击入口；登录弹窗和子路由仍退出覆盖层。联系人加载、失败和成功空结果都能直接发布快照，不再被 DOM 空态判断转成识别错误。回归覆盖无任何网页标签的完整桥接路径。修改前备份：backups/inbox-root-api-before-20261001-113731。

## 有内容列表布局（2026-10-01）
消息分段按顶部新消息入口、消息标题与列表、联系人标题与列表排列；Scroll 显式 TopStart，文字 Start。消息时间、摘要、头像和标题全部来自 ConversationsResource/get 响应，不读取网页行。更新条目保留接口响应 unread 与 last_updated_at，未读/已读分组由真实布尔值生成，缺少 unread 时不猜分组；时间按响应时间换算。三点入口仅绑定接口返回的真实更新 ID；新消息和联系人入口分别绑定会话/用户 ID，不能确认时保持不可用。回归补充消息标题/摘要/时间分离及更新已读字段；设备视觉与点击仍需实机。修改前快照：backups/inbox-list-layout-before-20261001-200651。

## 消息原生子流程（2026-10-01）
依据收件.har，默认 PIN_INBOX_CONVERSATIONS_API_ENABLED=true，列表使用 ConversationsResource/get/；聊天用 ApiResource 的 /v3/conversations/{id}/ 读取成员，再用 ConversationMessagesResource/get/ 读取消息。当前账号 ID 只在内存中用于区分发送方；消息正文、图片、时间取当前接口，用户样本不作为运行数据。聊天首屏定位至最新消息，可加载更早消息。原生新消息读取推荐联系人与搜索结果，选中后 Next 以 user_ids/emails 创建会话，并校验业务 endpoint 与会话 ID 后读取聊天。操作使用当前 ArkWeb 同源会话及临时 CSRF，不保存凭据。
返回：设置→聊天→新消息选择→收件箱；直接从已有会话或联系人进入时，聊天返回收件箱。系统返回和界面返回均走同一原生栈。网页根路由保留在底层，不通过网页跳转实现聊天。消息设置保留原有底栏；聊天及选择页不显示底栏，底栏自身样式与布局未改。
文字发送、消息爱心/删除、屏蔽联系人、删除更新、通知设置读取及聊天 Pin 的分享/收藏已按各自 HAR 或已确认的同源合同接入；未确认的举报、通知设置修改及图片下方反馈表情仍无操作。所有写操作均等待服务端业务响应后更新状态，不自动重放，失败保留当前内容并提供实际重试提示。原生界面包含截图给出的聊天欢迎提示，不将其作为接口返回字段。
开关 false 只用于诊断接口不可用状态，不恢复原消息列表或入口转发；更新、推荐联系人和会话列表开关保持独立；失败不自动回 DOM 会话数据。独立撤回备份：backups/inbox-chat-before-20261001-202618，restore.ps1 默认 dry run，-Apply 恢复，后续改动会拒绝覆盖。
check-inbox-conversations.cjs 检查会话/成员/消息映射、方向、图片、搜索乱序、创建确认、重复提交、逐级返回、取消后的迟到响应、菜单身份及开关。HAP 与实机网络/视觉分别验证。

## 四页切换保留（2026-10-02）
PinWebInboxCache 在本次应用运行期间按根地址与消息/更新分段保留原生内容及滚动位置，不存储认证信息。切回后先显示缓存并同步分段；操作仅在新会话快照确认后启用，联系人仍同步中时保留的旧联系人不可操作。更新、推荐联系人、会话列表新增 pause：取消在途读取，保留完成列表，更新游标可以继续分页；聊天/新消息子流程不缓存，离页废弃其状态。认证路由与主动刷新仍清理相关状态；完整文档重载重新请求。失败有重试，成功空列表覆盖旧数据。开关、数据源优先级、禁止自动 DOM 回退和原 guard 快照未改变；新改动会触发旧恢复脚本的后续修改保护。回归 check-root-page-retention.cjs 及现有 inbox 各检查，在线和设备验收尚未完成。

## 读取失败与分段切换（2026-10-02）
网站内部资源成功响应的 code 和 endpoint_name 允许省略；存在时仍严格校验（非零业务码、明确不匹配的 endpoint、非数组数据都失败），HTTP 状态和 resource_response.status 必须成功。会话/更新/联系人错误分别显示 HTTP、非 JSON、业务失败、数据结构和超时原因，不输出原始响应或账号凭据。
分段控制就绪（inboxSectionReady）独立于列表操作就绪（inboxActionsReady）：当前会话收到有效快照后，即使列表加载或失败也可切换分段；仅恢复旧缓存、尚未收到当前桥接快照时仍禁止操作。资料解析明确排除 inbox/messages/updates/notifications，避免将更新根地址视作用户资料。默认数据源、缓存策略、功能开关和回退规则均不变。
本次修改前快照：backups/inbox-read-validation-before-20261002-100140。新回归 check-inbox-read-failure.cjs 覆盖失败后分段切换、未就绪缓存禁用、根路由隔离；会话回归增加成功响应缺少可选字段、明确非零业务码、HTTP 403 与非 JSON。在线失败原因需要设备返回的新详细错误确认。

## 会话 HTTP 403 请求上下文（2026-10-02）
会话资源补齐 X-Pinterest-AppState=active、当前路径 X-Pinterest-Source-Url，以及与更新/联系人读取一致的 X-Pinterest-Pws-Handler=www/index.js。继续使用活动 WebView 的 same-origin 凭据，不复制 Cookie、不自动重放写操作。此修正针对请求头差异，不能证明服务器拒绝原因或线上恢复；如仍返回 403，需要当前会话实际成功请求的头部核对。修改前备份：backups/inbox-request-context-before-20261002。

## 更新菜单半模态（2026-10-02）
更新行更多入口使用三个独立圆点，40vp 点击区域，避免字体省略号在按钮内部裁切。更新菜单改用 ArkUI bindSheet，height=SheetSize.FIT_CONTENT，系统遮罩及拖拽条；选项为左对齐无填充菜单行，关闭采用中性色按钮。遮罩、下滑与关闭均退回当前更新列表。删除更新及通知设置仍未接入，不改变操作可用性。修改前备份：backups/inbox-menu-sheet-before-20261002；设备深浅色、大字体及手势验收尚需确认。

## 聊天控件与官方标题栏（2026-10-02）
聊天、选人和设置采用 ArkUI Navigation 的官方 Mini 标题栏、返回与菜单；更新 Sheet 使用 showClose=true 的系统关闭入口。图片旁分享/收藏入口复用既有帖子同源资源与原生面板，仅当前聊天快照确有此 Pin 时允许打开，服务上下文限制收件箱根路径且保留路由/会话检查。接收图片下方表情反馈及输入框爱心保持无写入，表情点击无操作；爱心使用现有图标与中性色圆按钮。修改前备份：backups/inbox-chat-controls-before-20261002。此资源复用新增聊天来源，实机联网的分享、收藏及标题栏布局仍需验收。

## 聊天分享与标题栏修正（2026-10-02）
聊天分享完成 Pin 校验后改为与帖子共用 buildShareSheet、shareSnapshot、联系人搜索和分享操作链；不再呈现首页自定义菜单。当前来源仍绑定聊天消息 Pin 与收件箱地址。标题栏实际挂载 HdsNavigation 路由栈及 HdsNavDestination，titleBar 配置官方标题、返回、菜单，修复上次移除标题行却未挂载容器的问题。空心收藏 SVG 移除 fillColor。更新 Sheet 增加独立空标题区域，使系统关闭按钮位于内容上方。备份：backups/inbox-chat-layout-before-20261002；设备布局与线上分享仍需确认。

## 两份聊天 HAR 与文字发送（2026-10-04）
已分析聊天对话.har与帖子和聊天信息查看.har，不保存抓包凭据、账号或原始数据。前者确认 ConversationMessagesResource/create/，options 为 conversation_id、text、field_set_key=[default_with_reactions]，成功 endpoint=v3_add_conversation_message，返回消息对象。新增 send 操作仅当前聊天与会话有效且未加载/发送时提交一次，正文上限2000字符；校验业务成功、消息ID、type、原正文及当前发送者后追加并去重，成功后清空输入并滚动最新消息。失败保留草稿，先重新读取会话确认结果，不自动重发。继续使用 common_network 注入适配，原生凭据不经 Proxy。
同一HAR还确认 ApiResource/create/ 的 /v3/conversations/messages/{message_id}/、reaction_text=❤️、v3_post_reaction_message；ApiResource/delete/ 同地址为 v3_delete_conversation_message。这是消息爱心反应及删除消息，不是输入框发送爱心消息；保持此前图片反馈无操作约定，不接入这两项UI操作。未发现屏蔽和举报合同。第二份确认聊天元信息、消息与列表读取，并包含帖子读取/收藏选择、通知流、通知订阅及埋点资源；不把通知角标清理当作删除更新，也不把埋点作为聊天写入。
备份：backups/chat-send-before-20261004。check-inbox-send.cjs 使用合成数据覆盖合同、重复提交、无乐观成功、身份不符与离页迟到结果。HAP未签名构建通过；未进行真机发送或线上确认。

## 截图对应消息操作（2026-10-04）
依据两份用户HAR及七幅截图，输入框爱心发送文字❤️，单独爱心用图标展示；长按未删除消息或点击图片反馈打开内容自适应Sheet，显示六种反应、Pin分享/收藏和本人消息删除。反应按 ApiResource/create/、reaction_text 提交；删除按 ApiResource/delete/，需原生确认弹窗。仅允许当前聊天快照中的消息ID，重复操作禁止，返回endpoint与消息ID校验后重新读取消息；删除返回正文必须确认此消息已被删除。读取reactions中用户ID到表情的映射，只向UI传表情值；deleted_by/服务端删除正文映射删除占位。消息列表摘要继续来自服务端正文。
更新菜单仅当接口对象能确认type=pin及有效ID时提供关闭此Pin图的更新，用 /v3/settings/notifications/objects/、object_ids_to_unsubscribe，并确认 v3_update_object_subscriptions_for_notifications 返回该ID=false后呈现已关闭说明。删除更新和查看通知设置仍无操作；截图不作为未知请求合同。消息写入不自动重放。新检查check-inbox-message-actions.cjs覆盖消息归属、重复写入、反应映射、删除和订阅确认；check-inbox-send.cjs继续通过。备份：backups/chat-message-actions-before-20261004。未签名HAP构建与真机联网、UI分开报告。

## 删除更新合同更正（2026-10-04）
此前仅筛查create/delete漏掉update，现确认帖子和聊天信息查看.har有ApiResource/update/，业务URL=/v3/news_hub/hide/batch/，data={news_ids:[当前条目真实ID],should_hide:true}，成功endpoint=v3_hide_batch_by_news_ids且data=null；false为取消隐藏抓包。现已接入删除更新，绑定当前菜单条目与页面，只发一次写请求；业务确认后从接口列表移除并关闭菜单，失败不乐观删除、不自动重放。通知badge/delete不是此操作。check-inbox-hide-news.cjs覆盖参数、重复提交与成功后更新；备份backups/news-hide-before-20261004。

## 通知设置原生读取（2026-10-04）
设置→通知与更新菜单→查看通知设置共用feature_settings通知页面，读取ApiResource/get/、/v3/settings/notifications/，严格校验v3_get_settings_all_notifications与成功数组。分组、条目、说明、渠道摘要及当前布尔值来自服务端；展开只显示渠道状态，修改接口未确认故开关不可修改。请求通过common_network原生适配，页面/登录/Store token保护迟到结果；加载、空、失败和重试分别呈现，不使用截图编造状态。官方HDS MINI标题栏统一安全区及滚动绑定。修改前快照backups/notification-settings-before-20261004；check-notifications.cjs通过，未签名HAP构建通过，未做实机联网验收。

## 聊天发送原生传输修正（2026-10-04）
设备日志确认 ConversationMessagesResource/create 在 dispatch 前被原生白名单拒绝，未到达服务端。现允许该已确认资源的 create 操作，其他未确认操作仍拒绝；不自动重发写请求。check-native-network.cjs 覆盖发送放行和未知操作拒绝，HAP 构建通过；真机发送结果尚需验证。修改前源码保留于 backups/chat-send-native-allow-before-20261004/。

## 消息表情与历史滚动（2026-10-04）
未删除消息下方提供表情入口，六种表情浮层复用已接入 react 操作；长按菜单表情使用独立 Text 与零内边距按钮避免裁切。发送者名称和头像取当前消息 sender。接近历史顶部停止滚动时加载上一页，保留新增内容前的阅读位置，不再显示加载更早消息按钮。HAP 构建与消息操作合成检查通过，手机滚动定位、大字体浮层和线上反应尚需验收。修改前界面保留 backups/chat-reactions-scroll-before-20261004/。

## 屏蔽联系人接口（2026-10-04）
依据 `屏蔽联系人.har`，消息设置中的联系人屏蔽使用当前 ArkWeb 会话的 `POST /resource/ApiResource/update/`，options.url 为 `/v3/users/{user_id}/block/`，并确认 `v3_block_user` 与 `data: null`；取消屏蔽使用同一 URL 的 `POST /resource/ApiResource/delete/`，确认 `v3_unblock_user` 与 `data: null`。HAR 中的账号、Cookie、CSRF 和用户 ID 未写入代码。

设置页使用内容自适应高度的 ArkUI `bindSheet` 半模态面板和系统关闭入口，标题及说明随屏蔽状态变化；只有接口业务确认后才更新按钮状态、关闭面板并显示提示条“已屏蔽…”或“已取消屏蔽…”。请求进行重复提交和当前页面校验，失败显示“屏蔽未确认，请重试”或“取消屏蔽未确认，请重试”。当前 HAR 未提供已有屏蔽状态读取合同，进入设置时只初始化目标联系人，不猜测服务器已有状态。

回滚快照：`backups/inbox-block-settings-before-20261004`。回归脚本：`scripts/check-inbox-block.cjs`；使用合成响应检查参数、业务 endpoint、重复提交和确认后的状态修订。HAP 编译打包已通过，Pinterest 线上请求、真机面板视觉和提示条仍需设备验收。


