# 视频详情与原生播放

> 2026-10-03 传输调整：现有业务 API 脚本在注入时适配原生 RCP，接口参数、数据优先级、业务成功校验和禁止自动回退规则继续沿用本文；网站自身请求、认证探测与标题 HTML 读取仍由 Web 执行。原生凭据仅运行时读取，失败不自动重放。范围、手动传输回退及验收边界见 [原生网络说明](NATIVE_NETWORK_NOTES.md)。


`services/PinWebVideoApiScript.ets` 的 `PIN_VIDEO_API_ENABLED=true` 默认启用。属于 Pinterest 网站内部接口，使用当前 ArkWeb 登录会话读取，不是官方 API/OAuth，不导入 HAR Cookie、用户 ID 或令牌。

## 数据与播放流程

- 现有 `PinResource/get/` 继续提供详情、封面、作者和帖子操作上下文。普通单视频帖新增 `video` 数据合同，多图/故事页保留原来的手动网页查看流程。
- 优先读取当前 Pin 的接口 `videos.video_list`，其次读取当前 Pin ID 匹配的 Relay JSON；只解析 JSON，不执行网页 script。
- 缺少播放源时调用视频 HAR 已确认的 `/_/graphql/` 完整移动端 Pin queryHash `c025ad33faccf5d04c2ed38344405d0a6c46dd1d786c17f3954b6980ef798538`，传入当前 `pinId` 和捕获的移动端变量结构。失效、缺少当前请求凭据或返回 Pin ID 不匹配时显示明确错误并允许重新读取，不改用 DOM 视频地址。
- GraphQL `videos.videoList.vHLSV4.url` 优先，`v720P.url` 为 MP4 后备。只接受 HTTPS pinimg 域名 `/videos/` 下、对应扩展名的实际地址，不猜 URL、不盲选 AV1/H.265 变体。提供视频宽、高、毫秒时长。
- 原生 `PinWebVideoPlayback` 使用 Media Kit `AVPlayer`，`PinWebVideoPlayer` 使用 `XComponent` 提供 Surface。监听状态后设置资源；initialized 绑定 Surface 并 prepare，prepared 后按用户意图 play。
- 详情首次取得当前视频源后默认自动播放；封面在实际首帧回调后隐藏。支持播放/暂停、重播、进度拖动、静音、缓冲状态、播放错误重试和重新读取媒体地址。离开画面、打开面板或应用进入后台暂停，回到前台等待用户点击；音频焦点暂停/停止中断同样暂停。
- 首页与搜索的接口 Pin 卡片读取 `videos.video_list.V_HLSV4` / `V_720P` 的实际媒体地址与毫秒时长，左上角显示浅色圆角 `m:ss` 标签；没有时长时不猜测。可见面积达到 60% 且根页为当前页、会话已就绪时静音自动播放，首帧前保留封面。离屏、打开详情/面板、切换底栏或进入后台释放播放器，重新可见时从头播放；播放失败保留封面，不自动重试或打开网页。共用 `common_ui` 的 AVPlayer 服务与视频数据合同，特性之间不新增依赖。
- HLS 初始化/播放错误或首帧等待超时，释放旧播放器后尝试同一响应中的 MP4。所有候选失败才显示错误；不自动跳转网页。当前未增加全屏按钮。
- 切换 Pin、更新媒体地址、组件退出时废弃旧世代并释放播放器；迟到创建结果也立即释放，旧错误/进度/状态不改变新播放器。返回缓存保留视频身份，等待当前接口重新读取播放地址，不持久化媒体源。
- 当前原生视频详情可见期间暂停当前 `/pin/{id}/` 主内容区的后台网页视频，并拦截其后续 play 事件，防止两层播放器同时发声。离开当前 Pin 或手动进入网页流程解除限制，不隐藏其他网页 UI。

## 验证与限制

`scripts/check-video-api.cjs` 验证接口/Relay 映射、当前 Pin ID、地址安全、GraphQL 凭据来源、过期结果、限定页面的网页播放抑制和详情接入。`check-video-playback.cjs` 使用 SDK TypeScript 和 AVPlayer 模拟验证 Surface、首帧、暂停、音频中断、音量、进度、候选切换、重试与资源释放。既有详情与返回流程回归通过。

HAP 构建验证 ArkTS 编译与打包（未签名）。没有证明真机解码、CDN 在原生播放器中的访问权限、HLS 音视频分片合流、拖动和画面渲染。播放源读取使用 ArkWeb 会话；原生 CDN 请求不假定继承 WebView Cookie，目前没有复制 Cookie 或模拟浏览器凭据。若设备实测出现 403、格式或渲染失败，需按具体错误处理，而非宣称可以播放全部视频。

## 手动撤回

关闭 `PIN_VIDEO_API_ENABLED` 后重建，可恢复视频帖子原有的手动网页查看入口，保留图片详情、收藏及其他接口。

修改前快照在 `backups/video-player-before-20261001/`。`restore.ps1` 默认仅核验哈希，`-Apply` 才恢复；先完整核验所有文件，拒绝覆盖后续修改。新增组件/服务/检查文件保留，但恢复后的旧代码不引用它们。

2026-10-05：详情先提交已验证封面与正文，再独立解析播放源；视频加载/失败只影响媒体区域。重新读取媒体使用当前 Pin 元数据重跑媒体解析，不重读 PinResource 或推荐。DetailTrace 的图片完成事件不代表视频首帧/解码成功，仍需真机验证。
