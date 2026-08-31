
(function () {
  "use strict";

  const $ = (id) => document.getElementById(id);

  // ---------- 平台配置 ----------
  const PLATFORMS = {
    hapi: {
      label: "HAPI gpt-image2",
      keyLabel: "HAPI API Key",
      keyPlaceholder: "sk-…",
      base: "https://image.hapiopen.cc",
      models: ["gpt-image-2"],
      maxN: 4,
      quality: true, format: true, fidelity: true,
      hint: "基于 HAPI 三方中转调用 gpt-image-2（OpenAI 兼容，同步返回）。文档：hapiopen.cc/docs#image-api",
    },
    mass: {
      label: "MaaS · mass.hzxmfg.com",
      keyLabel: "MaaS API Key",
      keyPlaceholder: "sk-ra-…",
      base: "https://mass.hzxmfg.com/v1",
      models: ["gpt-image-2", "gpt-image-1", "dall-e-3", "seedream-4.0",
               "flux-1.1-pro", "wan2.7-image-pro", "qwen-image-2.0-pro"],
      maxN: 4,
      quality: false, format: false, fidelity: false,
      hint: "统一 OpenAI 兼容网关，图片为异步任务（提交后轮询结果）。若调用失败可换 Base URL：https://api.mass.hzxmfg.com/v1",
    },
    qianwen_payg: {
      label: "千问 AI · 按量付费",
      keyLabel: "千问 API Key（按量，sk-…）",
      keyPlaceholder: "sk-…",
      base: "https://dashscope.aliyuncs.com/api/v1",
      models: ["wan2.7-image-pro", "wan2.7-image", "z-image-turbo",
               "qwen-image-2.0-pro", "qwen-image-2.0",
               "qwen-image-3.0-pro", "qwen-image-3.0", "wan2.6-image"],
      maxN: 6,
      quality: false, format: false, fidelity: false,
      hint: "按量付费，Key 以 sk- 开头。走千问 AI 原生接口（multimodal-generation，异步任务），尺寸自动转换为 W*H 格式。文档：platform.qianwenai.com/docs/developer-guides/getting-started/image-models",
    },
    qianwen_token: {
      label: "千问 AI · Token Plan",
      keyLabel: "千问 Token Plan Key（sk-sp-…）",
      keyPlaceholder: "sk-sp-…",
      base: "https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1",
      models: ["wan2.7-image-pro", "wan2.7-image", "z-image-turbo",
               "qwen-image-2.0-pro", "qwen-image-2.0",
               "qwen-image-3.0-pro", "qwen-image-3.0", "wan2.6-image"],
      maxN: 6,
      quality: false, format: false, fidelity: false,
      hint: "Token Plan 专属 Key 以 sk-sp- 开头，走 Token Plan 计费。同样是千问 AI 原生接口（multimodal-generation，异步任务），尺寸自动转换为 W*H 格式。",
    },
  };

  // ---------- 状态 ----------
  const state = {
    platform: "hapi",
    mode: "edit",          // edit | generate
    processMode: "once",   // once | batch
    sizeMode: "from-image",// from-image | auto | ratio | size
    ratio: "1:1",
    images: [],            // {file, url}
  };

  // ---------- 平台切换 ----------
  const platformSel = $("platform"), baseUrlInput = $("baseUrl"),
        keyInput = $("apiKey"), showKeyBtn = $("showKey"), clearKeyBtn = $("clearKeyBtn"),
        modelInput = $("model"), nInput = $("n");
  const KEY_PREFIX = "imgtool_key_", BASE_PREFIX = "imgtool_base_";

  function curCfg() { return PLATFORMS[state.platform]; }
  function keyStore() { return KEY_PREFIX + state.platform; }
  function baseStore() { return BASE_PREFIX + state.platform; }

  function applyPlatform() {
    const cfg = curCfg();
    // 参数可见性
    $("qualityField").classList.toggle("hidden", !cfg.quality);
    $("formatField").classList.toggle("hidden", !cfg.format);
    $("fidelityField").classList.toggle("hidden", !cfg.fidelity);
    // n 上限
    nInput.max = cfg.maxN;
    if (+nInput.value > cfg.maxN) nInput.value = cfg.maxN;
    // Base URL
    baseUrlInput.value = localStorage.getItem(baseStore()) || cfg.base;
    // 模型 datalist
    const dl = $("modelList");
    dl.innerHTML = cfg.models.map((m) => `<option value="${m}">`).join("");
    if (!cfg.models.includes(modelInput.value.trim())) modelInput.value = cfg.models[0];
    // API Key
    keyInput.value = localStorage.getItem(keyStore()) || "";
    keyInput.placeholder = cfg.keyPlaceholder;
    $("apiKeyLabel").textContent = cfg.keyLabel;
    $("platformHint").textContent = `当前平台：${cfg.label}。${cfg.hint}`;
    updateKeyHint();
  }

  platformSel.addEventListener("change", () => {
    state.platform = platformSel.value;
    applyPlatform();
    showStatus(`已切换到 ${curCfg().label}。`);
  });
  baseUrlInput.addEventListener("input", () => {
    localStorage.setItem(baseStore(), baseUrlInput.value.trim());
  });

  // ---------- API Key 持久化（按平台） ----------
  function loadKey() { return keyInput.value.trim(); }
  function saveKey(v) {
    if (v) localStorage.setItem(keyStore(), v);
    else localStorage.removeItem(keyStore());
  }
  function getKey() { return loadKey(); }

  keyInput.addEventListener("input", () => { saveKey(getKey()); updateKeyHint(); });
  showKeyBtn.addEventListener("click", () => {
    const show = keyInput.type === "password";
    keyInput.type = show ? "text" : "password";
    showKeyBtn.textContent = show ? "隐藏" : "显示";
  });
  clearKeyBtn.addEventListener("click", () => {
    saveKey("");
    keyInput.value = "";
    updateKeyHint();
    showStatus(`已清除「${curCfg().label}」保存在本地的 API Key（localStorage 已删除）。`);
  });
  function updateKeyHint() {
    const k = getKey();
    $("keyHint").textContent = k
      ? `已从浏览器本地读取「${curCfg().label}」的 Key（…${k.slice(-6)}）。`
      : `输入后自动保存到浏览器 localStorage（仅用于「${curCfg().label}」）；点击「清除当前平台 Key」可删除该平台的持久化数据。`;
  }

  // ---------- 模式切换 ----------
  const modeTabs = $("modeTabs");
  modeTabs.addEventListener("click", (e) => {
    const btn = e.target.closest(".tab");
    if (!btn) return;
    state.mode = btn.dataset.mode;
    [...modeTabs.children].forEach((t) => t.classList.toggle("active", t === btn));
    $("uploadCard").classList.toggle("hidden", state.mode === "generate");
    $("processCard").classList.toggle("hidden", state.mode === "generate");
    $("fidelityField").classList.toggle("hidden", state.mode === "generate");
    updateProcessHint();
    updateBatchUI();
  });

  // ---------- 文件选择 ----------
  const drop = $("drop"), fileInput = $("fileInput");
  drop.addEventListener("click", () => fileInput.click());
  drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
  drop.addEventListener("dragleave", () => drop.classList.remove("over"));
  drop.addEventListener("drop", (e) => {
    e.preventDefault(); drop.classList.remove("over");
    addFiles([...e.dataTransfer.files]);
  });
  fileInput.addEventListener("change", () => { addFiles([...fileInput.files]); fileInput.value = ""; });

  function addFiles(files) {
    const imgs = files.filter((f) => f.type.startsWith("image/"));
    imgs.forEach((f) => state.images.push({ file: f, url: URL.createObjectURL(f) }));
    renderThumbs();
    updateProcessHint();
    updateBatchUI();
  }
  function removeImg(i) {
    URL.revokeObjectURL(state.images[i].url);
    state.images.splice(i, 1);
    renderThumbs();
    updateProcessHint();
    updateBatchUI();
  }
  function renderThumbs() {
    const box = $("thumbs");
    box.innerHTML = "";
    state.images.forEach((img, i) => {
      const el = document.createElement("div");
      el.className = "thumb";
      el.innerHTML = `<img src="${img.url}"><div class="meta">${esc(img.file.name)}</div>` +
                     `<button class="x" title="移除">×</button>`;
      el.querySelector(".x").addEventListener("click", () => removeImg(i));
      box.appendChild(el);
    });
    $("imgInfo").textContent = state.images.length ? `已选择 ${state.images.length} 张图片` : "";
  }

  // ---------- 处理方式 ----------
  $("modeRow").addEventListener("click", (e) => {
    const r = e.target.closest(".radio");
    if (!r) return;
    state.processMode = r.dataset.m;
    [...$("modeRow").children].forEach((c) => c.classList.toggle("active", c === r));
    updateProcessHint();
    updateBatchUI();
  });
  function updateProcessHint() {
    const n = state.images.length;
    const el = $("processHint");
    if (state.mode === "generate") { el.textContent = ""; return; }
    if (n <= 1) { el.textContent = "当前 1 张图，一次处理与批量处理效果相同。"; return; }
    el.textContent = state.processMode === "once"
      ? `已选 ${n} 张：将全部放入同一个请求一次处理。`
      : `已选 ${n} 张：将逐张发送请求批量处理（各自按原图尺寸自适应）。`;
  }

  // ---------- 尺寸 ----------
  $("sizeModeChips").addEventListener("click", (e) => {
    const c = e.target.closest(".chip");
    if (!c || !c.dataset.s) return;
    state.sizeMode = c.dataset.s;
    [...$("sizeModeChips").children].forEach((x) => x.classList.toggle("active", x === c));
    $("ratioPanel").classList.toggle("hidden", state.sizeMode !== "ratio");
    $("sizePanel").classList.toggle("hidden", state.sizeMode !== "size");
    updateSizeInfo();
  });
  $("ratioPresets").addEventListener("click", (e) => {
    const c = e.target.closest(".chip");
    if (!c || !c.dataset.r) return;
    state.ratio = c.dataset.r;
    [...$("ratioPresets").children].forEach((x) => {
      if (x.dataset.r) x.classList.toggle("active", x === c);
    });
    const [w, h] = c.dataset.r.split(":");
    $("ratioW").value = w; $("ratioH").value = h;
  });
  ["ratioW", "ratioH"].forEach((id) => {
    $(id).addEventListener("input", () => { state.ratio = `${$("ratioW").value}:${$("ratioH").value}`; });
  });
  function updateSizeInfo() {
    const el = $("sizeInfo");
    const s = state.sizeMode;
    if (s === "from-image") el.textContent = "根据参考图宽高自动换算合法尺寸（边长 ≤ 3840、16 的倍数、总像素 655360~8294400）。";
    else if (s === "auto") el.textContent = "交由 API 按输入参考图自动判定尺寸。";
    else if (s === "ratio") el.textContent = `将按宽高比 ${state.ratio || "1:1"} 自动换算为合法像素尺寸。`;
    else el.textContent = "使用你指定的固定像素尺寸（建议 16 的倍数）。";
  }

  // ---------- 提交 ----------
  $("runBtn").addEventListener("click", async () => {
    if (!getKey()) { showStatus("请先在上方输入当前平台的 API Key。", true); return; }
    const prompt = $("prompt").value.trim();
    if (!prompt) { showStatus("请先填写提示词。", true); return; }
    if (state.mode === "edit" && state.images.length === 0) {
      showStatus("编辑模式需要至少 1 张参考图。", true); return;
    }

    const size = buildSize();
    const btn = $("runBtn");
    btn.disabled = true;
    btn.textContent = state.mode === "edit" && state.processMode === "batch" && state.images.length > 1
      ? `批量处理 ${state.images.length} 张中，请稍候…` : "生成中，请稍候…";
    showStatus(`正在请求 ${curCfg().label}…\n`);

    try {
      const t0 = Date.now();
      if (state.mode === "generate") {
        await callGenerate(prompt, size);
      } else {
        await callEdit(prompt, size);
      }
      showStatus(prev => prev + `\n完成，用时 ${((Date.now() - t0) / 1000).toFixed(1)}s。`);
    } catch (err) {
      showStatus("请求失败：" + err.message, true);
    } finally {
      btn.disabled = false;
      btn.textContent = "开始生成";
    }
  });

  function buildSize() {
    const s = state.sizeMode;
    if (s === "auto") return "auto";
    if (s === "ratio") return `${$("ratioW").value || 1}:${$("ratioH").value || 1}`;
    if (s === "size") return `${$("sizeW").value || 1024}x${$("sizeH").value || 1024}`;
    return "from-image";
  }

  function platformPayload() {
    return {
      platform: state.platform,
      base_url: baseUrlInput.value.trim() || curCfg().base,
    };
  }

  async function callGenerate(prompt, size) {
    const res = await fetch("/api/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(Object.assign({
        prompt, model: modelInput.value.trim() || curCfg().models[0],
        size, n: +nInput.value || 1,
        quality: $("quality").value, output_format: $("outputFormat").value,
        api_key: getKey(),
        timeout: (state.platform === "mass" || state.platform.startsWith("qianwen")) ? 900 : 300,
      }, platformPayload())),
    });
    const data = await res.json();
    if (!data.ok) throw new Error(fmtErr(data));
    renderResults(data.results, `尺寸：${data.requested_size || size}`);
  }

  async function callEdit(prompt, size) {
    const fd = new FormData();
    fd.append("prompt", prompt);
    fd.append("model", modelInput.value.trim() || curCfg().models[0]);
    fd.append("size", size);
    fd.append("mode", state.processMode);
    fd.append("n", nInput.value || "1");
    fd.append("quality", $("quality").value);
    fd.append("output_format", $("outputFormat").value);
    fd.append("input_fidelity", $("inputFidelity").value);
    fd.append("timeout", (state.platform === "mass" || state.platform.startsWith("qianwen")) ? "900" : "300");
    fd.append("api_key", getKey());
    fd.append("platform", state.platform);
    fd.append("base_url", baseUrlInput.value.trim() || curCfg().base);
    const name = state.images.length === 1 ? "image" : "image[]";
    state.images.forEach((img) => fd.append(name, img.file, img.file.name));

    const res = await fetch("/api/edit", { method: "POST", body: fd });
    const data = await res.json();
    if (!data.ok) throw new Error(fmtErr(data));
    renderResults(data.results, data.mode === "batch"
      ? `批量处理：${data.results.length} 个结果`
      : `一次处理：${data.results.length} 个结果 · 尺寸：${data.requested_size || size}`);
  }

  // ---------- 结果 ----------
  function resultCardHTML(r, label) {
    const src = r.url || "";
    const badge = r.input ? `基于 ${esc(r.input)}` : (label || "#");
    return `
      <div class="result-card">
        <div class="img-wrap">
          <img src="${src}" loading="lazy">
          <span class="badge">${badge}</span>
        </div>
        <div class="info">
          <div class="fname">${esc(r.name || "result")}</div>
          ${r.revised_prompt ? `<details class="rev"><summary>查看修正提示词</summary><p>${esc(r.revised_prompt)}</p></details>` : ""}
        </div>
        <a class="dl" href="${src}" download="${esc(r.name || "result.png")}">下载</a>
      </div>`;
  }

  function appendCard(grid, html) {
    const el = document.createElement("div");
    el.innerHTML = html;
    grid.appendChild(el.firstElementChild);
  }

  function renderResults(list, note) {
    const card = $("resultCard"), grid = $("results");
    card.classList.remove("hidden");
    grid.innerHTML = "";
    if (!list || !list.length) {
      grid.innerHTML = `<div class="muted">无结果。</div>`;
      return;
    }
    const head = document.createElement("div");
    head.className = "hint";
    head.textContent = note;
    grid.appendChild(head);
    list.forEach((r, i) => {
      if (!r.url) {
        const em = document.createElement("div");
        em.className = "muted";
        em.textContent = `#${i + 1} ${r.error || "无结果"}`;
        grid.appendChild(em);
        return;
      }
      appendCard(grid, resultCardHTML(r, `#${r.index || i + 1}`));
    });
  }

  function renderBatchResults(results, tasks) {
    const card = $("resultCard"), grid = $("results");
    card.classList.remove("hidden");
    grid.innerHTML = "";
    const okCount = results.filter((r) => r.ok).length;
    const head = document.createElement("div");
    head.className = "hint";
    head.textContent = `多任务并发完成：${okCount}/${results.length} 个结果成功。`;
    grid.appendChild(head);
    tasks.forEach((t, ti) => {
      const items = results.filter((r) => r.id === t.id);
      const ok = items.some((r) => r.ok);
      const block = document.createElement("div");
      block.className = "task-block";
      const headEl = document.createElement("div");
      headEl.className = "task-head";
      headEl.innerHTML = `任务 ${ti + 1}：${esc(t.prompt)} <span class="pill ${ok ? "ok" : "bad"}">${ok ? "成功" : "失败"}</span>`;
      block.appendChild(headEl);
      if (!items.length) {
        block.appendChild(Object.assign(document.createElement("div"), { className: "muted", textContent: "无结果" }));
      }
      items.forEach((r, i) => {
        if (!r.ok) {
          const em = document.createElement("div");
          em.className = "muted";
          em.textContent = `#${i + 1} ${fmtErr({ error: r.error })}`;
          block.appendChild(em);
          return;
        }
        if (!r.results || !r.results.length) {
          const em = document.createElement("div");
          em.className = "muted";
          em.textContent = "#" + (i + 1) + " 无结果";
          block.appendChild(em);
          return;
        }
        const sub = document.createElement("div");
        sub.className = "task-grid";
        r.results.forEach((img, j) => {
          if (!img.url) return;
          appendCard(sub, resultCardHTML(img, `#${j + 1}`));
        });
        block.appendChild(sub);
      });
      grid.appendChild(block);
    });
  }

  // ---------- 多任务并发 ----------
  const batchText = $("batchPrompts"), batchWorkers = $("batchWorkers"),
        batchCount = $("batchCount"), batchRunBtn = $("batchRunBtn");

  function batchTasks() {
    return batchText.value.split("\n").map((s) => s.trim()).filter(Boolean);
  }
  function updateBatchUI() {
    const n = batchTasks().length;
    batchCount.value = String(n);
    batchRunBtn.disabled = n === 0;
    batchRunBtn.textContent = n ? `并发提交 ${n} 个任务` : "并发提交";
    updateBatchHint();
  }
  function updateBatchHint() {
    const n = batchTasks().length;
    const modeDesc = state.mode === "generate"
      ? "文生图（无需参考图）"
      : (state.processMode === "batch" && state.images.length > 1
          ? `多图编辑 · 批量处理（每图一次，共 ${state.images.length} 张参考图）`
          : `多图编辑 · 一次处理（共 ${state.images.length} 张参考图）`);
    const imgNote = state.mode === "edit" && !state.images.length
      ? " <b style='color:#b45309'>未上传参考图，请先在「参考图片」上传！</b>" : "";
    $("batchHint").innerHTML =
      `当前 ${n} 个任务：所有任务共用上方「平台 / 模型 / 尺寸 / 输出数量 n / ${state.mode === "edit" ? "参考图 / " : ""}处理方式」配置，仅提示词不同，提交后并发执行。当前：${modeDesc}。${imgNote}`;
  }
  batchText.addEventListener("input", updateBatchUI);
  batchWorkers.addEventListener("input", updateBatchUI);

  function readAsDataURL(file) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = () => reject(new Error("读取图片失败: " + file.name));
      r.readAsDataURL(file);
    });
  }

  async function callBatch() {
    const tasks = batchTasks().map((prompt, i) => ({ id: i, prompt }));
    const payload = Object.assign({
      tasks,
      model: modelInput.value.trim() || curCfg().models[0],
      size: buildSize(), n: +nInput.value || 1,
      quality: $("quality").value, output_format: $("outputFormat").value,
      api_key: getKey(),
      mode: state.mode,
      batch: state.mode === "edit" && state.processMode === "batch" && state.images.length > 1,
      max_workers: +batchWorkers.value || 4,
      timeout: (state.platform === "mass" || state.platform.startsWith("qianwen")) ? 900 : 300,
    }, platformPayload());
    if (state.mode === "edit") {
      payload.images = await Promise.all(state.images.map((img) => readAsDataURL(img.file)));
    }
    const res = await fetch("/api/batch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!data.ok) throw new Error(fmtErr(data));
    renderBatchResults(data.results, tasks);
  }

  batchRunBtn.addEventListener("click", async () => {
    if (!getKey()) { showStatus("请先在上方输入当前平台的 API Key。", true); return; }
    const tasks = batchTasks();
    if (!tasks.length) { showStatus("请先填写至少一个任务提示词。", true); return; }
    if (state.mode === "edit" && !state.images.length) {
      showStatus("多任务图生图需要先在上方「参考图片」上传图片。", true); return;
    }
    const btn = batchRunBtn;
    btn.disabled = true;
    const old = btn.textContent;
    btn.textContent = `并发执行 ${tasks.length} 个任务中…`;
    showStatus(`正在并发请求 ${curCfg().label}（${Math.min(tasks.length, +batchWorkers.value || 4)} 路并发）…\n`);
    const t0 = Date.now();
    try {
      await callBatch();
      showStatus((prev) => prev + `\n完成，用时 ${((Date.now() - t0) / 1000).toFixed(1)}s。`);
    } catch (err) {
      showStatus("请求失败：" + err.message, true);
    } finally {
      btn.disabled = false;
      btn.textContent = old;
      updateBatchUI();
    }
  });

  // ---------- 工具 ----------
  function showStatus(text, isErr) {
    const el = $("status");
    if (typeof text === "function") el.textContent = text(el.textContent);
    else el.textContent = text;
    el.classList.toggle("err", !!isErr);
  }
  function fmtErr(data) {
    const e = data.error;
    if (typeof e === "string") return e;
    if (e && typeof e === "object") {
      return e.message || JSON.stringify(e);
    }
    return JSON.stringify(data);
  }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[c]));
  }

  // 健康检查提示
  fetch("/api/health").then((r) => r.json()).then(() => {
    applyPlatform();
  }).catch(() => {
    showStatus("无法连接本地服务。请先运行：python gpt_image2.py --server", true);
  });

  updateProcessHint();
  updateSizeInfo();
  updateBatchUI();
})();
