---
name: template-builder
description: >
  走线上模板制作全流程：agent 根据输入的 链接/参考图/创作要求 判定并收集素材（链接用自带
  联网工具抓正文+图片，纯文本用联网搜索，图片直接采用），必要时把宫格图拆成多张，真实参考图
  先过「反侵权技能」加工成干净成片姿势图，无参考图则文生图补姿势，再逐张图生图生成黑色线稿剪影，
  最后组装 template.pptpl+pose_images.json 并输出到 create_templates/<key> 供后台上传。
  当用户提供链接/参考图/创作要求并希望产出一套拍照模板时调用。
---

# 模板制作全流程（template-builder）

## 用途与触发

把「一份外部参考（链接 / 参考图 / 创作要求）」变成一个可上传的线上模板：统一的 N 张姿势图 + 对应黑色线稿剪影 + `template.pptpl` + `pose_images.json`。

**触发**：用户给出链接 / 一张或多张参考图 / 一段创作要求，并表达"做模板 / 生成一套姿势模板 / 按小红书的姿势做模板"等意图时调用。可配合 `anti-infringement-pose-edit`（真实参考图防侵权加工）一起使用。

## 运行前提

- 环境变量 API Key（或 `--api-key`）：文生图/剪影默认引擎 `qwen3pro` 走 `MASS_API_KEY`；反侵权默认引擎 `qwen3` 也走 `MASS_API_KEY`；`--engine gpt2k` 走 `HAPI_API_KEY`——复用 `gpt_image2.py` 的图生图/文生图接口。
- `requests`、`Pillow` 可用；反侵权技能的 `run_batch_edit.py` 在同一仓库内。
- 联网搜索/爬取：**由 agent 自带联网工具完成**（无独立爬虫脚本）。

## 目录

```
skills/template-builder/
├── SKILL.md
└── scripts/run_template.py   # 主编排
```

## 执行流程（agent 逐段推进）

> ⏱️ **执行纪律与时间预算（硬性，违反=事故）**：本流程理论耗时 **≤30 分钟**（参考收集 5min + 反侵权 4 次调用 6min + 剪影 6min + 组装秒级 + 验收 3min）。
> 1. **一条命令跑通**：`run_template.py` 自动串联 拆分→反侵权→剪影→组装。命令启动后**中途禁止停下来逐张看图、禁止边跑边改**，让脚本一次跑到组装完成。
> 2. **QA 只做一次**：组装完成后对全部成片**一次性**看图验收（不许逐张多轮看）。
> 3. **返工硬上限**：整批重跑 ≤2 轮、单张重生成 ≤3 次。**禁止创建 `_reedit{N}` 轮次目录**——重跑直接覆盖输出目录同名文件。超限立即停止，把不合格清单写入 `qa_report.md` 交用户决策，**绝不无限打磨**。
> 4. QA 由历史教训（6 轮 reedit 烧 3 小时）而来：agent 的"多看一眼、再修一张"就是时间黑洞，纪律优先于完美。

1. **判定输入并收集素材**
   - **链接(URL)**：用你的 WebFetch/WebSearch 抓取正文要点 + 收集图片 URL（og:image / 正文首图等），图片交给脚本下载。
   - **参考图**：直接采用。
   - **创作要求(纯文本)**：用你的联网搜索收集准确内容与图片资源。
   - 把收集到的信息整理成 `config.json`（见下），图片作为 `--inputs` 传入。
   - **素材存放约定（硬性）**：agent 收集/下载的参考原图与派生裁剪图，一律存到 **`create_templates/<key>/_refs/`**（与脚本自下载 URL 的 `_refs` 目录同构，config.json 同放 `<key>/` 下），`--inputs` 从该目录取路径；禁止散落在项目根目录等临时位置，验收通过后 `_refs/` 随中间产物按需清理。

2. **宫格检测/拆分**：脚本对每张参考图做布局检测（支持 k×k 正宫格与 1×n/n×1 横竖排，两级阈值抓白缝），是宫格则用反侵权技能的 `crop_grid` 拆分（band 边缘切 + 均质边清理），并**自动校验**：每格非空白、格尺寸一致；任一格空白或尺寸异常判为误检、该图回退按单图处理。拆分张数与 `cfg.poses` 数不符时打印告警，Agent 须在 QA 时逐张复核 panel。无缝宫格（格间无分隔线）无法自动检测，必要时人工预拆或 `--no-split` 逐张传入。

3. **姿势图加工**
   - **有真实参考图** → 脚本自动调用 `anti-infringement-pose-edit/run_batch_edit.py` 对姿势图做换脸防侵权 + 统一衣着，得到 N 张干净成片姿势图（`--skip-anti-infringement` 可跳过；引擎由 `--anti-engine` 决定，默认 `qwen3`/MaaS 快速通道，勿用 qwen3pro——mass 120s 硬超时会 502）。脚本会从 `cfg.poses[i].description` 提取景别（全身/半身）自动生成**构图提示**（含头顶/脚下留白与禁止推近裁切的约束）传给反侵权编辑，保持参考图构图；反侵权走 gpt2k 时自动启用 `input_fidelity=high`。
   - **无参考图** → 加 `--auto-gen`，脚本基于 `cfg.poses[i].description` 用引擎的文生图自动补姿势（默认 `qwen3pro`/MaaS，`--engine gpt2k` 走 HAPI）。

4. **姿势图 QA 与纠错（一次性验收）**：组装完成后，Agent 用看图能力对全部 `pose{i}.png` **一次性逐张审查**（就一次，不许反复看），判据见 `anti-infringement-pose-edit` 技能的「加工后 Agent 视觉 QA 与自动纠错」一节（对照参考原图 + cfg.poses 姿势描述 + `aspect_ratio`）：裁剪错位（人物被切/邻格串入）、**构图忠实度（景别/人物占比/留白与参考一致，成片明显更"满"即 FAIL，重点）**、**面部可见性一致性（原图不露脸→成片不得露脸，重点）**、人物/背景畸变、一致性。不合格张按其纠错闭环单图修复；**整批返工 ≤2 轮、单张 ≤3 次，超限即写 `qa_report.md` 交用户决策**，不擅自交付也不无限打磨。

5. **剪影**：对每张 `pose{i}.png` **单独一次图生图**（默认 `qwen3pro`/MaaS，`--engine gpt2k` 走 HAPI；提示词要求纯白底极简黑色线稿，只勾姿势轮廓），再用阈值 245 二值化转透明底线稿 → `pose{i}_sil.png`。逐个生成以保证姿势与姿势图一致、质量最高。剪影生成后同样抽查与对应姿势图姿势比例是否吻合。

6. **组装文档**：生成 `pose_images.json`（姿势名→文件）与 `template.pptpl`（与后端在线模板同构，可被导入）。

7. **输出**：全部产物写入 **`create_templates/<key>/`**（根目录下）。

## 用法

```bash
# 有参考图(含宫格/多张) → 反侵权加工 → 剪影 → 文档(默认输出 create_templates/<key>)
python scripts/run_template.py --key my_tpl --cfg config.json \
    --inputs ref1.png ref2.png ref3_9grid.png

# 指定任意输出父目录
python scripts/run_template.py --key my_tpl --cfg config.json \
    --inputs img_a.jpg https://xx/og.jpg --parent /some/path

# 纯文字/无图 → 文生图补姿势
python scripts/run_template.py --key my_tpl --cfg config.json --auto-gen --count 9

# 只预览
python scripts/run_template.py --key my_tpl --cfg config.json --dry-run
```

## 生图引擎

**分工默认**：反侵权加工走 `--anti-engine`（默认 `qwen3` = `mass`/`qwen-image-3.0`，快速）；文生图补姿势与剪影走 `--engine`（默认 `qwen3pro` = `mass`/`qwen-image-3.0-pro`）；需要 GPT-Image-2 2K 时显式指定 `--engine gpt2k`（HAPI，单次最多 4 张）：

> ⚠️ **反侵权勿用 `qwen3pro`**（2026-10 实测）：mass 平台对生图任务有 **120s 硬超时**，pro 版换脸级重绘任务 >120s 必然 502（`upstream_error: timeout`）。非 pro 版 `qwen-image-3.0` 同任务 31s、宫格 3 图约 90s 稳定通过，质量肉眼接近 pro。轻任务（色调/衣着/白底线稿）用 pro 不超时，所以 `--engine` 默认保持 qwen3pro。

```bash
# 默认: 反侵权 qwen3 / 文生图与剪影 qwen3pro
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png

# 指定 gpt-image2 2K（剪影仍可留给 MaaS 省成本）
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png --engine gpt2k --sil-engine qwen3pro
```

`--engine` 决定文生图/剪影的平台、模型与「单次请求图片上限」；反侵权子步骤由 `--anti-engine` 决定（默认 qwen3）；`--platform` / `--model` / `--max-per-call` 可单独覆盖。
另有 `--ratio`（覆盖 config.json 的 aspect_ratio）与 `--anti-no-grid`（反侵权不做宫格打包、每张单独编辑；渠道对多图输入超时时使用）。

## config.json 结构

```json
{
  "key": "my_tpl",
  "name": "模板名",
  "short_desc": "一句带情感价值的短文案",
  "description": "长描述",
  "tags": ["人像","旅拍"],
  "reference_source": "来源说明",
  "aspect_ratio": "3:4",
  "classification": {"majorStyle": "outdoor_travel", "style": "snow_cloud_hike", "method": ""},
  "ambience": {"seasons": ["autumn"], "weathers": ["sunny"], "timeTones": ["day"]},
  "style_prompt": "（auto-gen 时用）人物/场景/穿搭统一描述",
  "poses": [
    {"name": "封面·伸手探镜", "description": "姿势动作详述"},
    { "...更多，与姿势图一一对应" }
  ],
  "scene_guide": {},
  "post_process": {}
}
```

- 姿势图数量 = 参考图拆分后张数，或 `--count` 指定；`cfg.poses` 与之对齐。
- `scene_guide` / `post_process` 选填，直接透写入 `template.pptpl`。
- `aspect_ratio`：模板宽高比，**必须依据参考内容（链接正文/参考图/创作要求）判定后写入**，取值 `3:4 | 4:3 | 16:9 | 9:16 | 1:1`。它统一决定姿势图与剪影的出图尺寸、反侵权宫格画布、成片的最终像素与 `template.pptpl` 的 `composition.aspectRatio`。缺省时脚本按参考图比例推断，再缺省 `3:4`。

## 已知假设与局限

- 宫格检测为启发式（低方差分隔线 + 近白缝），**无缝宫格（格间无分隔线、内容直接相接）无法自动检测**；异常布局可能误判，必要时人工先拆好或用 `--inputs` 逐张传入（配 `--no-split`）。拆分后脚本会自动校验空白格/格尺寸并告警，Agent 仍须在 QA 时复核 panel。
- 真实参考图必须经过反侵权加工，否则有侵权风险；`--skip-anti-infringement` 仅限素材本身已合规时用。
- 构图保持依赖反侵权提示词的构图硬约束 + 每图构图提示 + hapi 通道 `input_fidelity`，生图模型仍可能偏离原图取景 → QA 的构图忠实度判据不可跳过，构图不符时用 `--anti-no-grid` 逐张重跑。
- 剪影依赖生图引擎是否能忠实"只描轮廓"；若个别剪影含五官/衣服细节，自动二值化后应复查重试。