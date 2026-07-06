# 如画 Lumira — 前端测试文档

> 配套文档：[前端设计文档](./2026-07-03-lumira-frontend.md) · [PRD](../superpowers/specs/2026-07-03-lumira-prd.md)
> 测试范围：页面跳转、按钮/手势交互、本地服务数据获取
> 产品特性：**单机离线**，零网络权限，无账号，无 AI，纯本地算法
> 最后更新：2026-07-03

---

## 0. 文档说明

### 0.1 测试分层

| 层级 | 工具建议 | 覆盖内容 |
|---|---|---|
| 单元测试 | Vitest | Service 方法、Store actions、工具函数、TemplateEngine |
| 组件测试 | Vitest + @vue/test-utils | 组件渲染、Props/Emits、交互事件 |
| 端到端（E2E） | 自动化脚本 / 手工用例 | 页面跳转、完整交互流、拍摄→后期→导出全链路 |
| 手工回归 | 本文档用例清单 | 真机相机、原生插件、权限、性能 |

### 0.2 用例编号规则

`LM-{模块}-{类型}-{序号}`
- 模块：`CAP`(拍摄) `TPL`(模板) `GAL`(相册/后期) `PRF`(我的) `NAV`(全局导航) `SVC`(服务层)
- 类型：`NAV`(跳转) `UI`(交互) `DATA`(数据) `ERR`(异常)

### 0.3 优先级

- **P0**：核心链路，阻塞发布（拍摄、模板应用、后期导出）
- **P1**：主要功能（模板管理、导入导出、相册）
- **P2**：次要/边缘（设置项、空态、异常提示）

### 0.4 前置约定

- 所有用例默认已授予相机与存储权限（权限用例单列，见 4.1）
- 「预期」列描述可断言的界面/数据结果
- 离线版无任何网络请求，`DATA` 类用例均针对本地 SQLite / 文件系统 / 原生插件

---

## 1. 全局导航测试

### 1.1 悬浮 Tab 栏（FloatingTabBar）

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-NAV-NAV-001 | P0 | Tab 切换到拍摄 | 点击悬浮 Tab「拍摄」 | 跳转 `/pages/capture/index`；拍摄图标变金填充 + 显「拍摄」文字；其余图标恢复灰线性 |
| LM-NAV-NAV-002 | P0 | Tab 切换到模板 | 点击「模板」 | 跳转 `/pages/templates/index`；选中态迁移到模板 |
| LM-NAV-NAV-003 | P0 | Tab 切换到我的 | 点击「我的」 | 跳转 `/pages/profile/index`；选中态迁移到我的 |
| LM-NAV-UI-004 | P1 | 选中态动效 | 点击任一 Tab | 图标 `scale(1.0→1.08)` + 文字淡入，约 200ms 完成，无整栏位移 |
| LM-NAV-UI-005 | P1 | 点击反馈 | 按住 Tab 图标 | `:active` 态 `scale(0.94)`，松手回弹 |
| LM-NAV-UI-006 | P0 | 深色态切换 | 进入拍摄页（取景器深色） | Tab 容器切换 `rgba(28,26,23,0.6)` 深色玻璃态；离开拍摄页恢复明亮态 |
| LM-NAV-UI-007 | P1 | 悬浮定位 | 任一 Tab 页滚动内容 | Tab 栏 `fixed` 固定悬浮，不随内容滚动；底部距 `safe-area + 16px` |
| LM-NAV-UI-008 | P2 | 内容避让 | 滚动列表至底部 | 最后一项内容不被 Tab 栏遮挡（底部预留 96px） |
| LM-NAV-NAV-009 | P1 | Tab 页栈保持 | 拍摄→模板→再回拍摄 | 拍摄页状态（取景器/当前模板）保持不丢失 |
| LM-NAV-UI-010 | P2 | 安全区适配 | 在刘海屏/全面屏设备 | Tab 栏底部随 `safe-area-inset-bottom` 上移，不被 Home 指示条遮挡 |

### 1.2 返回与栈管理

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-NAV-NAV-011 | P0 | 非 Tab 页返回 | 模板详情页点左上返回 | `navigateBack` 回到模板库，列表滚动位置保持 |
| LM-NAV-NAV-012 | P1 | 系统返回键（Android） | 详情页按物理返回键 | 等同点击返回按钮 |
| LM-NAV-ERR-013 | P2 | 编辑中返回拦截 | 后期编辑未保存时返回 | 弹确认框「放弃修改？」，取消则停留，确认则丢弃并返回 |

---

## 2. 拍摄模块（Capture）

### 2.1 拍摄页跳转 `/pages/capture/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-CAP-NAV-001 | P0 | 进入拍摄预览 | 点击快门按钮 | 拍摄成功后跳转 `/pages/capture/preview`，展示刚拍照片 |
| LM-CAP-NAV-002 | P1 | 打开参数面板 | 点击参数指示条/参数入口 | 弹出半屏 `/pages/capture/parameters` |
| LM-CAP-NAV-003 | P1 | 进入相册 | 点击相册入口缩略图 | 跳转 `/pages/gallery/index` |
| LM-CAP-NAV-004 | P1 | 打开设置 | 点击顶栏 ⚙ | 跳转 `/pages/profile/settings` |
| LM-CAP-NAV-005 | P2 | 切换当前模板 | 点击顶部模板名 TemplateTag | 跳转/弹出模板选择，选定后返回并应用叠图 |

### 2.2 拍摄页交互（按钮/手势）

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-CAP-UI-006 | P0 | 快门拍摄 | 点击 ShutterButton | 触发 `CameraService.capture()`，返回照片路径，进入预览 |
| LM-CAP-UI-007 | P1 | 切换前后摄像头 | 点击翻转按钮 | `switchCamera()` 生效，取景器画面切换，叠图保持 |
| LM-CAP-UI-008 | P0 | 构图叠图显示 | 应用含构图的模板 | 取景器出现三分/引导线叠图（RuleOfThirdsGrid/GuideLines），品牌金半透明 |
| LM-CAP-UI-009 | P1 | 姿势叠图显示 | 应用含姿势的模板 | PoseOverlay 剪影叠加于取景器中心 |
| LM-CAP-UI-010 | P1 | 叠图透明度调节 | 拖动叠图透明度滑块 | 实时调用 `setOverlayOpacity()`，叠图明暗随之变化 |
| LM-CAP-UI-011 | P1 | 水平检测提示 | 倾斜设备 | ParameterBar 水平指示实时变化；接近水平时提示「⊹ 水平」高亮 |
| LM-CAP-UI-012 | P1 | 参数条实时显示 | 应用带相机参数的模板 | 底部 pill 显示 EV/WB 等当前生效参数 |
| LM-CAP-UI-013 | P2 | 快门连拍防抖 | 快速连点快门 | 拍摄中禁用快门，避免重复触发；完成后恢复 |

### 2.3 参数面板 `/pages/capture/parameters`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-CAP-UI-014 | P1 | 调整 EV | 拖动 EV 滑块至 +0.3 | `setParameters({evBias:0.3})`；取景器亮度实时变化；参数条更新 |
| LM-CAP-UI-015 | P1 | 调整白平衡 | 选择 WB 5200K | `setParameters` 生效，画面色温变化 |
| LM-CAP-UI-016 | P2 | 重置参数 | 点击「重置」 | 参数恢复默认，取景器还原 |
| LM-CAP-UI-017 | P2 | 关闭面板 | 下滑/点遮罩 | 半屏面板收起，参数保留 |

### 2.4 拍摄预览 `/pages/capture/preview`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-CAP-NAV-018 | P0 | 进入后期编辑 | 预览页点「编辑」 | 跳转 `/pages/gallery/detail`，携带照片路径 |
| LM-CAP-UI-019 | P0 | 保存到相册 | 点「保存」 | 照片写入本地相册，SQLite 新增记录，toast「已保存」 |
| LM-CAP-UI-020 | P1 | 放弃重拍 | 点「重拍」 | 丢弃当前照片，返回拍摄页 |

### 2.5 拍摄服务数据（CameraService）

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-CAP-DATA-021 | P0 | 相机初始化 | 进入拍摄页 | `initialize(config)` resolve；`startPreview()` 渲染取景器 |
| LM-CAP-DATA-022 | P0 | 拍摄返回路径 | 调用 `capture()` | 返回有效本地文件路径字符串，文件存在 |
| LM-CAP-DATA-023 | P1 | 参数读写一致 | `setParameters` 后 `getParameters` | 读取值与设置值一致 |
| LM-CAP-DATA-024 | P1 | 水平检测数据 | 调用 `detectLevel()` | 返回 `{isLevel:boolean, angle:number}`，angle 合理范围 |
| LM-CAP-DATA-025 | P0 | 资源释放 | 离开拍摄页 | `stopPreview()` + `release()` 调用，相机资源释放不泄漏 |
| LM-CAP-ERR-026 | P0 | 相机被占用 | 其他 App 占用相机时进入 | 捕获初始化失败，提示「相机不可用」，不崩溃 |

---

## 3. 模板模块（Template）

### 3.1 模板库跳转 `/pages/templates/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-NAV-001 | P0 | 打开模板详情 | 点击模板卡片 | 跳转 `/pages/templates/detail`，携带模板 id |
| LM-TPL-NAV-002 | P1 | 新建模板 | 点「创建模板」 | 跳转 `/pages/templates/editor`（新建模式） |
| LM-TPL-NAV-003 | P0 | 导入模板入口 | 点「导入」 | 跳转 `/pages/templates/import` |

### 3.2 模板库交互

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-UI-004 | P1 | 分类筛选 | 点击 CategoryTabs「人像」 | 列表仅显示人像类模板，选中标签高亮 |
| LM-TPL-UI-005 | P2 | 分类横滑 | 左右滑动分类标签栏 | 标签栏横向滚动，超出项可见 |
| LM-TPL-UI-006 | P1 | 卡片能力标签 | 查看模板卡片 | 显示构图/姿势/参数/后期对应金色小标签 |
| LM-TPL-UI-007 | P2 | 空态显示 | 筛选无结果的分类 | 显示空态占位（无内置模板时） |

### 3.3 模板详情 `/pages/templates/detail`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-NAV-008 | P0 | 应用模板去拍摄 | 详情页点「用此模板拍摄」 | 跳转拍摄页，OverlayLayer 加载该模板叠图与参数 |
| LM-TPL-UI-009 | P1 | 叠图预览 | 查看 OverlayPreview | 正确渲染构图线/姿势剪影预览 |
| LM-TPL-NAV-010 | P1 | 编辑此模板 | 点「编辑」 | 跳转编辑器（编辑模式，预填数据） |
| LM-TPL-UI-011 | P1 | 导出分享模板 | 点「导出/分享」 | 序列化为 `.pptpl` 文件，唤起系统分享面板 |

### 3.4 模板编辑器 `/pages/templates/editor`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-UI-012 | P1 | 调整构图参数 | ControlPanel 修改构图 | EditorCanvas 实时预览更新 |
| LM-TPL-UI-013 | P1 | 预览切换 | 点 PreviewToggle | 编辑态/预览态切换正常 |
| LM-TPL-DATA-014 | P0 | 保存模板 | 点「保存」 | `TemplateEngine.serialize()` → 写入 SQLite，返回列表可见新模板 |
| LM-TPL-ERR-015 | P1 | 必填校验 | 未填名称保存 | `validate()` 失败，提示缺失字段，阻止保存 |

### 3.5 模板导入 `/pages/templates/import`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-DATA-016 | P0 | 导入有效模板 | 选择合法 `.pptpl` 文件 | `parse()` 成功，预览模板，确认后入库 |
| LM-TPL-ERR-017 | P0 | 导入损坏文件 | 选择非法/损坏 JSON | `validate()` 失败，提示「模板文件无效」，不入库 |
| LM-TPL-DATA-018 | P1 | 旧版本迁移 | 导入旧版本模板 | `checkCompatibility()` 识别，`migrate()` 升级后可用 |
| LM-TPL-ERR-019 | P2 | 重复导入 | 导入已存在的模板 | 提示重复，提供「覆盖/保留副本」选项 |

### 3.6 模板引擎数据（TemplateEngine）

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-TPL-DATA-020 | P0 | parse 往返一致 | serialize 后再 parse | 数据无损，字段一致 |
| LM-TPL-DATA-021 | P0 | validate 缺字段 | 校验缺 meta.id 的模板 | 返回 `ValidationResult` 含错误项 |
| LM-TPL-DATA-022 | P1 | 兼容性检查 | 检查未来版本号 | `checkCompatibility` 返回不兼容标识 |

---

## 4. 相册与后期模块（Gallery）

### 4.1 权限用例

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-GAL-ERR-001 | P0 | 首次相机授权 | 首次进入拍摄页 | 弹系统相机授权；允许→正常预览；拒绝→显示引导去设置 |
| LM-GAL-ERR-002 | P0 | 存储授权 | 首次保存照片 | 弹存储授权；拒绝→提示无法保存 |

### 4.2 相册页 `/pages/gallery/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-GAL-NAV-003 | P0 | 打开照片详情 | 点击相册缩略图 | 跳转 `/pages/gallery/detail`，加载该照片 |
| LM-GAL-DATA-004 | P0 | 相册列表加载 | 进入相册页 | 从 SQLite 读取拍摄记录，按时间倒序网格展示 |
| LM-GAL-UI-005 | P2 | 空相册态 | 无照片时进入 | 显示空态占位与「去拍摄」入口 |

### 4.3 后期编辑 `/pages/gallery/detail`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-GAL-DATA-006 | P0 | 加载图像 | 进入后期页 | `ImageProcessingService.load()` 返回句柄，画布显示图像 |
| LM-GAL-UI-007 | P0 | 调色滑块 | 拖动 ColorSliders 亮度 | `adjustColor()` 实时预览，数值 mono 显示 |
| LM-GAL-UI-008 | P1 | LUT 滤镜 | LutSelector 选滤镜 | `applyLut()` 生效，画面变化 |
| LM-GAL-UI-009 | P1 | 磨皮/锐化 | 拖 SmoothSlider/SharpenSlider | `smooth()`/`sharpen()` 强度实时生效 |
| LM-GAL-UI-010 | P1 | 裁剪 | 拖动 CropFrame | 裁剪框调整，`crop()` 应用 |
| LM-GAL-UI-011 | P1 | 前后对比 | 长按 CompareToggle | 显示原图，松手回到编辑效果 |
| LM-GAL-UI-012 | P0 | 隐藏悬浮 Tab | 进入后期页 | 后期工作台不显示悬浮 Tab 栏（沉浸编辑） |
| LM-GAL-DATA-013 | P0 | 导出照片 | 点「导出」 | `applyPostProcess()` + `export()` 生成成品，写入相册，无跟踪标识 |
| LM-GAL-UI-014 | P1 | 重置编辑 | 点「重置」 | 所有参数归零，画布还原原图 |
| LM-GAL-DATA-015 | P1 | 句柄释放 | 退出后期页 | `release(handle)` 调用，内存释放 |
| LM-GAL-ERR-016 | P1 | 导出失败处理 | 存储空间不足时导出 | 捕获异常，提示「存储空间不足」，不崩溃 |

---

## 5. 我的模块（Profile）

### 5.1 我的页 `/pages/profile/index`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-PRF-DATA-001 | P1 | 统计数据加载 | 进入我的页 | ProfileStats 从 SQLite 聚合：拍摄张数/使用模板数/收藏数，数字正确 |
| LM-PRF-NAV-002 | P1 | 进入设置 | 点「设置」 | 跳转 `/pages/profile/settings` |
| LM-PRF-NAV-003 | P1 | 我的相册 | 点「我的相册」 | 跳转 `/pages/gallery/index` |
| LM-PRF-NAV-004 | P1 | 我的模板 | 点「我的模板」 | 跳转模板库（我的创建筛选） |
| LM-PRF-NAV-005 | P1 | 导入模板 | 点「导入模板」 | 跳转 `/pages/templates/import` |

### 5.2 设置页 `/pages/profile/settings`

| 编号 | 优先级 | 场景 | 操作步骤 | 预期结果 |
|---|---|---|---|---|
| LM-PRF-UI-006 | P2 | 切换设置项 | 切换保存画质/网格默认显示等 | 设置持久化到本地，重启后保留 |
| LM-PRF-NAV-007 | P2 | 关于页 | 点「关于如画」 | 显示版本号与产品信息 |
| LM-PRF-DATA-008 | P2 | 清除缓存 | 点「清除缓存」 | 清理临时文件，相册与模板数据保留 |

---

## 6. 异常与边界总表

| 编号 | 优先级 | 场景 | 预期结果 |
|---|---|---|---|
| LM-SVC-ERR-001 | P0 | 原生插件不可用 | Camera/ImageProcessing 插件缺失时降级提示，不白屏 |
| LM-SVC-ERR-002 | P1 | SQLite 读写失败 | 捕获异常并提示，界面保持可用 |
| LM-SVC-ERR-003 | P1 | 大图内存溢出 | 超大照片加载做尺寸限制/降采样，不 OOM |
| LM-SVC-ERR-004 | P2 | 磁盘满 | 保存/导出前检测空间，友好提示 |
| LM-SVC-ERR-005 | P0 | 无任何网络请求 | 全程抓包验证：App 不发起任何网络连接（离线合规底线） |

---

## 7. 冒烟测试清单（发布前必过 P0）

- [ ] 冷启动 → 进入拍摄页 → 相机预览正常
- [ ] 应用一个内置模板 → 构图叠图正确显示
- [ ] 点快门 → 预览 → 保存到相册成功
- [ ] 相册 → 打开照片 → 后期调色 → 导出成功
- [ ] 模板库 → 导出 `.pptpl` → 重新导入成功
- [ ] 三个 Tab 互相切换，悬浮 Tab 栏选中态与深/浅态正确
- [ ] 抓包确认零网络请求
