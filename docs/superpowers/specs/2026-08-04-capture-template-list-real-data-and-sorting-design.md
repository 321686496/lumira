# 拍摄页模板列表真实数据整合与排序优化

**日期**: 2026-08-04
**状态**: 已通过设计评审，待编写实现计划
**关联文档**:
- 模板系统设计: `docs/superpowers/specs/2026-07-11-template-system-and-capture-guide-design.md`
- 拍照页增强: `docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`
- 人像模板重构: `docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md`

---

## 一、背景与目标

### 1.1 问题

拍摄页模板横向滚动条（`TemplateStrip`）存在三个问题：

1. **只读硬编码系统模板**：`TemplateStrip` 从 `TemplateRegistry`（编译期 `const Map`，12 个系统模板）读取，不读取数据库中的用户自定义模板。
2. **套用自定义模板时参数无法加载**：`originalTemplateProvider` 只查 `TemplateRegistry.getTemplate(id)`，选了自定义模板 ID 时返回 `null`，导致 `editableTemplateProvider` 为 `null`，参数面板和取景器都不生效。
3. **无排序优化**：模板按 `TemplateRegistry` 的固定顺序展示，不支持按使用频率或用户偏好排序。

### 1.2 目标

1. 拍摄页模板列表读取系统模板 + 自定义模板的真实数据
2. 自定义模板与系统模板功能完全统一（套用后参数正确加载到面板和取景器）
3. 模板列表按使用频率排序（降序），其次按用户偏好排序（topCategory 匹配优先）

### 1.3 范围边界

| 项 | 本次实现 | 不在本次范围 |
|---|---|---|
| 数据源 | 合并 TemplateRegistry + TemplatesDao | 不迁移系统模板到数据库 |
| 排序 | 使用频率 + 用户偏好 | 不做个性化推荐算法 |
| UI | TemplateStrip 适配新数据源 + 自定义模板标记 | 不重新设计模板卡片样式 |
| 自定义模板套用 | 完整参数加载（相机/后期/构图/场景） | 不涉及模板编辑器改动 |

---

## 二、设计

### 2.1 方案选型

采用**方案 A：统一 Provider 合并**。

理由：
- 系统模板保持编译期常量（启动即用，零延迟）
- DAO 只管自定义模板，职责清晰
- 合并逻辑在 provider 层，UI 无感知
- 改动最小，风险可控

### 2.2 数据源整合

#### 新增 providers（位于 `capture_state.dart`）

**`allTemplatesProvider`**（FutureProvider<List<PhotoTemplate>>）

异步加载所有模板（系统 + 自定义），合并为统一列表：

```
1. TemplateRegistry.allTemplates → 系统模板列表（同步）
2. await templatesDao.getCustomOnly() → 自定义 TemplateRecord 列表
3. TemplateMapper.toPhotoTemplate(record) 转换每条记录
4. 合并为 [...系统, ...自定义]
```

**`templateCacheProvider`**（Provider<Map<String, PhotoTemplate>>）

从 `allTemplatesProvider` 结果构建 ID→模板的 Map，供 `originalTemplateProvider` 快速查找。降级策略：加载中时仅含系统模板。

**`originalTemplateProvider`**（修改现有 Provider）

```
先查 TemplateRegistry.getTemplate(id) → 找到则返回（同步，系统模板快路径）
未找到 → 查 templateCacheProvider[id]（预加载的自定义模板缓存）
```

### 2.3 模板套用路径

现有链路不需改动，自动复用扩展后的数据源：

```
用户点击模板卡片
  ↓
currentTemplateIdProvider = templateId
  ↓
originalTemplateProvider（已扩展：查 TemplateRegistry 或 templateCacheProvider）
  ↓
editableTemplateProvider = original?.copyWith()
  ↓
effectiveCameraProvider / effectivePostProcessProvider / effectiveCompositionProvider
  ↓
ParamPanel（参数面板显示模板参数）
CameraPreview（取景器应用模板滤镜）
ApplyButton（参数偏离时显示"应用"按钮）
```

### 2.4 排序逻辑

#### 新增 `sortedTemplatesProvider`（FutureProvider<List<PhotoTemplate>>）

```
输入：
  - allTemplatesProvider（模板列表）
  - galleryDao.countByTemplate()（Map<templateId, 使用次数>）
  - userPreferenceProvider（topCategory）

排序规则（优先级从高到低）：
  1. 使用频率：usageCount 降序（常用模板排前面）
  2. 用户偏好：category == topCategory 的模板排前面
  3. 名称兜底：字母序
```

#### 缓存失效

用户创建/编辑/删除自定义模板后，调用 `ref.invalidate(allTemplatesProvider)` 刷新列表。

### 2.5 UI 适配

#### TemplateStrip 改动

1. **数据源切换**：`TemplateRegistry.getRecentTemplates(count)` → `ref.watch(sortedTemplatesProvider)`
2. **AsyncValue 处理**：
   - `data`：渲染排序后的模板列表
   - `loading`：降级显示系统模板（TemplateRegistry.allTemplates）
   - `error`：显示错误占位
3. **compact 模式**：显示排序前 6 个
   **非 compact 模式**：显示全部
4. **自定义模板标记**：卡片右上角加小标签（如"我的"），使用 app 主题色，不影响功能
5. **无封面图处理**：自定义模板无封面时显示占位图标

---

## 三、涉及文件

### 修改

| 文件 | 改动 |
|---|---|
| `lib/features/capture/data/capture_state.dart` | 新增 `allTemplatesProvider`、`templateCacheProvider`、`sortedTemplatesProvider`；修改 `originalTemplateProvider` |
| `lib/features/capture/widgets/template_strip.dart` | 数据源切换为 `sortedTemplatesProvider`；处理 AsyncValue；自定义模板标记 |

### 复用（不修改）

| 文件 | 用途 |
|---|---|
| `lib/features/capture/data/template_registry.dart` | 系统模板数据源 |
| `lib/features/templates/services/template_mapper.dart` | `TemplateMapper.toPhotoTemplate()` 转换方法 |
| `lib/features/templates/data/templates_providers.dart` | `userPreferenceProvider`、`templatesDaoProvider` |
| `lib/core/db/dao/gallery_dao.dart` | `countByTemplate()` |
| `lib/core/db/dao/templates_dao.dart` | `getCustomOnly()` |
| `lib/features/capture/widgets/apply_button.dart` | 不需改动 |
| `lib/features/capture/widgets/param_panel.dart` | 不需改动 |
| `lib/features/capture/widgets/camera_preview.dart` | 不需改动 |

---

## 四、数据流图

```
┌─────────────────┐     ┌──────────────────────┐
│ TemplateRegistry │     │   TemplatesDao       │
│ (12 系统模板)    │     │ .getCustomOnly()    │
│ (编译期 const)   │     │ (自定义模板)         │
└────────┬────────┘     └──────────┬───────────┘
         │                         │
         │  TemplateMapper.toPhotoTemplate()
         │                         │
         └──────────┬──────────────┘
                    ↓
         allTemplatesProvider (FutureProvider)
                    │
          ┌─────────┴──────────┐
          ↓                    ↓
  templateCacheProvider   sortedTemplatesProvider
  (Map<id, Template>)     (排序后的列表)
          │                    │
          ↓                    ↓
  originalTemplateProvider   TemplateStrip
          │               (渲染排序后卡片)
          ↓
  editableTemplateProvider
          │
          ↓
  effective* Providers
          │
    ┌─────┴──────┐
    ↓            ↓
  ParamPanel  CameraPreview
```

---

## 五、验收标准

1. **系统模板可见**：拍摄页模板列表包含 12 个系统模板
2. **自定义模板可见**：用户创建的自定义模板出现在模板列表中
3. **自定义模板标记**：自定义模板卡片有视觉标记区分来源
4. **自定义模板套用**：点击自定义模板后，参数面板显示模板参数，取景器应用模板滤镜
5. **排序-使用频率**：使用次数多的模板排在前面
6. **排序-用户偏好**：使用次数相同时，与用户最常用分类匹配的模板排前面
7. **应用按钮**：修改参数后点击"应用"按钮，参数恢复为模板原值（系统模板和自定义模板都生效）
8. **降级**：自定义模板加载中时，模板列表仍显示系统模板
9. **刷新**：创建/编辑/删除自定义模板后，模板列表自动刷新

---

## 六、风险与边界

### 6.1 已知风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| DAO 异步加载延迟 | 首次进入拍摄页时自定义模板可能延迟显示 | 降级策略：loading 时显示系统模板 |
| `countByTemplate()` 性能 | 模板数量多时聚合查询可能慢 | 当前模板数量有限（12 系统 + 少量自定义），暂不需索引优化 |
| `templateCacheProvider` 时机 | `originalTemplateProvider` 在缓存加载完成前只能查到系统模板 | 降级策略已覆盖：先查 TemplateRegistry，缓存加载后自动更新 |

### 6.2 不在本次范围

- 系统模板迁移到数据库
- 模板使用频率的显式持久化字段（`usage_count` 列）
- 模板推荐算法（场景匹配、时段精选等）
- TemplateStrip 卡片样式重新设计
- 模板搜索/筛选功能
