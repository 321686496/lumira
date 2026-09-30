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

- 环境变量 API Key（或 `--api-key`）：默认引擎 `qwen3pro` 走 `MASS_API_KEY`；`--engine gpt2k` 走 `HAPI_API_KEY`——复用于 `gpt_image2.py` hapi 图生图/文生图。
- `requests`、`Pillow` 可用；反侵权技能的 `run_batch_edit.py` 在同一仓库内。
- 联网搜索/爬取：**由 agent 自带联网工具完成**（无独立爬虫脚本）。

## 目录

```
skills/template-builder/
├── SKILL.md
└── scripts/run_template.py   # 主编排
```

## 执行流程（agent 逐段推进）

1. **判定输入并收集素材**
   - **链接(URL)**：用你的 WebFetch/WebSearch 抓取正文要点 + 收集图片 URL（og:image / 正文首图等），图片交给脚本下载。
   - **参考图**：直接采用。
   - **创作要求(纯文本)**：用你的联网搜索收集准确内容与图片资源。
   - 把收集到的信息整理成 `config.json`（见下），图片作为 `--inputs` 传入。

2. **宫格检测/拆分**：脚本对每张参考图先判断是否宫格拼图（低方差分隔线检测），是则拆成多张单图再继续；否 则作单图。

3. **姿势图加工**
   - **有真实参考图** → 脚本自动调用 `anti-infringement-pose-edit/run_batch_edit.py` 对姿势图做换脸防侵权 + 统一衣着，得到 N 张干净成片姿势图（`--skip-anti-infringement` 可跳过）。
   - **无参考图** → 加 `--auto-gen`，脚本基于 `cfg.poses[i].description` 用 hapi 文生图自动补姿势。

4. **剪影**：对每张 `pose{i}.png` **单独一次 hapi 图生图**（提示词要求纯白底极简黑色线稿，只勾姿势轮廓），再用阈值 245 二值化转透明底线稿 → `pose{i}_sil.png`。逐个生成以保证姿势与姿势图一致、质量最高。

5. **组装文档**：生成 `pose_images.json`（姿势名→文件）与 `template.pptpl`（与后端在线模板同构，可被导入）。

6. **输出**：全部产物写入 **`create_templates/<key>/`**（根目录下）。

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

默认走 **`qwen-image-3.0-pro`（MaaS，单次最多 3 张输入图）**；需要 GPT-Image-2 2K 时显式指定 `--engine gpt2k`（HAPI，单次最多 4 张）：

```bash
# 默认: qwen3pro
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png

# 指定 gpt-image2 2K
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png --engine gpt2k
```

引擎决定平台、模型与「单次请求图片上限」三件事，并自动透传给反侵权子步骤；`--platform` / `--model` / `--max-per-call` 可单独覆盖。
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

- 宫格检测为启发式（低方差分隔线），异常布局可能误判；必要时人工先拆好或用 `--inputs` 逐张传入。
- 真实参考图必须经过反侵权加工，否则有侵权风险；`--skip-anti-infringement` 仅限素材本身已合规时用。
- 剪影依赖 hapi 是否能忠实"只描轮廓"；若个别剪影含五官/衣服细节，自动二值化后应复查重试。