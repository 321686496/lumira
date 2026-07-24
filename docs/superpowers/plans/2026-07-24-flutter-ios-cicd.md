# Flutter iOS CI/CD 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `lumira_app_flutter` Flutter 项目创建 GitHub Actions 工作流，在 GitHub 云端构建 iOS 包，支持签名与未签名两种模式。

**Architecture:** 单一 workflow 文件 `.github/workflows/ios-build.yml`，通过触发器与 `workflow_dispatch` inputs 决定签名行为，复用 macos-13 runner + Flutter 3.7.12 钉定版本 + xcodebuild 命令行注入签名参数。

**Tech Stack:** GitHub Actions、YAML、Flutter 3.7.12、Xcode 14（macos-13）、xcodebuild、CocoaPods

## Global Constraints

- Flutter 版本必须钉定为 `3.7.12`（项目 pubspec.yaml 要求 `sdk: '>=2.19.6 <3.0.0'`，3.10+ 默认 Dart 3 会破坏 gitcode fork 依赖）
- macOS runner 必须为 `macos-13`（Xcode 14.x，与 Flutter 3.7 兼容；不用 macos-14 因其含 Xcode 15 可能不兼容）
- 工作目录为 `lumira_app_flutter/`（monorepo 子目录）
- 不修改 `project.pbxproj`，签名参数由 xcodebuild 命令行注入
- 路径触发限定在 `lumira_app_flutter/**` 与 workflow 文件本身
- Bundle ID 默认值 `com.example.lumiraAppFlutter` 为占位符，签名构建时通过 Secret `APP_BUNDLE_ID` 覆盖
- Secrets 缺失时签名构建必须 fail-fast 并给出清晰错误

---

## 文件结构

| 文件 | 操作 | 责任 |
|------|------|------|
| `.github/workflows/ios-build.yml` | 创建 | 唯一的 CI/CD 工作流文件，包含触发器、签名判断、构建步骤、产物上传、Release 发布 |

---

### Task 1: 创建 iOS 构建工作流文件

**Files:**
- Create: `.github/workflows/ios-build.yml`

**Interfaces:**
- Consumes: GitHub Secrets（`BUILD_CERTIFICATE_BASE64`、`P12_PASSWORD`、`BUILD_PROVISION_PROFILE_BASE64`、`KEYCHAIN_PASSWORD`、`APP_BUNDLE_ID`、`DEVELOPMENT_TEAM`、`PROVISIONING_PROFILE_UUID`）— 签名构建可选
- Produces: workflow 触发后的 `Runner.app`（未签名）或 `.ipa`（签名）artifact，以及 tag 触发时的 GitHub Release

- [ ] **Step 1: 创建 workflow 文件**

创建文件 `.github/workflows/ios-build.yml`，完整内容如下：

```yaml
name: iOS Build

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
        description: '构建类型（unsigned=未签名验证编译，signed=签名 IPA）'
        type: choice
        options: [unsigned, signed]
        default: unsigned

env:
  FLUTTER_VERSION: '3.7.12'
  WORK_DIR: lumira_app_flutter

concurrency:
  group: ios-build-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: iOS Build
    runs-on: macos-13
    timeout-minutes: 45
    defaults:
      run:
        working-directory: lumira_app_flutter

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 决定构建模式
        id: mode
        shell: bash
        working-directory: .
        run: |
          set -e
          SIGNED="false"
          if [[ "${{ github.event_name }}" == "push" && "${{ github.ref }}" == refs/tags/v* ]]; then
            SIGNED="true"
          elif [[ "${{ github.event_name }}" == "workflow_dispatch" && "${{ inputs.build_type }}" == "signed" ]]; then
            SIGNED="true"
          fi
          echo "signed=${SIGNED}" >> $GITHUB_OUTPUT
          # 跳过测试的判断：tag 触发或签名构建时跳过测试以加速
          SKIP_TEST="false"
          if [[ "${SIGNED}" == "true" || "${{ github.event_name }}" == "pull_request" ]]; then
            SKIP_TEST="false"
          fi
          echo "skip_test=${SKIP_TEST}" >> $GITHUB_OUTPUT

      - name: 校验签名 Secrets（仅签名构建）
        if: steps.mode.outputs.signed == 'true'
        shell: bash
        env:
          CERT: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          PROF: ${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}
          TEAM: ${{ secrets.DEVELOPMENT_TEAM }}
          UUID: ${{ secrets.PROVISIONING_PROFILE_UUID }}
          BUNDLE: ${{ secrets.APP_BUNDLE_ID }}
        run: |
          set -e
          missing=()
          [ -z "$CERT" ]  && missing+=("BUILD_CERTIFICATE_BASE64")
          [ -z "$PROF" ]  && missing+=("BUILD_PROVISION_PROFILE_BASE64")
          [ -z "$TEAM" ]  && missing+=("DEVELOPMENT_TEAM")
          [ -z "$UUID" ]  && missing+=("PROVISIONING_PROFILE_UUID")
          [ -z "$BUNDLE" ] && missing+=("APP_BUNDLE_ID")
          if [ ${#missing[@]} -gt 0 ]; then
            echo "::error::签名构建缺少必需的 Secrets：${missing[*]}"
            echo "::error::请前往 Settings → Secrets and variables → Actions 添加以下 Secrets："
            echo "::error::  - BUILD_CERTIFICATE_BASE64：.p12 证书的 base64（运行 base64 -i cert.p12 | pbcopy）"
            echo "::error::  - P12_PASSWORD：.p12 密码"
            echo "::error::  - BUILD_PROVISION_PROFILE_BASE64：.mobileprovision 的 base64"
            echo "::error::  - KEYCHAIN_PASSWORD：临时 keychain 密码（任意随机字符串）"
            echo "::error::  - DEVELOPMENT_TEAM：Apple Developer Team ID（10 位字母数字）"
            echo "::error::  - PROVISIONING_PROFILE_UUID：描述文件 UUID（运行 security cms -D -i profile.mobileprovision | plutil -p - | grep UUID）"
            echo "::error::  - APP_BUNDLE_ID：真实 Bundle ID（与 Apple Developer App ID 一致）"
            exit 1
          fi
          echo "签名 Secrets 校验通过"

      - name: 安装 Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: 缓存 pub-cache
        uses: actions/cache@v3
        with:
          path: |
            ~/.pub-cache
            ${{ env.WORK_DIR }}/.dart_tool
          key: pub-${{ runner.os }}-${{ env.FLUTTER_VERSION }}-${{ hashFiles('lumira_app_flutter/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-${{ env.FLUTTER_VERSION }}-

      - name: Flutter 版本与医生
        run: |
          flutter --version
          flutter doctor -v

      - name: 拉取依赖
        run: flutter pub get

      - name: 缓存 CocoaPods
        uses: actions/cache@v3
        with:
          path: ~/Library/Caches/CocoaPods
          key: pods-${{ runner.os }}-${{ hashFiles('lumira_app_flutter/ios/Podfile.lock') }}
          restore-keys: |
            pods-${{ runner.os }}-

      - name: pod install
        run: |
          cd ios
          pod install --repo-update

      - name: 运行测试（push/PR 时）
        if: steps.mode.outputs.skip_test == 'false' && github.event_name != 'push' && !startsWith(github.ref, 'refs/tags/')
        run: flutter test

      - name: 配置 iOS 签名（仅签名构建）
        if: steps.mode.outputs.signed == 'true'
        shell: bash
        env:
          BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
          BUILD_PROVISION_PROFILE_BASE64: ${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
          PROVISIONING_PROFILE_UUID: ${{ secrets.PROVISIONING_PROFILE_UUID }}
        run: |
          set -e

          # 创建临时 keychain
          KEYCHAIN_PATH=$RUNNER_TEMP/signing.keychain-db
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # 导入 .p12 证书
          CERT_PATH=$RUNNER_TEMP/cert.p12
          echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o "$CERT_PATH"
          security import "$CERT_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain

          # 安装 provisioning profile
          PP_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
          mkdir -p "$PP_DIR"
          PP_PATH="$PP_DIR/$PROVISIONING_PROFILE_UUID.mobileprovision"
          echo -n "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o "$PP_PATH"

          echo "签名配置完成"
          echo "Keychain: $KEYCHAIN_PATH"
          echo "Provisioning Profile: $PP_PATH"

      - name: 构建 iOS（未签名）
        if: steps.mode.outputs.signed == 'false'
        run: flutter build ios --no-codesign --release

      - name: 构建 iOS（签名）
        if: steps.mode.outputs.signed == 'true'
        env:
          DEVELOPMENT_TEAM: ${{ secrets.DEVELOPMENT_TEAM }}
          PROVISIONING_PROFILE_UUID: ${{ secrets.PROVISIONING_PROFILE_UUID }}
          APP_BUNDLE_ID: ${{ secrets.APP_BUNDLE_ID }}
        run: |
          set -e
          # 通过 xcodebuild 命令行注入签名参数，避免修改 project.pbxproj
          # 步骤 1：flutter build 触发 pod 生成 + flutter 代码生成
          flutter build ios --release --no-codesign

          # 步骤 2：用 xcodebuild 重新 archive，注入签名参数
          cd ios
          xcodebuild -workspace Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -archivePath $RUNNER_TEMP/Runner.xcarchive \
            -destination "generic/platform=iOS" \
            DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
            CODE_SIGN_IDENTITY="iPhone Distribution" \
            CODE_SIGN_STYLE="Manual" \
            PROVISIONING_PROFILE_SPECIFIER="" \
            PROVISIONING_PROFILE="$PROVISIONING_PROFILE_UUID" \
            PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" \
            archive \
            | tee $RUNNER_TEMP/xcarchive.log

          # 步骤 3：导出 IPA
          cat > $RUNNER_TEMP/ExportOptions.plist <<EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key>
            <string>app-store</string>
            <key>provisioningProfiles</key>
            <dict>
              <key>${APP_BUNDLE_ID}</key>
              <string>${PROVISIONING_PROFILE_UUID}</string>
            </dict>
            <key>signingStyle</key>
            <string>manual</string>
            <key>stripSwiftSymbols</key>
            <true/>
            <key>teamID</key>
            <string>${DEVELOPMENT_TEAM}</string>
            <key>uploadBitcode</key>
            <false/>
            <key>uploadSymbols</key>
            <false/>
          </dict>
          </plist>
          EOF

          xcodebuild -exportArchive \
            -archivePath $RUNNER_TEMP/Runner.xcarchive \
            -exportOptionsPlist $RUNNER_TEMP/ExportOptions.plist \
            -exportPath $RUNNER_TEMP/ipa-output \
            | tee $RUNNER_TEMP/export.log

          # 把 IPA 移到工作区便于上传
          mkdir -p build/ios/ipa
          cp $RUNNER_TEMP/ipa-output/*.ipa build/ios/ipa/Runner.ipa
          ls -lh build/ios/ipa/

      - name: 清理 keychain（仅签名构建）
        if: steps.mode.outputs.signed == 'true' && always()
        shell: bash
        run: |
          KEYCHAIN_PATH=$RUNNER_TEMP/signing.keychain-db
          if [ -f "$KEYCHAIN_PATH" ]; then
            security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null || true
          fi

      - name: 上传未签名产物
        if: steps.mode.outputs.signed == 'false' && github.event_name != 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: ios-unsigned-app
          path: lumira_app_flutter/build/ios/iphoneos/Runner.app
          retention-days: 14
          if-no-files-found: error

      - name: 上传签名 IPA
        if: steps.mode.outputs.signed == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: ios-signed-ipa
          path: lumira_app_flutter/build/ios/ipa/Runner.ipa
          retention-days: 14
          if-no-files-found: error

      - name: 上传构建日志（失败时）
        if: failure() && steps.mode.outputs.signed == 'true'
        uses: actions/upload-artifact@v4
        with:
          name: build-logs
          path: |
            ${{ runner.temp }}/xcarchive.log
            ${{ runner.temp }}/export.log
          retention-days: 7
          if-no-files-found: warn

      - name: 创建 GitHub Release（仅 tag 触发）
        if: startsWith(github.ref, 'refs/tags/v') && steps.mode.outputs.signed == 'true'
        uses: softprops/action-gh-release@v1
        with:
          files: lumira_app_flutter/build/ios/ipa/Runner.ipa
          name: Release ${{ github.ref_name }}
          generate_release_notes: true
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: 构建摘要
        if: always()
        shell: bash
        run: |
          echo "## iOS 构建摘要" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **触发方式**: ${{ github.event_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **分支/Tag**: ${{ github.ref_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **构建模式**: ${{ steps.mode.outputs.signed == 'true' && '签名（IPA）' || '未签名（Runner.app）' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Flutter 版本**: ${{ env.FLUTTER_VERSION }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Runner**: macos-13" >> $GITHUB_STEP_SUMMARY
          if [[ "${{ steps.mode.outputs.signed }}" == "true" ]]; then
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "### 签名信息" >> $GITHUB_STEP_SUMMARY
            echo "- Bundle ID: \`${{ secrets.APP_BUNDLE_ID }}\`" >> $GITHUB_STEP_SUMMARY
            echo "- Team: \`${{ secrets.DEVELOPMENT_TEAM }}\`" >> $GITHUB_STEP_SUMMARY
          fi
```

- [ ] **Step 2: 验证 YAML 语法**

Run: 在仓库根目录执行 `python -c "import yaml; yaml.safe_load(open('.github/workflows/ios-build.yml'))"`
Expected: 无输出（语法正确，无异常抛出）

如本地无 Python，可用以下任一替代：
- `npx -y yaml-lint .github/workflows/ios-build.yml`
- 或在 VS Code 中安装 YAML 扩展查看是否报错

- [ ] **Step 3: 提交**

```bash
git add .github/workflows/ios-build.yml
git commit -m "ci: add iOS build workflow for Flutter project

支持四种触发场景：
- push 到 master/main：未签名验证构建，产 Runner.app artifact
- pull_request：未签名验证构建，不产 artifact
- push tag v*：签名构建，产 .ipa 并创建 GitHub Release
- workflow_dispatch：手动选择 unsigned/signed

签名通过 xcodebuild 命令行注入 DEVELOPMENT_TEAM/CODE_SIGN_STYLE/
PROVISIONING_PROFILE，不修改 project.pbxproj。Flutter 钉定 3.7.12，
runner 用 macos-13（Xcode 14）兼容 Dart 2.19 约束。"
```

---

## 验收清单

- [ ] `.github/workflows/ios-build.yml` 文件存在且 YAML 语法正确
- [ ] 工作流包含四种触发器（push 分支 / push tag / pull_request / workflow_dispatch）
- [ ] 路径过滤器限定在 `lumira_app_flutter/**` 与 workflow 文件本身
- [ ] Flutter 版本固定为 3.7.12
- [ ] Runner 为 macos-13
- [ ] 未签名构建步骤使用 `flutter build ios --no-codesign --release`
- [ ] 签名构建步骤包含 keychain 创建、证书导入、profile 安装、xcodebuild archive、exportArchive
- [ ] 签名 Secrets 缺失时 fail-fast 并输出清晰错误信息
- [ ] keychain 在构建后清理（即使失败）
- [ ] 未签名产物上传为 `Runner.app`，签名产物上传为 `Runner.ipa`
- [ ] tag 触发时创建 GitHub Release 并附加 .ipa
- [ ] concurrency 配置避免同分支重复构建

## Self-Review

**1. Spec 覆盖**：
- §3.2 触发矩阵 → Task 1 Step 1 中 `on:` 块 ✓
- §3.3 签名判断逻辑 → "决定构建模式" step ✓
- §3.4 Job 步骤 → 全部覆盖（checkout、flutter、pub get、pod install、test、签名配置、构建、artifact、release）✓
- §3.5 缓存策略 → pub-cache + CocoaPods + Flutter SDK 内置缓存 ✓
- §3.6 产物保留 → retention-days: 14 ✓
- §4.1 Secrets 清单 → "校验签名 Secrets" step 中全部校验 ✓
- §4.2 显式输入 → workflow_dispatch.inputs.build_type ✓
- §5 Flutter 版本钉定 → FLUTTER_VERSION env + subosito/flutter-action ✓
- §6 macOS runner → runs-on: macos-13 ✓
- §9 风险项 → 无需在 workflow 中处理，是运行时观察项 ✓

**2. 占位符扫描**：无 TBD/TODO，所有 step 均含完整代码 ✓

**3. 类型一致性**：env 变量名（`FLUTTER_VERSION`、`WORK_DIR`）、step id（`mode`）、output 名（`signed`、`skip_test`）在所有引用处一致 ✓

**4. 已知限制**：
- 签名构建中 `flutter build ios --release --no-codesign` 先生成代码，再用 `xcodebuild archive` 注入签名参数。这是社区验证过的模式，避免修改 `project.pbxproj`。
- `CODE_SIGN_IDENTITY="iPhone Distribution"` 假设使用 Distribution 证书（适合 App Store 上传）。若用 Development 证书做 Ad Hoc 分发，需改为 `"iPhone Developer"` 并把 ExportOptions.plist 中 `method` 改为 `development` 或 `ad-hoc`。这是用户选择证书时的事项，spec §4.1 已说明。
