<p align="center">
  <img src="./AppScope/resources/base/media/pinmony_logo.jpg" width="160" alt="Pinmony app icon">
</p>

<h1 align="center">Pinmony</h1>

<p align="center">
  <a href="./README.zh-CN.md">中文</a> | <a href="./README.en.md">English</a>
</p>

Pinmony is a personal-interest HarmonyOS app built for learning, technical research, interface exploration, and mobile experience testing. Sign-in uses ArkWeb, while business screens after sign-in use native ArkUI. Some features depend on the active login session and Pinterest's internal same-origin resources, which are not official public APIs.

## Features

- **Discovery and search**: browse recommendations and categories; search Pins, boards, and topics, or search using photos, photo history, and selected image regions.
- **Pin viewing and interaction**: view images, videos, authors, comments, and related recommendations; zoom images, save Pins, comment, and share.
- **Profiles and boards**: browse profiles and saved content, search your own Pins, sort and merge boards, restore eligible deleted boards, and manage All Pins visibility.
- **Publishing and organization**: publish photos and website links, organize and move Pins, and reposition the board publish button by dragging it to an edge.
- **Messages and contacts**: browse inbox and chat messages, switch between messages and contacts, search contacts by username, and send Pins.
- **Recommendations and privacy**: browse recent activity by date and manage related recommendations, notifications, message permissions, mentions, and blocked accounts.
- **Display and playback**: configure immersive lighting and display preferences, with separate video autoplay controls for mobile data and Wi-Fi.
- **Languages and devices**: UI resources for Simplified Chinese, Traditional Chinese, US English, UK English, Japanese, and Korean, with phone and tablet layouts.
- **Runtime logs**: export and clear sanitized diagnostic logs to help report and investigate issues.

## Requirements

| Requirement | Details |
| --- | --- |
| Device and system | HarmonyOS 6.1.1 (API 24) or later |
| Network and account | Access to Pinterest and sign-in with an account and password in the app. Google sign-in is currently unavailable. |

Tablet layouts have been adapted but have not been tested on physical tablets. Correct layout and content display on all pages cannot be guaranteed. Please report display, overlap, or interaction issues through [GitHub Issues](https://github.com/Torotar/Pinmony/issues), including the device model, system version, screenshots, and steps to reproduce.

## Architecture

- `entry`: app entry, window lifecycle, login gate, root pages, routing, and cross-page coordination
- `feature_home`: home content, categories, pagination, caching, and home state
- `feature_search`: search discovery, image search, filters, results, categories, topics, and search state
- `feature_pin`: details, comments, related recommendations, media, saving, and sharing
- `feature_board`: board pages, board details, and board content
- `feature_profile`: profiles, saved content, personal content search, recent searches, publishing, and organization flows
- `feature_inbox`: inbox, combined messages and contacts page, conversation search, and notification-related pages
- `feature_settings`: settings, account information, language, notifications, social permissions, autoplay, display preferences, and sign-out flow
- `common_session`: login evidence, session, and credential adaptation
- `common_network`: native RCP transport and request lifecycle
- `common_ui`: reusable UI components and shared presentation state
- `common_foundation`: multilingual resources and preferences, caching, logging, task registration, and base runtime capabilities

## Language Resources and Preferences

App-owned copy uses stable resource names in `common_foundation/src/main/resources/{base,zh_CN,zh_TW,en_US,en_GB,ja,ko}/element/string.json`. UI resources are provided for Simplified Chinese, Traditional Chinese, US English, UK English, Japanese, and Korean. Preferences are restored after restart, and account language synchronization is integrated. Website and user content remains in its original form; only confirmed fixed controls use localized copy based on semantic identifiers.

Choose a language or follow the system under Settings → Display Settings. When a supported account language is read, the app synchronizes its UI language.

Some translations may be inaccurate or unnatural. Please report translation, text truncation, or display issues through [GitHub Issues](https://github.com/Torotar/Pinmony/issues), including the language and affected page.

### Release Build

Run this PowerShell command from the project root:

```powershell
./build-release.ps1 -DevEcoHome '<DevEco Studio installation directory>'
```

If the SDK is installed elsewhere, add `-SdkHome '<HarmonyOS SDK directory>'`. The script also accepts the `DEVECO_STUDIO_HOME` and `DEVECO_SDK_HOME` environment variables.

The output is `release/Pinmony-release-unsigned.hap`. The script verifies Release mode, `debug=false`, and the absence of Debug source maps. Signing and physical-device testing are separate steps.

### Standard Module Build

```powershell
$env:DEVECO_SDK_HOME = '<HarmonyOS SDK directory>'
$env:JAVA_HOME = '<DevEco Studio installation directory>\jbr'
& '<DevEco Studio installation directory>\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry assembleHap --no-daemon
```

## Privacy and Sessions

Pinmony uses ArkWeb to retain the current website login session. Native networking reads the required Cookies temporarily for each request and synchronizes Set-Cookie values back to the current ArkWeb session when needed. Cookies, CSRF values, account identifiers, access tokens, and response credentials are not written to source code, the repository, or persistent logs.

Runtime logs contain sanitized diagnostic information only and do not record Cookies, CSRF values, account tokens, request bodies, or complete sensitive URLs. Settings provides log export and clearing controls. Clearing in-app logs does not delete previously exported files.

## Disclaimer

This project is not affiliated with, partnered with, or authorized by Pinterest or its affiliates. The project uses the current ArkWeb login session to access Pinterest's internal same-origin resources. These resources are not Pinterest's official public APIs, and the project has no native OAuth flow or independent token lifecycle. The interfaces used by this project come from public pages or normal requests in the current login session and do not provide any means of bypassing access controls.

- This project does not access the target website's backend database, perform injection attacks, access resources without authorization, or bypass authorization.
- This project does not write Cookies, CSRF values, account identifiers, access tokens, or other credentials to source code, the repository, or persistent business logs; login session Cookies are stored by ArkWeb according to platform mechanisms.
- Users must comply with applicable laws and regulations, the target website's terms of service, and account rules.
- This project must not be used for illegal activity, infringement, bulk scraping, harassment, or disruption of the target website's normal operation.
- This project does not guarantee data completeness, accuracy, real-time availability, API stability, or continuous availability.
- Users are responsible for any account, data, device, or other consequences arising from use of this project.

Pinterest's name, trademarks, web design, images, videos, text, and resource responses belong to their respective rights holders and are not covered by this project's license. The project logo, third-party dependencies, and example resources may be subject to their own copyright or license terms.

## License

Pinmony source code is licensed under the Apache License 2.0; see [`LICENSE`](LICENSE) for the full text. Apache-2.0 applies only to the parts explicitly identified as project code and does not grant rights to Pinterest branding, website content, resource data, or third-party resources.
