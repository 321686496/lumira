# 模板季节/天气/时段（ambience）元数据 + 短简介 设计

> 日期：2026-08-20
> 状态：已确认，待转入实施计划

## 1. 背景与目标

当前模板推荐（`recommendation_engine.dart`）完全基于用户历史行为（分类/标签/风格/后期参数 + 问卷偏好）打分，**没有任何「当前环境」信号**，导致夏天也会推送冬季模板。后端已有 `WeatherService`（温度/天气/城市/日出日落），可作为环境信号来源，但模板侧缺少与之匹配的元数据字段。

本次目标（用户已确认）：
- **先添加元数据**，供后续推荐算法使用（推荐算法本轮不做）。
- 存储采用**单一结构化 JSON 列**。
- **Admin 后台表单同步新增**这些字段。

同时新增需求：模板增加「短简介」`shortDesc`，字数 ≤10，用于 banner / 模板卡片展示；现有 `description` 保留作为长简介详细描写。

## 2. 数据结构

### 2.1 新增列（`templates` 表，schema.ts）

```ts
ambienceJson: longtext('ambience_json').notNull().default('{}'),   // 季节/天气/时段
shortDesc: text('short_desc').notNull().default(''),                // 短简介，≤10字
```

### 2.2 共享类型（shared/src/types/template.ts）

```ts
export interface TemplateAmbience {
  /** 适用季节，可取多个 */
  seasons: ('spring' | 'summer' | 'autumn' | 'winter')[];
  /** 适用天气（对齐现有 WeatherService 描述词） */
  weathers: ('sunny' | 'cloudy' | 'overcast' | 'rain' | 'snow' | 'fog')[];
  /** 时段 / 色调倾向 */
  timeTones: ('goldenHour' | 'day' | 'night' | 'warm' | 'cool')[];
}
```

- `RemoteTemplateMeta`、`AdminTemplateListItem` / `AdminTemplateDetail` 新增：
  - `ambience: TemplateAmbience`
  - `shortDesc: string`
- `CreateTemplateRequest` / `UpdateTemplateRequest` 新增同名字段（短简介可空，ambience 可空）。
- `rowToMeta` / `rowToDetail` 解析 `ambienceJson`（JSON.parse，失败回退 `{ seasons:[], weathers:[], timeTones:[] }`）与 `shortDesc`。

### 2.3 取值范围与规则

| 字段 | 取值范围 | 说明 |
|---|---|---|
| `seasons` | spring / summer / autumn / winter | 空数组=不限 |
| `weathers` | sunny / cloudy / overcast / rain / snow / fog | 与 weather.service 产出一一对应 |
| `timeTones` | goldenHour / day / night / warm / cool | 时段+色调倾向 |
| `shortDesc` | 字符串，≤10 字符 | 空串=未标注，banner/卡片回退用 description 截断 |

### 2.4 校验与兜底

- 后端 DTO 校验 `shortDesc` ≤10 字符，超长返回 400；Admin 输入框 `maxLength={10}` + 字数计数双保险。
- `ambience` 字段全部允许为空，兼容存量模板（默认空即不受季节/天气/时段约束）。

## 3. 数据流

- **Admin（Vercel）→ 后端**：表单组装 `ambience` 对象 + `shortDesc`，走既有 `POST/PATCH /api/v1/admin/templates` 提交；回填时反解析。
- **后端 → Flutter**：`GET /api/v1/templates/list` / `:id` 返回 `ambience` + `shortDesc`（本轮不改 Flutter 端读取逻辑，仅保证字段随 meta 下发）。

## 4. Admin 表单（template-form.tsx）

在基础信息 steps 新增：

- **短简介**：`<Input maxLength={10}>` + `x/10` 字数计数，placeholder「一句话亮点（≤10字）」。
- **时节氛围**：三个多选组（季节 4 项 / 天气 6 项 / 时段色调 5 项），复用现有 shadcn checkbox；不选=不限。

## 5. 范围边界

- **本轮范围**：后端（schema 迁移 + 共享类型 + service 读写 + DTO 校验）+ Admin 表单。
- **后续范围（不在本轮）**：
  - Flutter 端模板模型 / 展示（banner / 卡片用 `shortDesc`）
  - 推荐算法接入 `ambience` + `WeatherService`
  - 存量模板的增量标注

## 6. 一致性检查

- 季节/天气/时段字段只为「后续推荐算法」提供数据基础，本轮不改任何页面展示，不引入潜在回归。
- `ambience` 采用英文枚举存储 + 展示侧各自映射中文，与既有 `classification` 风格一致。