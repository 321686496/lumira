# 模板生成技能：生图引擎区分与宽高比贯穿 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让模板生成链路支持两种生图引擎（默认 `qwen-image-3.0-pro` / 可选 `gpt-image2-2k`），单次请求图片上限随引擎自动区分，并把模板宽高比从参考内容端到端贯穿到尺寸、宫格布局与 `template.pptpl`。

**Architecture:** 引擎预设表与比例/尺寸纯函数集中放在共享库 `scripts/gpt_image2.py`（两个技能都已 import 它）；`run_batch_edit.py` 负责按批内张数动态选宫格布局、反算画布尺寸、裁剪并归一化成片；`crop_grid.py` 扩展为每个轴可定位多条分隔线以支持 3 格及以上；`run_template.py` 负责解析模板比例并透传给子进程。

**Tech Stack:** Python 3.13（仅标准库 + Pillow 12 / requests），无测试框架，验证方式为 `python -c` 断言 + `--dry-run` + 真实小样本端到端跑通。

## Global Constraints

- `CELL_SHORT = 768`：单张成片目标短边；`gpt_image2` 的既有尺寸约束必须保持不破：`MAX_SIDE = 3840`、`MIN_PIXELS = 655360`、`MAX_PIXELS = 8294400`、`MAX_RATIO = 3.0`、尺寸 16 对齐。
- `ENGINES` 只含两项：`qwen3pro` → `mass` / `qwen-image-3.0-pro` / `max_input_images = 3`；`gpt2k` → `hapi` / `gpt-image-2.5-sunburst-2k` / `max_input_images = 4`。`DEFAULT_ENGINE = "qwen3pro"`，`FALLBACK_MAX_INPUT_IMAGES = 4`。
- `aspect_ratio` 取值域限定 `3:4 | 4:3 | 16:9 | 9:16 | 1:1`，兜底 `3:4`（与 `docs/template-prompt-v3.md` 的 `composition.aspectRatio` 一致）。
- 引擎优先级：显式 `--platform` / `--model` / `--max-per-call` > `ENGINES[engine]` > `DEFAULT_ENGINE` 对应项。
- **不改动**：后端 / 后台 / Flutter；剪影流程（图生图 → 阈值二值化 → `crop_to_content` 紧裁）；两个技能的输入解析、宫格拆分、产物命名。
- **不在范围**（既有缺陷，勿顺手修）：宫格拆分落盘污染源目录、反侵权失败静默退回原图、自定义 `--prompt` 时锚点图不发送、`r{n}_.png` 回退导致索引错位、剪影紧裁后尺寸不固定。
- 工作区已有两处**未提交改动**（`scripts/gpt_image2.py` 的 `MassImages.edit` 改用 `images` 字段、`skills/template-builder/scripts/run_template.py` 的 `load_ref_tuple` / `--keep-grids` / `gender`）。它们是本计划的前置基础，**不得回退**。
- 每个任务结束前必须跑通该任务列出的验证命令并看到预期输出，再提交。

---

### Task 0: 固化工作区既有改动（前置）

**Files:**
- 无新增，仅提交已有未提交改动：`scripts/gpt_image2.py`、`skills/template-builder/scripts/run_template.py`

**Interfaces:**
- Consumes: 无
- Produces: 干净的工作区，使后续任务每次 commit 只包含本任务改动

- [ ] **Step 1: 确认待提交内容**

Run: `git diff --stat -- scripts/gpt_image2.py skills/template-builder/scripts/run_template.py`
Expected: 两个文件被列出，`scripts/gpt_image2.py` 约 5 行、`run_template.py` 约 32 行

- [ ] **Step 2: 提交**

```powershell
git add scripts/gpt_image2.py skills/template-builder/scripts/run_template.py
git commit -m "fix(scripts/skills): MassImages 多图改走 images 字段, 参考图压 JPEG 后上传" -m "MaaS(qwen-image-3.0-pro) 对大体积 base64 输入会上游超时; 同时把 platform/model 透传给反侵权子进程。"
```

- [ ] **Step 3: 确认工作区干净**

Run: `git status --short`
Expected: 只剩未跟踪的 `.tmp_edit/`、`.tmp_perfdata/` 之类临时目录（若你希望保留这两处改动为未提交状态，可跳过本任务，但后续 commit 会把它们一并带入）

---

### Task 1: 共享库引擎预设与比例尺寸工具

**Files:**
- Modify: `scripts/gpt_image2.py`（`PLATFORMS` 之后新增引擎预设；尺寸工具区新增比例/单张尺寸工具；`PLATFORMS["mass"]["models"]` 补模型名）

**Interfaces:**
- Consumes: 既有 `PLATFORMS`、`_round16(v)`
- Produces:
  - `ENGINES: dict`、`DEFAULT_ENGINE: str`、`FALLBACK_MAX_INPUT_IMAGES: int`
  - `resolve_engine(engine=None, platform=None, model=None, max_input_images=None) -> dict`，返回 `{"engine","platform","model","max_input_images","key_env"}`
  - `CELL_SHORT: int`
  - `parse_ratio(s) -> float`
  - `ratio_label(r: float) -> str`
  - `ratio_note(r: float) -> str`
  - `cell_size(ratio: float, short: int = CELL_SHORT) -> tuple[int, int]`
  - `cell_size_str(ratio: float, short: int = CELL_SHORT) -> str`

- [ ] **Step 1: 写失败验证**

Run: `python -c "import sys;sys.path.insert(0,'scripts');import gpt_image2 as g;print(g.ENGINES['qwen3pro']['max_input_images'])"`
Expected: FAIL — `AttributeError: module 'gpt_image2' has no attribute 'ENGINES'`

- [ ] **Step 2: 补 `mass` 模型清单**

在 `scripts/gpt_image2.py` 的 `PLATFORMS["mass"]["models"]` 中，把 `qwen-image-2.0-pro` 替换为：

```python
        "models": ["gpt-image-2", "gpt-image-1", "dall-e-3", "seedream-4.0",
                   "flux-1.1-pro", "wan2.7-image-pro", "qwen-image-3.0-pro"],
```

- [ ] **Step 3: 新增引擎预设与解析**

在 `scripts/gpt_image2.py` 中 `PLATFORMS = {...}` 字典之后、`# 兼容旧环境变量` 之前插入：

```python
# ---------------------------------------------------------------- 生图引擎预设

ENGINES = {
    "qwen3pro": {
        "label": "Qwen Image 3.0 Pro (MaaS)",
        "platform": "mass",
        "model": "qwen-image-3.0-pro",
        "max_input_images": 3,        # 该模型单次请求最多接受 3 张输入图
    },
    "gpt2k": {
        "label": "GPT-Image-2 2K (HAPI)",
        "platform": "hapi",
        "model": "gpt-image-2.5-sunburst-2k",
        "max_input_images": 4,
    },
}
DEFAULT_ENGINE = "qwen3pro"
FALLBACK_MAX_INPUT_IMAGES = 4   # 显式换平台/手填模型且未指定上限时的兜底


def resolve_engine(engine: str = None, platform: str = None, model: str = None,
                   max_input_images: int = None) -> dict:
    """解析「引擎预设 + 显式覆盖」, 返回最终生效的调用参数。

    优先级: 显式 platform/model/max_input_images > ENGINES[engine] > DEFAULT_ENGINE。
    - 显式换平台但没给模型 → 用该平台 models[0], 避免出现 platform/model 不匹配的组合;
    - 生效模型不是预设模型(手填或换平台得来) → 输入上限取 FALLBACK_MAX_INPUT_IMAGES。

    返回 {"engine","platform","model","max_input_images","key_env"}。
    """
    name = (engine or DEFAULT_ENGINE).strip()
    preset = ENGINES.get(name)
    if preset is None:
        raise ValueError(f"未知引擎: {name} (可选 {', '.join(ENGINES)})")
    p = (platform or preset["platform"]).strip()
    pcfg = PLATFORMS.get(p)
    if pcfg is None:
        raise ValueError(f"不支持的平台: {p} (可选 {', '.join(PLATFORMS)})")
    if model:
        m = model.strip()
    elif platform:
        m = pcfg["models"][0] if pcfg.get("models") else preset["model"]
    else:
        m = preset["model"]
    if max_input_images:
        cap = int(max_input_images)
    elif m != preset["model"]:
        cap = FALLBACK_MAX_INPUT_IMAGES
    else:
        cap = preset["max_input_images"]
    return {"engine": name, "platform": p, "model": m,
            "max_input_images": max(1, cap), "key_env": pcfg["key_env"]}
```

- [ ] **Step 4: 新增比例与单张尺寸工具**

在 `scripts/gpt_image2.py` 的 `def size_from_ratio(ratio_w: int, ratio_h: int) -> str:` 之后（`def size_from_image` 之前）插入：

```python
# ---------------------------------------------------------------- 比例 / 单张尺寸

CELL_SHORT = 768        # 单张成片目标短边: 决定成片分辨率与宫格画布大小

_RATIO_DESC_RE = re.compile(r"^([\d.]+)\s*[:/x]\s*([\d.]+)$")
_RATIO_NUM_RE = re.compile(r"^([\d.]+)$")


def parse_ratio(s) -> float:
    """解析比例描述为宽高比 w/h。支持 '3:4' / '3/4' / '3x4' / '0.75' 与数值。"""
    if isinstance(s, (int, float)):
        return float(s)
    s = str(s).strip().lower()
    m = _RATIO_DESC_RE.match(s)
    if m:
        return float(m.group(1)) / float(m.group(2))
    m = _RATIO_NUM_RE.match(s)
    if m:
        return float(m.group(1))
    raise ValueError(f"无法识别的比例: {s} (可用 3:4 / 3/4 / 3x4 / 0.75)")


def ratio_label(r: float) -> str:
    """把宽高比还原成显示用 'w:h' 文本(如 0.75 -> '3:4')。"""
    from fractions import Fraction
    fr = Fraction(float(r)).limit_denominator(50)
    return f"{fr.numerator}:{fr.denominator}"


def ratio_note(r: float) -> str:
    """注入出图提示词的比例约束句。"""
    return f"画面比例严格为 {ratio_label(r)}，不要改变画幅比例。"


def cell_size(ratio: float, short: int = CELL_SHORT) -> tuple:
    """按模板比例给出单张成片目标像素(短边 short, 16 对齐)。"""
    r = max(float(ratio), 1e-6)
    w, h = (short * r, short) if r >= 1 else (short, short / r)
    return (_round16(w), _round16(h))


def cell_size_str(ratio: float, short: int = CELL_SHORT) -> str:
    w, h = cell_size(ratio, short)
    return f"{w}x{h}"
```

- [ ] **Step 5: 运行验证**

Run: `python -c "import sys;sys.path.insert(0,'scripts');import gpt_image2 as g;print(g.resolve_engine());print(g.resolve_engine('gpt2k'));print(g.resolve_engine(None,'hapi'));print(g.resolve_engine(None,'mass','flux-1.1-pro'));print(g.resolve_engine(None,None,None,2));print(g.cell_size(0.75), g.cell_size(4/3), g.cell_size(1));print(g.ratio_label(0.75), g.ratio_label(16/9), g.parse_ratio('3:4'), g.parse_ratio('0.75'))"`
Expected:

```
{'engine': 'qwen3pro', 'platform': 'mass', 'model': 'qwen-image-3.0-pro', 'max_input_images': 3, 'key_env': 'MASS_API_KEY'}
{'engine': 'gpt2k', 'platform': 'hapi', 'model': 'gpt-image-2.5-sunburst-2k', 'max_input_images': 4, 'key_env': 'HAPI_API_KEY'}
{'engine': 'qwen3pro', 'platform': 'hapi', 'model': 'gpt-image-2.5-sunburst-2k', 'max_input_images': 4, 'key_env': 'HAPI_API_KEY'}
{'engine': 'qwen3pro', 'platform': 'mass', 'model': 'flux-1.1-pro', 'max_input_images': 4, 'key_env': 'MASS_API_KEY'}
{'engine': 'qwen3pro', 'platform': 'mass', 'model': 'qwen-image-3.0-pro', 'max_input_images': 2, 'key_env': 'MASS_API_KEY'}
(768, 1024) (1024, 768) (768, 768)
3:4 16:9 0.75 0.75
```

Run: `python -c "import sys;sys.path.insert(0,'scripts');import gpt_image2 as g;g.resolve_engine('nope')"`
Expected: `ValueError: 未知引擎: nope (可选 qwen3pro, gpt2k)`

- [ ] **Step 6: Commit**

```powershell
git add scripts/gpt_image2.py
git commit -m "feat(scripts): gpt_image2 新增生图引擎预设与比例/单张尺寸工具"
```

---

### Task 2: crop_grid 支持多分隔线（3 格及以上）

**Files:**
- Modify: `skills/anti-infringement-pose-edit/scripts/crop_grid.py`

**Interfaces:**
- Consumes: 既有 `_sep_line(prof)`、`_smooth`、`SEP_TOL`、`SEP_MAX_W_RATIO`、`GUTTER_VAR_RATIO`
- Produces: `_sep_lines(prof: list[float], count: int) -> list[tuple[int, int]]`（返回 `count-1` 条分隔带，升序，半开区间），`crop_grid(img, rows, cols)` 签名与返回值语义不变

- [ ] **Step 1: 写失败验证**

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');from PIL import Image,ImageDraw;from crop_grid import crop_grid;im=Image.effect_noise((288,128),60).convert('RGB').resize((2304,1024),Image.NEAREST);d=ImageDraw.Draw(im);[d.ellipse([o+120,260,o+648,820],fill=(230,190,150)) for o in (0,768,1536)];d.rectangle([764,0,772,1024],fill=(255,255,255));d.rectangle([1532,0,1540,1024],fill=(255,255,255));cells,v=crop_grid(im,1,3);print([c.size for c in cells],v)"`
Expected: FAIL — 中间格宽度为 0（`[(764, 1024), (0, 1024), (764, 1024)] [True, False, True]` 之类），或抛 `ValueError`

- [ ] **Step 2: 新增 `_sep_lines`**

在 `skills/anti-infringement-pose-edit/scripts/crop_grid.py` 的 `def _sep_line(prof)` 之后插入：

```python
def _sep_lines(prof: list[float], count: int) -> list[tuple[int, int]]:
    """定位 count-1 条内部分隔线, 返回各分隔带 [start, end) (升序, 半开)。

    count==2 时沿用 _sep_line 的中央带逻辑(保持 2x2 行为完全不变);
    count>=3 时按等分位置推出预期边界, 在每个预期边界附近的小窗口内
    套用同一套「最小方差 + 容差扩展 + 过宽退化窄切」逻辑。
    定位不到的分隔线返回该等分位置的零宽退化带, 调用方得到紧邻的两格。
    """
    n = len(prof)
    if count <= 1:
        return []
    if count == 2:
        band = _sep_line(prof)
        return [band if band else (n // 2, n // 2)]
    span = n / count
    win = max(3, int(span * 0.35))
    out: list[tuple[int, int]] = []
    for i in range(1, count):
        center = int(round(span * i))
        lo = max(1, center - win)
        hi = min(n - 1, center + win)
        seg = prof[lo:hi + 1]
        ref = max(seg) if seg else 0.0
        if ref <= 1e-6 or min(seg) > GUTTER_VAR_RATIO * ref:
            out.append((center, center))     # 无明显分隔线 -> 零宽退化带
            continue
        pos = lo + seg.index(min(seg))
        tol = max(SEP_TOL, min(seg) * 1.5)
        a, b = pos, pos
        while a - 1 >= lo and prof[a - 1] < min(seg) + tol:
            a -= 1
        while b + 1 <= hi and prof[b + 1] < min(seg) + tol:
            b += 1
        b += 1
        max_w = max(1, int(n * SEP_MAX_W_RATIO))
        if b - a > max_w:
            a, b = pos, pos + 1
        out.append((a, b))
    # 保证严格升序且不重叠
    for i in range(1, len(out)):
        if out[i][0] < out[i - 1][1]:
            out[i] = (out[i - 1][1], max(out[i - 1][1] + 1, out[i][1]))
    return out
```

- [ ] **Step 3: 改写 `crop_grid` 的边界计算**

在 `skills/anti-infringement-pose-edit/scripts/crop_grid.py` 中，把 `crop_grid` 内的这一段：

```python
    cx_sep_start = sx(band_x[0]) if band_x else None   # 左列末尾(不含白线)
    cx_sep_end = sx(band_x[1]) if band_x else None     # 右列开头
    cy_sep_start = sy(band_y[0]) if band_y else None   # 上行末尾(不含白线)
    cy_sep_end = sy(band_y[1]) if band_y else None     # 下行开头
```

替换为：

```python
    def col_edge(c: int, left: bool) -> int:
        """第 c 列的左/右边界(不含白线); c 超出范围时退回整幅边界。"""
        if left:
            if c <= 0:
                return sx(left_trim) if left_trim is not None else 0
            return sx(col_bands[c - 1][1])
        if c >= cols - 1:
            return W - sx(right_trim) if right_trim is not None else W
        return sx(col_bands[c][0])

    def row_edge(r: int, top: bool) -> int:
        """第 r 行的上/下边界(不含白线); r 超出范围时退回整幅边界。"""
        if top:
            if r <= 0:
                return sy(top_trim) if top_trim is not None else 0
            return sy(row_bands[r - 1][1])
        if r >= rows - 1:
            return H - sy(bottom_trim) if bottom_trim is not None else H
        return sy(row_bands[r][0])
```

并把同一函数里 `band_y = _sep_line(row_sep)` / `band_x = _sep_line(col_sep)` 两行替换为：

```python
    row_bands = _sep_lines(row_sep, rows)   # 横向分隔带(行方向)
    col_bands = _sep_lines(col_sep, cols)   # 纵向分隔带(列方向)
```

最后把 `for r in range(rows): for c in range(cols):` 内的 `x0/x1/y0/y1` 四段 if/else 替换为：

```python
            x0 = col_edge(c, True)
            x1 = col_edge(c, False)
            y0 = row_edge(r, True)
            y1 = row_edge(r, False)
            boxes.append((x0, y0, x1, y1))
```

（`boxes` 的 append 只保留上面这一处，删除原来的 `boxes.append((x0, y0, x1, y1))` 重复行。）

- [ ] **Step 4: 运行验证（3 格 + 2x2 回归）**

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');from PIL import Image,ImageDraw;from crop_grid import crop_grid;im=Image.effect_noise((288,128),60).convert('RGB').resize((2304,1024),Image.NEAREST);d=ImageDraw.Draw(im);[d.ellipse([o+120,260,o+648,820],fill=(230,190,150)) for o in (0,768,1536)];d.rectangle([764,0,772,1024],fill=(255,255,255));d.rectangle([1532,0,1540,1024],fill=(255,255,255));cells,v=crop_grid(im,1,3);print([c.size for c in cells],v)"`
Expected: `[(764, 1024), (760, 1024), (764, 1024)] [True, True, True]`

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');from PIL import Image,ImageDraw;from crop_grid import crop_grid;im=Image.effect_noise((288,256),60).convert('RGB').resize((1536,2048),Image.NEAREST);d=ImageDraw.Draw(im);[d.ellipse([x+120,y+120,x+648,y+888],fill=(230,190,150)) for y in (0,1024) for x in (0,768)];d.rectangle([764,0,772,2048],fill=(255,255,255));d.rectangle([0,1020,1536,1028],fill=(255,255,255));cells,v=crop_grid(im,2,2);print([c.size for c in cells],v)"`
Expected: `[(764, 1020), (764, 1020), (764, 1020), (764, 1020)] [True, True, True, True]`

- [ ] **Step 5: Commit**

```powershell
git add skills/anti-infringement-pose-edit/scripts/crop_grid.py
git commit -m "feat(skills): crop_grid 支持每轴多条分隔线, 可切 3 格及以上"
```

---

### Task 3: run_batch_edit 接入引擎与上限推导

**Files:**
- Modify: `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py`

**Interfaces:**
- Consumes: `gpt_image2.resolve_engine` / `parse_ratio` / `ratio_label` / `cell_size_str` / `ENGINES` / `DEFAULT_ENGINE`（Task 1）
- Produces: `make_client(eng: dict, api_key: str = "", base_url: str = "") -> tuple`；CLI 新增 `--engine`，`--platform` / `--max-per-call` 默认 `None`，`--size-batch` 移除

- [ ] **Step 1: 写失败验证**

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py --dry-run a.png b.png c.png d.png`
Expected: 报错 `unrecognized arguments: --engine`（先确认 CLI 不存在）或打印里没有引擎信息

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');import run_batch_edit as r;print(hasattr(r,'parse_ratio'))"`
Expected: `True`（此时还是本地副本，本步骤只是建立基线）

- [ ] **Step 2: 删除本地 `parse_ratio` 与 `ratio_to_grid_size`**

在 `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py` 中删除 `def parse_ratio(s: str) -> float:` 整个函数与 `def ratio_to_grid_size(r: float, base: int = 1024) -> str:` 整个函数（保留 `infer_ratio`）。

- [ ] **Step 3: 改写客户端构造与 CLI**

把 `def make_client(cfg: argparse.Namespace):` 整个函数替换为：

```python
def make_client(eng: dict, api_key: str = "", base_url: str = ""):
    """按解析结果构造客户端, 返回 (client, model)。"""
    pcfg = gpt_image2.PLATFORMS[eng["platform"]]
    key = api_key or os.environ.get(pcfg["key_env"], "")
    if not key:
        raise RuntimeError(
            f"未配置 API Key: 请设置环境变量 {pcfg['key_env']} 或使用 --api-key")
    return gpt_image2.make_client(eng["platform"], key,
                                  base_url or pcfg["base_url"]), eng["model"]
```

把 argparse 中的这几行：

```python
    ap.add_argument("--max-per-call", type=int, default=4, help="每批目标图上限(默认4)")
    ap.add_argument("--platform", default="hapi", choices=list(gpt_image2.PLATFORMS))
    ap.add_argument("--model", default=None)
    ap.add_argument("--api-key", default=None)
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--size-batch", default="1024x1024",
                    help="多图批次的输出尺寸(未指定 --ratio 且无法推断时生效, 默认方形)")
    ap.add_argument("--ratio", default=None,
                    help="宫格输出比例(如 3:4 / 3/4 / 0.75)。缺省时自动按原图比例推断(全部一致用该比例, 否则取多数)")
    ap.add_argument("--size-single", default="from-image", help="单图回退的输出尺寸")
```

替换为：

```python
    ap.add_argument("--engine", default=gpt_image2.DEFAULT_ENGINE,
                    choices=list(gpt_image2.ENGINES),
                    help="生图引擎预设(默认 qwen3pro: mass/qwen-image-3.0-pro, 单次上限 3 张)")
    ap.add_argument("--platform", default=None, choices=list(gpt_image2.PLATFORMS),
                    help="覆盖引擎预设的平台")
    ap.add_argument("--model", default=None, help="覆盖引擎预设的模型")
    ap.add_argument("--max-per-call", type=int, default=None,
                    help="每批图片上限(默认按引擎推导: qwen3pro=3 / gpt2k=4)")
    ap.add_argument("--api-key", default=None)
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--ratio", default=None,
                    help="模板宽高比(如 3:4 / 3/4 / 0.75)。缺省按输入图比例推断(全部一致用该比例, 否则取多数), 再缺省 3:4")
    ap.add_argument("--size-single", default="from-image", help="单图路径的输出尺寸")
```

- [ ] **Step 4: 改写 `main()` 前置解析**

把 `args = ap.parse_args()` 之后到 `if args.dry_run:` 之前的这一段：

```python
    args = ap.parse_args()

    batches = build_batches(len(args.images), args.max_per_call)

    # 宫格输出尺寸: 优先 --ratio, 其次自动按原图比例推断(全部一致→该比例/不一致→多数), 否则回退 --size-batch
    if args.ratio:
        ratio = parse_ratio(args.ratio)
    else:
        ratio = infer_ratio(args.images)
    if ratio:
        size_batch = ratio_to_grid_size(ratio)
        ratio_note = f"[尺寸] 宫格输出比例 w/h={ratio:.3f}, 尺寸 {size_batch} (跟随原图; 可用 --ratio 覆盖)"
    else:
        size_batch = args.size_batch
        ratio_note = f"[尺寸] 宫格输出尺寸 {size_batch} (方形, 无法推断原图比例)"
```

替换为：

```python
    args = ap.parse_args()

    try:
        eng = gpt_image2.resolve_engine(args.engine, args.platform, args.model,
                                        args.max_per_call)
    except ValueError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1

    # 模板宽高比: --ratio > 输入图推断 > 3:4
    ratio = gpt_image2.parse_ratio(args.ratio) if args.ratio else (infer_ratio(args.images) or 0.75)
    ratio_label = gpt_image2.ratio_label(ratio)
    batches = build_batches(len(args.images), eng["max_input_images"])
```

并把 `try: client, model = make_client(args)` 替换为 `try: client, model = make_client(eng, args.api_key or "", args.base_url or "")`。

- [ ] **Step 5: 改写 dry-run 输出**

把 `if args.dry_run:` 整段替换为：

```python
    if args.dry_run:
        print(f"[dry-run] 引擎 {eng['engine']}: platform={eng['platform']} "
              f"model={eng['model']} 单次上限={eng['max_input_images']} 张")
        print(f"[比例] {ratio_label}  单格 {gpt_image2.cell_size_str(ratio)}")
        print("[dry-run] 分批计划:")
        for bi, idxs in enumerate(batches, 1):
            layout = "单图编辑" if len(idxs) == 1 else "%d行%d列" % pick_layout(len(idxs), ratio)
            anchor = "无(首批)" if bi == 1 else "上一批首张成片"
            print(f"  批次{bi}: 目标 {len(idxs)} 张  布局 {layout}  锚点={anchor}")
            print(f"          输入 {[args.images[i] for i in idxs]}")
        print("[dry-run] 结束, 未调接口")
        return 0
```

（本步骤依赖 Task 4 的 `pick_layout`；若两任务合并执行，本步骤与 Task 4 Step 2 一起落地。）

- [ ] **Step 6: 运行验证**

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py --dry-run a.png b.png c.png d.png`
Expected:

```
[dry-run] 引擎 qwen3pro: platform=mass model=qwen-image-3.0-pro 单次上限=3 张
[比例] 3:4  单格 768x1024
[dry-run] 分批计划:
  批次1: 目标 3 张  布局 1行3列  锚点=无(首批)
          输入 ['a.png', 'b.png', 'c.png']
  批次2: 目标 1 张  布局 单图编辑  锚点=上一批首张成片
          输入 ['d.png']
[dry-run] 结束, 未调接口
```

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py --engine gpt2k --dry-run a.png b.png c.png d.png e.png`
Expected: 首行 `单次上限=4 张`，`批次1: 目标 4 张  布局 2行2列`，`批次2: 目标 1 张  布局 单图编辑`

- [ ] **Step 7: Commit**

```powershell
git add skills/anti-infringement-pose-edit/scripts/run_batch_edit.py
git commit -m "feat(skills): 反侵权脚本接入生图引擎预设与单次上限推导"
```

---

### Task 4: 动态布局、画布反算与成片归一化

**Files:**
- Modify: `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py`

**Interfaces:**
- Consumes: `gpt_image2.cell_size` / `resolve_size`（Task 1）、`crop_grid`（Task 2）
- Produces:
  - `pick_layout(n: int, ratio: float) -> tuple[int, int]`
  - `canvas_size(ratio: float, rows: int, cols: int) -> str`
  - `normalize_image(im, target: tuple[int, int])`
  - `split_and_normalize(grid_img, n: int, ratio: float) -> tuple[list, list]`

- [ ] **Step 1: 写失败验证**

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');import run_batch_edit as r;print(r.pick_layout(3,0.75))"`
Expected: FAIL — `AttributeError: module 'run_batch_edit' has no attribute 'pick_layout'`

- [ ] **Step 2: 新增布局/画布/归一化函数**

在 `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py` 的 `def build_batches(total: int, max_per_call: int)` 之后插入：

```python
def pick_layout(n: int, ratio: float) -> tuple:
    """按本批目标数 n 与模板比例 r 选宫格布局 (rows, cols)。

    n==4 用 2x2; n 为 2/3 时: 竖构图(r<=1)横排、横构图(r>1)竖排,
    使画布长宽比 = n*r 或 r/n 不超过 gpt_image2.MAX_RATIO(3:1)。
    """
    if n <= 1:
        return (1, 1)
    if n >= 4:
        return (2, 2)
    return (1, n) if ratio <= 1 else (n, 1)


def canvas_size(ratio: float, rows: int, cols: int) -> str:
    """宫格画布尺寸 = 单格目标尺寸 × 布局, 再经既有尺寸约束归一。"""
    cw, ch = gpt_image2.cell_size(ratio)
    return gpt_image2.resolve_size(f"{cw * cols}x{ch * rows}")


def normalize_image(im, target: tuple):
    """居中裁剪到目标比例并缩放到目标像素, 保证所有单张尺寸完全一致。"""
    from PIL import Image
    tw, th = target
    w, h = im.size
    if (w, h) == (tw, th):
        return im
    if w / h > tw / th:          # 过宽 -> 裁左右
        nw = min(w, max(1, int(round(h * tw / th))))
        x = (w - nw) // 2
        im = im.crop((x, 0, x + nw, h))
    else:                        # 过高 -> 裁上下
        nh = min(h, max(1, int(round(w * th / tw))))
        y = (h - nh) // 2
        im = im.crop((0, y, w, y + nh))
    return im.resize((tw, th), Image.LANCZOS)


def split_and_normalize(grid_img, n: int, ratio: float) -> tuple:
    """按 n 对应的布局裁剪宫格, 并把每格归一化到统一的单格目标像素。

    返回 (cells, validity), 长度均为 n。
    """
    rows, cols = pick_layout(n, ratio)
    cells, validity = crop_grid(grid_img, rows, cols)
    target = gpt_image2.cell_size(ratio)
    return [normalize_image(c, target) for c in cells[:n]], validity[:n]
```

- [ ] **Step 3: 替换宫格裁剪与落盘逻辑**

在 `main()` 的批次循环里，把这段：

```python
        size = gpt_image2.resolve_size(size_batch)
        status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=args.timeout)
```

中的尺寸行替换为（使用本批布局反算画布；`n==1` 的批次在 Task 5 单独走单图路径，此处先用 layout 兜底）：

```python
        rows, cols = pick_layout(len(targets), ratio)
        size_arg = canvas_size(ratio, rows, cols)
        size = gpt_image2.resolve_size(size_arg)
        status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=args.timeout)
```

并把解码裁剪这一段：

```python
            with Image.open(grid_path) as im:
                im = im.convert("RGB")
                cells, validity = crop_grid(im, 2, 2)

        # 把裁剪格按读取顺序映射到目标图
        for j, cell in enumerate(cells[:len(targets)]):
```

替换为：

```python
            with Image.open(grid_path) as im:
                cells, validity = split_and_normalize(im.convert("RGB"), len(targets), ratio)

        # 把裁剪格按读取顺序映射到目标图
        for j, cell in enumerate(cells):
```

并把 validity 回退循环 `for j, ok in enumerate(validity[:len(targets)]):` 改为 `for j, ok in enumerate(validity):`。

- [ ] **Step 4: 运行验证（合成宫格，离线）**

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');from PIL import Image,ImageDraw;import run_batch_edit as r;im=Image.effect_noise((288,128),60).convert('RGB').resize((2304,1024),Image.NEAREST);d=ImageDraw.Draw(im);[d.ellipse([o+120,260,o+648,820],fill=(230,190,150)) for o in (0,768,1536)];d.rectangle([764,0,772,1024],fill=(255,255,255));d.rectangle([1532,0,1540,1024],fill=(255,255,255));cells,v=r.split_and_normalize(im,3,0.75);print([c.size for c in cells],v);print(r.pick_layout(2,0.75),r.pick_layout(3,0.75),r.pick_layout(3,4/3),r.pick_layout(4,0.75));print(r.canvas_size(0.75,1,3),r.canvas_size(0.75,2,2),r.canvas_size(0.75,1,2))"`
Expected:

```
[(768, 1024), (768, 1024), (768, 1024)] [True, True, True]
(1, 2) (1, 3) (3, 1) (2, 2)
2304x1024 1536x2048 1536x1024
```

- [ ] **Step 5: Commit**

```powershell
git add skills/anti-infringement-pose-edit/scripts/run_batch_edit.py
git commit -m "feat(skills): 反侵权宫格布局动态化并按布局反算画布与归一化成片"
```

---

### Task 5: 提示词比例约束、宫格指令与单图路径

**Files:**
- Modify: `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py`

**Interfaces:**
- Consumes: `gpt_image2.ratio_note` / `ratio_label`（Task 1）、`pick_layout` / `canvas_size`（Task 4）
- Produces: `grid_suffix(rows: int, cols: int) -> str`；`run_single(client, model, target, out_dir, prefix, size_single, timeout, ratio, anchor=None, custom_prompt=False) -> str | None`

- [ ] **Step 1: 写失败验证**

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');import run_batch_edit as r;print(r.grid_suffix(1,3))"`
Expected: FAIL — `AttributeError: module 'run_batch_edit' has no attribute 'grid_suffix'`

- [ ] **Step 2: 替换宫格指令常量**

在 `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py` 中，把 `GRID_SUFFIX = (...)` 整块替换为：

```python
# 多图打包成宫格的指令(布局在运行时按批内张数生成)
def grid_suffix(rows: int, cols: int) -> str:
    return (f"请将每张输入图的修改结果，按{rows}行{cols}列整齐排列为一张输出图"
            f"（顺序：从左到右、从上到下，与输入顺序一致），"
            f"格与格之间留清晰边框/分隔线，便于拆分。"
            f"人物保持原姿势与构图，仅修改面部与衣着。")
```

- [ ] **Step 3: 让单图路径支持锚点与比例**

把 `def run_single(...)` 整个函数替换为：

```python
def run_single(client, model, target: str, out_dir: str, prefix: str,
               size_single: str, timeout: int, ratio: float,
               anchor: str | None = None, custom_prompt: bool = False) -> str | None:
    """单图编辑: 直接产出一张成片(附锚点参考以统一衣着), 并归一化到目标尺寸。"""
    imgs = [_load_tuple(target)]
    prompt = SINGLE_PROMPT + gpt_image2.ratio_note(ratio)
    if anchor and not custom_prompt:
        prompt += ANCHOR_NOTE
        imgs.append(_load_tuple(anchor))
    size = gpt_image2.resolve_size(size_single, imgs[0][2])
    status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=timeout)
    if status != 200 or not resp.get("data"):
        print(f"    [回退失败] HTTP {status}: {resp}", file=sys.stderr)
        return None
    with tempfile.TemporaryDirectory() as td:
        item = resp["data"][0]
        p = _decode_item(item, td, "s_")
        ext = os.path.splitext(p)[1]
        out = os.path.join(out_dir, f"{prefix}{ext or '.png'}")
        with Image.open(p) as im:
            normalize_image(im.convert("RGB"), gpt_image2.cell_size(ratio)).save(out)
    print(f"    [单图] {target} -> {out} {gpt_image2.cell_size_str(ratio)}")
    return out
```

- [ ] **Step 4: 改写批次循环（完整替换）**

把 `main()` 中从 `base_prompt = args.prompt or BASE_PROMPT` 到循环结束（`anchor_path = outputs[idxs[0]]` 那一段）整块替换为：

```python
    base_prompt = (args.prompt or BASE_PROMPT) + gpt_image2.ratio_note(ratio)

    outputs: list[str | None] = [None] * len(args.images)  # 与输入顺序对齐
    anchor_path: str | None = None  # 首批首张成片, 用作后续批次衣着锚点

    for bi, idxs in enumerate(batches, 1):
        targets = [args.images[i] for i in idxs]
        rows, cols = pick_layout(len(targets), ratio)
        print(f"[批次 {bi}/{len(batches)}] 目标 {len(targets)} 张 "
              f"{rows}行{cols}列 -> {targets}")

        # 单张批次: 不走宫格, 直接单图编辑(仍附锚点)
        if len(targets) == 1:
            gi = idxs[0]
            outputs[gi] = run_single(client, model, targets[0], args.out,
                                     f"out{gi+1}.", args.size_single, args.timeout,
                                     ratio, anchor_path, bool(args.prompt))
            continue

        prompt = base_prompt + grid_suffix(rows, cols)
        imgs = [_load_tuple(t) for t in targets]
        if anchor_path and not args.prompt:
            # 仅在使用默认提示词时注入锚点说明(自定义 prompt 时不叠加, 避免措辞冲突)
            prompt += ANCHOR_NOTE
            imgs.append(_load_tuple(anchor_path))
            print(f"    锚点参考图: {anchor_path}")

        size_arg = canvas_size(ratio, rows, cols)
        size = gpt_image2.resolve_size(size_arg)
        print(f"    画布 {size_arg}")
        status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=args.timeout)
        if status != 200 or not resp.get("data"):
            print(f"    [批次失败] HTTP {status}: {resp}", file=sys.stderr)
            # 逐张回退
            for t in targets:
                gi = args.images.index(t)
                outputs[gi] = run_single(client, model, t, args.out, f"out{gi+1}.",
                                         args.size_single, args.timeout, ratio,
                                         anchor_path, bool(args.prompt))
            continue

        # 解码宫格 -> 按布局裁剪 -> 归一化
        grid_path = os.path.join(grids_dir, f"batch{bi}.png")
        keep_grid_file = False
        with tempfile.TemporaryDirectory() as td:
            decoded = _decode_item(resp["data"][0], td, f"g{bi}_")
            if args.keep_grids:
                shutil.move(decoded, grid_path)
                keep_grid_file = True
            else:
                grid_path = decoded
            with Image.open(grid_path) as im:
                cells, validity = split_and_normalize(im.convert("RGB"), len(targets), ratio)

        # 把裁剪格按读取顺序映射到目标图
        for j, cell in enumerate(cells):
            gi = idxs[j]
            out = os.path.join(args.out, f"out{gi+1}.png")
            cell.convert("RGB").save(out)
            outputs[gi] = out
            print(f"    格{j+1} -> {out}  {cell.size[0]}x{cell.size[1]}  valid={validity[j]}")

        # 未覆盖/空白的: 单图回退
        for j, ok in enumerate(validity):
            if not ok:
                gi = idxs[j]
                print(f"    格{j+1} 空白/低质, 单图回退 {targets[j]}")
                outputs[gi] = run_single(client, model, targets[j], args.out,
                                         f"out{gi+1}.", args.size_single, args.timeout,
                                         ratio, anchor_path, bool(args.prompt))

        # 记录锚点: 第一批的首张成片
        if bi == 1 and outputs[idxs[0]]:
            anchor_path = outputs[idxs[0]]
```

（`keep_grid_file` 变量仅为保留原语义，如无需要可不引入；`grids_dir` 与 `os.makedirs` 保持原样。）

- [ ] **Step 5: 更新文件头注释**

把 `skills/anti-infringement-pose-edit/scripts/run_batch_edit.py` 顶部 docstring 的流程描述改为：

```python
"""姿势图反侵权批量编辑编排器。

流程:
  1. 读取 N 张输入图(保持顺序);
  2. 按引擎预设的单次上限分批(--engine qwen3pro 上限3 / gpt2k 上限4; --max-per-call 可覆盖):
     - 第一批: 最多 `上限` 张目标图(无锚点);
     - 后续批: 每批 `上限-1` 张目标图 + 追加 1 张"衣着锚点"(第一批首张成片), 用于统一衣着;
     - 批内只剩 1 张时不走宫格, 直接单图编辑(仍附锚点);
  3. 每批按批内张数与模板比例选布局(1x2 / 1x3 / 2x2 / 竖排镜像), 一次发出,
     要求模型把每张的修改结果按该布局排成一张图;
  4. 用 crop_grid.py 按布局裁剪 → 归一化到统一的目标单格像素(短边 768, 比例=模板比例);
  5. 裁不干净/空白的格 → 对该目标图单独跑一次单图编辑兜底;
  6. 输出与输入顺序对齐、尺寸完全一致的单张成片到 --out。

运行前提: 环境变量 MASS_API_KEY(默认引擎 qwen3pro) 或 HAPI_API_KEY(gpt2k) 已配置。
"""
```

- [ ] **Step 6: 运行验证**

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py --dry-run a.png b.png c.png d.png`
Expected: 与 Task 3 Step 6 相同

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');import run_batch_edit as r;print(r.grid_suffix(1,3))"`
Expected: `请将每张输入图的修改结果，按1行3列整齐排列为一张输出图（顺序：从左到右、从上到下，与输入顺序一致），格与格之间留清晰边框/分隔线，便于拆分。人物保持原姿势与构图，仅修改面部与衣着。`

Run: `python -c "import sys;sys.path.insert(0,'skills/anti-infringement-pose-edit/scripts');import gpt_image2 as g;print(g.ratio_note(0.75))"`（在项目根执行，`scripts/` 已在 sys.path 内）
Expected: `画面比例严格为 3:4，不要改变画幅比例。`

- [ ] **Step 7: Commit**

```powershell
git add skills/anti-infringement-pose-edit/scripts/run_batch_edit.py
git commit -m "feat(skills): 反侵权提示词注入比例约束, 单图路径支持锚点并统一成片尺寸"
```

---

### Task 6: run_template 引擎、上限与比例链路

**Files:**
- Modify: `skills/template-builder/scripts/run_template.py`

**Interfaces:**
- Consumes: `gpt_image2.resolve_engine` / `parse_ratio` / `ratio_label` / `ratio_note` / `cell_size_str` / `DEFAULT_ENGINE` / `ENGINES`（Task 1）；子进程 CLI（Task 3/5）
- Produces: `resolve_aspect(explicit: str | None, cfg: dict, refs: list) -> tuple`；`pose_size(ratio: float) -> str`；`write_docs(cfg, out_dir, poses, aspect_ratio=None)`；CLI 新增 `--engine` / `--max-per-call` / `--ratio`

- [ ] **Step 1: 写失败验证**

Run: `python -c "import sys;sys.path.insert(0,'skills/template-builder/scripts');import run_template as r;print(r.resolve_aspect(None,{},[]))"`
Expected: FAIL — `AttributeError: module 'run_template' has no attribute 'resolve_aspect'`

- [ ] **Step 2: 新增比例解析与尺寸函数**

在 `skills/template-builder/scripts/run_template.py` 的 `SIZE_TUPLE = ...` 之后插入（`SIZE` 常量保留给 `load_ref_tuple` 的缩略图上限使用，不再作为出图尺寸）：

```python
def resolve_aspect(explicit, cfg: dict, refs: list) -> tuple:
    """解析模板宽高比, 返回 (ratio 浮点, 显示标签 'w:h')。

    优先级: --ratio > cfg.aspect_ratio > 参考图推断(全部一致用该比例, 否则取多数) > 3:4。
    """
    if explicit:
        r = gpt_image2.parse_ratio(explicit)
        return r, gpt_image2.ratio_label(r)
    v = (cfg or {}).get("aspect_ratio")
    if v:
        r = gpt_image2.parse_ratio(v)
        return r, gpt_image2.ratio_label(r)
    if refs:
        try:
            sys.path.insert(0, str(_AIE_SCRIPTS))
            from run_batch_edit import infer_ratio   # 复用反侵权技能的参考图比例推断
            r = infer_ratio([str(p) for p in refs])
            if r:
                return r, gpt_image2.ratio_label(r)
        except Exception as e:
            print(f"  [比例] 参考图推断失败, 回退 3:4: {e}", flush=True)
    return 0.75, "3:4"


def pose_size(ratio: float) -> str:
    """姿势图/剪影出图尺寸: 短边 768, 按模板比例(与反侵权技能保持一致)。"""
    return gpt_image2.cell_size_str(ratio)
```

- [ ] **Step 3: 让提示词与尺寸跟随比例**

把 `def gen_hapi(...)` 的签名 `size: str = SIZE` 改为 `size: str = None`，并在函数体第一行插入：

```python
    if size is None:
        size = pose_size(ASPECT[0])
```

在 `skills/template-builder/scripts/run_template.py` 的常量区（`TIMEOUT = 660` 附近）新增：

```python
ASPECT = [0.75, "3:4"]   # 运行时由 resolve_aspect 填入 (ratio 浮点, 显示标签)
```

把 `def gen_silhouette(client, model, pose_path: Path, out_dir: Path) -> Path | None:` 内的：

```python
    raw = gen_hapi(client, model, SIL_PROMPT, out_dir / "_sil_raw", "sil",
                   ref=pose_path, size=SIZE)
```

替换为：

```python
    raw = gen_hapi(client, model, SIL_PROMPT + gpt_image2.ratio_note(ASPECT[0]),
                   out_dir / "_sil_raw", "sil", ref=pose_path, size=pose_size(ASPECT[0]))
```

- [ ] **Step 4: 透传引擎/上限/比例到子进程**

把 `def run_anti_infringement(pose_sources: list[str], work: Path, api_key: str = "", platform: str = "", model: str = "", keep_grids: bool = False) -> list[Path] | None:` 的签名改为：

```python
def run_anti_infringement(pose_sources: list[str], work: Path, api_key: str = "",
                          platform: str = "", model: str = "",
                          max_per_call: int = 0, ratio: str = "",
                          keep_grids: bool = False) -> list[Path] | None:
```

并在 `if keep_grids:` 之前插入：

```python
    if max_per_call:
        cmd += ["--max-per-call", str(max_per_call)]
    if ratio:
        cmd += ["--ratio", ratio]
```

- [ ] **Step 5: CLI 与主流程接线**

在 argparse 中，把：

```python
    ap.add_argument("--platform", default="hapi", choices=list(gpt_image2.PLATFORMS))
    ap.add_argument("--model", default=None)
```

替换为：

```python
    ap.add_argument("--engine", default=gpt_image2.DEFAULT_ENGINE,
                    choices=list(gpt_image2.ENGINES),
                    help="生图引擎预设(默认 qwen3pro: mass/qwen-image-3.0-pro)")
    ap.add_argument("--platform", default=None, choices=list(gpt_image2.PLATFORMS),
                    help="覆盖引擎预设的平台")
    ap.add_argument("--model", default=None, help="覆盖引擎预设的模型")
    ap.add_argument("--max-per-call", type=int, default=None,
                    help="反侵权每批图片上限(默认按引擎推导)")
    ap.add_argument("--ratio", default=None,
                    help="模板宽高比(如 3:4 / 4:3 / 9:16 / 16:9 / 1:1), 缺省取 cfg.aspect_ratio")
```

在 `try: client, model = make_client(args)` 之前插入：

```python
    try:
        eng = gpt_image2.resolve_engine(args.engine, args.platform, args.model,
                                        args.max_per_call)
    except ValueError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1
```

把 `def make_client(cfg_args) -> tuple:` 整个函数替换为：

```python
def make_client(eng: dict, api_key: str = "", base_url: str = "") -> tuple:
    pcfg = gpt_image2.PLATFORMS[eng["platform"]]
    key = api_key or os.environ.get(pcfg["key_env"], "")
    if not key:
        raise RuntimeError(f"未配置 API Key: 设置环境变量 {pcfg['key_env']} 或使用 --api-key")
    return gpt_image2.make_client(eng["platform"], key, base_url or pcfg["base_url"]), eng["model"]
```

把 `client, model = make_client(args)` 改为 `client, model = make_client(eng, args.api_key or "", args.base_url or "")`。

把反侵权调用段：

```python
            key = args.api_key or os.environ.get(
                gpt_image2.PLATFORMS.get(args.platform, gpt_image2.PLATFORMS["hapi"]).get("key_env", ""), "")
            done = run_anti_infringement([str(p) for p in pose_sources], out_dir, key,
                                         args.platform, model, args.keep_grids)
```

替换为：

```python
            key = args.api_key or os.environ.get(eng["key_env"], "")
            done = run_anti_infringement([str(p) for p in pose_sources], out_dir, key,
                                         eng["platform"], eng["model"],
                                         eng["max_input_images"], ASPECT[1], args.keep_grids)
```

把 auto-gen 提示词段：

```python
            prompt = f"{style}。姿势动作:{desc}。写实全身人像, 3:4竖构图, 保留皮肤毛孔与真实质感。"
            p = gen_hapi(client, model, prompt, out_dir, f"pose{i+1}")
```

替换为：

```python
            prompt = (f"{style}。姿势动作:{desc}。写实全身人像, "
                      f"{gpt_image2.ratio_note(ASPECT[0])}保留皮肤毛孔与真实质感。")
            p = gen_hapi(client, model, prompt, out_dir, f"pose{i+1}", size=pose_size(ASPECT[0]))
```

- [ ] **Step 6: 解析比例并写入 pptpl**

在 `refs = resolve_inputs(args, out_dir)` 之后插入：

```python
    ASPECT[0], ASPECT[1] = resolve_aspect(args.ratio, cfg, refs)
    print(f"  [比例] {ASPECT[1]}  单格 {pose_size(ASPECT[0])}", flush=True)
```

把 `write_docs` 的签名与 `composition` 行改为：

```python
def write_docs(cfg: dict, out_dir: Path, poses: list[dict], aspect_ratio: str = None) -> None:
```

```python
        "composition": {"overlayType": "rule_of_thirds",
                        "aspectRatio": aspect_ratio or cfg.get("aspect_ratio") or "3:4",
                        "opacity": 0.5,
                        "description": cfg.get("composition_description", "")},
```

把调用处 `write_docs(cfg, out_dir, poses_cfg)` 改为 `write_docs(cfg, out_dir, poses_cfg, ASPECT[1])`。

在完成打印段（`print(f"\n[完成] 模板产物在 {out_dir.resolve()}", flush=True)` 之前）插入尺寸回显：

```python
    from PIL import Image as _Image
    for p in sorted(out_dir.glob("pose*.png")):
        with _Image.open(p) as im:
            print(f"  [尺寸] {p.name} {im.size[0]}x{im.size[1]}", flush=True)
```

并在 dry-run 分支里，把 `print(f"[dry-run] key=...")` 之后补一行引擎/比例回显：

```python
        print(f"[dry-run] 引擎={args.engine} 平台/模型={gpt_image2.resolve_engine(args.engine, args.platform, args.model, args.max_per_call)}")
```

- [ ] **Step 7: 运行验证**

Run: `python -c "import sys;sys.path.insert(0,'skills/template-builder/scripts');import run_template as r;print(r.resolve_aspect(None,{},[]));print(r.resolve_aspect('4:3',{},[]));print(r.resolve_aspect(None,{'aspect_ratio':'9:16'},[]));print(r.pose_size(0.75), r.pose_size(4/3))"`
Expected:

```
(0.75, '3:4')
(1.3333333333333333, '4:3')
(0.5625, '9:16')
768x1024 1024x768
```

Run: `python -c "import sys,json,tempfile,pathlib;sys.path.insert(0,'skills/template-builder/scripts');import run_template as r;d=pathlib.Path(tempfile.mkdtemp());r.write_docs({},d,[],'9:16');print(json.loads((d/'template.pptpl').read_text(encoding='utf-8'))['composition']['aspectRatio']);d2=pathlib.Path(tempfile.mkdtemp());r.write_docs({'aspect_ratio':'1:1'},d2,[]);print(json.loads((d2/'template.pptpl').read_text(encoding='utf-8'))['composition']['aspectRatio'])"`
Expected:

```
9:16
1:1
```

Run: `python skills/template-builder/scripts/run_template.py --key demo_tpl --dry-run`
Expected: 打印 `[dry-run] key=demo_tpl ...` 与 `[dry-run] 引擎=qwen3pro 平台/模型={'engine': 'qwen3pro', 'platform': 'mass', ...}`

- [ ] **Step 8: Commit**

```powershell
git add skills/template-builder/scripts/run_template.py
git commit -m "feat(skills): 模板脚本接入引擎预设, 宽高比贯穿尺寸/提示词/pptpl"
```

---

### Task 7: 同步两个 SKILL.md

**Files:**
- Modify: `skills/template-builder/SKILL.md`
- Modify: `skills/anti-infringement-pose-edit/SKILL.md`

**Interfaces:**
- Consumes: 前序任务落地的 CLI 参数与 `config.json` 新字段
- Produces: 与代码一致的技能文档

- [ ] **Step 1: 更新 template-builder 的 config.json 结构与用法**

在 `skills/template-builder/SKILL.md` 的 config.json 示例中，把 `"reference_source": "来源说明",` 之后补一行：

```json
  "aspect_ratio": "3:4",
```

并在示例下方补充说明：

```markdown
- `aspect_ratio`：模板宽高比，**必须依据参考内容（链接正文/参考图/创作要求）判定后写入**，取值 `3:4 | 4:3 | 16:9 | 9:16 | 1:1`。它统一决定姿势图与剪影的出图尺寸、反侵权宫格画布、成片的最终像素与 `template.pptpl` 的 `composition.aspectRatio`。缺省时脚本按参考图比例推断，再缺省 `3:4`。
```

- [ ] **Step 2: 更新 template-builder 的用法与引擎说明**

把用法段落改为（保留原有示例，补引擎说明）：

```markdown
## 生图引擎

默认走 **`qwen-image-3.0-pro`（MaaS，单次最多 3 张输入图）**；需要 GPT-Image-2 2K 时显式指定 `--engine gpt2k`（HAPI，单次最多 4 张）：

```bash
# 默认: qwen3pro
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png

# 指定 gpt-image2 2K
python scripts/run_template.py --key my_tpl --cfg config.json --inputs ref1.png ref2.png --engine gpt2k
```

引擎决定平台、模型与「单次请求图片上限」三件事，并自动透传给反侵权子步骤；`--platform` / `--model` / `--max-per-call` 可单独覆盖。
```

- [ ] **Step 3: 更新 anti-infringement 的引擎与批处理说明**

在 `skills/anti-infringement-pose-edit/SKILL.md` 中新增小节：

```markdown
## 生图引擎与单次上限

`--engine` 决定平台/模型/单次输入图片上限（默认 `qwen3pro` = `mass` / `qwen-image-3.0-pro` / 3 张；`gpt2k` = `hapi` / `gpt-image-2.5-sunburst-2k` / 4 张），`--max-per-call` 可覆盖。

分批与布局规则：首批最多「上限」张（无锚点）；后续每批「上限-1」张目标 + 1 张衣着锚点；批内只剩 1 张时走单图编辑。宫格布局按批内张数与模板比例动态选择（1 张无宫格 / 2 张 1x2 或 2x1 / 3 张 1x3 或 3x1 / 4 张 2x2）。

裁剪出的每格会归一化到统一的目标像素（短边 768、比例 = 模板比例），因此所有成片尺寸完全一致。
```

- [ ] **Step 4: 运行验证**

Run: `python -c "import pathlib;print('--engine' in pathlib.Path('skills/template-builder/SKILL.md').read_text(encoding='utf-8'), '--engine' in pathlib.Path('skills/anti-infringement-pose-edit/SKILL.md').read_text(encoding='utf-8'))"`
Expected: `True True`

Run: `python -c "import pathlib;print('aspect_ratio' in pathlib.Path('skills/template-builder/SKILL.md').read_text(encoding='utf-8'))"`
Expected: `True`

- [ ] **Step 5: Commit**

```powershell
git add skills/template-builder/SKILL.md skills/anti-infringement-pose-edit/SKILL.md
git commit -m "docs(skills): 同步生图引擎、动态宫格与 aspect_ratio 说明"
```

---

### Task 8: 真实小样本端到端验证

**Files:**
- 无代码改动（仅运行与核对）

**Interfaces:**
- Consumes: 前序任务全部改动
- Produces: 真实调用链路可用性结论（含 `mass` 是否真的提供 `qwen-image-3.0-pro`）

- [ ] **Step 1: 确认 mass 引擎可用（不需要完整模板）**

Run: `python scripts/gpt_image2.py "纯白背景上的一只橘猫, 侧身坐姿" --platform mass --model qwen-image-3.0-pro --size 3:4`
Expected: 返回 200 并把图片落到 `scripts/results/`。若返回模型不存在/无权限：停止后续步骤，把 `PLATFORMS["mass"]["models"]` 与 `ENGINES["qwen3pro"]["model"]` 一并改回 `qwen-image-2.0-pro`，并把该引擎的 `max_input_images` 复核后同步。

- [ ] **Step 2: 确认 3 张输入上限行为**

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py --dry-run <3 张真实参考图路径>`
Expected: `引擎 qwen3pro: platform=mass model=qwen-image-3.0-pro 单次上限=3 张`，`批次1: 目标 3 张  布局 1行3列`

- [ ] **Step 3: 跑一次真实 3 张反侵权加工**

Run: `python skills/anti-infringement-pose-edit/scripts/run_batch_edit.py <3 张真实参考图路径> --out .tmp_edit/anti3 --keep-grids`
Expected: 打印 `画布 2304x1024`，三格均 `valid=True`，三张 `out*.png` 尺寸完全相同（应是 `768x1024`），无 `[批次失败]`

- [ ] **Step 4: 端到端跑一次模板产物**

Run: `python skills/template-builder/scripts/run_template.py --key e2e_engine --cfg <你的 config.json> --inputs <3 张参考图路径> --parent create_templates`
Expected: 日志含 `[比例] 3:4  单格 768x1024`；`create_templates/e2e_engine/` 下 `pose1..poseN.png` 尺寸完全一致；`template.pptpl` 的 `composition.aspectRatio` 等于 `config.json` 的 `aspect_ratio`

- [ ] **Step 5: 核对 pptpl 与尺寸**

Run: `python -c "import json,pathlib;from PIL import Image;d=pathlib.Path('create_templates/e2e_engine');print(json.loads((d/'template.pptpl').read_text(encoding='utf-8'))['composition']['aspectRatio']);print(sorted({Image.open(p).size for p in d.glob('pose[0-9].png')}))"`
Expected: 第一行是 config 里的 `aspect_ratio`；第二行只有一个尺寸元组（如 `[(768, 1024)]`）

- [ ] **Step 6: 记录结论**

若任一步失败，把失败日志与复现命令写入本计划文件末尾的「执行记录」小节；不要静默放宽断言或改动 spec 的验收标准。

---

## 执行记录

（执行过程中在此追加：每个任务的验证命令实际输出、真实验证结论、偏离计划之处及原因。）
