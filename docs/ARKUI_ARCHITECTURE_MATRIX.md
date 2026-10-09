# HarmonyOS ArkUI 应用架构完成矩阵

本矩阵只覆盖软件基础架构，不把首页三点菜单、分享或下载当作架构完成条件。状态分为：

- **源码与静态检查通过**：责任边界和关键实现已在工程中存在。
- **源码具备，真机待验**：代码已具备，但设备行为、性能或系统交互还没有证据。
- **未完成**：当前工程没有足够实现或配置。

| 架构主题 | 当前结论 | 当前落点 | 真机/线上验收指标 |
| --- | --- | --- | --- |
| 应用模型 | 源码与静态检查通过 | Stage、唯一 `EntryAbility`、`entry` HAP、手机设备配置 | 冷启动、后台、前台、销毁后重新启动；检查 AbilityLifecycle 顺序 |
| 页面架构 | 源码与静态检查通过 | `Index` 单一 `@Entry`；页面组件归属 `feature_*`；状态归属七个 Store | 页面出现/消失后无重复 Store、桥接或网络回调 |
| 页面导航 | 源码与静态检查通过 | `PinWebNavigationHistory`、Sheet → 二级页 → 根页返回层级 | 连续进入详情/图板/收件箱子页并返回，检查目标和滚动位置 |
| 根页面与标签 | 源码与静态检查通过 | 一个 `HdsTabs`、四个 `TabContent`、根页切换动画时长为 0 | 四个标签切换不重建页面、不丢滚动、不重复请求 |
| 窗口与安全区 | 源码与静态检查通过，真机待验 | `avoidAreaChange`、状态栏/导航栏安全区、HDS 子页安全区合同 | 首屏、滚动、二级页、深浅色和系统手势区无重叠或重复留白 |
| ArkWeb 架构 | 源码与静态检查通过，真机待验 | 登录可见 Web；登录后隐藏 Web 保留同源会话和桥接 | 登录、登出、网络失败、页面重建后 Web 不可见且会话证据正确 |
| 原生网络 | 源码与静态检查通过，线上待验 | `common_network` 统一 RCP Session、8 路调度、12 个在途上限、取消和受限重试 | 真机 VPN/断网/恢复；检查 pending、active、取消、重试和迟到响应 |
| 系统能力 | 源码与静态检查通过，真机待验 | ShareKit、PhotoViewPicker、DocumentViewPicker、Pasteboard、系统颜色模式 | 系统授权取消、返回、分享目标、文件保存和颜色模式变化 |
| 媒体架构 | 源码与静态检查通过，设备解码待验 | `AVPlayer` + `XComponent`；视频播放状态独立于 Web 页面 | 播放/暂停/静音/重播/失败；检查释放后无回调和无黑屏 |
| 资源管理 | 源码与静态检查通过，设备资源待验 | `$r('app.*')`、共享颜色/图标、`SmartImage` 尺寸降采样和失败占位 | 深浅色、图片失败、资源缺失和页面反复进入后的内存稳定性 |
| 响应式布局 | 源码具备，跨尺寸待验 | `layoutWeight`、`onAreaChange`、WaterFlow/List、图片 `sourceSize`；当前产品配置为 phone | 至少验证窄屏/常规屏和字体放大；横竖屏/折叠屏未纳入当前设备配置 |
| 鸿蒙无障碍 | 源码具备，辅助功能待验 | 主要按钮、卡片、状态、输入和视频控件使用 `accessibilityText/Selected` | 开启屏幕朗读，验证焦点顺序、名称、状态、禁用态和弹层关闭 |
| 鸿蒙动效 | 源码具备，性能待验 | 根 Tabs 无切换动画；二级页和面板使用受限 transition/animateTo | 连续切换、返回和低端设备帧率；检查无动画叠加和卡顿 |
| 线程与任务 | 源码具备，压力待验 | 业务采用异步 Promise、RCP 调度和取消；页面定时任务由 `PinWebTaskRegistry` 统一登记和失效；未使用 TaskPool/Worker | 并发首屏、分页、预取和取消；检查 UI 响应、active ≤ 8、pending ≤ 12，页面退出后 pending timer=0 |
| 数据存储 | 源码与静态检查通过，设备恢复待验 | `PersistentStorage`/`AppStorage`、账号隔离磁盘缓存、LRU、TTL、原子提交 | 冷启动、TTL 过期、账号切换、登出清理和异常中断恢复 |
| 生命周期与资源释放 | 源码与静态检查通过，真机待验 | Ability/Page 生命周期日志、网络 invalidate、窗口监听移除、媒体释放、页面任务注册器失效 | 前后台、窗口重建、强制结束后重启；检查 sequence、释放次数、`pendingBefore`、`pendingAfter=0` 和无迟到更新 |
| 工程模块 | 源码与静态检查通过 | `entry` + 7 个 feature HAR + 4 个 common HAR；依赖单向 | 运行模块边界、Store、RCP 和 HAP 构建检查 |

统一静态入口：

```powershell
node scripts/check-arkui-architecture.cjs
```

该脚本只证明源码责任和配置存在，不替代签名安装、真机 UI、系统辅助功能、媒体解码或 Pinterest 线上服务验证。
