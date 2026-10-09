# 四个根页加载优化与验收记录

## 第二轮修复（2026-10-07）

针对 13:51/13:52 日志未出现缓存恢复、搜索输入等待内容和资料串行等待：增加晚到身份缓存恢复去重及新 Feed 覆盖保护，独立搜索 inputReady，本人已保存首批与资料请求并行。预连接已共用业务 Session，新增状态诊断，不改重试/TLS策略。check-root-startup-readiness 覆盖身份晚到、重复事件、新 Feed 保护、两种资料响应顺序、取消及其他人/创建分段不预读取；网络检查验证同一 Session 对象。第二轮 20 项相关回归全部通过，entry assembleHap 构建成功，产出 unsigned HAP；检查和构建输出见 diagnostics/root-readiness-*。历史三份检查的夹具/断言问题仍按前文记录，未声称全仓检查通过。需新真机日志确认缓存 lookup/restored、并行请求时间和实际输入/图片上屏；尚未验证签名安装或线上耗时。

## 本轮实施

依据用户提供的四份 2026-10-07 运行日志，并对照当前源码，落实有明确证据的等待消除。此前日志存在重复导出的历史事件，分析按完整事件去重；卡片状态提交时间不等于首张图片上屏时间。

| 范围 | 改动 | 验证边界 |
| --- | --- | --- |
| 首页 | 当前认证用户名确认后，“所有”Feed 与真实分类并行发起；分类等待/失败不阻塞 Feed。分类失败保留成功卡片及独立重试，重试分类不重读 Feed。 | 合成测试已验证两请求在任一响应前启动，以及两种响应顺序、独立失败、重试。真机节省时间未测量。 |
| 首页附带请求 | 首页分类读取限定在首页文档，避免首页脚本在搜索、收件箱及资料文档中随身份绑定启动分类读取。 | 不影响资料自身的图板读取，不按接口名称合并业务参数不同的请求。 |
| 我的 | 已有展示快照时不因 profileActionsReady=false 再次自动加载文档；无快照仍由可见生命周期首次读取。主动操作继续准备当前会话。 | 缓存展示不启用操作权限；快速切页、有效空结果与失败门禁有回归。 |
| 搜索及根页准备 | 搜索分类/主题导航发起前登记完整目标地址和代次，并禁用旧操作会话。同一地址、同一代次的在途准备合并，导航回调清除 pending 后仍可加入等待。 | 12 秒窗口只用于准备合并，不更改接口超时；不同查询、切页、失败、过期及已完成后的主动重载分别验证。 |
| 收件箱 | 保留已经并行的联系人/会话请求，减少首页分类附带读取。 | 没有修改消息接口、联系人操作或业务成功门禁。 |

所有业务接口继续依赖活动 ArkWeb 的 Pinterest 网站内部同源资源，经现有原生 RCP 适配读取；不是官方开放 API 或原生 OAuth。未修改网络并发上限、证书校验、缓存 TTL、登录证据、写操作重放或 DOM 回退规则。

本轮未引入跨特性共享图板请求缓存，也未改资料首屏内容依赖：日志不足以证明同名请求具有完全相同的会话/参数合同。这些属于后续单独核对的优化候选。

工作区同时出现了首页恢复文档复用与 HomeRecoveryTrace 增量，已保留，最终检查与构建以当前组合源码为准。

## 本地验证

18 项检查通过：check-root-loading-optimization、check-home-api、check-home-bridge、check-root-initial-loading、check-root-content-actions、check-search-topic-navigation、check-native-root-switch、check-root-page-retention、check-secondary-root-context、check-search-api、check-search-bridge、check-search-discovery-api、check-search-inbox-pull、check-home-disk-cache、check-profile-api、check-profile-feeds、check-profile-retention、check-root-tabs-return。

结果在 `diagnostics/root-loading-check-summary-20261007.txt`，详细输出在 `diagnostics/root-loading-checks-20261007.log`。检查使用 DevEco 自带 TypeScript；相关旧夹具补齐真实 pathname、资料缓存及新增方法依赖。

扩展检查还发现三份历史脚本未通过，不能声称全仓回归全部通过：

- check-home-first-paint：断言已经不在当前 UI 源码中的旧 chromeScrollDistance 滚动行为；本轮未修改该行为。
- check-home-retention：尝试提取已经不存在的 requestHomeTitles 方法，未进入行为检查。
- check-session-startup：旧登录夹具未覆盖当前账号缓存/身份绑定依赖，未触发其期望的 home 效果；本轮未修改 updateAuthState。

Hvigor entry assembleHap 构建成功，产物为 `entry/build/default/outputs/default/entry-default-unsigned.hap`。构建输出在 `diagnostics/root-loading-build-20261007.log`；项目未配置签名，因此未验证签名安装。

## 真机验收

1. 正常网络冷启动首页：确认 BoardsFeed 与 UserHomefeed 请求时间重叠，比较 StartupTrace 首批卡片提交与实际首张图片上屏；分别记录，不能用数据提交代替图片显示。
2. 连续切换四页至少 10 轮：已有快照保持内容、滚动和正常空状态；“我的”不再因 visible-session-unconfirmed 发起自动页面读取。首次无快照仍加载。
3. 从搜索发现点主题/分类后立即输入：同一目标只准备一次；可观察 page-read-joined。不同查询只提交最新输入，切页废弃旧意图，旧结果不覆盖新页。
4. 首页分类单独失败：卡片继续显示，分类错误可重试；分类成功后更新真实标签，Feed 不重复请求。Feed 单独失败及两者同时失败仍保留已有内容并禁用旧操作。
5. 缓存“我的”的分段、编辑、发布等已接入操作：先确认当前资料会话，再执行；退出、切换账号、进入子页或关闭面板后不派发旧意图。
6. 覆盖返回、四个底栏点击/底栏上方滚动、浅深色和安全区。证书 -200 仍属于连接故障，单独排查，不纳入正常网络速度比较。

尚未执行签名安装、真机 UI、图片解码上屏或 Pinterest 线上行为验证；本轮不承诺具体秒数改善。
