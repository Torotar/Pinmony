# 资料与关注读取

2026-10-07：本人已保存首批 BoardsFeedResource 与 UserResource 并行；仅使用当前认证用户名和匹配资料地址，不猜测账号 ID。UserResource 确认后才映射数量与卡片。创建分段、其他人资料保留原顺序；重置、离页、切换分段和资料失败取消预读取，迟到响应校验代次和页面。

依据用户提供的个人资料.har、关注粉丝.har。使用活动 ArkWeb 会话，业务请求通过 common_network RCP 适配；这些是网站内部资源，不是官方开放 API。

- ApiResource/get/ → /v3/users/settings/：按资料.har读取当前账号编辑资料，响应 username 必须匹配资料页。不再使用旧 UserSettingsResource/get 合同。
- UserFollowingResource/get/：关注用户首批，page_size=50，保留捕获中的 exclude_not_explictly_followed 拼写。
- ApiResource/get/ POST：代理 /v3/users/{运行时用户名}/boards/following/ 只读请求，page_size=12。新增 HAR 已包含非空图板和分页证据；当前仅首批，线上运行尚未验证。
- 粉丝首批使用资料.har 的 GraphQL v3GetUserHandlerQuery，variables.userId 从当前 UserResource 获取；校验 User 全局 ID、followers.connection.edges 与 pageInfo。保存 entityId、头像、用户名、关注状态；hasNextPage=true 保留首批并说明后续分页未接入。

编辑资料完成按钮使用用户提供的编辑个人.har 中确认的 GraphQL EditProfileUpdateMutation，统一提交姓名、姓氏、简介、网站和用户名。保存桥接异步执行，原生端轮询有界结果并阻止重复提交；关闭或会话变化忽略迟到结果。只有 V3EditSettingsHandler 和返回 User 同时通过校验才刷新资料，用户名变更同步后台资料地址。ClientError.error.message 为“用户名已被使用。”时显示提示条并保留草稿；其他失败或超时不推断成功、不自动重放。HAP 构建及静态检查不代表线上保存验证。

头像上传响应已捕获，但 HAR 缺少 multipart 请求体，头像更改仍未启用；移除、屏蔽仍未启用。关注/取消关注已按本轮下述合同接入。没有 DOM 自动回退。举报不接入。返回关闭原生子页，后台资料路由不变。
资料页 Created/Saved 页签由原生 ArkUI 触发资料接口读取，页签切换不再点击网页 DOM；已创建 Pin、已收藏 Pin/图板及资料头部均以资源接口响应为准。隐藏 ArkWeb 仅保留当前会话、接口请求和路由同步。

界面：关注用户/图板复用收件箱的 CapsuleSegmentButtonV2（280vp，最大不超过正文宽度，48vp 容器，关注页正文顶部不额外留白）；编辑资料采用带边框的单行字段和多行关于输入，主题灰色更改按钮。完成位于 HDS MINI 标题栏，保存未接入时禁用。保持单层顶部安全区和正文 Scroller 绑定。

2026-10-04：资料读取增加网站响应 is_partner（企业布局依据）、about、website_url 和运行时身份。个人布局居中，企业布局头像昵称横排，简介更多打开原生 Sheet。资料正文滚过头部后显示紧凑头像昵称；访问用户子页使用 HDS MINI、单层安全区与同一 Scroller。头像跳转只使用响应中的 username/同站资料地址；不根据昵称或照片猜身份。访问栈最多12层，仅运行时存储来源地址、页签、资料快照、滚动位置和面板，返回原来源。帖子作者、评论、图板所属用户、关注用户、收件箱联系人/单人会话头像接入主页导航；群聊头像没有唯一用户目标时仍进入会话。

关注图板首批12条，显示封面、Pin数量及修改时间并可进入图板；后续分页仍未实现。新 HAR 已补充非空与分页证据，以及部分关注操作合同；图板关注提交仍未启用；用户关注/取消关注及粉丝首批已接入。运行时头像字段缺失时不猜用户地址。

访问用户资料承载在 Tabs 上方的独立二级页面，保留来源根页选中项，显示期间收起底栏；后台资料路由同步不得选中我的。我的标题栏不显示搜索框。
资料页关注、联系/消息、分享及编辑按钮统一使用 Normal 按钮与16vp圆角。联系/消息名称和可见性从当前网站资料页的对应动作读取，未接入提交操作仍无反应。

2026-10-07 资料.har 接入：

- 用户主页、关注用户列表和粉丝列表按钮使用 v3FollowUserMethodMutation / v3UnfollowUserMethodMutation。followee 使用当前会话读取的数字 ID，服务端返回的 User 全局 ID 必须等于 btoa('User:' + followee)，explicitlyFollowedByMe 必须与目标状态一致才更新。禁止自关注及当前响应明确屏蔽的用户；提交期间禁用重复点击；网络错误或超时仅提示结果未确认，不自动重放。完整地址、读取代次、原生 panelToken 和登录状态共同隔离迟到结果。
- 用户主页分享调用 PinWebNativeShareApiOpen(page,true)，继续由 SHARE_PANEL_BRIDGE_SCRIPT 与既有原生半模态面板展示。GraphQL v3InviteUserExternalQuery 的运行时 objectId 为主页用户ID，inviteType={invite_category:3,invite_object:3,invite_channel:12}；联系人按 ShareSuggestionsResource 的 suggestion_type=share、hide_group_conversations=false 读取。短链、联系人分别校验，部分失败保留另一部分。
- 这份 HAR 只确认主页复制渠道12，复制成功反馈以系统剪贴板写入完成为准。平台横向列表保留原面板顺序但操作禁用；主页联系人发送、搜索未抓到请求，保持无操作。没有系统 ShareKit 替代面板、DOM 回退、Pin发送参数套用或头像上传字段猜测。
- 保留既有 UserResource、图板/关注图板、Pin 内容和会话列表集成。profileSettings GraphQL 与 /v3/users/settings/ 都是资料读取，本轮使用后者，避免重复读取。归档独立列表、UserStoryPinsFeed、图板邀请在当前原生页面没有对应接入入口，不新增界面。
- 静态回归与未签名 HAP 构建用于验证合同和编译，不能证明 Pinterest 线上写入或真机 UI。

2026-10-07：关注图板读取字段修正为 HAR 已确认的 board.images[236x]、board.owner() 与 user.username，移除未捕获的 board.images、board.owner.username；封面解析跳过空图片项。非空列表、封面、数量与图板目标地址纳入 check-profile-har-contracts.cjs。线上加载仍需设备验证。

2026-10-07 主页分享.har：主页平台渠道继续使用 v3InviteUserExternalQuery（invite_object=3），联系人列表使用 ShareSuggestionsResource；联系人搜索使用 ShareSuggestionsTypeaheadResource；发送主页使用 ConversationsResource/create，options={user_ids:[联系人ID],user:当前主页用户ID}，响应需确认 success/code=0、last_message.id 和 users 包含目标联系人。主页分享面板现已启用平台入口、联系人搜索和发送，保持同一 Pin 分享半模态面板。
