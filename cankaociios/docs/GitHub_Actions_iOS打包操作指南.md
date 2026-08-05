# FitTrack iOS 打包操作指南（GitHub Actions）

> 本文档说明如何使用 GitHub Actions 代替 Codemagic 构建 iOS 安装包（IPA），
> 以及首次需要完成的配置。Bundle ID 为 `com.lt.lifttrack`。

---

## 1. 工作原理

仓库根目录的 `.github/workflows/ios-build.yml` 定义了 iOS 构建流水线：

| 触发方式 | 手动运行（Actions 页面点按钮） |
|---|---|
| 运行环境 | GitHub 托管 macOS 14 runner（M 系列芯片） |
| Flutter 版本 | 3.7.12 |
| 产物 | `Runner.app` / `Runner.ipa` / `.dSYM.zip`（debug symbols） |

### 三种运行模式

| 模式 | 参数 | 是否需配置 Secrets | 产物 |
|---|---|---|---|
| 仅验证编译 | `sign=false`（默认） | 不需要 | `Runner.app` |
| 签名导出 IPA | `sign=true` | 需要 4 个签名 Secrets | `Runner.ipa` + `dSYM.zip` |
| 签名 + 上传 TestFlight | `sign=true` + `upload_to_testflight=true` | 签名 Secrets + 3 个 API Key Secrets | IPA 自动上传至 App Store Connect |

---

## 2. 前置条件

- [ ] GitHub 账号，仓库已推送（`github` 远程：`git@github.com:321686496/fittrack.git`）
- [ ] 已付费的 Apple Developer 账号（¥99/年）
- [ ] 任意电脑（Windows / Mac / Linux 均可，无需 Mac 设备）
- [ ] OpenSSL 命令行工具（用于生成证书；Windows 可用 Git Bash 自带，或安装 [Win64 OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)）

> 构建本身完全在 GitHub 托管的 macOS 服务器上完成，本地只需要做一次性的
> 证书文件生成和网页配置，**全程不需要 Mac 设备**。

---

## 3. 一次性配置（首次做，之后不需要重复）

### 3.1 在 Apple Developer 后台创建 App ID

1. 打开 [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → 新建 App ID：
   - 类型：App
   - Bundle ID：`com.lt.lifttrack`（必须与工程一致）
   - 按需勾选 Capabilities（如 Push Notifications、App Groups）

### 3.2 用 OpenSSL 生成私钥与证书签名请求（CSR）

> 不需要 Mac 钥匙串。在 Windows（Git Bash / PowerShell）或任意系统执行：

```bash
# 生成私钥 distribution.key 和证书签名请求 distribution.csr
openssl req -new -newkey rsa:2048 -nodes \
  -keyout distribution.key -out distribution.csr \
  -subj "/CN=FitTrack Distribution/O=你的公司名/C=CN"
```

### 3.3 申请证书并合并为 .p12

1. 打开 [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → 新建 App ID：
   - 类型：App
   - Bundle ID：`com.lt.lifttrack`（必须与工程一致）
   - 按需勾选 Capabilities（如 Push Notifications、App Groups）
3. **Certificates** → 新建 → **Apple Distribution**
4. 上传上一步生成的 `distribution.csr`，下载 `.cer` 证书文件
5. 将 `.cer` 与本地私钥合并为 `.p12`（CI 签名需要包含私钥的 .p12）：

```bash
# .cer 是 DER 格式，先转为 PEM
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM

# 合并私钥 + 证书为 .p12（会提示设置导出密码，务必记住，填入 P12_PASSWORD）
# 必须加 -legacy！OpenSSL 3.x 默认用 AES-256/SHA-256 新式算法，
# Apple 的 security 工具不兼容，会导致 CI 报 "MAC verification failed (wrong password)"
openssl pkcs12 -export -out distribution.p12 \
  -inkey distribution.key -in distribution.pem -legacy
```

> 如果 `-legacy` 不可用（OpenSSL 1.1.1），用显式指定旧式算法代替：
> `openssl pkcs12 -export -out distribution.p12 -inkey distribution.key -in distribution.pem -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1`

### 3.4 创建 Provisioning Profile

1. Apple Developer → **Profiles** → 新建
2. 类型选 **App Store Connect**（若想 Ad Hoc 内测分发，选 **Ad Hoc** 并勾选目标设备）
3. 选择 App ID：`com.lt.lifttrack`
4. 勾选你的 Distribution 证书
5. 下载生成的 `.mobileprovision` 文件

### 3.5 对文件做 base64 编码

**方式一：Windows PowerShell**（推荐）

```powershell
# 证书 .p12
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12"))

# Provisioning Profile
[Convert]::ToBase64String([IO.File]::ReadAllBytes("com.lt.lifttrack.mobileprovision"))
```

**方式二：Mac / Linux 终端**

```bash
base64 -i distribution.p12 | pbcopy        # Mac：结果直接进剪贴板
base64 -i distribution.p12 -o cert.p12.b64 # 或写入文件后 cat 查看
cat cert.p12.b64
```

把输出的完整 base64 字符串复制到对应的 GitHub Secret。

### 3.6 创建 App Store Connect API Key（仅需上传 TestFlight 时）

1. 打开 [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **用户和访问** → **密钥（Keys）** → **App Store Connect API**
2. 生成新密钥，角色选 **App Manager**（或 Admin）
3. **立即下载 `.p8` 文件**（只能下载一次，请妥善保存）
4. 记录两个值：
   - **Key ID**（形如 `XXXXXXXXXX`）
   - **Issuer ID**（形如 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`，页面上方可查看）
5. 对 `.p8` 文件做 base64 编码：

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))
```

```bash
# Mac / Linux
base64 -i AuthKey_XXXXXXXXXX.p8
```

### 3.7 配置 GitHub Secrets

打开 GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**。

| Secret 名称 | 内容 | 必填场景 |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | `.p12` 文件的 base64 内容 | `sign=true` |
| `P12_PASSWORD` | 导出 .p12 时设置的密码 | `sign=true` |
| `PROVISIONING_PROFILE_BASE64` | `.mobileprovision` 的 base64 内容 | `sign=true` |
| `TEAM_ID` | Apple Developer Team ID（10 位，如 `ABCD1234EF`，在账号页可查） | `sign=true` |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID | 上传 TestFlight |
| `APP_STORE_CONNECT_ISSUER_ID` | API Key Issuer ID | 上传 TestFlight |
| `APP_STORE_CONNECT_KEY_BASE64` | `.p8` 文件的 base64 内容 | 上传 TestFlight |

> **安全提示**：`.p12` 与 `.p8` 包含私钥，属于机密。base64 内容只能放进 GitHub Secrets，
> **不要**提交到仓库或分享给他人。

---

## 4. 每次构建的操作流程

### 4.1 推送代码到 GitHub

```bash
git push github master
```

### 4.2 手动触发构建

1. GitHub 仓库 → **Actions** 页 → 左侧选择 **iOS Build**
2. 点击 **Run workflow** 按钮
3. 选择参数：
   - 只想验证能否编译 → 两个参数都不勾，直接运行
   - 要生成可安装的 IPA → 勾选 **sign**
   - 要同时上传 TestFlight → 同时勾选 **sign** 和 **upload_to_testflight**
4. 点击 **Run workflow** 开始构建

### 4.3 查看构建日志

点击运行中的任务即可查看日志。常见阶段：

```
Checkout → Set up Flutter → Install dependencies → Patch OHOS fork packages
→ [sign=true] 签名准备（keychain/证书/Profile/ExportOptions）
→ Build iOS（no codesign / Build IPA）
→ [可选] Upload to TestFlight
```

> 流程内置了 **OHOS fork 插件兼容补丁**（`flutter_local_notifications` 等包在标准
> Flutter SDK 下需替换 `TargetPlatform.ohos`），自动执行，无需手动操作。

### 4.4 下载产物

构建成功后，在任务详情页底部 **Artifacts** 区域下载：

| 模式 | Artifact 名称 | 内容 |
|---|---|---|
| `sign=false` | `fittrack-ios-build` | `Runner.app`（未签名） |
| `sign=true` | `fittrack-ios-ipa` | `Runner.ipa` |
| `sign=true` | `fittrack-ios-dsym` | `Runner.dSYM.zip`（崩溃符号，上架/排查用） |

### 4.5 上传 TestFlight（若未在 workflow 中开启）

```text
方式一（推荐，无需 Mac）：重新运行 workflow，同时勾选 sign 和 upload_to_testflight，
CI 内的 macOS 服务器会自动完成上传。
```

上传成功后，打开 [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
**TestFlight** → 等待「正在处理」完成后即可添加测试员分发。

> 首次上传前需在 App Store Connect 中创建 App（Bundle ID `com.lt.lifttrack`）并填写
> 基础信息（名称、截图、隐私政策等），否则上传会提示 App 不存在。

---

## 5. 常见问题排查

| 现象 | 原因与处理 |
|---|---|
| 构建失败：`No profile found` / 签名错误 | 证书或 Profile 过期/不匹配。重新生成 Profile，更新对应 Secrets |
| 构建失败：`No signing certificate` | `BUILD_CERTIFICATE_BASE64` 或 `P12_PASSWORD` 配置错误。确认 .p12 含私钥、密码正确 |
| 上传 TestFlight 报 401/403 | API Key 权限不足或已失效。确认角色为 App Manager/Admin，重新生成 Key |
| 上传提示 App 不存在 | 未在 App Store Connect 创建 App。先创建应用（Bundle ID 一致） |
| 想分发到指定设备而非 TestFlight | 使用 **Ad Hoc** 类型 Profile（需在 3.4 选择 Ad Hoc 并勾选设备 UDID） |
| macOS 构建时长/费用 | private 仓库 macOS runner 按 10 倍计费（免费 2000 分钟 ≈ 200 分钟 macOS）。仓库设为 **public** 则 macOS 构建免费无限 |

---

## 6. Secrets 速查对照表

```
┌────────────────────────────────┬──────────────────────────────────────┐
│ Secret                          │ 生成来源                              │
├────────────────────────────────┼──────────────────────────────────────┤
│ BUILD_CERTIFICATE_BASE64        │ 钥匙串导出 .p12 → base64             │
│ P12_PASSWORD                    │ 导出 .p12 时设置的密码               │
│ PROVISIONING_PROFILE_BASE64     │ Apple Developer 下载 .mobileprovision│
│ TEAM_ID                         │ Apple Developer 账号页               │
│ APP_STORE_CONNECT_KEY_ID        │ App Store Connect 密钥页             │
│ APP_STORE_CONNECT_ISSUER_ID     │ App Store Connect 密钥页             │
│ APP_STORE_CONNECT_KEY_BASE64    │ 下载的 .p8 → base64                  │
└────────────────────────────────┴──────────────────────────────────────┘
```

---

## 7. 相关文件

- Workflow 定义：`.github/workflows/ios-build.yml`
- iOS 工程目录：`fittrack_flutter/ios/`
- Bundle ID：`com.lt.lifttrack`（`ios/Runner.xcodeproj/project.pbxproj` 与 workflow 中均已配置）
- 原 Codemagic 配置：`codemagic.yaml`（如需保留可不动）
