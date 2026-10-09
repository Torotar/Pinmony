# Pin 图片放大与选区相关搜索

## 当前范围（2026-10-03）

这是当前 ArkWeb 登录会话中的 Pinterest 网站内部资源，不是官方开放 API。来源为用户提供的“帖子pin放大，相关搜索.har”；没有复制抓包 Cookie、CSRF、账号 ID 或跟踪字段。

- 点击详情图片进入 ArkUI 放大层；支持捏合缩放、放大后拖动、点击图片隐藏/恢复操作栏，关闭返回当前详情。轮播图片可点击放大当前页。
- 操作栏只有关闭、分享、下载和收藏；按用户要求不显示三点菜单、“在应用中打开”或“举报 Pin 图”。分享沿用原生分享流程，下载沿用已接入的图片地址解析与系统文件保存选择器，不按点击宣称下载成功。
- 未收藏时打开现有收藏图板面板；已收藏时本次收藏使用已确认的收藏副本 ID 撤销。没有本次副本时，复用编辑读取合同核验当前账号拥有此 Pin 后发送一次删除。失败/不确定不更新收藏状态，不自动重放。关闭/换 Pin/会话失效阻止尚未发送的操作。
- 单图片详情右下角首次显示“搜索图片＋图标”，2.5 秒后收成图标；视频不显示图片搜索入口。
- 搜索原生层显示归一化选区、区域外遮罩，支持移动和四角缩放。以实际 Contain 图片矩形换算坐标，限制图片边界和最小选区；280ms 防抖后更新结果。
- 结果使用 ArkUI bindSheet 半模态面板，初始 40%，可上滑至 LARGE，并收回选区；双列图片结果支持底部自动分页，点击结果进入原生详情。

## 请求合同

`GET /resource/VisualSearchFlashlightUnifiedResource/get/` 经 common_network 的 RCP 适配；handler 为 `www/pin/[id]/visual-search.js`。source_url 指向当前 Pin 的 visual-search 子路由，仅作请求参数，不露出业务网页。

options 包括运行时 pin_id、归一化 crop{x,y,w,h}、crop_source（首次 5，调整 6）、is_shopping:false、entry_source:flashlight、entrypoint（首次 closeup_cta，后续 unknown）。分页通过上一页 resource_response.bookmark 放入 options.bookmarks。首屏不带游标。

响应必须同时符合 status:success、code:0、endpoint_name:v3_unified_flashlight_handler 和 data.results 数组。仅映射 type:pin；抓包里的购物 story 模块不当作普通 Pin。按 Pin ID 去重，最多保留 400 条；游标为空、-end-、重复或达到上限时结束分页。搜索失败和空结果分别展示，分页失败保留已有结果。

没有单独图片放大接口；详情 images.orig 用作高清图片，不修改图片 CDN 路径。没有加入“物体自动选区”，也没有接入购物模块。

## 生命周期与开关

PinWebPinStore 保存结果与原生请求代次；脚本保存当前完整页面、Pin、选区及 AbortController。新选区中止上一请求；关闭、切换 Pin 和会话失效废弃原生回调。读取有 15 秒请求超时及 18 秒原生轮询界限，无自动 DOM 或网页请求回退。

`PIN_VISUAL_SEARCH_API_ENABLED` 位于 feature_pin/services/PinWebVisualSearchApiScript.ets。手动关闭只停用相关搜索入口，不更改其他接口和受保护备份。

同时修复原生传输已有 GET 瞬态错误重试的注册顺序：先释放失败会话及旧请求 ID，再创建唯一允许的第二次尝试。POST 不重试，凭据仍逐请求读取。

## 验证边界

check-visual-search.cjs 使用合成数据验证参数、选区边界、混合结果过滤、去重、分页、旧选区响应、关闭/页面改变和业务失败；check-image-viewer-actions.cjs 验证收藏选择、确认副本撤销、归属失败不删除及单次写入。现有详情、轮播、编辑、帖子扩展、原生传输检查用于相关回归。

未签名 HAP 编译不代表真机图片缩放、面板升降、保存文件、分享、取消收藏或 Pinterest 在线选区搜索通过。仍需登录设备验证图片坐标、拖动与滚动冲突、系统返回、深浅色和安全区。

2026-10-03：上述新检查及详情、轮播、编辑、帖子扩展、帖子接口、原生网络、收藏重入与系统返回回归通过；entry assembleHap 通过（未签名）。未安装设备或验证 Pinterest 线上服务。

同日设备截图反馈后的界面调整：入口文字与按钮宽度使用 240ms EaseInOut 收起过渡；搜索结果使用 bindSheet 系统标题栏；选区四角使用圆弧 SVG 和圆头线条。搜索返回与放大操作分别放在官方 HDS MINI 标题栏内，由 HDS 统一处理顶部安全区。此次未修改请求合同。需真机复验状态栏遮挡、标题栏点击及动画。

后续设备反馈：撤除图片子组件中额外的 HDS 导航和标题栏 stackBuilder。放大、选区搜索现在都作为详情同一 HdsNavDestination 的正文层，标题栏由详情唯一负责；放大关闭使用 backIcon，分享/下载/收藏使用正式 menu.value（maxCount:3）。点击图片通过控件显隐回调切换这一标题栏。Index 保持详情顶部 padding 为 0，只有外层 HDS 处理 TOP 安全区，避免多层导航重复处理。系统返回、收藏动作回归和未签名 HAP 构建通过；按钮可见性与时间栏位置仍待真机复验。

下载 SVG 改为明确的封闭轮廓路径（箭头线条与 U 形托盘），不依赖 fill=none，避免 HDS 着色填实开放路径。相关搜索结果区的“图片搜索”分组标题在 loading 期间隐藏，页面导航标题保留。

选区手势修正：搜索标题栏显式 menu.value=[] 清除详情分享菜单；选框与角点不再分别承载旋转/移动中的手势，统一由固定图片容器命中角点/内部并处理 PanGesture。四块遮罩直接绑定 crop 状态，随边界刷新。check-visual-crop.cjs 验证四方向、四角和边界；视觉搜索合同检查与未签名构建通过。真机手势方向及遮罩跟随仍需设备复验。

2026-10-04：单图片详情左下角增加固定灰色“由 AI 修改”标签，不随右侧搜索入口收起。当前只按已确认 ai_disclosures 包含 1 的接口合同显示；不根据画面内容猜测 AI，不推断尚未确认的 digital_media_source_type 枚举。标签随详情快照、收藏结果和缓存保留；不拦截图片点击。详情/收藏重入检查和未签名构建通过，真机位置待复验。
