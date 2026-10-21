<p align="center">
  <img src="./AppScope/resources/base/media/pinmony_logo.jpg" width="160" alt="Pinmony app icon">
</p>

<h1 align="center">Pinmony</h1>

<p align="center">
  <a href="./README.zh-CN.md">中文</a> | <a href="./README.en.md">English</a>
</p>

Pinmony is a personal-interest HarmonyOS app built for learning, technical research, interface exploration, and mobile experience testing. It reads pages or resource data publicly returned by the target website through the current login session, and presents a native interface with ArkUI.

## Features

- Browse recommended Pins, boards, and category content on the home page
- Search for Pins, categories, topics, and related content, including selecting a photo for image search
- View Pin details, authors, comments, related recommendations, and supported videos; select an image region in details to find related content
- Browse profiles, saved content, boards, and the inbox; search your own Pins and view recent searches on your profile
- Switch between messages and contacts in the inbox, and search by username
- Share Pins, boards, and contacts; share entries follow the flow of each page
- Use the app UI in system language, Chinese, or English; app-owned copy switches immediately and the language preference is saved
- Configure notifications, social permissions, video autoplay, display preferences, and export sanitized runtime logs in Settings
- Use adaptive layouts on phones and tablets
- Preserve page state, scroll position, navigation hierarchy, and loading state

## Requirements

| Requirement | Details |
| --- | --- |
| Device and system | HarmonyOS 6.1.1 (API 24) or later |
| Development environment | DevEco Studio, ArkTS, Hvigor, and the HarmonyOS SDK |
| Network and account | Access to Pinterest and sign-in with an account and password in the app. Google sign-in is currently unavailable. |

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
- `common_foundation`: Chinese and English resources and preferences, caching, logging, task registration, and base runtime capabilities

## Language Resources and Preferences

App-owned copy is maintained in `common_foundation/src/main/resources/{base,zh_CN,en_US}/element/string.json` with stable resource names. The language selector is available in Display Settings and supports System, Chinese, and English; the preference is restored after restart. Website and user content remains in its original form, and only confirmed fixed controls use localized copy based on semantic identifiers.

## Building the HAP

Configure the local HarmonyOS SDK in PowerShell, then run:

```powershell
$env:DEVECO_SDK_HOME = '<HarmonyOS SDK directory>'
$env:JAVA_HOME = '<DevEco Studio installation directory>\jbr'
& '<DevEco Studio installation directory>\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry assembleHap --no-daemon
```

## Privacy and Sessions

Pinmony uses ArkWeb to retain the current website login session. Native networking reads the required Cookies temporarily for each request and synchronizes Set-Cookie values back to the current ArkWeb session when needed. Cookies, CSRF values, account identifiers, access tokens, and response credentials are not written to source code, the repository, or persistent logs.

Runtime logs contain sanitized diagnostic information only and do not record Cookies, CSRF values, account tokens, request bodies, or complete sensitive URLs. Settings provides an entry point for exporting runtime logs.

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
