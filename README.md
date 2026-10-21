<p align="center">
  <img src="./AppScope/resources/base/media/pinmony_logo.jpg" width="160" alt="Pinmony 应用图标">
</p>

<h1 align="center">Pinmony</h1>

<p align="center">
  <a href="./README.zh-CN.md">中文</a> | <a href="./README.en.md">English</a>
</p>

Pinmony 是个人为了兴趣开发的 HarmonyOS 应用，主要用于学习、技术研究、界面探索和移动端体验测试。应用通过当前登录会话读取目标网站公开返回的页面或接口数据，并使用 ArkUI 提供原生界面。

## 功能

- 首页浏览推荐 Pin、图板和分类内容
- 搜索 Pin、分类、主题和相关内容，并支持选择照片进行图片搜索
- 查看 Pin 详情、作者、评论、相关推荐和支持的视频；详情中可选取图片区域并查找相关内容
- 浏览个人资料、已保存内容、图板和收件箱；个人主页支持搜索自己的 Pin 和最近搜索
- 收件箱支持消息与联系人切换，并可按用户名搜索
- 支持 Pin、图板和联系人分享，分享入口按具体页面流程展示
- 应用界面支持跟随系统、中文和 English；应用自有文案可即时切换并保存语言偏好
- 设置支持通知、社交权限、视频自动播放、显示偏好和脱敏运行日志导出
- 支持手机和平板自适应布局
- 保留页面状态、滚动位置、返回层级和加载状态

## 使用条件

| 条件 | 要求 |
| --- | --- |
| 设备与系统 | HarmonyOS 6.1.1（API 24）以上版本 |
| 开发环境 | DevEco Studio、ArkTS、Hvigor 和 HarmonyOS SDK |
| 网络与账号 | 可访问 Pinterest，并在应用内使用账号密码完成登录。Google 登录暂不可用。 |


## 技术架构

- `entry`：应用入口、窗口生命周期、登录门禁、根页面、路由和跨页面协调
- `feature_home`：首页内容、分类、分页、缓存和首页状态
- `feature_search`：搜索发现、图片搜索、筛选、结果、分类、主题和搜索状态
- `feature_pin`：详情、评论、相关推荐、媒体、收藏和分享
- `feature_board`：图板页面、图板详情和图板内容
- `feature_profile`：个人资料、已保存内容、个人内容搜索、最近搜索、发布和整理流程
- `feature_inbox`：收件箱、消息与联系人合并页、会话搜索和通知相关页面
- `feature_settings`：设置、账号信息、语言、通知、社交权限、自动播放、显示偏好和退出登录流程
- `common_session`：登录证据、会话和凭据适配
- `common_network`：原生 RCP 网络传输和请求生命周期
- `common_ui`：跨特性复用的 UI 组件和公共展示状态
- `common_foundation`：中英文语言资源与偏好、缓存、日志、任务登记和基础运行时能力

## 语言资源与偏好

应用自有文案统一维护在 `common_foundation/src/main/resources/{base,zh_CN,en_US}/element/string.json`，使用稳定资源名。语言选择入口位于显示设置，支持跟随系统、中文和 English，偏好会在重启后恢复。网站和用户内容保持原文，仅对已确认的固定控件按语义标识显示本地文案。

## 构建 HAP

在 PowerShell 中配置本机 HarmonyOS SDK 后执行：

```powershell
$env:DEVECO_SDK_HOME = '<HarmonyOS SDK 目录>'
$env:JAVA_HOME = '<DevEco Studio 安装目录>\jbr'
& '<DevEco Studio 安装目录>\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry assembleHap --no-daemon
```


## 隐私与会话

Pinmony 使用 ArkWeb 保留当前网站登录会话。原生网络按请求临时读取必要的 Cookie，并在需要时将 Set-Cookie 同步回当前 ArkWeb 会话。Cookie、CSRF、账号标识、访问令牌和响应凭据不会写入源码、仓库或持久化日志。

运行日志仅保存脱敏诊断信息，不记录 Cookie、CSRF、账号令牌、请求正文或完整敏感 URL。设置页提供运行日志导出入口。

## 免责声明

本项目与 Pinterest 及其关联方不存在任何隶属、合作或授权关系。本项目使用当前 ArkWeb 登录会话访问 Pinterest 网站内部同源资源，这些资源不是 Pinterest 官方开放 API；项目没有原生 OAuth 流程或独立令牌生命周期。所用接口来自目标网站公开页面或当前登录会话中的正常请求，不提供任何破解内容。

- 本项目不访问目标网站后台数据库，不进行注入攻击、越权访问或绕过授权。
- 本项目不会将 Cookie、CSRF、账号标识、访问令牌或其他凭据写入源码、仓库或持久化业务日志；登录会话 Cookie 由 ArkWeb 按平台机制保存。
- 使用者应遵守所在地区法律法规、目标网站服务条款和账号规则。
- 不得将本项目用于违法、侵权、批量采集、骚扰或破坏目标网站正常运行的行为。
- 本项目不保证数据完整性、准确性、实时性、接口稳定性或持续可用性。
- 使用本项目产生的账号、数据、设备或其他后果由使用者自行承担。

Pinterest 的名称、商标、网页设计、图片、视频、文本和接口返回内容归其各自权利人所有，不属于本项目许可证的授权范围。项目 Logo、第三方依赖和示例资源可能适用各自独立的版权或许可证条款。

## 许可

Pinmony 源代码采用 Apache License 2.0，许可证全文见 [`LICENSE`](LICENSE)。Apache-2.0 仅适用于本项目明确声明为项目代码的部分，不授权 Pinterest 的品牌、网站内容、接口数据或第三方资源。
