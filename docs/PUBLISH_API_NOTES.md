# 原生发布接口（2026-10-04）

标题栏加号沿用 PinWebPublishSheet 的现有样式、网页提供的分组和标签，不改变 Pin/图板分享面板。选项 ID 必须来自当前资料快照且启用；进入流程时核对资料路由、登录、会话和面板。此前转发 PinWebProfilePublishSelect 点击并设置 WebFlow 的临时实现已移除，所有可见发布界面均使用 ArkUI。

## 三个入口

- 网站：原生链接输入 → FindPinImagesResource/get → 选择 Pin 图（单选、多选、全选、取消全选，未选择时“跳过”关闭）→ 完成 → 收藏至图板 → PinResource/create。成功空候选显示“没有读取到可创建 Pin 的图片”，允许返回改链接；解析失败保留真实错误，可手动再次提交读取。
- 照片：PhotoViewPicker 系统图片选择 → 原生选择/预览 → 收藏至图板 → PinResource/create。一次最多 10 张，单张文件不超过 4 MiB，支持 PNG/JPEG/WebP；不支持的格式或大小显示实际原因并终止该次选择，可重新进入。读取选中 URI，只在内存转换 Base64，以有界分片送入当前脚本；图片内容不写日志、测试夹具或磁盘，不发送网页 input 控件点击。系统选择取消后关闭子流程。
- 图板：原生创建页 → 名称及私密开关 → BoardResource/create → 业务确认后返回并刷新资料。不会自动发布任何图片。

选择/图板列表/创建表单复用 PinWebOrganizePage，发布特化标题及完成/跳过回调；不使用整理的 bulk/move 写接口。子页使用 HDS MINI、安全区、同一 Scroller、主题资源、禁用默认滚动遮罩。Index 在发布页存在时不叠加状态栏 padding，隐藏底栏，返回先处理当前发布层。提交中禁止返回和重复点击；照片系统选择及分片传输期间禁止业务操作。关闭不改变后台资料路由。

## HAR 合同

仅采用用户提供 发布.har 和 zhaop.har 的参数结构与成功响应，不复制其中 Cookie、CSRF、用户 ID、跟踪字段、图片或令牌。

FindPinImagesResource/get 的 options：url（用户输入）、source=pin_create、appendItems=false、followRedirects=true、scrapeMetric=www_url_scrape。成功 endpoint=v3_find_image，data.title、destination_url、items；只呈现 type=pinnable 且 URL/link 为 HTTP(S) 的候选，最多 100 个。不是直接抓取目标网站 DOM。

先用 UserResource/get 的 profile 字段集确认当前用户，响应资料用户名必须匹配，client_context.user.id 必须等于资料用户 ID；不能确认时阻止写入。ID 仅属于本次脚本内存。BoardPickerBoardsResource/get 使用 filter=all、field_set_key=profile_grid_item 和本次用户 ID，读取 all_boards；只允许 access 包含 write 且未存档的图板。抓包没有确认发布图板分页合同，本轮只使用已返回列表，不伪造分页、名称建议或分区入口。

BoardResource/create 的 options 为 name 和 privacy=public/secret。仅在 status=success、code=0、endpoint=v3_create_board，且返回图板 ID、名称、隐私及 owner.id 全部匹配后确认创建。发布中创建图板成功后用返回图板继续发布；若后一步失败，不重复创建该图板。

PinResource/create 共同字段为 boardId/board_id、description、guid=''、imageBase64/image_base64、imageUrl/image_url、link、method。网站使用 method=scraped 和候选图片/link，Base64 为空；照片使用 method=uploaded 和 data:image/...;base64,...，URL/link 为空。别名字段一致，不猜测独立上传端点。

路由请求上下文：FindPinImagesResource 的 handler=www/pin-builder.js，source 为当前资料；PinResource 和 BoardPicker 的 handler=www/pin/create/[method].js，source=/pin/create/pinbuilder/ 或 /pin/create/uploaded/；创建图板 handler=www/board/create.js、source=/board/create/。X-App-Version 从当前文档初始数据读取，可用时才提交，不能使用 HAR 固定版本。凭据由 common_network/common_session 原生读取并同步 ArkWeb。

每张 Pin 仅在 status=success、code=0、endpoint=v3_create_pin_handler、有效 Pin ID/type、目标图板、当前 pinner、is_repin=false 及图片数据确认后计数。多选逐张提交，成功条目移除待提交数据；中途网站明确拒绝时保留剩余项目，允许用户再次明确提交；网络、超时、响应结构或业务成功字段不明时标记 uncertain，禁止再次写入，显示已确认数量并要求关闭刷新核对。HTTP 200 本身不是完成证据。没有写请求自动重放或接口失败 DOM 回退。

## 生命周期与检查

发布状态归 feature_profile Store，接口脚本绑定唯一 token、完整后台页面地址、资料地址；关闭、离页、登录失效废弃 token 并取消请求。照片选择完成和分片发送前后检查同一 token/page；旧回调不进入新流程。已确认写入或结果未知时关闭流程清除资料缓存并回读，完成文案只基于已确认数量。

已验证：check-publish-api.cjs（网站/照片/图板、请求合同、身份、候选/空态、只读权限、重复提交、部分成功、明确拒绝、未知响应、取消及迟到结果），check-publish-network.cjs（创建白名单、体积、别名、未知字段和会话），相关资料/整理/网络/认证/返回/架构离线回归。HAP 采用 API 24 SDK 编译为未签名包。

未验证：签名安装、真机图片 URI/编码/大请求桥接、Pinterest 当前服务接受情况、系统照片选择、首屏/滚动安全区、四个根页点击/滑动、嵌套返回和深浅色。因此三个流程已实现不等于已在线发布验收。

手动撤回应将 selectProfilePublish 保持无操作并重建；不恢复旧 DOM 点击、profileWebFlow 或可见业务网页。不修改 backups 中任何受保护快照、清单或恢复脚本。
