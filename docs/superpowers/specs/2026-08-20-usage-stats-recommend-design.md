# 使用次数统计 + 推荐增强 + 场景后台管理 设计

日期：2026-08-20
状态：待用户审阅
涉及端：后端（`lumira-server/packages/backend`）、后台（`lumira-server/packages/admin`）、客户端（`lumira_app_flutter`）

## 1. 背景与目标

当前模板/场景/推荐/Banner/搜索多在 App 端本地（mock 数据 + sqflite DAO）实现，后端缺少「使用次数记录、推荐情报、场景管理、结果排序」能力。

目标：**本地优先、离线可用**；联网时后端记录所有用户对模板/场景的使用次数，App 把汇总次数同步到本地，由本地推荐算法/搜索排序用这些「全站流行度」增强。仅做增强，不做全后端驱动。

### 记什么（埋点口径）
- 事件类型：`open_detail`（打开详情页）、`use_shoot`（完成一次拍摄/保存成片）、`scene_select`（场景选择面板选定预设）
- 模板：仅记录**内置（builtin）**与**后台（remote）**模板；**用户自定义（custom）模板不记录**
- 场景：仅记录**系统内置**场景；用户自定义场景不记录

### 同步机制
App 本地先记事件 → 联网批量 POST 后端（后端存原始事件）→ 后端汇总 → App GET 汇总次数用于本地推荐。离线用本地事件次数，联网后覆盖/合并。

## 2. Part 1 · 后端数据模型与 API

### 2.1 新增表 `usage_events`（原始事件，上报幂等）
| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | int 自增 PK | |
| `device_id` | varchar | 上报设备，`devices` 外键 |
| `client_event_id` | varchar | App 生成唯一 ID，批量重试幂等（唯一索引） |
| `item_type` | varchar | `template` \| `scene` |
| `item_id` | varchar | 模板/场景 id |
| `item_source` | varchar | 模板来源 `builtin`\|`remote`；场景恒为 `system` |
| `event_type` | varchar | `open_detail` \| `use_shoot` \| `scene_select` |
| `occurred_at` | int | 事件发生时间戳 |

唯一索引：`uq_usage_event` on (`client_event_id`)。仅做**上报幂等**（重试不重复计数），不做按设备去重。

### 2.2 新增表 `system_scenes`（系统内置场景）
| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | varchar PK | 场景 id（如 `seaside`） |
| `name` | text | 场景名 |
| `category` | text | `light`/`outdoor`/`indoor`/`mood` |
| `style` | text | 风格 |
| `icon` | text | phosphor 图标名（`ph-xxx`） |
| `vibe` | text | 氛围 |
| `filter_json` | text | 滤镜参数（沿用现有场景结构） |
| `tips_json` | text | 拍照提示 |
| `example_images_json` | text | 示例图 |
| `where_to_shoot` / `best_time` / `related_category` / `recommended_tag_ids_json` | text | 沿用现有场景结构 |
| `sort_order` / `is_active` / `created_at` / `updated_at` | | 排序与启停 |

### 2.3 客户端 API
| 接口 | 说明 |
|---|---|
| `POST /api/v1/usage/events` | 批量上报 `{ events: [...] }`，按 `client_event_id` upsert，幂等 |
| `GET /api/v1/usage/stats?itemType=template\|scene` | 全站汇总次数 `{ items: [{ itemId, itemType, useShoot, openDetail, sceneSelect }] }` |
| `GET /api/v1/scenes` | 当前启用的系统内置场景（含各自使用次数），App 同步覆盖本地场景缓存 |

### 2.4 后台 API
`/api/v1/admin/scenes`：系统内置场景 CRUD + 启停。（沿用现有 admin-templates / admin-categories 管理模式）

## 3. Part 2 · 后台管理 UI + App 端改动

### 3.1 后台（admin）
- 新增「场景管理」：`sidebar.tsx` 入口 + `dashboard-shell.tsx` 标题映射
- 页面 `app/dashboard/scenes/page.tsx` + 组件 `components/scene-manager.tsx`
  - 列表：场景卡片网格（名称/分类/风格/图标/启停/**使用次数**）
  - 新建/编辑表单：名称、分类（色调/室外/室内/情绪）、风格、图标、氛围、拍照提示、优选时间等（复用 `TemplateForm` 表单风格）
  - 启停切换、删除
- **模板列表加次数列**：`components/template-card-grid.tsx` 模板卡展示 `use_shoot`/`open_detail` 汇总次数
- `lib/api.ts` 增加：`listScenes/createScene/updateScene/deleteScene/toggleScene`；模板明细关联 `usageStats`
- 新增 server actions `actions/scenes.ts`

### 3.2 客户端（Flutter）
1. **本地事件表 + 埋点**
   - 新增本地表 `usage_events`（sqflite，vN 迁移）：`client_event_id, item_type, item_id, item_source, event_type, occurred_at, synced`
   - 新增 `UsageEventRecorder.record(itemType, itemSource, eventType, itemId)`：仅内置/后台模板、系统内置场景才记录；用户自定义跳过
   - 埋点位置：
     - `templates_detail_page.dart` 打开 → `template/open_detail`
     - 拍摄保存成片（capture 流程，含 templateId/sceneId）→ `use_shoot`
     - 场景详情打开 → `scene/open_detail`；场景选择面板选定 → `scene/scene_select`
2. **同步服务**：新增 `UsageSyncService`，联网时批量 POST 未同步事件（成功后 `synced=1`）→ GET `/usage/stats` 写入本地持久化（新增 `usage_stats` 表：`item_type,item_id,event_type,count`）。触发：页面 `invalidate` / 拍摄保存后
3. **推荐引擎增强**：`recommendation_service.dart` 与模板 `recommendation_engine.dart` 打分时叠加远程全站次数流行度权重；离线/无缓存用本地事件次数，逻辑不变
4. **搜索排序增强**：`scenes_search_page.dart` 结果排序加入 `use_shoot/open_detail` 次数（远程优先，回退本地）；模板搜索/列表排序叠加
5. **Banner**：`banner_recommendation_provider.dart` 候选挑选并入流行度次数
6. **场景元数据同步**：`scenes_dao.syncSystemScenes()`（upsert 后端启用的系统场景）；首启用现 mock 种子兜底，联网后覆盖为后端元数据

## 4. Part 3 · 推荐算法细节

### 4.1 打分模型
```
finalNote = score_local * (1 - α) + score_pop * α
```
- `score_local`：现有个性化基础分（离线可用）
- `score_pop`：全站流行度分
- `α`：流行度权重系数；**联网且有数据 > 0，离线/无缓存 = 0**（功能不降级）

### 4.2 流行度分 `score_pop`
```
score_pop = (use_shoot/max_use_shoot)*w_use
          + (open_detail/max_open_detail)*w_open
          + (scene_select/max_select)*w_select
          + (scene_use_shoot/max_scene_use_shoot)*w_scene_use
```
每事件类型内部线性归一化到 [0,1]。

### 4.3 事件类型权重（归一化后）
| 事件 | 模板权重 | 场景权重 |
|---|---|---|
| `use_shoot` | 0.6 | 0.55 |
| `open_detail` | 0.3 | 0.25 |
| `scene_select` | — | 0.2 |

「完成拍摄」权重最高（真实使用信号），「详情打开/选定」为弱信号。

### 4.4 归一化与冷却
- 每事件类型线性归一化：`count / maxCount(itemType, eventType)`
- 原可选时间衰减（仅对最近 N 天 `use_shoot` 计权重）——**默认不启用**，后续如遇「过气热门」问题再加，避免本期过度设计

### 4.5 去重口径
- 事件**按次累加**（同一设备反复使用计入，反映真实热度）
- 去重仅依赖 `client_event_id` 唯一索引做上报幂等，不做按设备去重
- MySQL 侧 `GROUP BY item_type,item_id,event_type` 实时聚合；统计量小、查询频率低，无需预置汇总表；数据量大后再引入定时汇总

### 4.6 汇总接口返回
```
{ "items": [ { "itemId": "...", "itemType": "template",
    "useShoot": 12, "openDetail": 34, "sceneSelect": 0 } ] }
```
- 模板只返回 `useShoot/openDetail`；场景返回 `useShoot/openDetail/sceneSelect`
- App 拉取写入本地 `usage_stats`；推荐/搜索排序读取；无数据时 `score_pop` 权重自动置 0

### 4.7 场景使用次数归属
- 场景 `use_shoot` 在拍摄保存成片且使用**系统内置场景**时记录；用户自定义场景不记录（与模板口径一致）

## 5. 风险与边界
- 热更新排序依赖联网同步；弱网/离线退化为本地逻辑（符合离线优先，可接受）
- 场景元数据后端管理后，App 首次联网用后端覆盖本地 mock 种子 → 需保留本地兜底种子防冷启动白屏
- 埋点覆盖详情页/拍摄保存/场景选择三处；漏埋入口不计数（不影响运行）
- 客户端 Flutter 3.7.12 / Dart 2.19.6，不支持 Dart 3 records 语法（大对象用类）
- 同时遵守 AGENTS.md UI 规范（4 风格 × 各主题、新拟态浮雕取向、禁止风格混搭）

## 6. 涉及文件清单（实现计划时细化）
- 后端：`database/schema.ts`（usage_events、system_scenes）、migrations、新 module（usage / scenes）、shared 类型
- 后台：`sidebar.tsx`、`dashboard-shell.tsx`、`api.ts`、`actions/scenes.ts`、`scene-manager.tsx`、`app/dashboard/scenes/page.tsx`、模板卡次数列
- 客户端：库表迁移（usage_events、usage_stats）、`UsageEventRecorder`、`UsageSyncService`、`scenes_dao.syncSystemScenes`、推荐引擎/搜索/Banner 增强、埋点