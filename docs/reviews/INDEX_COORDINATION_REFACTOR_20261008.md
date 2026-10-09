# Index 协调职责首轮优化记录

开始：2026-10-08。完成验证：2026-10-09。

本轮完成脚本组合、系统操作适配和搜索业务流程的闭环迁移。Index 从 **9,106 行减少至 8,411 行**，减少 695 行（约 7.6%，按物理行统计）。目标是让职责归属可独立维护，不能将代码行数下降解释为启动或网络提速。

## 实施范围

| 落点 | 已承担职责 | 产品层保留职责 |
| --- | --- | --- |
| entry/app/PinWebScriptRegistry.ets | 24 条文档启动脚本的组合、既有开关及传输适配 | Index 每实例构造一次列表并绑定同一 Web |
| entry/app/PinWebSystemActions.ets | 剪贴板、外部链接、日志导出、图片选择和 JPEG 读取、下载目录选择及下载回调 | 业务许可、目标与会话校验、业务成功确认 |
| feature_search/controllers/PinWebSearchController.ets | 搜索快照验收、缓存/合并、输入/提交、分类与主题导航意图、筛选、灵感操作、刷新及分页 | 登录/真实文档门禁、根页准备、产品导航、返回和面板挂载 |
| feature_search/models/PinWebSearchPorts.ets | 特性所需的明确回调合同 | entry 实现受限能力，不向控制器传递整个 Index |
| feature_search/stores/PinWebSearchStore.ets | 原有可观察状态与输入意图代次 | 同一 Store 仍由 Index 的 @State 持有 |

没有新增框架或空 Repository。特性不依赖其他特性或 entry；新增 common_foundation 本地依赖用于既有任务注册表和日志。已运行 OHPM 更新依赖锁文件。

七个 Store、唯一 @Entry、稳定 ArkWeb 和四个真实 TabContent 保留。四根页的 buildRootTabs 声明经换行归一化后与本轮快照逐字相同；Web 的布局、触摸及登录展示条件保持，启动脚本属性改为注册表生成的同一列表。统一业务分享面板、接口开关、默认数据源和回退规则未变。

## 异步与资源清理

搜索控制器拥有独立 PinWebTaskRegistry。切页、后台、明确会话清理和 Index 销毁时废弃待执行输入、筛选和读取代次，取消定时器并收敛等待 Promise；迟到刷新失败不再改写新页面。筛选读取被取消时结束加载并显示真实取消状态，保留可重试入口。

文档准备中的 clearSearch 只清理旧业务状态与计时器，保留正在等待该文档的最新用户意图。准备完成后从当前 Store 重新读取 session 和完整 pageKey；新输入覆盖旧输入，切页取消后不派发旧操作。缓存恢复始终保持结果操作和输入门禁关闭，等待当前会话确认。

下载目录选择有独立生命周期代次；Index 销毁会取消尚未启动的下载，迟到目录结果不能启动任务或显示旧页面反馈。JPEG 读取使用嵌套 finally 释放文件、ImageSource 和 ImagePacker，包含编码失败路径。系统 API 的实际设备行为尚待验证。

## 本地验证

| 验证层级 | 结果 | 证据与边界 |
| --- | --- | --- |
| 相关 Node 回归 | 46 / 46 通过 | diagnostics/index-refactor-20261008/checks.json，覆盖架构、搜索、根页、登录、生命周期、网络、缓存、分享、评论图片及返回 |
| 24 条启动脚本合同 | 通过 | 按原序逐条比较 script SHA256 与 scriptRules，包含现有开关和原生传输组合；fixture 来自迁移前脚本 |
| 真实控制器行为 | 通过 | 加载实际 SearchController、SearchStore 和 TaskRegistry；测试准备期间文档重置、取消等待、迟到响应、保留/空/失败与门禁 |
| 实际 Hvigor 输出 | 通过 | check-compiled-store-access：139 个字段访问落在实际所有者；SearchStore 先初始化，再绑定控制器，只有一个实例 |
| entry 未签名 HAP | BUILD SUCCESSFUL | diagnostics/index-refactor-20261008/build.log，最后构建 11s327ms；无签名配置，SignHap 跳过 |
| 签名安装、真机界面和 Pinterest 线上服务 | 未执行 | 本地静态检查、模拟原生 API 和编译不能替代设备及线上验收 |

此次回归将原来直接提取 Index 搜索方法的夹具改为实际控制器和真实产品绑定，不拼接一份虚拟旧源码。原生系统 API 使用测试替身，只用于验证参数、清理和迟到结果处理。

扩展检查发现三项迁移前已存在的脚本漂移：缓存恢复方法名、登录夹具缺失缓存/身份同步能力、BFCache 仍断言旧的 2/120（当前源码是 4/300）。已用迁移前 Index 复现，记录在 expanded-baseline.json；本次修正测试指向当前合同，保留原来的门禁与时序断言。ArkUI 检查中过时的 sourceSize 断言也已改为当前实际分档封面策略。

早期基线还发现 check-home-retention 与 check-image-viewer-actions 的旧夹具缺少当前所需方法；这两项不计入本轮 46 项通过集合，未在本轮修复。没有宣称仓库所有脚本均通过。

## 待设备验收

1. 四根页反复切换、空根页首次读取、缓存恢复、搜索结果及正常空状态；核对滚动、底栏点击与系统手势区。
2. 快速输入/提交与上下文准备并发；切页、后台及返回后确认没有旧输入或旧筛选读取继续执行。
3. 搜索筛选、灵感推荐、搜索 Pin 的详情打开/返回及来源恢复；当前会话失效后旧标识不能继续操作。
4. 图片选择/评论上传、下载目录选择和取消、剪贴板、日志导出；检查深浅色、后台往返和现有分享面板。
5. 新安装构建的 PageLifecycle、RootTabTrace 和 NetworkTrace 与设备行为一致；另行比较加载耗时及请求数量。

## 快照与后续范围

本轮快照位于 diagnostics/index-refactor-20261008/before；manifest.json 记录受影响文件的迁移前/最终 SHA256。恢复入口 restore.ps1 默认只验证全部当前文件和原始快照；文件出现后续修改时拒绝覆盖。仅在用户明确要求撤回本轮时使用 -Apply，执行前应退出构建与重新安装前的编辑流程。恢复后需重新 OHPM install --all 和构建；不会恢复已生成的依赖或构建产物，也不会动已有 backups。

默认恢复校验已通过，未执行恢复。本地没有 Git 仓库，因此没有提交或 PR。

首页、收件箱、资料、图板、复杂帖子流程，以及导航/返回/会话协调仍待后续阶段迁移。Index 仍然较大；本轮完成可独立验证的搜索试点，为后续迁移建立相同 Store、明确 ports 和任务作用域的模式。见 ../INDEX_COORDINATION_REFACTOR_PLAN.md。
