# 模板生成技能：生图引擎区分（qwen / gpt-image2）与宽高比贯穿

- 日期：2026-09-30
- 范围：`skills/template-builder/`（主）+ `skills/anti-infringement-pose-edit/` + `scripts/gpt_image2.py`
- 关联：
  - `docs/template-prompt-v3.md`（模板结构字段 / `composition.aspectRatio` 取值域）
  - 提交 `92cd8cff`（新增线上模板与姿势生成技能、切换低价生图模型）
- 前置状态：两个技能已落地，反侵权步骤为「多图打包成 2x2 四宫格 → 裁剪」，出图尺寸与 `composition.aspectRatio` 均写死 3:4
- 产品影响：仅影响模板素材生产工具链，不改动后端 / 后台 / Flutter

---

## 1. 背景与问题

模板生成链路目前把所有生图调用都交给同一个平台与模型，存在四个问题：

1. **引擎不区分**。`run_template.py` 与 `run_batch_edit.py` 的 `--platform` 默认 `hapi`、`--model` 取该平台 `models[0]`，即 `gpt-image-2.5-sunburst-2k`；代码里没有任何「引擎」概念。
2. **批量上限不区分**。反侵权步骤单次请求的图片数是固定值：`--max-per-call` 默认 4，且 `template-builder` 调子进程时**根本不传这个参数**，所以永远按 4 张走。而不同模型对单次输入图片数上限不同（qwen-image 系列最多 3 张），一旦换模型就会整批请求失败、逐张回退。
3. **宫格布局写死 2x2**。`crop_grid(im, 2, 2)` 的 `2, 2` 是调用处硬编码；批内目标数不足 4 时（如 3 张、2 张）仍要求模型排 2x2，空格只能靠 `validity` 判定 + 单图回退兜底，且模型把图排到非预期格位时会错位。
4. **宽高比写死 3:4**。`run_template.py` 的 `SIZE = "768x1024"`、`write_docs()` 里 `composition.aspectRatio: "3:4"`、文生图提示词里的「3:4竖构图」都是常量；而模板的宽高比应当由参考内容决定（产品规范见 `docs/template-prompt-v3.md`：先量样片真实宽高比，再作为 `composition.aspectRatio`）。写死会导致非 3:4 参考图产出的模板比例错误，且 App 取景框比例、剪影与成片画布全部错位。

## 2. 目标与非目标

### 目标

- **引擎可切换且默认 qwen**：新增语义开关 `--engine`，默认走 `qwen-image-3.0-pro`（MaaS）；需要 gpt-image2 2K 时显式指定 `--engine gpt2k`（HAPI）。
- **批量上限跟随引擎**：单次请求图片上限由引擎预设决定（qwen 3 / gpt 4），并自动贯穿到子进程。
- **宫格布局动态化**：按每批实际目标数决定行列布局，不再固定 2x2，不产生空格。
- **宽高比端到端一致**：模板比例从参考内容来，统一驱动提示词约束、出图尺寸、宫格画布、`composition.aspectRatio`，并保证所有成片尺寸完全一致。

### 非目标

- 不改动剪影生成流程（仍为：以姿势图为参考做图生图 → 阈值二值化 → 按内容紧裁）。
- 不新增平台、不接入新的第三方渠道；只补 `mass` 平台缺失的 qwen 3.0 模型名。
- 不改动后端 / 后台 / Flutter 端任何代码。
- 不重构两个技能的既有骨架（输入解析、宫格拆分、产物命名、文档写出）。
- 不修本文档「7. 不在本次范围」列出的既有缺陷。

## 3. 总体设计

### 3.1 引擎预设（单一真源）

在 `scripts/gpt_image2.py` 的 `PLATFORMS` 之后新增：

```python
ENGINES = {
    "qwen3pro": {"platform": "mass", "model": "qwen-image-3.0-pro",       "max_input_images": 3},
    "gpt2k":    {"platform": "hapi", "model": "gpt-image-2.5-sunburst-2k", "max_input_images": 4},
}
DEFAULT_ENGINE = "qwen3pro"
FALLBACK_MAX_INPUT_IMAGES = 4   # 手填其他 model 时的兜底上限
```

并新增解析函数，供两个技能复用：

```python
def resolve_engine(engine=None, platform=None, model=None, max_input_images=None) -> dict
```

返回 `{"engine", "platform", "model", "max_input_images", "key_env"}`。

- **优先级**：显式 `--platform` / `--model` / `--max-per-call` > `ENGINES[engine]` > `DEFAULT_ENGINE` 对应项。
- 同时把 `qwen-image-3.0-pro` 补进 `PLATFORMS["mass"]["models"]`（当前只有 `qwen-image-2.0-pro`）。

选在 `gpt_image2.py` 而非技能目录内新建模块，理由是：两个技能已经 `import gpt_image2`，平台/密钥/尺寸工具都在这里，引擎预设与 `PLATFORMS` 同源可以避免两处清单漂移。

### 3.2 CLI 与覆盖优先级

两个脚本的参数统一为：

| 参数 | 现状 | 改后 |
|---|---|---|
| `--engine` | 无 | 新增，默认 `qwen3pro`（即默认走 qwen） |
| `--platform` | 默认 `"hapi"` | 默认 `None`，仅作覆盖 |
| `--model` | 默认 `None` | 不变，仅作覆盖 |
| `--max-per-call` | 仅子脚本有，默认 4 | 默认 `None` → 按引擎/模型推导；`template-builder` 新增同名参数并透传 |
| `--ratio` | 仅子脚本有，默认 `None` | 两边都有；`template-builder` 默认取 `cfg.aspect_ratio` |
| `--size-batch` | 子脚本有，比例推断失败时的方形兜底 | **移除**。比例恒有兜底（`3:4`），画布改由「单格尺寸 × 布局」反算，该参数不再参与计算。`--size-single` 保留，仅用于单图路径 |

`template-builder` 调子进程时把解析结果**显式**透传（`--platform --model --max-per-call --ratio`），避免父子两层各自解析引擎导致不一致。

### 3.3 批大小与动态宫格布局

`build_batches()` 的既有结构天然适配，无需改动：首批 ≤ 上限（无锚点，可满员）；后续每批 ≤ 上限−1 目标 + 1 张锚点（锚点 = 首批首张成片），恰好卡满上限。

| 引擎 | 上限 | 首批 | 后续每批 | 9 张输入的实际分批 |
|---|---|---|---|---|
| qwen3pro | 3 | 3 目标 | 2 目标 + 1 锚点 | `[0,1,2]` `[3,4]+锚` `[5,6]+锚` `[7,8]+锚`（4 批） |
| gpt2k | 4 | 4 目标 | 3 目标 + 1 锚点 | `[0..3]` `[4,5,6]+锚` `[7,8]+锚`（3 批） |

布局按**本批实际目标数 `n`** 决定（`r` = 模板宽高比）：

| n | 布局 (rows, cols) | 说明 |
|---|---|---|
| 1 | — | 不走宫格，直接单图编辑（仍附锚点以保留跨批统一衣着；受既有 `--prompt` 限制，见 §7） |
| 2 | `r ≤ 1` → (1,2)；`r > 1` → (2,1) | 竖构图横排 / 横构图竖排 |
| 3 | `r ≤ 1` → (1,3)；`r > 1` → (3,1) | 同上 |
| 4 | (2,2) | 固定方阵 |

选向规则的原因：单行/单列布局的画布长宽比 = `n × r`（横排）或 `r / n`（竖排），必须落在 `gpt_image2.MAX_RATIO = 3.0` 之内，否则 `_clamp_size()` 会触发比例钳制。按上表取向，`r ∈ [1/3, 3]` 时结果均 ≤ 2.25（`r = 1` 时为 3.0，取等号不触发钳制）。

`crop_grid()` **需要扩展后才能用**：当前实现每个轴只定位**一条**中央分隔带，并用它推出该轴所有格边界（`crop_grid.py` L205-L246）；`cols=3` 时中间那一格的左右边界会取到同一条分隔线，裁出零宽废格。改法：新增多分隔线定位——按等分位置推出 `k-1` 条内部低方差分隔带（在各预期边界附近的小窗口内复用既有 `_sep_line` 的容差扩展逻辑），以相邻分隔带的中点为格边界，定位不到时保留既有的等分退路。定位完成后 `cells[:len(targets)]` 的索引映射逻辑不变。

### 3.4 画布尺寸反算

单格目标尺寸：**短边 `CELL_SHORT = 768`**，按比例计算后四舍五入到 16 的倍数。

| r | 单格 | 2 格画布 | 3 格画布 | 4 格画布（2x2） |
|---|---|---|---|---|
| 3:4 | 768x1024 | 1536x1024 | 2304x1024 | 1536x2048 |
| 4:3 | 1024x768 | 1024x1536 | 1024x2304 | 2048x1536 |
| 1:1 | 768x768 | 1536x768 | 2304x768 | 1536x1536 |

（2 格 / 3 格的画布尺寸按其取向布局计算：`r ≤ 1` 为横排 `n` 列，`r > 1` 为竖排 `n` 行。）

画布尺寸 = `(cols × cellW) × (rows × cellH)`，仍经 `gpt_image2.resolve_size()` → `_clamp_size()` 过一遍边长（3840）/像素（0.65M~8.29M）/比例（≤3:1）约束。`_clamp_size()` 只做等比缩放与 16 对齐，不改变比例，因此单格比例始终等于模板比例。

相对现状：2x2 画布从 `768x1024` 变为 `1536x2048`，单格从约 `384x512` 提升到 `768x1024`。

### 3.5 宽高比链路

比例来源优先级：`--ratio` > `cfg.aspect_ratio` > 从参考图推断（复用 `infer_ratio`）> 兜底 `3:4`。

- `config.json` 新增 `aspect_ratio` 字段，取值限定为 `3:4 | 4:3 | 16:9 | 9:16 | 1:1`（与 `docs/template-prompt-v3.md` 的 `composition.aspectRatio` 取值域一致），由 agent 依据参考内容（链接/参考图/创作要求）判定后写入。
- 该比例统一驱动五处：
  1. **提示词约束**：所有出图提示词显式写明「画面比例严格为 `w:h`，不得改变画幅比例」（见 §5）。
  2. **出图尺寸**：`run_template.py` 的 `SIZE` 常量改为按比例计算（`pose_size(r)`）。
  3. **宫格画布**：§3.4 反算。
  4. **`template.pptpl`**：`composition.aspectRatio` 由常量 `"3:4"` 改为该比例值。
  5. **成片归一化**：§3.6。

### 3.6 成片比例归一化

裁剪出的每格像素尺寸取决于宫格分隔线位置，必然与目标单格尺寸有差异。为满足「所有生成的单张图片必须一致」，落盘前对每张成片做归一化：

1. 按目标比例居中裁剪（只裁掉多余边缘，不做拉伸变形）；
2. LANCZOS 缩放到目标单格像素（如 `768x1024`）。

并打印每张产物的实际尺寸与比例偏差，偏差 > 1% 时告警。

归一化对**宫格裁剪产物与单图回退产物**同样生效，因此无论走哪条路径，最终 `pose{i}.png` 的像素尺寸都一致。

### 3.7 剪影（保持不变）

`gen_silhouette()` 流程不变：以姿势图为参考图生图 → `binarize_to_transparent()` 阈值二值化 → `crop_to_content()` 按 alpha bbox 紧裁。唯一变化是它请求的出图尺寸的比例跟随模板比例（入参姿势图已是同比例）。紧裁后的剪影尺寸不固定，属既有行为，本次不动。

## 4. 改动清单

| 文件 | 改动 |
|---|---|
| `scripts/gpt_image2.py` | 新增 `ENGINES` / `DEFAULT_ENGINE` / `FALLBACK_MAX_INPUT_IMAGES` / `resolve_engine()`；`PLATFORMS["mass"]["models"]` 补 `qwen-image-3.0-pro` |
| `skills/anti-infringement-pose-edit/scripts/crop_grid.py` | 新增多分隔线定位，使每个轴可切 3 格及以上（当前每轴仅支持一条中央分隔带，`rows/cols ≥ 3` 会裁出零宽废格）；`crop_grid()` 签名与 `validity` 语义不变 |
| `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py` | 新增 `--engine`；`--platform`/`--max-per-call` 默认改 `None` 并按引擎推导；按本批 `n` 选布局并把布局传给 `crop_grid`；画布尺寸改为「单格尺寸 × 布局」；成片归一化；提示词注入比例约束；单图路径支持附锚点；`--dry-run` 输出引擎/上限/分批/每批布局与画布尺寸 |
| `skills/template-builder/scripts/run_template.py` | 新增 `--engine` / `--max-per-call` / `--ratio`；`SIZE` 改为按比例计算；`write_docs()` 的 `aspectRatio` 用该比例；文生图提示词去掉写死的「3:4竖构图」；调子进程时透传 `engine/platform/model/max-per-call/ratio`；完成时打印每张成片尺寸 |
| `skills/anti-infringement-pose-edit/SKILL.md` | 同步引擎、上限、动态布局、比例约束的说明与示例命令 |
| `skills/template-builder/SKILL.md` | 同步默认引擎、`config.json` 新增 `aspect_ratio` 字段、示例命令 |

## 5. 提示词改动

在既有提示词上追加一句比例约束，不改动既有语义：

- `BASE_PROMPT` / `SINGLE_PROMPT` / `GRID_SUFFIX`（反侵权）
- `run_template.py` 的 auto-gen 文生图提示词（替换写死的「3:4竖构图」）
- `SIL_PROMPT`（剪影）

统一措辞：`画面比例严格为 {w}:{h}，不要改变画幅比例。`

宫格指令还需按本批布局生成，例如：`请将每张输入图的修改结果按 1 行 3 列整齐排列为一张输出图（顺序：从左到右，与输入顺序一致）`。

## 6. 验收标准

1. `--dry-run` 可打印：解析出的引擎 / 平台 / 模型 / 单次上限 / 分批计划 / 每批布局与画布尺寸 / 模板比例。
2. 默认（不传 `--engine`）时解析结果为 `mass` + `qwen-image-3.0-pro` + 上限 3；传 `--engine gpt2k` 时为 `hapi` + `gpt-image-2.5-sunburst-2k` + 上限 4。
3. qwen3pro 下 9 张输入 → 4 批，每批含锚点在内不超过 3 张图；gpt2k 下 9 张 → 3 批，每批不超过 4 张图。
4. 任一引擎下，产出的所有 `pose{i}.png` 像素尺寸完全一致，且等于目标单格尺寸；日志中每张比例偏差 < 1%。
5. `template.pptpl` 的 `composition.aspectRatio` 等于 `cfg.aspect_ratio`。
6. 反侵权整批失败率显著下降（不再因超出模型输入张数上限而整批失败）。

验证方式：先跑 `--dry-run` 校验 1~3；再用一次真实小样本（3 张参考图）跑通 4~6。

## 7. 不在本次范围

以下为已发现的既有缺陷，本次不处理，仅记录：

- 宫格拆分产物落盘在原图所在目录（本地路径输入时会污染源目录）。
- 反侵权加工失败时静默退回原图继续出模板，产出可能含侵权风险。
- 自定义 `--prompt` 时锚点图**既不加说明也不随请求发送**，跨批统一衣着失效。
- 反侵权单图回退产物为 `r{n}_.png`，`template-builder` 侧按 `out*.png` 排序取值会索引错位、末尾丢张。
- 剪影紧裁后尺寸不固定（既有行为）。

## 8. 风险与权衡

| 风险 | 说明 | 应对 |
|---|---|---|
| `mass` 是否真的提供 `qwen-image-3.0-pro`、以及其单图输入上限是否为 3 | 代码清单此前只有 2.0-pro，属未实测假设 | 实施第一步先用该引擎跑通 1 批真实请求验证；若模型名不可用则改回 `qwen-image-2.0-pro` 并同步上限 |
| 单格短边 768 使 2x2 画布达到 1536x2048（约 3.1MP） | 相比现状 768x1024 输出像素放大约 4 倍，单次成本与时延上升 | 已确认接受（换来成片分辨率从约 384x512 提升到 768x1024）；`CELL_SHORT` 作为常量集中定义，后续可调 |
| 单行 3 列 / 单列 3 行是新布局，模型排版能力未知 | 排错格位会导致裁剪错配 | 保留既有 `validity` 空白判定 + 单图回退兜底；`--dry-run` 与日志可核对格位映射 |
| qwen 上游对大体积 base64 输入超时 | `run_template.py` 的 `load_ref_tuple` 注释已记录 MaaS/qwen-image-3.0-pro 出现过该问题 | 沿用现有「参考图统一压成 JPEG 再上传」策略，不改动 |
