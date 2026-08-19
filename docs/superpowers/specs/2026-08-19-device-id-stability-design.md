# 设备标识加固（deviceId 稳定性）设计文档

> **目标**：让 app 的设备唯一标识（deviceId）在「卸载重装」场景下保持稳定，后端据此沿用旧数据，避免用户重装后数据被隔离丢失。

## 背景与根因

当前用户身份由 `deviceId` 决定，后端所有数据以 `deviceId` 为关联键（`device.service.ts` 按 `deviceId` 查库，查到则 `isNewDevice: false` 返回既有数据）。因此只要 `deviceId` 稳定，卸载重装本就不会丢数据。

查证 CPF 移植版 `device_info_plus 9.1.2` 鸿蒙端源码后发现**根因**：

- 鸿蒙插件 `DeviceMethodHandler.ets` 只实现了 `getDeviceInfo`，返回字段含 `ODID` 等，**不含 `id`（ANDROID_ID）**、也不实现 `getAndroidDeviceInfo`/`getIosDeviceInfo`。
- Dart 侧 `DeviceInfoPlugin().androidInfo` 实际是把 `deviceInfo()` 的返回 map 包成 `AndroidDeviceInfo`，其 `id` 读的是 key `'id'`——鸿蒙返回无此 key，故 `id` 为 null。
- 现有 `defaultResolveDeviceId` 的鸿蒙分支 `return info.id` 得到 null 走 catch，最终回退到 `fallback-${时间戳}`。

**结果**：鸿蒙上每次注册的 deviceId 都是新的「时间戳兜底」值。同一安装内靠 sqflite 本地复用维持数据，**重装即本地清空 → 重新采集 → 新的时间戳 → 后端判为新设备 → 数据隔离丢失**。此问题影响所有重装的鸿蒙用户，与本项目「卸载重装丢数据」的现象完全吻合。

## 平台标识可用性

| 平台 | 首选稳定标识 | 来源 | 卸载重装稳定性 |
|---|---|---|---|
| 鸿蒙 (ohos) | `ODID` | `DeviceInfoPlugin().ohosInfo.odID` | 稳定（按设备+应用开放标识，恢复出厂时重置） |
| Android | `ANDROID_ID` | `DeviceInfoPlugin().androidInfo.id` | 稳定（同签名、未恢复出厂） |
| iOS | `identifierForVendor` | `DeviceInfoPlugin().iosInfo.identifierForVendor` | 重装稳定；同厂商 App 全删才重置 |
| 兜底（聚合哈希） | 稳定硬件属性哈希 | `manufacture|brand|productModel` 等 | 稳定（只要任一属性可取） |
| 最后兜底 | 本地持久化 UUID | 无 OS 标识 + 无本地记录 | 重装会变（物理无解） |

## 设计决策

### 1. 鸿蒙路径改用 ODID
将 `defaultResolveDeviceId` 鸿蒙分支由 `androidInfo.id`（恒为 null）改为读取 `DeviceInfoPlugin().ohosInfo.odID`，并校验非空。

### 2. Android / iOS 保持首选标识，但增加非空校验
Android 仍需 `androidInfo.id`；iOS 需 `identifierForVendor`。当为空/采集失败时进入聚合哈希，而非直接掉入时间戳兜底。

### 3. 聚合哈希兜底（确定性）
当首选平台标识拿不到时，把稳定硬件属性 `[manufacture, brand, productModel]`（鸿蒙）或 `[manufacturer, brand, model, product]`（Android）中非空值拼接，跑 **FNV-1a 64 位哈希**（不引入新依赖，可复现、跨实例稳定），得到确定性 deviceId。任一稳定属性可用即可保证重装不变。

### 4. 最后兜底（仅无 OS 标识且无本地记录时）
返回一个本地持久化的 UUID（沿用现有逻辑，生成后由 `AuthController.save` 落库）。该场景 OS 未暴露任何稳定标识，物理上无法跨重装确定，纳入已知局限，交由后续「账号恢复（二维码/邮箱）」兜底。

### 5. 接口与签名不变
`defaultResolveDeviceId` 仍返回 `Future<String>`；`AuthController` 及调用方无需改动。已有的「注册前优先复用本地已存 deviceId」逻辑保留，作为第一道防线。

## 数据结构与文件影响

- **修改**：`lumira_app_flutter/lib/core/auth/auth_controller.dart`
  - 新增纯函数 `fnv1a64Hex(List<String> parts)`（可单测）。
  - 新增 `_resolveAndroidOrOhos()`：内部按 `Platform.operatingSystem` 分支取 ODID / ANDROID_ID。
  - 重写 `defaultResolveDeviceId` 平台分支，串进聚合哈希。
- **新增测试**：`lumira_app_flutter/test/core/auth/device_id_resolver_test.dart`（或并入 `auth_controller_test.dart`）
  - ODID 路径、ANDROID_ID 路径、identifierForVendor 路径。
  - 聚合哈希确定性：相同属性输入 → 相同 id；缺部分属性时仍确定。
  - 最后兜底返回非空、且非确定值。
- 不涉及后端 `lumira-server`、后台 `admin` 改动。

> 说明：鸿蒙 `ohosInfo` 字段明确来自本插件输出，测试中通过注入 DeviceInfoPlatform 或抽象采集函数来 mock，不依赖真机。

## 错误处理

- 采集 `ohosInfo`/`androidInfo`/`iosInfo` 任一抛异常 → 进入聚合哈希（而非直接时间戳兜底）。
- 聚合哈希所有属性都为空 → 本地 UUID 兜底（现状逻辑保留）。
- 不更改注册流程、不更改 `AuthController` 状态机、不触发并发注册相关问题。

## 测试与验收

- `flutter analyze` 无新增告警。
- 单元测试覆盖上表各分支，验证「卸载重装 → 重新采集 → 上报相同 deviceId」。
- 组成一个 Dart 端自包含改动，不触碰后端/后台，可直接提交；提交后 CI `flutter-ci.yml` 跑 analyze + test。

## 不做的事（YAGNI）

- 不做后端数据模型改造（暂不引入账号实体、多设备表）。
- 不做「二维码保存账号 / 邮箱绑定找回」——这部分仅在设备标识物理无法确定（换机/出厂/彻底无 OS 标识）时才有价值，后续单独立项。
- 不引入新依赖（自实现 FNV-1a）。