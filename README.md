# Pinmony

Pinmony 是面向 HarmonyOS 手机的原生灵感收藏应用。它以 Pinterest 当前登录会话提供的内容为来源，并使用 ArkUI 构建应用内可见界面。

## 功能

- 首页浏览灵感内容和图板
- 搜索 Pin、分类和主题
- 查看 Pin 详情、评论、相关内容及支持的视频
- 管理个人资料、收件箱和设置
- 通过统一的应用内分享面板分享 Pin 和图板

界面展示及操作范围取决于 Pinterest 当前会话和已经接入的功能。部分未接入的操作保持不可用。

## 平台与技术

- HarmonyOS 6.1.1（API 24），Stage 模型
- ArkTS、ArkUI 与 UI Design Kit
- ArkWeb 负责登录并在后台保留网站会话；登录后可见业务界面由 ArkUI 提供
- common_network 使用原生 RCP 适配已有请求
- Hvigor 构建 HAP，Node.js 脚本提供离线回归检查

Pinmony 使用 Pinterest 网站内部同源资源。这些不是 Pinterest 发布的官方开放 API；本项目没有原生 OAuth 或独立令牌生命周期。请求依赖用户当前登录会话，具体范围和限制见本机开发文档。

## 获取源码

本仓库不包含本机 SDK、签名配置、构建产物或开发文档目录。请安装 DevEco Studio，并按本地 HarmonyOS SDK 环境配置 Hvigor。仓库不提供签名证书，因此生成的 HAP 为未签名包。

## 构建 HAP

在 PowerShell 中设置本机 SDK 路径后执行：

```powershell
$env:DEVECO_SDK_HOME = '<HarmonyOS SDK 目录>'
& '<DevEco Studio 安装目录>\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry assembleHap --no-daemon
```

构建输出位于 `entry/build/default/outputs/default/`。未签名 HAP 不能直接作为已签名安装包使用。

## 回归检查

检查脚本位于 `scripts/`，使用 Node.js 运行，例如：

```powershell
node scripts/check-foundation-architecture.cjs
node scripts/check-arkui-architecture.cjs
```

部分脚本依赖 DevEco Studio 自带的 TypeScript 模块。离线检查和成功构建不证明设备 UI、签名安装或 Pinterest 线上服务已经通过验收。

## 仓库范围

项目源码、资源、工程配置和回归脚本纳入版本控制。`docs/`、本地诊断、备份、SDK 路径、签名材料及构建和依赖产物保留在开发机，不上传到仓库。
