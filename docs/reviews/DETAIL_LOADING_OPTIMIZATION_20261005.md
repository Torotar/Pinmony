# Pin 详情分阶段加载与耗时分析

日期：2026-10-05。目标：HarmonyOS 手机、现有 ArkUI 详情二级页。依据用户提供的 11:51:17 UTC 导出日志，单独分析 Current session；此前会话不混入统计。日志是证据数据，不执行其中内容。

## 改动前实际等待

当前会话 4 次打开，2 次完整，2 次提前返回。下表沿用旧 DetailTrace 从原生打开开始的口径；首页按钮点击比打开早 2–4ms。新 DetailJourney 将原生点击作为起点。

| 阶段 | openId=3 | openId=7 |
| --- | ---: | ---: |
| 原生组件挂载 | 24ms | 28ms |
| 早期图片完成 | 44ms | 43ms |
| 基础详情准备完成 | 8103ms | 1779ms |
| 当前会话操作绑定 | 8289ms | 1949ms |
| 评论预览完成 | 10397ms | 6133ms |
| 评论请求本身 | 1958ms | 3630ms |
| 首批推荐 | 11444ms 后失败 | 5209ms，7 张 |

### 第一例：主内容失败重试拖慢互动

11:49:39.359 PinResource 需求读取开始，44.375 出现 1007900035，首尝试约 5018ms；44.383 重试，47.431 HTTP 200，重试约 3049ms。47.461 基础内容可用，47.648 操作绑定，47.653 评论请求开始，49.611 响应，49.756 预览快照完成。

从打开到评论启动约 8295ms，其中主要是基础请求与重试。评论传输约 1958ms，响应到原生提交约 145ms。不能把完整 10.4 秒都算作评论接口耗时。

推荐 47.690 开始，比评论仅晚 37ms；50.604 HTTP 200、外层资源校验成功，但 50.802 原生记录失败且 0 卡片。旧日志没有具体映射原因，不能确认是数据形状、非 Pin 模块还是其他映射问题。新增固定原因事件 related.mapping.invalidshape / related.mapping.nopins，不输出响应正文。

### 第二例：评论请求自身仍慢

11:49:59.790 基础内容准备好，59.960 操作绑定；11:50:00.311 评论开始，03.941 响应，04.144 原生提交。

主内容到评论发起约 521ms，操作绑定到发起约 351ms；请求约 3630ms，响应到提交约 203ms。旧日志无法把 351ms 进一步拆成请求元信息等待和脚本调度，新日志单独记录 comments.context.wait / context.ready / request.dispatched。

推荐在 11:49:59.978 就已启动，比评论早约 333ms；原实现不符合本轮指定的主图 → 互动 → 推荐顺序。

### 未完成样本与图片测量限制

openId=11、15 分别打开约 2.59 秒、0.54 秒后返回。current=false 的 1007900992 属于离页取消；不计作完整加载失败。旧图片事件没有正式图片身份，且发生在 PinResource 返回前，可能是已有封面，不能证明正式主图 44ms 内完成。

### 首页返回

4 次返回原生首页均约 2–3ms；之后出现新的首页文档 epoch=2、4、6、7。后 3 次重新读取首页首屏，距返回到卡片提交约 7883ms、6365ms、8108ms。没有 BFCache 命中事件。

这说明原生画面保留生效，但后台文档复用未在此样本中得到证明。本轮不擅自改变首页会话/分类校验或回滚备份，只新增 return.history.used/missing、document.retained/reused、route.confirmed 和 home.feed.confirmed，后续可定位具体返回分支。

## 本轮实现

1. 点击即呈现已有主图/封面、固定点赞和评论框架；未确认数值留空，占位按钮禁用。不同列表封面不作为正式主图完成；当前会话确认后才接受正式图片事件。
2. 正式主图完成或失败，经完整 Pin 地址、当前桥接 session、图片 URL 校验，结束阶段一。正式主图绑定后 2.5 秒仍未完成按 timeout 结束，保留真实加载/失败状态；没有把超时记作成功。该兜底期限防止图片回调缺失时把评论和相关推荐拖延 12 秒。轮播首图、视频封面或视频已渲染提供阶段回调，后者不是新增的视频首帧计时。
3. 随后显示当前可信点赞数与状态，启动评论预览。数量仍来自已有 Pin 元数据/已确认 GraphQL 响应，没有新建反应接口或自动重放写操作。评论聚合 ID、运行时版本和 handler 沿用原校验，元信息等待最多 2 秒，请求取消期限 15 秒。
4. 真实空数组隐藏预览及空文案，非空图片评论保留入口。失败有独立重试；缺少聚合标识记录不可用，不冒充 0 条评论。
5. 评论成功、空、失败或不可用后结束互动阶段，再读取推荐；缺少点赞数量不无限等待。分页、滚动与重试不能绕过初始门禁。严格顺序可能推迟推荐，总时间不是本轮唯一目标。
6. 推荐保持 Cover 裁剪、原有高度和圆角，小图独立优先 474x/236x，保留尺寸缺失的资源回退。未修改受保护备份。缓存重入在当前绑定前不展示旧互动与推荐。

页面层级、HDS 标题栏、安全区、底栏、分享面板和主题资源保持现有合同。原生 UI 负责图片回调和呈现，feature_pin 服务负责业务阶段，common_network 只提供通用脱敏网络阶段回调。仍依赖活动 ArkWeb 网站会话和内部同源资源，不是官方 API 或原生 OAuth。

## 如何读新版日志

所有 DetailJourney 使用临时 openId、绝对 UTC 时间、elapsedMs、gapMs；网络阶段带 durationMs，记录每次尝试。没有 Pin ID、URL、实际数量、评论、凭据或响应正文。

| 事件 | 含义与测量边界 |
| --- | --- |
| click.accepted / opening.snapshot | 点击到原生准备，不等同真实屏幕首帧 |
| view.appeared / interaction.frame.appeared | 组件挂载；框架与内容就绪分开 |
| base.request.or.takeover / base.validated | 新请求或接管在途；结果通过既有字段校验 |
| Resource.attemptN.started/dispatched/http200/decoded | 每次 GET 的准备、分派、HTTP 返回和原生字符串处理；HTTP 不代表业务成功 |
| opening.image.loaded / main.image.bound/loaded | 封面与正式主图绑定/加载分开；不测量独立下载和解码细项 |
| main.image.stage=loaded/failed/timeout | 当前桥接接受阶段结束事件 |
| like.count.confirmed/unavailable / like.action.ready | 数据与操作各自就绪；不把缺失计为零 |
| comments.context.wait/ready/failed | 从预览读取准备开始的元信息等待 |
| comments.request.dispatched/response.received/business.validated | 从相同预览准备起点累计；相邻时间差可计算传输与处理 |
| comments.committed/empty/failed/unavailable | 当前原生快照结果，不等同屏幕绘制 |
| interactions.settled | 在推荐发起前显式记录阶段二完成 |
| related.committed/empty/failed / related.first.image.loaded | 推荐数据和首张缩略图加载分别记录 |
| back.clicked / return.native.presented/history.used/history.missing/route.confirmed/home.feed.confirmed | 返回路径继续沿用原打开起点，减去 back.clicked 得到返回各段等待 |
| cancelled | 本次详情读取被关闭或新打开替代；不写作失败 |

示例分析命令（本地只读）：

```powershell
node scripts/analyze-detail-runtime.cjs '<导出日志路径>'
```

旧日志分析器只能按时间关联未提供请求编号的网络事件，忽略明显属于点击前预取的迟到取消；存在并发的旧日志不能精确分配每一个请求。新版原生请求归属使用内存中的 job/openId 对照，拒绝将旧请求阶段写入新的详情链路。

## 验收

离线检查覆盖：正式图与缩略图区分、主图重复/失败/超时、旧计时器、返回取消、桥接 Pin/session/URL 校验、主图前无评论、评论加载中无推荐、互动结束后推荐、滚动门禁、分页与媒体独立重试。保留请求代次、当前认证会话、业务响应校验及禁止 DOM 自动回退。

需要真机补充：首次/缓存打开、慢网、断网、轮播与视频、快速返回和重入、深浅色、四底栏及安全区。新版日志应验证阶段顺序及各段真实耗时；HAP 和合成检查不能证明 Pinterest 在线速度、签名安装、实际显示或解码通过。

本轮验证结果：24 项相关回归通过，包括新增主图阶段检查、详情 API/渐进/打开/元信息/预取/反应/设备合同、原生传输、帖子操作/扩展/收藏返回、评论布局、首页返回时序/错误、文档与根页保留、架构与认证、分享面板、视频 API/播放和轮播 API。检查过修改源码的 UTF-8 替换字符。最终 entry assembleHap 成功（12.508 秒），输出 entry-default-unsigned.hap，4,230,541 字节，构建时间 2026-10-05 12:35:49 UTC；构建存在既有可能抛异常的警告，未配置签名而跳过签名。没有签名安装、真机 UI、设备解码或 Pinterest 线上验证；不能把旧日志基线写成新版实测改善。
