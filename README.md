<p align="center">
  <img src="./assets/readme/logo.jpg" width="112" alt="Pinmony 应用图标">
</p>

<h1 align="center">Pinmony</h1>

<p align="center">面向 HarmonyOS 的非官方 Pinterest 客户端</p>

<p align="center">
  <a href="https://github.com/Torotar/Pinmony/releases/latest">下载最新版本</a> ·
  <a href="https://github.com/Torotar/Pinmony/releases">更新记录</a> ·
  <a href="https://github.com/Torotar/Pinmony/issues">问题反馈</a>
</p>

<p align="center">
  <a href="./README.zh-CN.md">中文</a> | <a href="./README.en.md">English</a>
</p>

Pinmony 为 HarmonyOS 带来原生界面的 Pinterest 浏览体验。在手机上发现灵感、搜索图片、收藏喜欢的内容，也可以在平板和阔折叠设备上浏览与整理图板。

本仓库用于应用介绍、版本公告、安装包发布与问题反馈，源码不在此仓库继续更新。

## 下载与更新

前往 **[GitHub Releases 下载最新版本](https://github.com/Torotar/Pinmony/releases/latest)**，查看版本说明并在 **Assets** 中下载该版本提供的安装包。请根据发布页说明选择适合设备的文件，完成安装或更新。

应用内也可进入 **设置 → 关于**，通过更新入口打开 GitHub 发布页面。

| 使用条件 | 说明 |
| --- | --- |
| 系统 | HarmonyOS 6.1.1（API 24）及以上版本，建议使用 API 26 及以上版本。 |
| 设备 | 支持手机，并提供平板及阔折叠设备布局适配。 |
| 网络 | 需要能够访问 Pinterest 的网络环境。 |
| 登录 | 在应用内使用 Pinterest 账号密码登录，Google 登录不可用。 |

## 界面预览

### 手机

<p align="center">
  <img src="./assets/readme/phone-search.png" width="280" alt="Pinmony 手机搜索页面">
  &nbsp;&nbsp;
  <img src="./assets/readme/phone-detail.png" width="280" alt="Pinmony 手机 Pin 详情页面">
</p>

<p align="center">搜索与发现 · Pin 详情</p>

### 平板与阔折叠

<p align="center">
  <img src="./assets/readme/large-screen-landscape.png" width="760" alt="Pinmony 平板与阔折叠横向布局预览">
</p>

<p align="center">
  <img src="./assets/readme/large-screen-portrait.png" width="320" alt="Pinmony 平板与阔折叠纵向布局预览">
</p>

<p align="center">横向与纵向界面预览</p>

截图用于展示界面，实际内容与布局以所安装版本、设备尺寸和账号状态为准。

## 主要功能

- **发现灵感**：浏览首页推荐、分类与主题，查看图片、视频、多图和拼贴内容。
- **搜索内容**：搜索 Pin、图板与主题，使用照片搜索及局部图片识别，也可粘贴内容链接打开对应页面。
- **浏览与收藏**：查看 Pin 详情、作者、评论及相关推荐，放大图片、切换多图，将喜欢的内容收藏到图板。
- **管理图板**：浏览个人已创建和已保存的内容，搜索自己的 Pin，整理与移动内容，管理图板、区块及协作者。
- **分享与交流**：分享图片、视频或 Pin，通过应用内联系人发送内容，查看消息、通知及关注动态。
- **调整使用偏好**：切换深浅色、界面语言与个人主页排版，调整照片显示、视频自动播放和大屏设备方向。

部分功能依赖 Pinterest 当前登录会话及服务状态，实际可用操作以应用内显示为准。

## 常用操作

| 想要做什么 | 操作方式 |
| --- | --- |
| 打开内容链接 | 在搜索框粘贴 Pin 链接或个人主页链接并提交。 |
| 用图片搜索 | 在搜索页选择照片或历史照片，调整识别区域后查看相关结果。 |
| 调整外观与语言 | 进入“设置 → 显示设置”，调整主题、语言和个人主页排版。 |
| 完整显示详情照片 | 在“设置 → 显示设置”中开启“完整显示详情照片”。 |
| 查看消息与动态 | 进入收件箱，查看更新、消息、联系人及关注动态。 |
| 检查版本更新 | 进入“设置 → 关于”，打开 GitHub 发布页面。 |


## 问题反馈

欢迎通过 **[GitHub Issues](https://github.com/Torotar/Pinmony/issues)** 提交问题或建议。反馈时请尽量提供：

- 应用版本、设备型号和 HarmonyOS 版本。
- 复现步骤、预期结果与实际表现。
- 相关截图；涉及显示问题时，注明屏幕方向和深浅色模式。

应用设置中提供运行日志导出和清理入口。提交截图或日志前，请检查其中的个人信息，勿上传账号密码、Cookie、令牌等凭据。

## 隐私与会话

登录会话由系统 ArkWeb 组件保存，用于访问当前账号可见的 Pinterest 内容。Cookie、CSRF 和访问令牌等凭据不会写入源码、仓库或持久化业务日志。

运行日志仅保存脱敏诊断信息。清理应用内日志不会删除此前已导出的文件。

## 免责声明

Pinmony 是个人兴趣项目，与 Pinterest 及其关联方不存在隶属、合作或授权关系。

使用应用时，请遵守所在地区的法律法规、Pinterest 服务条款和账号规则，不得用于侵权、批量采集、骚扰或破坏网站正常运行的行为。应用不保证内容的完整性、准确性、实时性或服务持续可用性。

Pinterest 的名称、商标及平台中的图片、视频、文本等内容归各自权利人所有。界面截图中的内容仅用于展示应用使用效果。
