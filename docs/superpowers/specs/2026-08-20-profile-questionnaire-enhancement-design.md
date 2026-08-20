# 个人中心完善 + 问卷新增性别与首次引导设计

> 日期：2026-08-20

## 1. 背景与目标

用户希望：

1. 完善个人中心页。
2. 问卷调查页新增「性别」一题。
3. 问卷只在**首次使用**时展示，**不在设置中常驻**。
4. 后续在**个人中心**修改：性别、喜欢拍什么、拍摄烦恼、摄影水平、想获得什么、常用拍摄场景、拍摄频率。
5. 修改的头像**在后端保存**，用户可**自定义头像**；名称、性别等**全部同步到数据库**。

### 数据定位（用户明确说明）

- 问卷提交的内容**单独存放在现有 `questionnaire_records` 表**，用于**数据分析**（用户为何选择 App、初期有什么烦恼，便于后续针对性调整 App）。该表**只追加、不修改**。
- 问卷首次提交时，把其中的性别 + 6 项偏好**同步一份到 `user_profiles`**（个人中心偏好的单一数据源）。
- 在个人中心后续填写的偏好**只更新 `user_profiles`**，**不改动** `questionnaire_records`。

---

## 2. 数据模型（后端）

### 2.1 `questionnaire_records` — 保持不变
仅追加；问卷提交写这里。**新增性别字段随答案进 `answersJson`**（后端 DTO 增加 `gender`），表结构无需改动。

### 2.2 `user_profiles` — 扩展为"当前可编辑个人资料"

新增字段：

| 字段 | 列名 | 类型 | 说明 |
|---|---|---|---|
| 性别 | `gender` | varchar, 可空 | `male` / `female` / `prefer_not` |
| 喜欢拍什么 | `favorite_categories_json` | json/text 可空 | 值集合数组 |
| 拍摄烦恼 | `pain_points_json` | json/text 可空 | 值集合数组 |
| 摄影水平 | `skill_level` | varchar 可空 | `beginner`/`intermediate`/`advanced`/`pro` |
| 想获得什么 | `expectations_json` | json/text 可空 | 值集合数组 |
| 常用拍摄场景 | `common_scenes_json` | json/text 可空 | 值集合数组 |
| 拍摄频率 | `shoot_frequency` | varchar 可空 | `rarely`/`monthly`/`weekly`/`daily` |
| 自定义头像 | `avatar_url` | varchar 可空 | 后端 `/uploads/...` URL；为空则用 `avatar_seed` |

沿用现有 `device_id`（主键）、`username`、`avatar_seed`、`updated_at`。

**头像逻辑**：`avatar_url` 有值 → 用后端图；为空 → 用 `avatar_seed`（picsum）。

**联动规则**：
- 问卷首次提交 → 后端在写 `questionnaire_records` 的同时，把性别 + 6 项 upsert 进 `user_profiles`（**只写这些偏好字段，不覆盖 username/avatar**）。
- 个人中心编辑 → `PATCH /profile` 仅更新 `user_profiles`，绝不触碰 `questionnaire_records`。

---

## 3. 后端接口

复用现有 `DeviceAuthGuard`、multipart（已注册）、`/uploads/` 静态服务。

- **`GET /profile`**：返回全部资料字段（原字段 + gender + 6 项 + avatar_url）。
- **扩展 `PATCH /profile`**：`UpdateProfileDto` 增加可选 `gender`、`favorite_categories`、`pain_points`、`skill_level`、`expectations`、`common_scenes`、`shoot_frequency`、`avatar_url`。仅更新传入的非空字段。
- **新增 `POST /profile/avatar`**（multipart，单个图片）：
  - 校验后缀/mimetype（白名单：jpg/jpeg/png/webp/gif），限制大小（参考反馈单张 10MB）。
  - 存储到 `{UPLOAD_DIR}/users/{deviceId}/avatar.{ext}`（旧文件先删）。
  - 返回 `{ avatarUrl }`（`buildPublicUrl` 方式拼绝对 URL）。
  - 保存 `user_profiles.avatar_url`，并清空/保留 seed（seed 保留，切回内置时用）。

**问卷提交服务（`questionnaire.service.submit`）改动**：写记录后，将 `dto.answers` 中 6 项 + gender 合并写入 `user_profiles`（无记录则先 getOrCreate）。

**DTO（`submit-questionnaire.dto.ts`）**：`QuestionnaireAnswers` 增加 `gender`（可空）。

（共享类型 `packages/shared/src/types/questionnaire.ts` 同步增加 `gender`。）

---

## 4. Flutter 前端

### 4.1 问卷页（`questionnaire_page.dart` + `questionnaire_data.dart`）
- 新增**首问「性别」**（单选）：`male` 男 / `female` 女 / `prefer_not` 保密。共 8 题。
- `QuestionnaireAnswers` 增加 `gender` 字段。
- 提交时：除原有问卷上报外，把性别 + 6 项偏好同步到本地 `ProfileData` 并置为待同步（走 `ProfileSyncService.save`），随后再由启动补传上报后端 `PATCH /profile`。

> 说明：问卷数据仍走 `questionnaire_records`（数据分析）；个人中心偏好数据由 Flutter 在提交问卷时通过既有 `ProfileSyncService` 通道写入 `user_profiles`，保持单一写路径、离线优先。

### 4.2 首次引导
- **保留**：splash 依据「新设备 + 本地问卷未完成」跳问卷（现状已满足"仅首次展示"）。
- 若当时问卷已被跳过，「新设备」判定为一次性；后续不再自动弹出。可进入个人中心补填偏好。
- **移除设置页「偏好问卷」入口**（`profile_settings_page.dart` 相关 `_SettingItem`）。

### 4.3 模型 / 仓库 / 服务 / DAO
- `ProfileData`：新增 `gender`、`favoriteCategories`、`painPoints`、`skillLevel`、`expectations`、`commonScenes`、`shootFrequency`、`avatarUrl`（含 `copyWith`、`fromJson`/`toJson`）。
- `ProfileRepository.update(...)`：参数扩展上述字段；新增 `Future<String> uploadAvatar(...)` 调用 `POST /profile/avatar`（multipart 上传）。
- `ProfileSyncService.save(...)`：透传新字段；`syncPendingIfNeeded` 补传时带上。
- `UserProfileDao`（sqflite）：建表新增列，`read/write` 覆盖新字段；注意**旧库迁移**（`onUpgrade`/重建兜底）。
- 头像解析统一：`avatarUrl` 非空优先用 `avatarUrl`，否则 `BuiltinProfiles.avatarUrl(avatarSeed)`。

### 4.4 个人中心编辑页（`profile_edit_page.dart`）
扩展现有编辑资料页：
- **头像区**：内置 seed 网格（保留）+「上传自定义头像」入口（拉起相册/相机，`POST /profile/avatar`，成功后展示后端图；提供"恢复内置头像"）。上传中/失败有状态提示。
- **性别**：单选（男/女/保密）。
- **6 项偏好**：复用问卷的单选/多选 pill 样式，字段与点一致。
- 保存 → `ProfileSyncService.save` 全量新字段。

### 4.5 个人中心主页（`profile_page.dart` + HeroCard）
- HeroCard：头像点击行为改为「点击进入编辑资料」（已存在）并支持头像大图预览；`avatarUrl` 有值时用后端图。
- 新增「偏好/个人资料」摘要卡片：展示性别、摄影水平、常用场景、拍摄频率等已填项；点击进入编辑资料页；未填项显示引导文案。
- 对 HeroCard/整体卡片做视觉打磨，主题/风格下保持统一（沿用 NeuCard / glass / female 分支）。

---

## 5. 兼容与迁移

- `user_profiles` 旧行新字段可空，读取兜底默认值（多选空数组、单选 null）。
- Flutter 本地 `ProfileDao` 加列需处理已安装设备的旧 schema 升级。
- 已填过问卷的存量用户：本地无 `gender` 等字段 → 编辑资料页展示为空并允许补填；后端旧问卷记录不追溯迁移。
- `questionnaire_records` 表结构不变，旧数据不受影响。

---

## 6. 测试

- **后端单测/e2e**：PATCH /profile 各字段部分更新；POST /profile/avatar 上传成功（存在 URL）、非法类型/超限 `400`；问卷提交后 `user_profiles` 同步成功、二次提交幂等；个人中心 PATCH 不回写 questionnaire_records。
- **Flutter 单测**：ProfileData 序列化；ProfileRepository 新字段 body 组装；头像解析（有/无 avatarUrl）；初始化旧库迁移不崩。
- **手动**：新设备首启见问卷（含性别）→ 提交后个人中心显示偏好；个人中心改任意偏好不回改后台问卷数据；上传/恢复内置头像流程；设置页无「偏好问卷」入口。

---

## 7. 范围外（本次不做）
- 问卷的"来源 `source`"不写入 `user_profiles`（仅留在问卷表做分析）。
- 不做头像裁切/滤镜，仅上传后等比展示。
- 不做性别对推荐算法的联动。