# Flutter iOS CI/CD 设计文档

- **日期**: 2026-07-24
- **主题**: 为 `lumira_app_flutter` Flutter 项目编写 GitHub Actions 云构建 iOS 包
- **状态**: 已批准（用户 2026-07-24 确认）

## 1. 背景与目标

### 1.1 项目背景

- Flutter 项目位于 monorepo 子目录 `lumira_app_flutter/`，与 uni-app 版本（`lumira-app/`）和 NestJS 服务端（`lumira-server/`）共存于同一仓库。
- 项目钉定 **Flutter 3.7.12 / Dart 2.19.6**（pubspec.yaml 中 `sdk: '>=2.19.6 <3.0.0'`），不可升级，否则触发 Dart 3 迁移破坏 Harmony 适配依赖。
- pubspec 中多个依赖走 gitcode.com 的 CPF-Flutter fork（如 `camerawesome_ohos`、`sqflite`、`permission_handler` 等）。这些 fork 仍保留 iOS 实现，理论上可在 iOS 上构建，但 CI 首次运行时需观察是否有 iOS 端兼容性问题。
- iOS 项目目标 `IPHONEOS_DEPLOYMENT_TARGET = 11.0`，Bundle ID 为占位符 `com.example.lumiraAppFlutter`，`project.pbxproj` 中未配置 `DEVELOPMENT_TEAM`，仅含默认 `CODE_SIGN_IDENTITY = "iPhone Developer"`。

### 1.2 目标

提供一条 GitHub Actions 云构建流水线，支持两种产物：

1. **未签名构建**：验证 iOS 编译通过，产出 `Runner.app`，无需 Apple 开发者账号。
2. **签名构建**：产出可安装的 `.ipa`，需 Apple 开发者账号 + 证书 + 描述文件。

### 1.3 非目标（YAGNI）

- 不做 Android 构建（仅 iOS）。
- 不引入 fastlane（保持透明、低学习成本；如未来需 TestFlight 自动上传再单独引入）。
- 不修改 `project.pbxproj`（签名参数由 CI 通过 `xcodebuild` 命令行注入，仓库保持中性）。
- 不引入第三方 CI 服务（Codemagic / Bitrise），坚持 GitHub 云构建。
- 不做 TestFlight / App Store Connect 自动上传（首期）。

## 2. 方案选型

| 维度 | 方案 A：单工作流 + 手动签名（**采用**） | 方案 B：Fastlane + match |
|------|--------------------------------|------------------------|
| 文件数量 | 1 个 workflow | workflow + Fastfile + Gemfile + match 仓库 |
| 学习成本 | 低（直接 xcodebuild） | 中 |
| 初始设置 | 上传 .p12 + .mobileprovision 到 Secrets | 需初始化 match 仓库 |
| 灵活性 | 直接改 YAML | 改 Fastfile 语法 |
| TestFlight | 需手动 xcrun altool | 一行 `pilot upload` |

**决策**：采用方案 A。直接、透明、好排查。如未来需要 TestFlight 自动上传，再单独加 fastlane lane。

## 3. 工作流设计

### 3.1 单文件策略

单一文件 `.github/workflows/ios-build.yml`，所有触发场景共用一个 job，通过 inputs 与 `secrets` 是否存在决定签名行为。

### 3.2 触发器

```yaml
on:
  push:
    branches: [master, main]
    tags: ['v*']
    paths:
      - 'lumira_app_flutter/**'
      - '.github/workflows/ios-build.yml'
  pull_request:
    branches: [master, main]
    paths:
      - 'lumira_app_flutter/**'
      - '.github/workflows/ios-build.yml'
  workflow_dispatch:
    inputs:
      build_type:
        description: '构建类型'
        type: choice
        options: [unsigned, signed]
        default: unsigned
```

**触发与产物矩阵**：

| 触发方式 | 签名 | 产物 | 上传 Release |
|---------|------|------|------------|
| push 分支 | 否 | Runner.app artifact（14 天） | 否 |
| pull_request | 否 | 无 artifact（仅验证编译） | 否 |
| push tag v* | 是 | .ipa artifact（14 天）+ Release | 是（附在 tag） |
| workflow_dispatch（unsigned） | 否 | Runner.app artifact | 否 |
| workflow_dispatch（signed） | 是 | .ipa artifact | 否 |

### 3.3 签名判断逻辑

```yaml
# 是否执行签名构建
- name: 决定构建模式
  id: mode
  run: |
    if [[ "${{ github.event_name }}" == "push" && "${{ github.ref }}" == refs/tags/v* ]]; then
      echo "signed=true" >> $GITHUB_OUTPUT
    elif [[ "${{ github.event_name }}" == "workflow_dispatch" && "${{ inputs.build_type }}" == "signed" ]]; then
      echo "signed=true" >> $GITHUB_OUTPUT
    else
      echo "signed=false" >> $GITHUB_OUTPUT
    fi
```

签名分支额外校验：若 `secrets.BUILD_CERTIFICATE_BASE64` 不存在则 fail-fast。

### 3.4 Job 执行步骤

**Job 运行环境**：`macos-13`（含 Xcode 14，兼容 Flutter 3.7；不用 macos-14 因其含 Xcode 15 可能与 Flutter 3.7 不兼容）。

```
1. Checkout（fetch-depth: 0，用于读取版本号）
2. 切换工作目录到 lumira_app_flutter/
3. 安装 Flutter 3.7.12（subosito/flutter-action，channel stable，固定版本）
4. flutter pub get
5.（仅 push 分支/PR）flutter test
6. pod install（cd ios && pod install --repo-update）
7. 分支判断：
   - 未签名：flutter build ios --no-codesign --release
   - 签名：
     a. 创建临时 keychain
     b. 解码 .p12 到 keychain
     c. 解码 .mobileprovision 到 ~/Library/MobileDevice/Provisioning Profiles/
     d. 通过 xcodebuild 命令行注入 DEVELOPMENT_TEAM / CODE_SIGN_STYLE / PROVISIONING_PROFILE_SPECIFIER
     e. flutter build ios --release
     f. xcodebuild -exportArchive 导出 .ipa
8. 上传 artifact
9.（仅 tag 触发）创建 GitHub Release 并附加 .ipa
```

### 3.5 缓存策略

- **Flutter SDK**：`subosito/flutter-action@v2` 内置缓存，按 `flutter-version` 哈希。
- **pub-cache**：`actions/cache@v3`，key 含 `pubspec.lock` 哈希。
- **CocoaPods**：`actions/cache@v3`，key 含 `ios/Podfile.lock` 哈希（首次构建后会生成）。

### 3.6 产物保留策略

- 未签名 `Runner.app`：14 天（默认）
- 签名 `.ipa`：14 天
- Tag Release：永久（附在 GitHub Release 上）

## 4. 配置项

### 4.1 GitHub Secrets（仅签名构建需要）

| Secret 名 | 说明 | 示例 |
|----------|------|------|
| `BUILD_CERTIFICATE_BASE64` | 开发者证书 `.p12` 的 base64 编码 | `base64 -i cert.p12` 输出 |
| `P12_PASSWORD` | `.p12` 密码 | 导出时设置的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision` 的 base64 编码 | `base64 -i profile.mobileprovision` 输出 |
| `KEYCHAIN_PASSWORD` | 临时 keychain 密码（任意值即可） | `random-string-12345` |
| `APP_BUNDLE_ID` | 真实 Bundle ID（默认占位符 `com.example.lumiraAppFlutter`，需改成实际 ID） | `com.lumira.app` |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID（10 位字母数字） | `ABCDE12345` |
| `PROVISIONING_PROFILE_UUID` | 描述文件 UUID（从 .mobileprovision 中读取） | `a1b2c3d4-...` |

### 4.2 显式输入（workflow_dispatch）

- `build_type`：`unsigned`（默认）或 `signed`

## 5. Flutter 版本钉定

`subosito/flutter-action@v2` 配置：

```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.7.12'
    channel: 'stable'
    cache: true
```

**为什么是 3.7.12**：pubspec.yaml 明确要求 `sdk: '>=2.19.6 <3.0.0'`，对应 Flutter 3.7.x 系列。3.10+ 默认 Dart 3，会破坏 CPF-Flutter fork 的依赖。3.7.12 是 3.7 系列最后一个稳定版。

## 6. macOS Runner 选择

- 使用 `macos-13`（Xcode 14.x）。
- **不用** `macos-14`（Xcode 15+，可能与 Flutter 3.7 有兼容问题，参考社区 issue）。
- **不用** `macos-12`（已逐步被 GitHub 淘汰）。

## 7. 待创建文件

1. `.github/workflows/ios-build.yml` — 主工作流（唯一需新建的代码文件）
2. 本设计文档（已存在）

## 8. 用户操作清单（首次运行签名构建前需完成）

1. 在 Apple Developer 后台创建/复用开发证书（Development 或 Distribution）。
2. 创建/复用 App ID（使用真实 Bundle ID，如 `com.lumira.app`）。
3. 创建 Provisioning Profile（Development 或 App Store）。
4. 导出 `.p12` 证书文件（设置一个密码）。
5. 下载 `.mobileprovision` 文件。
6. 用 `base64` 编码上述文件，连同密码、Team ID、UUID 一起填入 GitHub Secrets。
7. 修改 `APP_BUNDLE_ID` 为真实 Bundle ID（与 App ID 中一致）。

**未签名构建无需以上步骤**，可直接触发验证编译。

## 9. 风险与已知问题

1. **gitcode fork 的 iOS 兼容性**：CPF-Flutter fork 主要为 Harmony 适配，但保留 iOS 实现。首次 CI 运行时需观察 `pod install` 是否有原生插件报错。如有，需在 issue 中追踪。
2. **iOS 11.0 部署目标**：macOS 13 runner 的 Xcode 14 仍支持 iOS 11 部署目标。若未来 runner 升级到 Xcode 15，可能需将部署目标提到 12.0（Apple 已弃用 iOS 11）。
3. **Flutter 3.7 在新 macOS runner 上的可用性**：3.7.12 发布于 2023 年初，在 macos-13 上稳定运行。若 GitHub 强制升级 runner，可能需固定到 `macos-13` 大版本。
4. **首次 `pod install` 可能无 Podfile.lock**：缓存 key 用 `ios/Podfile.lock` 哈希，首次运行会 miss，后续命中。这是预期行为。

## 10. 验收标准

- [ ] 推送 commit 到 master 后，CI 自动触发并产出未签名 `Runner.app` artifact。
- [ ] 提交 PR 时 CI 跑 `flutter test` + 未签名构建（不产 artifact）。
- [ ] 手动触发 workflow，选 `unsigned` 时产 `Runner.app`，选 `signed` 时（Secrets 已配置）产 `.ipa`。
- [ ] 推送 `v1.0.0` tag 时，CI 产 `.ipa` 并自动创建 GitHub Release 附带该 `.ipa`。
- [ ] 未配置签名 Secrets 时，签名构建 fail-fast 并给出清晰错误提示。
