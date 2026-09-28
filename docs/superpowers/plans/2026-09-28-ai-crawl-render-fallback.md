# 网页爬取「静态优先 + 无头渲染降级」与按域 Cookie 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `crawl_website` 在静态抓取失败（403/429/正文过短）时降级到自建薄 Chromium 容器渲染，并支持按域名隔离的登录态 cookie，失败时给出模型可改道的可读错误。

**Architecture:** 渲染是**纯追加分支**：静态成功路径不变；`crawl_render_enabled` 默认 0，关闭时链路等价于现状。SSRF 守卫统一到一套做 DNS 全量解析的实现（`common/net/guarded-fetch.ts`），静态请求与渲染期 CDP 请求拦截共用同一份判定。cookie 按域名后缀匹配注入，AES-256-GCM 加密落库，接口只回显域名列表。

**Tech Stack:** NestJS 10 + Fastify + Drizzle ORM + MySQL 8（后端，CommonJS / ES2021 / `strict: true`）；`node:crypto`（AES-256-GCM）；`puppeteer-core`（纯 JS，不下载浏览器二进制）；独立 `debian:bookworm-slim` + `chromium` 渲染容器（CDP over WebSocket）；Next.js + Tailwind + shadcn/ui（后台）。

## Global Constraints

- **语言**：所有代码注释、错误文案、文档均为中文。
- **不要修改** `lumira-app/`（废弃的 uni-app 原型）。
- **冻结区**：`lumira-server/packages/admin/src/components/ai-create/**` 是并行 WIP，**禁止改动**。本计划要改的 `ai-config-form.tsx` 不在该目录内。
- **git 纪律**：显式列路径 `git add <path>`，**禁止** `git add -A` / `git add .`；**禁止** `reset` / `stash` / `rebase`；**禁止**无路径过滤的 `git diff`（仓库有并行未跟踪文件）。
- **推送纪律**（`AGENTS.md`）：后端/后台每完成一次改动即 commit 并推两远端：`git push origin master`（gitee）+ `git push github master`（github）。纯文档改动可由用户决定是否推送。
- **迁移编号**：049 已用 → 本计划用 **050**。
- **常量取值（逐字来自 spec）**：`STATIC_MIN_CHARS = 300`、`CRAWL_RENDER_MAX_PER_SESSION = 2`、`DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20000`、渲染超时夹紧区间 `5000~60000`、`CRAWL_TIMEOUT_MS = 8_000`、`MAX_BYTES = 1_048_576`、`MAX_CHARS = 6_000`、cookie 值上限 `4096`。
- **基线（改动前必须成立）**：`pnpm --filter @lumira/backend test` = **635 passed / 3 skipped**；`pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json` = **恰 3 处既有错误**（`golden-set.service.spec.ts:30`、`image-prompt.composer.spec.ts:119`、`image-score.service.spec.ts:69`）。任何新增错误都是回归。
- **命令工作目录**：所有 `pnpm` 命令的 `cwd` 为 `e:\Project\photo_post\lumira-server`。
- **两处对 spec 的显式澄清**（实施时按此执行，不得回退为 spec 字面）：
  1. 403/429 文案中的状态码**用实际值插值**（`HTTP ${status}`），而不是写死 `403`。理由：spec 的触发条件含 429，写死 403 会给模型错误信息，违背「模型可读」目标。
  2. 静态响应只在 `res.ok` 时才读体与判断 MIME。理由：403/429 的响应体是反爬壳（实测知乎 584 B），解析它无价值；且非 `ok` 时 MIME 判断无意义。既有「非网页类型被拒绝（PDF）」用例在 `res.ok` 下仍然成立。
- **诚实声明**：即使全部落地，**知乎仍不保证 100% 抓到**（开源方案无 stealth / 住宅代理）。设计只保证「能过就取正文，过不去就给可读错误，绝不卡死」。

---

## 执行顺序与依赖

```
T1 guarded-fetch（共享 SSRF 守卫）
 ├─→ T4 crawl-url（依赖 T1 + T2 + T3）
T2 cookie-crypto（加解密 + 按域选择）
 ├─→ T6 ai-config（依赖 T2）
T3 render-fetch（CDP 驱动器 + puppeteer-core）
 └─→ T4

T5 text-tools（依赖 T4 的 CrawlOptions / CRAWL_RENDER_MAX_PER_SESSION）
T6 ai-config（迁移 050 + schema + DTO + service）
T7 启动告警 + 部署产物（main.ts / renderer Dockerfile / compose / .env.example / AGENTS.md）
T8 后台表单与类型
T9 后续优化登记 + 全量验证 + 推送
```

T1/T2/T3 互不依赖，可并行；其余按序。

---

### Task 1: 共享 SSRF 守卫模块（`common/net/guarded-fetch.ts`）

把 `research-image-fetch.ts` 里更强的 DNS 级守卫**原样搬入**共享模块，使其可被爬取链路复用；`fetchGuarded` 仅新增可选入参，既有调用行为**完全不变**。

**Files:**
- Create: `lumira-server/packages/backend/src/common/net/guarded-fetch.ts`
- Create: `lumira-server/packages/backend/src/common/net/guarded-fetch.spec.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts`

**Interfaces:**
- Consumes: 无（叶子模块，仅 `node:dns/promises`）
- Produces:
  - `type DnsLookup = (host: string) => Promise<{ address: string }[]>`
  - `isPrivateAddress(ip: string): boolean`
  - `assertPublicHttpUrl(raw: string, deps?: { lookup?: DnsLookup }): Promise<URL>`
  - `fetchGuarded(url: string, opts: { timeoutMs: number; accept?: string; headers?: Record<string, string>; lookup?: DnsLookup }): Promise<Response>`
  - `GUARDED_FETCH_MAX_REDIRECTS = 3`

- [ ] **Step 1: 写失败的测试**

创建 `lumira-server/packages/backend/src/common/net/guarded-fetch.spec.ts`：

```ts
// lumira-server/packages/backend/src/common/net/guarded-fetch.spec.ts
import { assertPublicHttpUrl, fetchGuarded, isPrivateAddress } from './guarded-fetch';

/** 注入式 DNS：按域名返回预设地址，单测不触网 */
const dns = (map: Record<string, string[]>) => async (host: string) =>
  (map[host] ?? []).map((address) => ({ address }));

describe('isPrivateAddress', () => {
  it('拦截 IPv4 私网 / 环回 / 链路本地 / 保留段', () => {
    for (const ip of ['10.1.2.3', '172.16.0.1', '192.168.1.1', '127.0.0.1', '169.254.1.1', '0.0.0.0', '100.64.0.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv4', () => {
    expect(isPrivateAddress('8.8.8.8')).toBe(false);
  });

  it('拦截 IPv6 环回 / ULA / 链路本地 / v4 映射私网', () => {
    for (const ip of ['::1', 'fc00::1', 'fd12:3456::1', 'fe80::1', '::ffff:192.168.1.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });
});

describe('assertPublicHttpUrl', () => {
  it('拒绝非 http(s) 协议', async () => {
    await expect(assertPublicHttpUrl('file:///etc/passwd')).rejects.toThrow('不支持的协议');
  });

  it('拒绝非法 URL', async () => {
    await expect(assertPublicHttpUrl('not a url')).rejects.toThrow('图片地址非法');
  });

  it('IP 字面量为私网时拒绝', async () => {
    await expect(assertPublicHttpUrl('http://192.168.1.10/x')).rejects.toThrow('目标地址位于内网');
    await expect(assertPublicHttpUrl('http://[::1]/x')).rejects.toThrow('目标地址位于内网');
  });

  it('裸公网 IP 放行', async () => {
    await expect(assertPublicHttpUrl('http://8.8.8.8/x')).resolves.toBeInstanceOf(URL);
  });

  it('域名解析到私网时拒绝（注入 lookup）', async () => {
    const deps = { lookup: dns({ 'evil.example': ['172.16.0.9'] }) };
    await expect(assertPublicHttpUrl('http://evil.example/x', deps)).rejects.toThrow('目标地址解析到内网');
  });

  it('域名解析全部为公网时放行（注入 lookup）', async () => {
    const deps = { lookup: dns({ 'ok.example': ['93.184.216.34'] }) };
    await expect(assertPublicHttpUrl('https://ok.example/x', deps)).resolves.toBeInstanceOf(URL);
  });

  it('域名无解析结果时拒绝（注入 lookup）', async () => {
    const deps = { lookup: dns({}) };
    await expect(assertPublicHttpUrl('https://none.example/x', deps)).rejects.toThrow('域名无解析结果');
  });
});

describe('fetchGuarded', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => fetchMock.mockReset());
  afterAll(() => fetchMock.mockRestore());

  const publicDns = { lookup: dns({ 'ok.example': ['93.184.216.34'] }) };

  it('逐跳校验重定向并跟到最终响应', async () => {
    fetchMock
      .mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'https://ok.example/b' } }))
      .mockResolvedValueOnce(new Response('final', { status: 200 }));
    const res = await fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns });
    expect(res.status).toBe(200);
    await expect(res.text()).resolves.toBe('final');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('重定向目标解析到私网时拒绝且不发出该跳请求', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'http://192.168.1.9/secret' } }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('目标地址位于内网');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('自定义 headers 覆盖默认 User-Agent（供爬取链路传伪装头与 cookie）', async () => {
    fetchMock.mockResolvedValueOnce(new Response('ok', { status: 200 }));
    await fetchGuarded('https://ok.example/a', {
      timeoutMs: 1000,
      headers: { 'User-Agent': 'Chrome', Cookie: 'a=1' },
      ...publicDns,
    });
    const init = fetchMock.mock.calls[0][1] as RequestInit;
    const headers = init.headers as Record<string, string>;
    expect(headers['User-Agent']).toBe('Chrome');
    expect(headers.Cookie).toBe('a=1');
  });

  it('超时映射为可读错误', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('抓取超时');
  });

  it('超出跳数上限时拒绝', async () => {
    fetchMock.mockImplementation(async () => new Response('', { status: 302, headers: { Location: 'https://ok.example/loop' } }));
    await expect(fetchGuarded('https://ok.example/a', { timeoutMs: 1000, ...publicDns })).rejects.toThrow('重定向次数超出上限');
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest src/common/net/guarded-fetch.spec.ts`
Expected: FAIL —— `Cannot find module './guarded-fetch'`

- [ ] **Step 3: 创建共享模块（从 `research-image-fetch.ts` 原样搬入）**

创建 `lumira-server/packages/backend/src/common/net/guarded-fetch.ts`：

```ts
// lumira-server/packages/backend/src/common/net/guarded-fetch.ts
// 出站请求的 SSRF 守卫：host 为 IP 字面量时直接判定，否则 DNS 全量解析、任一私网即拒；
// 下载走手动逐跳重定向，每跳重新校验。
// 从 modules/ai/trend-research/research-image-fetch.ts 原样搬迁，供参考图抓取与网页爬取共用。

import { lookup } from 'node:dns/promises';

/** 手动跟随重定向的最大跳数（值与原 RESEARCH_IMAGE_MAX_REDIRECTS 一致） */
export const GUARDED_FETCH_MAX_REDIRECTS = 3;

/** DNS 解析注入点（缺省用 node:dns/promises 的 lookup；单测注入假实现以避免触网） */
export type DnsLookup = (host: string) => Promise<{ address: string }[]>;

const defaultLookup: DnsLookup = (host) => lookup(host, { all: true });

/** IPv4 → 32 位整数 */
function ipv4ToInt(ip: string): number | null {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    if (!/^\d{1,3}$/.test(p)) return null;
    const v = Number(p);
    if (v > 255) return null;
    n = (n << 8) | v;
  }
  return n >>> 0;
}

/** IPv4 私网 / 环回 / 链路本地 / 保留段判定 */
function isPrivateV4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  if (n === null) return false;
  const inRange = (base: string, bits: number): boolean => {
    const b = ipv4ToInt(base);
    if (b === null) return false;
    const mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0;
    return (n & mask) === (b & mask);
  };
  return (
    inRange('0.0.0.0', 8) ||
    inRange('10.0.0.0', 8) ||
    inRange('100.64.0.0', 10) ||
    inRange('127.0.0.0', 8) ||
    inRange('169.254.0.0', 16) ||
    inRange('172.16.0.0', 12) ||
    inRange('192.0.0.0', 24) ||
    inRange('192.168.0.0', 16) ||
    inRange('198.18.0.0', 15) ||
    inRange('224.0.0.0', 4) ||
    inRange('240.0.0.0', 4)
  );
}

/** IP 字面量是否属于私网 / 环回 / 链路本地 / 保留段（IPv4 与 IPv6） */
export function isPrivateAddress(ip: string): boolean {
  const s = (ip || '').trim().toLowerCase().replace(/^\[|\]$/g, '');
  if (!s) return true;
  // v4 映射 v6
  const mapped = s.match(/^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (mapped) return isPrivateV4(mapped[1]);
  if (s.includes(':')) {
    if (s === '::1' || s === '::') return true;
    if (/^f[cd][0-9a-f]{2}:/.test(s)) return true; // fc00::/7（ULA）
    if (/^fe[89ab][0-9a-f]:/.test(s)) return true; // fe80::/10（链路本地）
    return false;
  }
  return isPrivateV4(s);
}

const IPV4_LITERAL = /^\d{1,3}(?:\.\d{1,3}){3}$/;

/**
 * 校验 URL 可安全外发：仅 http/https；host 为 IP 字面量时直接判定，
 * 否则 DNS 解析全部地址，任一为私网即拒绝。
 */
export async function assertPublicHttpUrl(raw: string, deps: { lookup?: DnsLookup } = {}): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('图片地址非法');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`不支持的协议：${url.protocol}`);
  }
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (IPV4_LITERAL.test(host) || host.includes(':')) {
    if (isPrivateAddress(host)) throw new Error('目标地址位于内网，已拦截');
    return url;
  }
  const resolve = deps.lookup ?? defaultLookup;
  let addrs: { address: string }[];
  try {
    addrs = await resolve(host);
  } catch {
    throw new Error(`域名解析失败：${host}`);
  }
  if (!addrs.length) throw new Error(`域名无解析结果：${host}`);
  if (addrs.some((a) => isPrivateAddress(a.address))) throw new Error('目标地址解析到内网，已拦截');
  return url;
}

/**
 * 受控下载：手动跟随重定向（≤ GUARDED_FETCH_MAX_REDIRECTS 跳），每跳重新做 SSRF 校验。
 * 返回最终 Response（调用方负责读体与 content-type 判断）。
 * `opts.headers` 为可选覆盖（缺省 undefined → 与搬迁前行为完全一致）。
 */
export async function fetchGuarded(
  url: string,
  opts: { timeoutMs: number; accept?: string; headers?: Record<string, string>; lookup?: DnsLookup },
): Promise<Response> {
  let current = url;
  for (let hop = 0; hop <= GUARDED_FETCH_MAX_REDIRECTS; hop++) {
    await assertPublicHttpUrl(current, { lookup: opts.lookup });
    const headers: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (compatible; LumiraBot/1.0)' };
    if (opts.accept) headers.Accept = opts.accept;
    if (opts.headers) Object.assign(headers, opts.headers);
    const res = await fetch(current, {
      headers,
      redirect: 'manual',
      signal: AbortSignal.timeout(opts.timeoutMs),
    }).catch((err: unknown) => {
      const name = (err as { name?: string } | null | undefined)?.name;
      if (name === 'AbortError' || name === 'TimeoutError') throw new Error('抓取超时');
      throw new Error('抓取失败（网络不可达）');
    });
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      if (!loc) throw new Error(`重定向缺少 location（HTTP ${res.status}）`);
      current = new URL(loc, current).toString();
      continue;
    }
    return res;
  }
  throw new Error('重定向次数超出上限');
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/common/net/guarded-fetch.spec.ts`
Expected: PASS（全部用例）

- [ ] **Step 5: 把 `research-image-fetch.ts` 改为 re-export（对外 API 与行为不变）**

修改 `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts`：

1. 删除文件内 `ipv4ToInt` / `isPrivateV4` / `isPrivateAddress` / `IPV4_LITERAL` / `assertPublicHttpUrl` / `fetchGuarded` 六个定义（第 12-130 行区域）。
2. 顶部 import 区改为：

```ts
import {
  RESEARCH_IMAGE_ALLOWED_MIMES,
  RESEARCH_IMAGE_MAX_BYTES,
} from './research-image';
import {
  assertPublicHttpUrl,
  fetchGuarded,
  isPrivateAddress,
} from '../../../common/net/guarded-fetch';

// 对外保持原 API：既有调用方与 spec 继续从本模块导入这些符号
export { assertPublicHttpUrl, fetchGuarded, isPrivateAddress };
```

> 注意：`RESEARCH_IMAGE_MAX_REDIRECTS` 搬走后在本文件已无使用，必须从 import 中移除（否则是死导入）。

3. 文件头注释补一行：`// SSRF 守卫已抽到 common/net/guarded-fetch.ts（爬取链路共用），本文件 re-export 保持 API 不变。`
4. `fetchImageSafely` / `fetchPageHtml` / `readCapped` / `extractPageImageUrl` / `decodeHtml` 保持原样不动。

- [ ] **Step 6: 跑既有参考图测试，确认零回归**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/trend-research/research-image`
Expected: PASS（`research-image-fetch.spec.ts` / `research-image.service.spec.ts` / `research-image-store.spec.ts` 全部通过，无新增失败）

- [ ] **Step 7: 类型检查**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json`
Expected: 恰 3 处既有错误（`golden-set.service.spec.ts:30`、`image-prompt.composer.spec.ts:119`、`image-score.service.spec.ts:69`），零新增。

- [ ] **Step 8: Commit**

```bash
git add lumira-server/packages/backend/src/common/net/guarded-fetch.ts lumira-server/packages/backend/src/common/net/guarded-fetch.spec.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts
git commit -m "refactor(backend): SSRF 守卫抽到 common/net/guarded-fetch，供爬取链路共用"
```

---

### Task 2: Cookie 加密与按域选择（`cookie-crypto.ts`）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/cookie-crypto.spec.ts`

**Interfaces:**
- Consumes: `node:crypto`
- Produces:
  - `selectCookiesForHost(host: string, cookies: Record<string, string>): Record<string, string>`
  - `encryptCookies(cookies: Record<string, string>): string | null`（空对象返回 `null`；密钥缺失/非法抛 `Error('未配置 CRAWL_COOKIE_SECRET，无法保存 cookie')`）
  - `decryptCookies(stored: string | null | undefined): Record<string, string>`（任何异常返回 `{}` 并 warn）

- [ ] **Step 1: 写失败的测试**

创建 `lumira-server/packages/backend/src/modules/ai/cookie-crypto.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/cookie-crypto.spec.ts
import { decryptCookies, encryptCookies, selectCookiesForHost } from './cookie-crypto';

const SECRET = 'a'.repeat(64); // 32 字节 hex

describe('selectCookiesForHost', () => {
  const cookies = { 'zhihu.com': 'z_c0=abc', 'www.zhihu.com': 'x=1', 'other.com': 'y=2' };

  it('精确匹配', () => {
    expect(selectCookiesForHost('zhihu.com', cookies)).toEqual({ 'zhihu.com': 'z_c0=abc' });
  });

  it('子域后缀匹配（同时命中父域与自身域）', () => {
    expect(selectCookiesForHost('www.zhihu.com', cookies)).toEqual({
      'zhihu.com': 'z_c0=abc',
      'www.zhihu.com': 'x=1',
    });
  });

  it('伪子域不匹配（evil-zhihu.com 不得命中 zhihu.com）', () => {
    expect(selectCookiesForHost('evil-zhihu.com', cookies)).toEqual({});
  });

  it('无匹配则不发送任何 cookie', () => {
    expect(selectCookiesForHost('example.com', cookies)).toEqual({});
  });

  it('host 大小写与尾点归一化', () => {
    expect(selectCookiesForHost('WWW.Zhihu.com.', cookies)).toEqual({
      'zhihu.com': 'z_c0=abc',
      'www.zhihu.com': 'x=1',
    });
  });
});

describe('cookie 加解密', () => {
  const original = process.env.CRAWL_COOKIE_SECRET;

  beforeEach(() => {
    process.env.CRAWL_COOKIE_SECRET = SECRET;
  });
  afterAll(() => {
    if (original === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = original;
  });

  it('加解密往返一致', () => {
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    expect(stored).toMatch(/^v1:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+$/);
    expect(stored).not.toContain('z_c0=abc');
    expect(decryptCookies(stored)).toEqual({ 'zhihu.com': 'z_c0=abc' });
  });

  it('空对象加密返回 null', () => {
    expect(encryptCookies({})).toBeNull();
    expect(encryptCookies({ 'zhihu.com': '' })).toBeNull();
  });

  it('密钥缺失时加密抛错（绝不落明文）', () => {
    delete process.env.CRAWL_COOKIE_SECRET;
    expect(() => encryptCookies({ 'zhihu.com': 'z_c0=abc' })).toThrow('未配置 CRAWL_COOKIE_SECRET');
  });

  it('密钥长度非法时加密抛错', () => {
    process.env.CRAWL_COOKIE_SECRET = 'abcd';
    expect(() => encryptCookies({ 'zhihu.com': 'z_c0=abc' })).toThrow('未配置 CRAWL_COOKIE_SECRET');
  });

  it('密文被篡改时解密返回空对象（不抛错）', () => {
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' }) as string;
    const tampered = stored.slice(0, -2) + (stored.endsWith('00') ? '11' : '00');
    expect(decryptCookies(tampered)).toEqual({});
  });

  it('格式非法 / 空值 / 密钥缺失时解密返回空对象', () => {
    expect(decryptCookies('garbage')).toEqual({});
    expect(decryptCookies(null)).toEqual({});
    expect(decryptCookies('')).toEqual({});
    delete process.env.CRAWL_COOKIE_SECRET;
    const stored = `v1:${'0'.repeat(24)}:${'0'.repeat(32)}:${'0'.repeat(8)}`;
    expect(decryptCookies(stored)).toEqual({});
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/cookie-crypto.spec.ts`
Expected: FAIL —— `Cannot find module './cookie-crypto'`

- [ ] **Step 3: 实现模块**

创建 `lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts
// 网页爬取 cookie 的加密存储与按域选择。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第五节
//
// 安全约束：cookie 按域名后缀匹配注入，无匹配就一份都不发（禁止模糊匹配，
// 否则会把某站会话泄露给任意被抓站点）；密文格式 v1:<ivHex>:<tagHex>:<cipherHex>。

import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const STORAGE_VERSION = 'v1';
const IV_BYTES = 12;
const ALGO = 'aes-256-gcm';

/** 归一化 hostname / 域名：小写、去尾点 */
function normalizeHost(s: string): string {
  return (s || '').trim().toLowerCase().replace(/\.+$/, '');
}

/**
 * 按目标 host 选择要发送的 cookie：`host === domain || host.endsWith('.' + domain)`。
 * 无匹配返回空对象（此时不得发送任何 cookie）。
 */
export function selectCookiesForHost(host: string, cookies: Record<string, string>): Record<string, string> {
  const h = normalizeHost(host);
  const out: Record<string, string> = {};
  if (!h) return out;
  for (const [domain, value] of Object.entries(cookies ?? {})) {
    const d = normalizeHost(domain);
    if (!d || !value) continue;
    if (h === d || h.endsWith(`.${d}`)) out[domain] = value;
  }
  return out;
}

/** 读取并校验 32 字节密钥（64 位 hex）；缺失/非法抛可读错误 */
function readKey(): Buffer {
  const raw = (process.env.CRAWL_COOKIE_SECRET || '').trim();
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new Error('未配置 CRAWL_COOKIE_SECRET，无法保存 cookie');
  }
  return Buffer.from(raw, 'hex');
}

/** 加密 cookie 映射；无可存内容返回 null；密钥缺失/非法抛错（绝不落明文） */
export function encryptCookies(cookies: Record<string, string>): string | null {
  const entries = Object.entries(cookies ?? {}).filter(([d, v]) => normalizeHost(d) && v);
  if (!entries.length) return null;
  const key = readKey();
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGO, key, iv);
  const plain = JSON.stringify(Object.fromEntries(entries));
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${STORAGE_VERSION}:${iv.toString('hex')}:${tag.toString('hex')}:${enc.toString('hex')}`;
}

/** 解密 cookie 映射；任何异常（格式非法 / 密钥缺失 / 被篡改）返回空对象并 warn，不中断链路 */
export function decryptCookies(stored: string | null | undefined): Record<string, string> {
  if (!stored) return {};
  try {
    const [version, ivHex, tagHex, dataHex] = stored.split(':');
    if (version !== STORAGE_VERSION || !ivHex || !tagHex || !dataHex) return {};
    const raw = (process.env.CRAWL_COOKIE_SECRET || '').trim();
    if (!/^[0-9a-fA-F]{64}$/.test(raw)) return {};
    const decipher = createDecipheriv(ALGO, Buffer.from(raw, 'hex'), Buffer.from(ivHex, 'hex'));
    decipher.setAuthTag(Buffer.from(tagHex, 'hex'));
    const plain = Buffer.concat([decipher.update(Buffer.from(dataHex, 'hex')), decipher.final()]).toString('utf8');
    const parsed = JSON.parse(plain);
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, string>) : {};
  } catch {
    // 只报事实，绝不输出 cookie 值
    console.warn('WARN: 网页爬取 cookie 解密失败，本次按「无 cookie」处理');
    return {};
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/cookie-crypto.spec.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts lumira-server/packages/backend/src/modules/ai/cookie-crypto.spec.ts
git commit -m "feat(backend): 新增爬取 cookie 的 AES-256-GCM 加密存储与按域选择"
```

---

### Task 3: 渲染驱动器（`tools/render-fetch.ts` + `puppeteer-core`）

用 `puppeteer-core` 连接独立 renderer 容器的 CDP 端点，页面级请求拦截复用 T1 守卫，cookie 按域注入。`connect` 可注入，单测**不启动真实 Chromium**。

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/tools/render-fetch.spec.ts`
- Modify: `lumira-server/packages/backend/package.json`（新增依赖）

**Interfaces:**
- Consumes: `assertPublicHttpUrl`（T1）；`process.env.RENDERER_WS_ENDPOINT`
- Produces:
  - `interface RenderOptions { timeoutMs: number; cookies: Record<string, string> }`
  - `interface RenderDeps { connect?: (endpoint: string) => Promise<BrowserLike> }`
  - `interface BrowserLike { newPage(): Promise<PageLike>; close(): Promise<void>; disconnect?(): void }`
  - `interface PageLike { setRequestInterception(v: boolean): Promise<void>; on(event: 'request', handler: (req: InterceptedRequest) => void): void; setCookie(...c: Array<{ name: string; value: string; domain: string; path: string }>): Promise<void>; goto(url: string, o: { waitUntil: string; timeout: number }): Promise<unknown>; content(): Promise<string>; close(): Promise<void> }`
  - `interface InterceptedRequest { url(): string; continue(): Promise<void>; abort(): Promise<void> }`
  - `renderUrl(url: string, opts: RenderOptions, deps?: RenderDeps): Promise<string>`

- [ ] **Step 1: 加依赖**

Run: `pnpm --filter @lumira/backend add puppeteer-core@^23.11.1`
Expected: `package.json` 的 `dependencies` 出现 `"puppeteer-core": "^23.11.1"`，`pnpm-lock.yaml` 变更；**不下载任何浏览器二进制**（`puppeteer-core` 无 postinstall 下载）。

> 若 npmmirror 上该版本不可用，装当前可用的 23.x 最新版，并在 commit message 中记录实际版本。

- [ ] **Step 2: 写失败的测试**

创建 `lumira-server/packages/backend/src/modules/ai/tools/render-fetch.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/tools/render-fetch.spec.ts
// 用注入的假浏览器验证拦截 / cookie / 超时 / 内容返回，不启动真实 Chromium。
import { renderUrl } from './render-fetch';
import type { BrowserLike, InterceptedRequest, PageLike } from './render-fetch';

type Req = { url: () => string; continued: boolean; aborted: boolean };

/** 假页面：记录拦截回调、cookie、goto 参数 */
function fakePage(requests: Req[], html = '<body><p>渲染正文</p></body>') {
  let handler: ((req: InterceptedRequest) => void) | null = null;
  const page: PageLike = {
    setRequestInterception: jest.fn(async () => undefined),
    on: ((_e: 'request', h: (req: InterceptedRequest) => void) => {
      handler = h;
    }) as PageLike['on'],
    setCookie: jest.fn(async () => undefined),
    goto: jest.fn(async () => undefined),
    content: jest.fn(async () => html),
    close: jest.fn(async () => undefined),
  };
  return {
    page,
    /** 触发一次拦截回调并等待其异步完成 */
    fire: async (url: string) => {
      const req: Req = { url: () => url, continued: false, aborted: false };
      requests.push(req);
      handler?.({
        url: () => url,
        continue: async () => {
          req.continued = true;
        },
        abort: async () => {
          req.aborted = true;
        },
      });
      // 拦截回调内部是 async IIFE，让出事件循环使其跑完
      await new Promise((r) => setTimeout(r, 0));
      return req;
    },
  };
}

function fakeBrowser(page: PageLike) {
  const browser: BrowserLike = {
    newPage: jest.fn(async () => page),
    close: jest.fn(async () => undefined),
    disconnect: jest.fn(),
  };
  return browser;
}

const OPTS = { timeoutMs: 5_000, cookies: { 'zhihu.com': 'z_c0=abc' } };

describe('renderUrl', () => {
  const original = process.env.RENDERER_WS_ENDPOINT;

  afterEach(() => {
    if (original === undefined) delete process.env.RENDERER_WS_ENDPOINT;
    else process.env.RENDERER_WS_ENDPOINT = original;
  });

  it('未配置 RENDERER_WS_ENDPOINT 时抛可读错误', async () => {
    delete process.env.RENDERER_WS_ENDPOINT;
    await expect(renderUrl('https://a.example/x', OPTS, { connect: jest.fn() })).rejects.toThrow('RENDERER_WS_ENDPOINT');
  });

  it('页面发起的私网请求被 abort，公网请求 continue', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page, fire } = fakePage(requests);
    const browser = fakeBrowser(page);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => browser });

    const bad = await fire('http://192.168.1.9/secret');
    expect(bad.aborted).toBe(true);
    expect(bad.continued).toBe(false);

    const good = await fire('https://cdn.example/a.js');
    expect(good.continued).toBe(true);
    expect(good.aborted).toBe(false);
  });

  it('非 http(s) 协议（data:/blob:）直接放行，不 abort', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page, fire } = fakePage(requests);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });

    const data = await fire('data:text/html,<p>hi</p>');
    expect(data.continued).toBe(true);
    expect(data.aborted).toBe(false);
  });

  it('cookie 按域注入：匹配 zhihu.com 及其子域，不匹配的站点一份都不发', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page } = fakePage(requests);
    await renderUrl('https://www.zhihu.com/question/1', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.setCookie).toHaveBeenCalledWith({ name: 'z_c0', value: 'abc', domain: 'zhihu.com', path: '/' });

    (page.setCookie as jest.Mock).mockClear();
    await renderUrl('https://93.184.216.34/other', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.setCookie).not.toHaveBeenCalled();
  });

  it('goto 使用 networkidle2 与传入超时', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([]);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.goto).toHaveBeenCalledWith('https://93.184.216.34/x', { waitUntil: 'networkidle2', timeout: 5_000 });
  });

  it('返回 page.content() 的 HTML', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([], '<body><p>渲染正文</p></body>');
    const html = await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });
    expect(html).toContain('渲染正文');
  });

  it('goto 超时映射为可读错误，且 release 浏览器（disconnect）', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([]);
    (page.goto as jest.Mock).mockRejectedValueOnce(Object.assign(new Error('timeout'), { name: 'TimeoutError' }));
    const browser = fakeBrowser(page);
    await expect(renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => browser })).rejects.toThrow('渲染超时');
    expect(browser.disconnect).toHaveBeenCalled();
  });

  it('目标 URL 解析到私网时在连接前就拒绝', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const connect = jest.fn();
    await expect(renderUrl('http://192.168.1.9/x', OPTS, { connect })).rejects.toThrow('目标地址位于内网');
    expect(connect).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/render-fetch.spec.ts`
Expected: FAIL —— `Cannot find module './render-fetch'`

- [ ] **Step 4: 实现驱动器**

创建 `lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts
// 无头渲染驱动器：连接独立 renderer 容器的 CDP 端点，取回渲染后的 HTML。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第一 / 二 / 三节
//
// 安全：页面自身的每个请求都过一遍 DNS 级 SSRF 守卫（私网 abort），这是
// 「薄容器 + 后端驱动」相对现成渲染服务镜像的核心收益——守卫只有一份。

import { assertPublicHttpUrl } from '../../../common/net/guarded-fetch';

export interface RenderOptions {
  timeoutMs: number;
  /** 域名 → cookie 原始串（调用方已按域筛选，仅内存传递） */
  cookies: Record<string, string>;
}

/** 渲染期被拦截的请求（puppeteer Request 的结构子集） */
export interface InterceptedRequest {
  url(): string;
  continue(): Promise<void>;
  abort(): Promise<void>;
}

/** puppeteer Page 的结构子集（只为可注入假实现而定义，不引 puppeteer 类型） */
export interface PageLike {
  setRequestInterception(value: boolean): Promise<void>;
  on(event: 'request', handler: (req: InterceptedRequest) => void): void;
  setCookie(...cookies: Array<{ name: string; value: string; domain: string; path: string }>): Promise<void>;
  goto(url: string, opts: { waitUntil: string; timeout: number }): Promise<unknown>;
  content(): Promise<string>;
  close(): Promise<void>;
}

/** puppeteer Browser 的结构子集 */
export interface BrowserLike {
  newPage(): Promise<PageLike>;
  close(): Promise<void>;
  /** connect 得到的远端浏览器用 disconnect 释放连接（不关掉对方进程） */
  disconnect?(): void;
}

export interface RenderDeps {
  connect?: (endpoint: string) => Promise<BrowserLike>;
}

/** 缺省连接实现：puppeteer-core 是纯 JS 包（不含浏览器二进制），此处懒加载避免单测引入 */
async function defaultConnect(endpoint: string): Promise<BrowserLike> {
  const puppeteer = await import('puppeteer-core');
  const browser = await puppeteer.connect({ browserWSEndpoint: endpoint });
  return browser as unknown as BrowserLike;
}

/** 把 `a=1; b=2` 解析为 name/value 对（CDP 只能按对设置，不能整串塞） */
function parseCookiePairs(raw: string): Array<{ name: string; value: string }> {
  return raw
    .split(';')
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p) => {
      const i = p.indexOf('=');
      return i === -1 ? { name: p.trim(), value: '' } : { name: p.slice(0, i).trim(), value: p.slice(i + 1).trim() };
    })
    .filter((c) => c.name);
}

function isHttpUrl(u: string): boolean {
  return u.startsWith('http://') || u.startsWith('https://');
}

/** 渲染并返回页面 HTML；失败抛可读 Error（调用方决定降级） */
export async function renderUrl(url: string, opts: RenderOptions, deps: RenderDeps = {}): Promise<string> {
  const endpoint = process.env.RENDERER_WS_ENDPOINT;
  if (!endpoint) throw new Error('未配置 RENDERER_WS_ENDPOINT，无法渲染');

  await assertPublicHttpUrl(url);

  const connect = deps.connect ?? defaultConnect;
  const browser = await connect(endpoint);
  let page: PageLike | null = null;
  try {
    page = await browser.newPage();
    await page.setRequestInterception(true);
    page.on('request', (req) => {
      void (async () => {
        try {
          // data: / blob: / about: 等非 http(s) 请求无 SSRF 面，直接放行
          if (isHttpUrl(req.url())) await assertPublicHttpUrl(req.url());
          await req.continue();
        } catch {
          await req.abort().catch(() => undefined);
        }
      })();
    });

    // 按域注入 cookie（调用方已过滤，此处不再做域名判断）
    const cookieParams: Array<{ name: string; value: string; domain: string; path: string }> = [];
    for (const [domain, raw] of Object.entries(opts.cookies ?? {})) {
      for (const pair of parseCookiePairs(raw)) cookieParams.push({ ...pair, domain, path: '/' });
    }
    if (cookieParams.length) await page.setCookie(...cookieParams);

    await page.goto(url, { waitUntil: 'networkidle2', timeout: opts.timeoutMs }).catch((err: unknown) => {
      const name = (err as { name?: string } | null | undefined)?.name;
      if (name === 'TimeoutError') throw new Error('渲染超时，请换其他来源');
      throw new Error('渲染失败，请换其他来源');
    });

    return await page.content();
  } finally {
    await page?.close().catch(() => undefined);
    // 远端浏览器：断开连接（puppeteer 的 disconnect 为同步方法）
    try {
      if (browser.disconnect) browser.disconnect();
      else await browser.close();
    } catch {
      /* 释放失败不影响结果 */
    }
  }
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/render-fetch.spec.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/package.json lumira-server/pnpm-lock.yaml lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts lumira-server/packages/backend/src/modules/ai/tools/render-fetch.spec.ts
git commit -m "feat(backend): 新增 puppeteer-core 驱动的无头渲染器（CDP 请求拦截 + 按域 cookie）"
```

---

### Task 4: `crawl-url.ts` 改造（静态优先 + 降级判定 + 统一守卫）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts`

**Interfaces:**
- Consumes: `assertPublicHttpUrl` / `fetchGuarded`（T1）；`selectCookiesForHost`（T2）；`renderUrl`（T3，动态 import）
- Produces:
  - `interface CrawlOptions { renderEnabled?: boolean; renderTimeoutMs?: number; cookies?: Record<string, string>; renderBudget?: { used: number; max: number }; render?: RenderFn }`
  - `type RenderFn = (url: string, o: { timeoutMs: number; cookies: Record<string, string> }) => Promise<string>`
  - `interface CrawlResult { url; text; chars; truncated; usedRender: boolean }`
  - `crawlUrl(raw: string, opts?: CrawlOptions): Promise<CrawlResult>`
  - `shouldRenderFallback(status: number, text: string): boolean`
  - `export const CRAWL_RENDER_MAX_PER_SESSION = 2`
  - `htmlToText` / `clearCrawlCache` 保持不变

- [ ] **Step 1: 改写既有 spec（先改测试，跑出 RED）**

把 `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts` **整体替换**为：

```ts
// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts
import { crawlUrl, htmlToText, shouldRenderFallback, clearCrawlCache } from './crawl-url';

// DNS 解析打桩：单测不触网（公网域名一律解析为公网地址）
jest.mock('node:dns/promises', () => ({
  lookup: jest.fn(async () => [{ address: '93.184.216.34' }]),
}));

function htmlResponse(body: string, contentType = 'text/html; charset=utf-8', headers: Record<string, string> = {}) {
  return new Response(body, { status: 200, headers: { 'Content-Type': contentType, ...headers } });
}

/** 足够长（≥ STATIC_MIN_CHARS=300）的正文，避免触发降级 */
const LONG_TEXT = '正'.repeat(400);
const longHtml = (extra = '') => `<body><p>${LONG_TEXT}</p>${extra}</body>`;

describe('htmlToText', () => {
  it('去噪：移除 script/style/注释，保留正文', () => {
    const html = `<html><head><style>a{color:red}</style></head><body>
      <!-- 注释 --><script>var a=1;</script><h1>标题</h1><p>第一段&amp;内容</p></body></html>`;
    const text = htmlToText(html);
    expect(text).toContain('标题');
    expect(text).toContain('第一段&内容');
    expect(text).not.toContain('color:red');
    expect(text).not.toContain('var a=1');
    expect(text).not.toContain('注释');
  });

  it('优先提取 article 区块', () => {
    const html = `<body><nav>导航项</nav><article><h2>正文标题</h2><p>正文内容</p></article><footer>页脚</footer></body>`;
    const text = htmlToText(html);
    expect(text).toContain('正文标题');
    expect(text).not.toContain('导航项');
  });
});

describe('shouldRenderFallback', () => {
  it('403 / 429 触发降级', () => {
    expect(shouldRenderFallback(403, '')).toBe(true);
    expect(shouldRenderFallback(429, '')).toBe(true);
  });
  it('正文不足 300 字触发降级', () => {
    expect(shouldRenderFallback(200, '短正文')).toBe(true);
  });
  it('正文足够时不降级', () => {
    expect(shouldRenderFallback(200, '正'.repeat(300))).toBe(false);
  });
});

describe('crawlUrl — 静态路径（渲染关闭，默认行为）', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
    delete process.env.RENDERER_WS_ENDPOINT;
  });

  it('抓取 HTML 并返回纯文本', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    const r = await crawlUrl('https://example.com/post');
    expect(r.text).toContain('正');
    expect(r.truncated).toBe(false);
    expect(r.usedRender).toBe(false);
    expect(r.chars).toBe(r.text.length);
  });

  it('超过 6000 字被截断并置 truncated', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(`<body><p>${'字'.repeat(8000)}</p></body>`));
    const r = await crawlUrl('https://example.com/long');
    expect(r.chars).toBe(6000);
    expect(r.truncated).toBe(true);
  });

  it('非网页类型被拒绝', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('%PDF-1.4', 'application/pdf'));
    await expect(crawlUrl('https://example.com/a.pdf')).rejects.toThrow('不是网页正文');
  });

  it('超大响应体被拒绝（Content-Length 声明）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml(), 'text/html', { 'Content-Length': String(2 * 1024 * 1024) }));
    await expect(crawlUrl('https://example.com/big')).rejects.toThrow('过大');
  });

  it('无 Content-Length 的超大响应被流式拒绝', async () => {
    const res = new Response('x'.repeat(2 * 1024 * 1024), { headers: { 'Content-Type': 'text/html' } });
    res.headers.delete('content-length');
    fetchMock.mockResolvedValueOnce(res);
    await expect(crawlUrl('https://example.com/big-stream')).rejects.toThrow('过大');
  });

  it('超时抛既有可读错误（文案不变）', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(crawlUrl('https://example.com/slow')).rejects.toThrow('抓取超时（8 秒），请换其他链接');
  });

  it('相同 URL 第二次命中缓存（不再发起 fetch）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/cached');
    await crawlUrl('https://example.com/cached');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('重定向到私网时拒绝（手动逐跳校验）', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'http://192.168.1.9/secret' } }));
    await expect(crawlUrl('https://example.com/redirect')).rejects.toThrow('目标地址位于内网');
  });

  it('裸 IP / 内网字面量直接拒绝', async () => {
    await expect(crawlUrl('http://192.168.1.10/x')).rejects.toThrow('目标地址位于内网');
    await expect(crawlUrl('http://8.8.8.8/x')).rejects.toThrow('不允许');
  });
});

describe('crawlUrl — 渲染降级', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
  });
  afterAll(() => {
    delete process.env.RENDERER_WS_ENDPOINT;
  });

  const opts = (render: jest.Mock, extra: Record<string, unknown> = {}) => ({
    renderEnabled: true,
    render,
    renderBudget: { used: 0, max: 2 },
    ...extra,
  });

  it('静态成功且正文充足 → 不调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    const render = jest.fn();
    const r = await crawlUrl('https://example.com/ok-1', opts(render));
    expect(render).not.toHaveBeenCalled();
    expect(r.usedRender).toBe(false);
  });

  it('静态 403 → 调用渲染并返回渲染正文', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const r = await crawlUrl('https://example.com/403-ok', opts(render));
    expect(render).toHaveBeenCalledTimes(1);
    expect(r.usedRender).toBe(true);
    expect(r.text).toContain('正');
  });

  it('静态正文不足 300 字 → 调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>太短</p></body>'));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const r = await crawlUrl('https://example.com/short-1', opts(render));
    expect(render).toHaveBeenCalledTimes(1);
    expect(r.usedRender).toBe(true);
  });

  it('开关关闭 → 不调用渲染，403 抛新文案', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(crawlUrl('https://example.com/403-off', { renderEnabled: false, render })).rejects.toThrow(
      '目标站点拒绝自动抓取（HTTP 403）',
    );
    expect(render).not.toHaveBeenCalled();
  });

  it('渲染抛错 + 静态有短正文 → 静默降级返回静态正文', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>短但可用</p></body>'));
    const render = jest.fn(async () => {
      throw new Error('渲染失败');
    });
    const r = await crawlUrl('https://example.com/short-fallback', opts(render));
    expect(r.text).toContain('短但可用');
    expect(r.usedRender).toBe(false);
  });

  it('渲染抛错 + 静态无正文（403）→ 403 文案追加「已尝试浏览器渲染」', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => {
      throw new Error('渲染失败');
    });
    await expect(crawlUrl('https://example.com/403-fail', opts(render))).rejects.toThrow('已尝试浏览器渲染仍未取到正文');
  });

  it('渲染成功但正文为空 → 动态加载/需登录文案', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>太短</p></body>'));
    const render = jest.fn(async () => '<html><head></head><body></body></html>');
    await expect(crawlUrl('https://example.com/empty-render', opts(render))).rejects.toThrow('脚本动态加载或需登录');
  });

  it('渲染预算耗尽 → 不再调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(
      crawlUrl('https://example.com/budget-out', { renderEnabled: true, render, renderBudget: { used: 2, max: 2 } }),
    ).rejects.toThrow('目标站点拒绝自动抓取（HTTP 403）');
    expect(render).not.toHaveBeenCalled();
  });

  it('渲染成功后预算计数 +1', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const budget = { used: 0, max: 2 };
    await crawlUrl('https://example.com/budget-count', { renderEnabled: true, render, renderBudget: budget });
    expect(budget.used).toBe(1);
  });

  it('RENDERER_WS_ENDPOINT 未配置 → 视为渲染不可用', async () => {
    delete process.env.RENDERER_WS_ENDPOINT;
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(crawlUrl('https://example.com/no-endpoint', opts(render))).rejects.toThrow('目标站点拒绝自动抓取（HTTP 403）');
    expect(render).not.toHaveBeenCalled();
  });

  it('静态带 cookie 按域发送；无匹配域名时不带 Cookie 头', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://www.zhihu.com/q/1', {
      cookies: { 'zhihu.com': 'z_c0=abc', 'other.com': 'y=1' },
    });
    const headers = (fetchMock.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
    expect(headers.Cookie).toBe('z_c0=abc');

    clearCrawlCache();
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/other', { cookies: { 'zhihu.com': 'z_c0=abc' } });
    const headers2 = (fetchMock.mock.calls[1][1] as RequestInit).headers as Record<string, string>;
    expect(headers2.Cookie).toBeUndefined();
  });

  it('静态请求使用浏览器伪装头', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/ua');
    const headers = (fetchMock.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
    expect(headers['User-Agent']).toContain('Mozilla/5.0');
    expect(headers['Accept-Language']).toContain('zh-CN');
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/crawl-url.spec.ts`
Expected: FAIL —— `shouldRenderFallback is not a function` / `usedRender` 断言失败

- [ ] **Step 3: 改造实现**

把 `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts` **整体替换**为：

```ts
// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts
// 网页正文抓取：静态优先，失败（403/429/正文过短）时降级到无头渲染。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第二节
//
// 安全：SSRF 守卫统一走 common/net/guarded-fetch（DNS 全量解析 + 逐跳校验）；
// 限体积（1MB）、超时（静态 8s / 渲染默认 20s）、限长度（6000 字）；
// cookie 按域名后缀匹配，无匹配则一份不发。

import { LruCache } from '../trend-research/lru-cache';
import { assertPublicHttpUrl, fetchGuarded } from '../../../common/net/guarded-fetch';
import { selectCookiesForHost } from '../cookie-crypto';

export interface CrawlResult {
  url: string;
  text: string;
  chars: number;
  truncated: boolean;
  /** 本次结果是否来自无头渲染 */
  usedRender: boolean;
}

/** 渲染实现签名（注入点，便于单测不启动 Chromium） */
export type RenderFn = (
  url: string,
  o: { timeoutMs: number; cookies: Record<string, string> },
) => Promise<string>;

export interface CrawlOptions {
  /** 静态失败时是否降级渲染；缺省 false → 纯静态 */
  renderEnabled?: boolean;
  /** 单次渲染超时；缺省 20000 */
  renderTimeoutMs?: number;
  /** 域名 → cookie 原始串（仅内存传递） */
  cookies?: Record<string, string>;
  /** 会话级渲染预算（同一工具会话内共享同一对象，跨多次 crawl 调用累计） */
  renderBudget?: { used: number; max: number };
  /** 渲染实现注入点；缺省用 tools/render-fetch.ts 的真实实现 */
  render?: RenderFn;
}

const CRAWL_TIMEOUT_MS = 8_000;
const MAX_BYTES = 1_048_576; // 1MB
const MAX_CHARS = 6_000;
/** 静态正文短于此值即认为「没拿到内容」，尝试渲染降级 */
const STATIC_MIN_CHARS = 300;
/** 单会话最多渲染次数（与 maxPerSession 配合控制最坏耗时；调优入口见后续优化登记） */
export const CRAWL_RENDER_MAX_PER_SESSION = 2;
const DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20_000;

/** 浏览器伪装头（静态与渲染共用；不伪造 Sec-Fetch-* / Referer——服务端发起时语义不成立） */
const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const ALLOWED_MIME = ['text/html', 'application/xhtml+xml', 'text/plain'];

/** 面向模型的可读错误文案（逐条单测断言，让模型能判断「该换来源了」） */
export const ERR_CRAWL_TIMEOUT = '抓取超时（8 秒），请换其他链接';
export const ERR_CRAWL_OTHER = '网站响应异常，请换其他来源';
export const ERR_CRAWL_RENDER_EMPTY = '该站内容由脚本动态加载或需登录，未取到正文，请换来源';
export const errCrawlBlocked = (status: number, rendered: boolean): string =>
  `目标站点拒绝自动抓取（HTTP ${status}），请改用搜索摘要或换其他来源${rendered ? '，已尝试浏览器渲染仍未取到正文' : ''}`;

/** 成功结果进程内缓存（key = 归一化 URL） */
const cache = new LruCache<CrawlResult>(100);

/** 块级标签 → 换行，保证段落不粘连 */
const BLOCK_TAGS =
  /<\/?(p|div|section|article|main|header|footer|li|ul|ol|h[1-6]|tr|td|th|table|thead|tbody|blockquote|br|hr|pre|figure|figcaption|aside|nav|address|dl|dt|dd)[^>]*>/gi;

/** HTML → 纯文本：去噪 → 提正文区块 → 去标签 → 解实体 → 压缩空白 */
export function htmlToText(html: string): string {
  let s = html
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<(script|style|noscript|svg|iframe|template|head)\b[\s\S]*?<\/\1>/gi, '');

  const body = s.match(/<article\b[\s\S]*?<\/article>/i)?.[0] ?? s.match(/<main\b[\s\S]*?<\/main>/i)?.[0];
  if (body) s = body;

  return s
    .replace(BLOCK_TAGS, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t\f\v]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** 流式读取响应体：逐块累计字节数，超 MAX_BYTES 立即中止并抛「过大」 */
async function readBodyWithinLimit(res: Response): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return res.text();
  const decoder = new TextDecoder();
  let text = '';
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    received += value.byteLength;
    if (received > MAX_BYTES) {
      await reader.cancel();
      throw new Error('网页内容过大（超过 1MB），已跳过');
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

/** 降级判定：403/429，或正文不足 STATIC_MIN_CHARS */
export function shouldRenderFallback(status: number, text: string): boolean {
  if (status === 403 || status === 429) return true;
  return text.length < STATIC_MIN_CHARS;
}

/** 伪装头 + 按域 cookie（无匹配则不带 Cookie） */
function buildStaticHeaders(cookies: Record<string, string>): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': BROWSER_UA,
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };
  const cookieHeader = Object.values(cookies).join('; ');
  if (cookieHeader) headers.Cookie = cookieHeader;
  return headers;
}

/** 静态阶段错误 → 可读文案（SSRF 守卫的既有可读错误原样透出） */
function mapStaticFetchError(err: unknown): Error {
  const msg = err instanceof Error ? err.message : '';
  if (msg === '抓取超时') return new Error(ERR_CRAWL_TIMEOUT);
  if (msg === '抓取失败（网络不可达）') return new Error('网页抓取失败，请换其他链接');
  if (msg.startsWith('重定向次数超出上限') || msg.startsWith('重定向缺少 location')) return new Error(ERR_CRAWL_OTHER);
  return err instanceof Error ? err : new Error(ERR_CRAWL_OTHER);
}

/** 裁剪 + 缓存 + 返回 */
function finalize(key: string, text: string, usedRender: boolean): CrawlResult {
  const truncated = text.length > MAX_CHARS;
  const clipped = truncated ? text.slice(0, MAX_CHARS) : text;
  const result: CrawlResult = { url: key, text: clipped, chars: clipped.length, truncated, usedRender };
  cache.set(key, result);
  return result;
}

/** 抓取网页正文；失败抛面向模型可读的 Error（由工具执行器转成 error 文本回填） */
export async function crawlUrl(raw: string, opts: CrawlOptions = {}): Promise<CrawlResult> {
  // 1. 统一 SSRF 守卫（DNS 全量解析）
  const url = await assertPublicHttpUrl(raw);
  const key = url.toString();

  // 2. 缓存
  const cached = cache.get(key);
  if (cached) return cached;

  const cookies = selectCookiesForHost(url.hostname, opts.cookies ?? {});

  // 3. 静态抓取（手动逐跳重定向 + 每跳校验）
  let res: Response;
  try {
    res = await fetchGuarded(key, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      accept: 'text/html,application/xhtml+xml,text/plain;q=0.9',
      headers: buildStaticHeaders(cookies),
    });
  } catch (err) {
    throw mapStaticFetchError(err);
  }

  const status = res.status;
  let staticText = '';
  let staticError: Error | null = null;

  // 4. 仅在 res.ok 时读体与判类型（403/429 的体是反爬壳，解析无价值）
  if (res.ok) {
    const mime = (res.headers.get('content-type') ?? '').toLowerCase();
    if (!ALLOWED_MIME.some((m) => mime.includes(m))) {
      throw new Error('该链接不是网页正文（类型不支持），请换其他链接');
    }
    const declared = Number(res.headers.get('content-length') ?? '0');
    if (Number.isFinite(declared) && declared > MAX_BYTES) {
      throw new Error('网页内容过大（超过 1MB），已跳过');
    }
    try {
      const rawBody = await readBodyWithinLimit(res);
      staticText = mime.includes('text/plain') ? rawBody.replace(/\s+/g, ' ').trim() : htmlToText(rawBody);
    } catch (err) {
      staticError = err instanceof Error ? err : new Error(ERR_CRAWL_OTHER);
    }
  }

  // 5. 降级判定
  if (!shouldRenderFallback(status, staticText)) return finalize(key, staticText, false);

  // 6. 渲染前提：开关开 + 预算未耗尽 + 端点已配置
  const budget = opts.renderBudget;
  const canRender =
    opts.renderEnabled === true && (!budget || budget.used < budget.max) && !!process.env.RENDERER_WS_ENDPOINT;

  let renderTried = false;
  let renderEmpty = false;
  if (canRender) {
    // 7. 记账（失败的尝试也计入预算，避免同一会话反复重试同一渲染）
    if (budget) budget.used += 1;
    renderTried = true;
    try {
      const render = opts.render ?? (await import('./render-fetch')).renderUrl;
      const html = await render(key, {
        timeoutMs: opts.renderTimeoutMs ?? DEFAULT_CRAWL_RENDER_TIMEOUT_MS,
        cookies,
      });
      const rendered = htmlToText(html);
      if (rendered) return finalize(key, rendered, true);
      renderEmpty = true;
    } catch {
      // 渲染不可用/失败 → 落到下面的错误优先级
    }
  }

  // 8. 错误优先级：静态短正文 → 403/429 → 渲染空正文 → 其余
  if (staticText) return finalize(key, staticText, false);
  if (status === 403 || status === 429) throw new Error(errCrawlBlocked(status, renderTried));
  if (renderEmpty) throw new Error(ERR_CRAWL_RENDER_EMPTY);
  throw staticError ?? new Error(ERR_CRAWL_OTHER);
}

/** 清空抓取缓存（测试用） */
export function clearCrawlCache(): void {
  cache.clear();
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/crawl-url.spec.ts`
Expected: PASS

- [ ] **Step 5: 类型检查**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json`
Expected: 恰 3 处既有错误，零新增（`text-tools.ts` 因 `CrawlResult` 新增必填字段 `usedRender` 仍可编译——它只是读 `r.usedRender`）。

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts
git commit -m "feat(backend): crawl_website 静态优先 + 无头渲染降级 + 统一 SSRF 守卫与按域 cookie"
```

---

### Task 5: `text-tools.ts` 透传配置与会话级渲染预算

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts`

**Interfaces:**
- Consumes: `CrawlOptions` / `CRAWL_RENDER_MAX_PER_SESSION`（T4）
- Produces:
  - `interface CrawlToolConfig { enabled: boolean; maxPerSession: number; renderEnabled?: boolean; renderTimeoutMs?: number; cookies?: Record<string, string> }`
  - `createToolExecutor(opts?: CrawlOptions, renderBudget?: { used: number; max: number }): TextToolContext['execute']`

- [ ] **Step 1: 扩展测试（先改测试，跑出 RED）**

在 `lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts` 末尾追加：

```ts
describe('createToolExecutor — 渲染配置透传', () => {
  beforeEach(() => crawlUrlMock.mockReset());

  it('把渲染配置与同一份 renderBudget 传给 crawlUrl', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: false });
    const budget = { used: 0, max: 2 };
    const exec = createToolExecutor(
      { renderEnabled: true, renderTimeoutMs: 15_000, cookies: { 'a.com': 'x=1' } },
      budget,
    );
    await exec(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(crawlUrlMock).toHaveBeenCalledWith('https://a.com', {
      renderEnabled: true,
      renderTimeoutMs: 15_000,
      cookies: { 'a.com': 'x=1' },
      renderBudget: budget,
    });
  });

  it('渲染命中时 resultBrief 追加「（渲染）」', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: true });
    const exec = createToolExecutor({}, { used: 0, max: 2 });
    await exec(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    // 断言不抛错即可（trace 被 mock 为 null，此处主要防回归）
    expect(crawlUrlMock).toHaveBeenCalledTimes(1);
  });

  it('crawlUrl 抛错时原样 rethrow（交由循环层回填 error）', async () => {
    crawlUrlMock.mockRejectedValueOnce(new Error('目标站点拒绝自动抓取（HTTP 403）'));
    await expect(createToolExecutor({}, { used: 0, max: 2 })(CRAWL_TOOL_NAME, '{"url":"https://a.com"}')).rejects.toThrow(
      '目标站点拒绝自动抓取',
    );
  });
});

describe('resolveTextTools — 渲染配置', () => {
  it('下发 renderEnabled / renderTimeoutMs / cookies，并为每次会话新建预算对象', () => {
    const cfg = {
      crawl: {
        enabled: true,
        maxPerSession: 3,
        renderEnabled: true,
        renderTimeoutMs: 12_000,
        cookies: { 'zhihu.com': 'z_c0=abc' },
      },
    };
    const a = resolveTextTools(cfg);
    const b = resolveTextTools(cfg);
    expect(a).toBeDefined();
    expect(b).toBeDefined();
    // 两个会话对象必须是不同实例（预算彼此独立）
    expect(a).not.toBe(b);
  });

  it('缺省不传渲染配置时 renderEnabled=false、cookies={}', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: false });
    const ctx = resolveTextTools({ crawl: { enabled: true, maxPerSession: 3 } });
    await ctx?.execute(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(crawlUrlMock).toHaveBeenCalledWith('https://a.com', {
      renderEnabled: false,
      renderTimeoutMs: undefined,
      cookies: {},
      renderBudget: { used: 0, max: 2 },
    });
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/text-tools.spec.ts`
Expected: FAIL —— `createToolExecutor` 收到 0 个参数断言不匹配

- [ ] **Step 3: 实现**

修改 `lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts`：

1. import 区改为：

```ts
import type { ToolDef } from '../llm-client';
import { traceCrawlCall } from '../llm-trace';
import { crawlUrl, CRAWL_RENDER_MAX_PER_SESSION } from './crawl-url';
import type { CrawlOptions } from './crawl-url';
import type { TextToolContext } from './text-tool-loop';
```

2. `CrawlToolConfig` 扩展：

```ts
export interface CrawlToolConfig {
  enabled: boolean;
  maxPerSession: number;
  /** 静态失败时是否降级到无头渲染；缺省 false */
  renderEnabled?: boolean;
  /** 单次渲染超时（毫秒）；缺省 20000 */
  renderTimeoutMs?: number;
  /** 按域隔离的 cookie（已在 ai-config 解密，仅内存传递） */
  cookies?: Record<string, string>;
}
```

3. `createToolExecutor` 整体替换为：

```ts
/** 工具执行器：把 crawlUrl 的异常留给循环层回填为 error 文本 */
export function createToolExecutor(
  opts: CrawlOptions = {},
  renderBudget?: { used: number; max: number },
): TextToolContext['execute'] {
  return async (name: string, argsJson: string): Promise<string> => {
    if (name !== CRAWL_TOOL_NAME) throw new Error(`未知工具：${name}`);
    const args = parseArgs(argsJson);
    const url = typeof args.url === 'string' ? args.url.trim() : '';
    if (!url) throw new Error('缺少 url 参数');

    const handle = traceCrawlCall({ url });
    try {
      const r = await crawlUrl(url, { ...opts, renderBudget });
      handle?.done(r.text.slice(0, 200), {
        resultBrief: `抓取 ${r.chars} 字${r.usedRender ? '（渲染）' : ''}${r.truncated ? '（已截断）' : ''}`,
      });
      return JSON.stringify({ url: r.url, text: r.text, truncated: r.truncated });
    } catch (err) {
      handle?.fail(err);
      throw err;
    }
  };
}
```

4. `resolveTextTools` 整体替换为：

```ts
/**
 * 开关入口：cfg.crawl.enabled !== true → undefined（文本调用退回旧行为）。
 * maxPerSession 夹紧到 1~6，防止后台异常值。
 * 每次调用新建独立的会话级渲染预算（跨本次工具会话内多次 crawl 调用累计）。
 */
export function resolveTextTools(cfg: { crawl?: CrawlToolConfig } | undefined | null): TextToolContext | undefined {
  const crawl = cfg?.crawl;
  if (!crawl?.enabled) return undefined;
  const raw = Math.floor(Number(crawl.maxPerSession));
  const maxToolCalls = Math.min(Math.max(Number.isFinite(raw) ? raw : MAX_TOOL_CALLS_LOWER, MAX_TOOL_CALLS_LOWER), MAX_TOOL_CALLS_UPPER);
  const renderBudget = { used: 0, max: CRAWL_RENDER_MAX_PER_SESSION };
  const execOpts: CrawlOptions = {
    renderEnabled: crawl.renderEnabled === true,
    renderTimeoutMs: crawl.renderTimeoutMs,
    cookies: crawl.cookies ?? {},
  };
  return { tools: [buildCrawlToolDef()], execute: createToolExecutor(execOpts, renderBudget), maxToolCalls };
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/tools/text-tools.spec.ts src/modules/ai/tools/text-tool-loop.spec.ts`
Expected: PASS（含既有用例）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts
git commit -m "feat(backend): 文本工具循环透传渲染配置与会话级渲染预算"
```

---

### Task 6: 配置层（迁移 050 / schema / DTO / `ai-config.service.ts`）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts`

**Interfaces:**
- Consumes: `encryptCookies` / `decryptCookies`（T2）
- Produces:
  - `AiConfigView` 新增 `crawlRenderEnabled: boolean`、`crawlRenderTimeoutMs: number`、`crawlCookieDomains: string[]`
  - `ActiveAiConfig.crawl` 扩展为 `{ enabled; maxPerSession; renderEnabled: boolean; renderTimeoutMs: number; cookies: Record<string, string> }`
  - `DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20_000`（模块内常量，导出以便测试）

- [ ] **Step 1: 写迁移**

创建 `lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql
-- AI 设置：网页爬取的无头渲染降级开关 / 超时 / 按域 cookie（加密存储）
-- 幂等：由 _migrations 表记录，仅执行一次；NOT NULL DEFAULT 保证存量行零数据迁移

ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_render_enabled` INT NOT NULL DEFAULT 0 COMMENT '爬取静态失败时是否降级到无头渲染：1=启用；0=关闭',
  ADD COLUMN `crawl_render_timeout_ms` INT NOT NULL DEFAULT 20000 COMMENT '单次无头渲染超时（毫秒，5000~60000）',
  ADD COLUMN `crawl_cookies` TEXT NULL COMMENT '按域名隔离的 cookie（JSON：{domain: cookieString}），AES-256-GCM 加密存储';
```

- [ ] **Step 2: 扩展 schema**

在 `lumira-server/packages/backend/src/database/schema.ts` 的 `crawlMaxPerSession`（L398）之后、`searchQwenBaseUrl`（L399）之前插入：

```ts
  /** 爬取静态失败时是否降级到无头渲染：1=启用；0=关闭 */
  crawlRenderEnabled: int('crawl_render_enabled').notNull().default(0),
  /** 单次无头渲染超时（毫秒，5000~60000） */
  crawlRenderTimeoutMs: int('crawl_render_timeout_ms').notNull().default(20_000),
  /** 按域名隔离的 cookie（JSON：{domain: cookieString}），AES-256-GCM 加密存储 */
  crawlCookies: text('crawl_cookies'),
```

同时在文件顶部的 drizzle 导入中加入 `text`（若尚未导入）。

- [ ] **Step 3: 扩展 DTO**

在 `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts` 的 `crawlMaxPerSession`（L240）之后、类结束 `}` 之前插入：

```ts
  /** 爬取静态失败时是否降级到无头渲染；缺省 = 沿用原值 */
  @IsOptional()
  @IsBoolean()
  crawlRenderEnabled?: boolean;

  /** 单次无头渲染超时（毫秒，5000~60000）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(5000)
  @Max(60000)
  crawlRenderTimeoutMs?: number;

  /**
   * 按域名隔离的 cookie（{domain: cookieString}）。
   * 语义：字段缺省 = 保留存量；传入对象 = 以该对象整体覆盖（传 {} 即清空全部域名 cookie）。
   * 值长度与域名合法性在 service 层校验；落库前加密。
   */
  @IsOptional()
  @IsObject()
  crawlCookies?: Record<string, string>;
```

并确认文件顶部已 import `IsObject`（`class-validator`）；若无则加入。

- [ ] **Step 4: 扩展 `ai-config.service.ts`**

1. import 区新增：

```ts
import { decryptCookies, encryptCookies } from './cookie-crypto';
```

2. `AiConfigView` 的 `crawlMaxPerSession`（L73）之后新增三个字段：

```ts
  /** 爬取静态失败时是否降级到无头渲染 */
  crawlRenderEnabled: boolean;
  /** 单次无头渲染超时（毫秒） */
  crawlRenderTimeoutMs: number;
  /** 已配置 cookie 的域名列表（只回显域名，绝不回传 cookie 值） */
  crawlCookieDomains: string[];
```

3. `ActiveAiConfig.crawl`（L121-125）扩展：

```ts
  /** 网页爬取工具（文本模型工具循环的开关、预算、渲染降级与按域 cookie） */
  crawl: {
    enabled: boolean;
    maxPerSession: number;
    /** 静态失败时是否降级到无头渲染 */
    renderEnabled: boolean;
    /** 单次无头渲染超时（毫秒） */
    renderTimeoutMs: number;
    /** 按域隔离的 cookie（已解密，仅内存存在） */
    cookies: Record<string, string>;
  };
```

4. 常量区（`DEFAULT_CRAWL_MAX_PER_SESSION` 之后）新增：

```ts
/** 无头渲染默认超时（与迁移 050 的 DEFAULT 一致） */
const DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20_000;
/** 无头渲染超时允许区间（毫秒） */
const CRAWL_RENDER_TIMEOUT_LOWER = 5_000;
const CRAWL_RENDER_TIMEOUT_UPPER = 60_000;
/** cookie 单值长度上限 */
const CRAWL_COOKIE_VALUE_MAX = 4096;
/** cookie 域名字面量（必须是带点的合法 hostname，如 zhihu.com） */
const CRAWL_COOKIE_DOMAIN_RE = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/i;
```

5. `get()` 的 `crawlMaxPerSession`（L247）之后新增：

```ts
      crawlRenderEnabled: row.crawlRenderEnabled === 1,
      crawlRenderTimeoutMs: row.crawlRenderTimeoutMs ?? DEFAULT_CRAWL_RENDER_TIMEOUT_MS,
      crawlCookieDomains: Object.keys(decryptCookies(row.crawlCookies)),
```

6. `save()` 中，在既有的 `crawlMaxPerSession` 计算（L336）之后新增：

```ts
    if (
      dto.crawlRenderTimeoutMs !== undefined &&
      (dto.crawlRenderTimeoutMs < CRAWL_RENDER_TIMEOUT_LOWER || dto.crawlRenderTimeoutMs > CRAWL_RENDER_TIMEOUT_UPPER)
    ) {
      throw new BadRequestException('无头渲染超时需在 5000~60000 毫秒之间');
    }
    if (dto.crawlCookies !== undefined) {
      for (const [domain, value] of Object.entries(dto.crawlCookies)) {
        if (!CRAWL_COOKIE_DOMAIN_RE.test(domain.trim())) {
          throw new BadRequestException(`cookie 域名非法：${domain}`);
        }
        if (typeof value !== 'string' || value.length > CRAWL_COOKIE_VALUE_MAX) {
          throw new BadRequestException(`cookie 值非法或过长（域名 ${domain}）`);
        }
      }
    }
    const crawlRenderEnabled = dto.crawlRenderEnabled === undefined ? (existing?.crawlRenderEnabled === 1 ? 1 : 0) : dto.crawlRenderEnabled ? 1 : 0;
    const crawlRenderTimeoutMs = dto.crawlRenderTimeoutMs ?? existing?.crawlRenderTimeoutMs ?? DEFAULT_CRAWL_RENDER_TIMEOUT_MS;
    // cookie：仅在显式传入时重写（加密后落库）；未传则保留存量
    let nextCrawlCookies: string | null = existing?.crawlCookies ?? null;
    if (dto.crawlCookies !== undefined) {
      try {
        nextCrawlCookies = encryptCookies(dto.crawlCookies);
      } catch (err) {
        throw new BadRequestException(err instanceof Error ? err.message : 'cookie 保存失败');
      }
    }
```

7. insert 分支：在 `crawlMaxPerSession,`（L405）之后插入：

```ts
        crawlRenderEnabled,
        crawlRenderTimeoutMs,
        crawlCookies: nextCrawlCookies,
```

8. update 分支：在 `crawlMaxPerSession,`（L452）之后插入：

```ts
          crawlRenderEnabled,
          crawlRenderTimeoutMs,
          crawlCookies: nextCrawlCookies,
```

9. `getActiveConfig()` 的 `crawl`（L675-678）替换为：

```ts
      crawl: {
        enabled: row.crawlEnabled === 1,
        maxPerSession: row.crawlMaxPerSession ?? DEFAULT_CRAWL_MAX_PER_SESSION,
        renderEnabled: row.crawlRenderEnabled === 1,
        renderTimeoutMs: row.crawlRenderTimeoutMs ?? DEFAULT_CRAWL_RENDER_TIMEOUT_MS,
        cookies: decryptCookies(row.crawlCookies),
      },
```

- [ ] **Step 5: 扩展配置测试**

在 `lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts` 的 `describe` 块内追加（保留既有 7 条用例，注意既有 `getActiveConfig()` 断言用的是 `toEqual`，须同步更新为含新字段的期望值）：

```ts
  it('get() 映射渲染开关 / 超时 / cookie 域名列表（只回显域名）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    const service = new AiConfigService(
      readonlyDb(row({ crawlRenderEnabled: 1, crawlRenderTimeoutMs: 12_000, crawlCookies: stored })),
    );
    const view = await service.get();
    expect(view).toMatchObject({
      crawlRenderEnabled: true,
      crawlRenderTimeoutMs: 12_000,
      crawlCookieDomains: ['zhihu.com'],
    });
    expect(JSON.stringify(view)).not.toContain('z_c0=abc');
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('get() 缺列 → 渲染关闭 / 默认 20000 / 无域名', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    expect(view).toMatchObject({ crawlRenderEnabled: false, crawlRenderTimeoutMs: 20_000, crawlCookieDomains: [] });
  });

  it('getActiveConfig() 暴露渲染配置（cookie 解密为明文映射）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    const service = new AiConfigService(readonlyDb(row({ crawlRenderEnabled: 1, crawlCookies: stored })));
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({
      enabled: false,
      maxPerSession: 3,
      renderEnabled: true,
      renderTimeoutMs: 20_000,
      cookies: { 'zhihu.com': 'z_c0=abc' },
    });
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 渲染超时越界 → 400', async () => {
    const { service } = writableDb(row());
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlRenderTimeoutMs: 1_000,
      } as never),
    ).rejects.toThrow('5000~60000');
  });

  it('save() cookie 落库值不是明文，且域名非法被拒', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { service, updateSet } = writableDb(row());
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
      crawlCookies: { 'zhihu.com': 'z_c0=abc' },
    } as never);
    const patch = updateSet.mock.calls[0][0] as Record<string, unknown>;
    expect(String(patch.crawlCookies)).toMatch(/^v1:/);
    expect(String(patch.crawlCookies)).not.toContain('z_c0=abc');

    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlCookies: { 'not a domain': 'x=1' },
      } as never),
    ).rejects.toThrow('cookie 域名非法');

    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 未配置密钥时保存 cookie → 400（绝不落明文）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    delete process.env.CRAWL_COOKIE_SECRET;
    const { service, updateSet } = writableDb(row());
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlCookies: { 'zhihu.com': 'z_c0=abc' },
      } as never),
    ).rejects.toThrow('未配置 CRAWL_COOKIE_SECRET');
    expect(updateSet).not.toHaveBeenCalled();
    if (secret !== undefined) process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 未传 cookie → 保留存量', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' }) as string;
    const { service, updateSet } = writableDb(row({ crawlCookies: stored }));
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
    });
    const patch = updateSet.mock.calls[0][0] as Record<string, unknown>;
    expect(patch.crawlCookies).toBe(stored);
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });
```

**同时必须更新既有断言**（否则会 RED）：
- `getActiveConfig() 暴露 crawl 配置`：`toEqual({ enabled: true, maxPerSession: 5 })` → `toEqual({ enabled: true, maxPerSession: 5, renderEnabled: false, renderTimeoutMs: 20_000, cookies: {} })`
- `getActiveConfig() 缺列 → crawl 默认关闭、上限 3`：同理补三个新字段的默认值
- `save() 更新未传 crawl 字段 → 保留存量值`：`toHaveBeenCalledWith(expect.objectContaining({ crawlEnabled: 1, crawlMaxPerSession: 5 }))` 需追加 `crawlRenderEnabled: 0, crawlRenderTimeoutMs: 20_000, crawlCookies: null`
- `save() 首次保存缺 crawl 字段 → insert 收到默认值`：追加 `crawlRenderEnabled: 0, crawlRenderTimeoutMs: 20_000, crawlCookies: null`

- [ ] **Step 6: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest src/modules/ai/ai-config`
Expected: PASS（`ai-config.crawl.spec.ts` + `ai-config.service.spec.ts`；若 `ai-config.service.spec.ts` 有 `toEqual` 全量快照式断言，同样按 Step 5 的方式补齐新字段）

- [ ] **Step 7: 类型检查 + 全量回归**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json`
Expected: 恰 3 处既有错误

Run: `pnpm --filter @lumira/backend test`
Expected: 通过数 = 635 + 本计划新增用例数；**0 failed**；skipped 仍为 3

- [ ] **Step 8: Commit 并推送两远端（后端改动，按 AGENTS.md 必须推送）**

```bash
git add lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts
git commit -m "feat(backend): AI 配置新增无头渲染开关/超时与按域 cookie（迁移 050）"
git push origin master
git push github master
```

---

### Task 7: 启动告警 + 部署产物

**Files:**
- Create: `deploy/renderer/Dockerfile`
- Modify: `deploy/docker-compose.prod.yml`
- Modify: `lumira-server/packages/backend/src/main.ts`
- Modify: `lumira-server/packages/backend/.env.example`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: `process.env.RENDERER_WS_ENDPOINT` / `process.env.CRAWL_COOKIE_SECRET`
- Produces: compose 服务 `lumira-renderer`、网络 `renderer-net`、backend 环境变量 `RENDERER_WS_ENDPOINT`

- [ ] **Step 1: 创建渲染容器 Dockerfile**

创建 `deploy/renderer/Dockerfile`（注意：ENTRYPOINT 必须写成**单行** JSON 数组，Dockerfile 的 JSON 形式不支持 `\` 换行续写）：

```dockerfile
# =============================================================================
# Lumira 无头渲染容器
# =============================================================================
# 只提供 Chromium 的 CDP 端点（--remote-debugging-port=9222），不含任何业务代码。
# 后端（lumira-backend）经 renderer-net 用 ws://lumira-renderer:9222 连接
# （puppeteer-core.connect），页面级请求拦截与 SSRF 判定全部在后端 TS 侧完成。
#
# 不用 ghcr.io 的现成渲染镜像：开源版不含 stealth/CAPTCHA，且镜像 3.6GB。
# 本镜像走 Debian 官方源（阿里云镜像加速），约 400MB。
FROM debian:bookworm-slim

# 切换为阿里云 Debian 镜像源（与后端 Dockerfile 同写法；|| true 兼容 deb822 与旧格式）
# chromium：无头浏览器本体；fonts-noto-cjk / fonts-wqy-zenhei：中文页面渲染字体；
# fontconfig：字体缓存；ca-certificates：HTTPS 站点证书；curl：仅供 HEALTHCHECK。
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources || true \
    && sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         chromium fonts-noto-cjk fonts-wqy-zenhei fontconfig ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# --no-sandbox 是容器内的必需取舍（否则需要 SYS_ADMIN 权限），作为残余风险记录在
# 设计文档第一节；渲染目标由后端在 CDP 请求拦截层做私网拦截。
ENTRYPOINT ["chromium", "--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--no-first-run", "--remote-debugging-address=0.0.0.0", "--remote-debugging-port=9222", "--user-data-dir=/tmp/chrome"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=20s \
  CMD curl -f http://127.0.0.1:9222/json/version || exit 1
```

- [ ] **Step 2: 更新 compose**

修改 `deploy/docker-compose.prod.yml`：

1. 文件头注释的环境变量清单（L13-23）追加两行：

```
#   CRAWL_COOKIE_SECRET=...   （可空，网页爬取 cookie 的 AES-256-GCM 密钥，64 位 hex；
#                              未配置时后台无法保存 cookie，渲染降级不受影响）
#   RENDERER_WS_ENDPOINT      （由本文件注入，无需在 .env 维护；
#                              未配置时爬取的渲染降级自动关闭）
```

2. `lumira-backend` 的 `environment`（L86 之后）追加：

```yaml
      # 无头渲染容器 CDP 端点（renderer-net 内部地址，不暴露到宿主机）
      - RENDERER_WS_ENDPOINT=ws://lumira-renderer:9222
```

3. `lumira-backend` 的 `networks`（L89-90）追加 `renderer-net`：

```yaml
    networks:
      - lumira-net
      - renderer-net
```

4. 在 `lumira-searxng` 服务块（L125）之后新增：

```yaml
  # ---- 无头渲染服务（2026-09-28，网页爬取静态失败时降级）----
  # 只提供 Chromium CDP 端点，不暴露端口到宿主机。
  # 网络隔离意图：只入 renderer-net，因此访问不到 lumira-mysql；
  # backend 同时接入两网（渲染期页面若访问 lumira-backend，会被后端 DNS 私网判定拦下）。
  lumira-renderer:
    build:
      context: ./repo/deploy/renderer
      dockerfile: Dockerfile
    image: lumira-renderer:latest
    restart: always
    # Chromium 需要足够的共享内存（官方建议 shm_size 至少 1g，否则易崩）
    shm_size: "1g"
    networks:
      - renderer-net
```

5. `networks` 段（L127-134）追加：

```yaml
  # 渲染专用网络：由 compose 创建（非 external），backend 与 renderer 各接入
  renderer-net:
    driver: bridge
```

- [ ] **Step 3: 启动告警**

修改 `lumira-server/packages/backend/src/main.ts`，在 production fail-fast 块（L23）之后、`async function bootstrap()` 之前插入：

```ts
// 渲染降级能力需要 renderer 容器的 CDP 端点（docker-compose 注入）。
// 未配置时该能力自动关闭——显式告警，避免运营在后台开了开关却「以为开了」。
if (!process.env.RENDERER_WS_ENDPOINT) {
  console.warn("WARN: RENDERER_WS_ENDPOINT 未配置，网页爬取的无头渲染降级已关闭（crawlRenderEnabled 开关不会生效）");
}
```

- [ ] **Step 4: 补 `.env.example`**

在 `lumira-server/packages/backend/.env.example` 末尾追加：

```

# 网页爬取 cookie 的加密密钥（64 位 hex = 32 字节；生成：openssl rand -hex 32）
# 未配置时后台保存 cookie 会返回 400（绝不落明文）；纯静态抓取与渲染降级不受影响
CRAWL_COOKIE_SECRET=

# 无头渲染容器 CDP 端点（生产由 docker-compose 注入 ws://lumira-renderer:9222）
# 未配置时「静态失败降级到无头渲染」自动关闭
RENDERER_WS_ENDPOINT=
```

- [ ] **Step 5: 更新 AGENTS.md 部署章节**

在 `AGENTS.md` 的「服务器 `.env` 必填变量」表格之后追加一段：

```markdown
**服务器 `.env` 可选变量（网页爬取渲染降级）**：

| 变量                    | 说明                                                                        |
| --------------------- | ------------------------------------------------------------------------- |
| `CRAWL_COOKIE_SECRET` | 网页爬取 cookie 的 AES-256-GCM 密钥（`openssl rand -hex 32`）。未配置时后台保存 cookie 返回 400，纯静态抓取不受影响 |
| `RENDERER_WS_ENDPOINT` | 由 `deploy/docker-compose.prod.yml` 注入（`ws://lumira-renderer:9222`），无需在服务器 `.env` 手动维护 |

> ⚠️ 首次部署（或 renderer 镜像有改动）时必须用 `docker compose -f docker-compose.prod.yml --env-file .env up -d --build`，以便构建 `lumira-renderer` 镜像；仅 `up -d` 不会构建新服务。
```

- [ ] **Step 6: 校验 compose 语法**

Run（`cwd` = `e:\Project\photo_post`）: `docker compose -f deploy/docker-compose.prod.yml config --quiet`
Expected: 无输出（语法合法）。若本机无 docker 或缺 `.env` 变量导致校验失败，记录该事实并在 T9 的人工验收清单中标注（**不得伪造通过结论**）。

- [ ] **Step 7: 类型检查 + 全量测试**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json`
Expected: 恰 3 处既有错误

Run: `pnpm --filter @lumira/backend test`
Expected: 0 failed

- [ ] **Step 8: Commit 并推送两远端**

```bash
git add deploy/renderer/Dockerfile deploy/docker-compose.prod.yml lumira-server/packages/backend/src/main.ts lumira-server/packages/backend/.env.example AGENTS.md
git commit -m "chore(deploy): 新增无头渲染容器与 renderer-net，后端注入 CDP 端点并启动告警"
git push origin master
git push github master
```

---

### Task 8: 后台表单与类型

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`

**Interfaces:**
- Consumes: 后端 `AiConfigView.crawlRenderEnabled` / `crawlRenderTimeoutMs` / `crawlCookieDomains`（T6）
- Produces: 后台可读写「渲染降级开关 + 超时 + 域名/cookie 行列表」

- [ ] **Step 1: 扩展类型**

`lumira-server/packages/admin/src/types/admin.ts`：

1. 视图定义（`crawlMaxPerSession` L457 之后）追加：

```ts
  /** 爬取静态失败时是否降级到无头渲染 */
  crawlRenderEnabled: boolean;
  /** 单次无头渲染超时（毫秒，5000~60000） */
  crawlRenderTimeoutMs: number;
  /** 已配置 cookie 的域名列表（只回显域名，值不回传） */
  crawlCookieDomains: string[];
```

2. 载荷定义（`crawlMaxPerSession` L531 之后）追加：

```ts
  /** 是否降级到无头渲染；缺省 = 沿用原值 */
  crawlRenderEnabled?: boolean;
  /** 无头渲染超时（毫秒，5000~60000）；缺省 = 沿用原值 */
  crawlRenderTimeoutMs?: number;
  /** 按域名隔离的 cookie；缺省 = 保留存量，传入对象 = 整体覆盖 */
  crawlCookies?: Record<string, string>;
```

- [ ] **Step 2: 扩展表单状态**

`lumira-server/packages/admin/src/components/ai-config-form.tsx`：

1. `FormState`（L98 之后）追加：

```ts
  crawlRenderEnabled: boolean;
  crawlRenderTimeoutMs: number;
  /** 域名 / cookie 行列表（value 留空 = 沿用存量） */
  crawlCookies: Array<{ domain: string; value: string }>;
```

2. configured 初始化分支（L226 之后）追加：

```ts
          crawlRenderEnabled: initial.crawlRenderEnabled ?? false,
          crawlRenderTimeoutMs: initial.crawlRenderTimeoutMs ?? 20000,
          crawlCookies: (initial.crawlCookieDomains ?? []).map((d) => ({ domain: d, value: '' })),
```

3. 非 configured 分支（L258 之后）追加：

```ts
          crawlRenderEnabled: false,
          crawlRenderTimeoutMs: 20000,
          crawlCookies: [],
```

4. 载荷组装（L525 之后）追加：

```ts
      payload.crawlRenderEnabled = form.crawlRenderEnabled;
      payload.crawlRenderTimeoutMs = Number(form.crawlRenderTimeoutMs) || 20000;
      // 只提交填了值的行（value 留空 = 沿用存量）；一行都没填则不发该字段（保留存量）
      const filledCookies = Object.fromEntries(
        form.crawlCookies
          .map((r) => ({ domain: r.domain.trim(), value: r.value.trim() }))
          .filter((r) => r.domain && r.value)
          .map((r) => [r.domain, r.value]),
      );
      if (Object.keys(filledCookies).length > 0) payload.crawlCookies = filledCookies;
```

5. UI：把 L1160-1197 的「网页爬取」`Card` 内、`单会话次数上限` 的 `<div className="space-y-2 md:max-w-xs">`（L1180-1196）之后追加：

```tsx
            <div className="flex items-center justify-between">
              <label htmlFor="ai-crawl-render-enabled" className="text-sm font-medium text-foreground">
                静态抓取失败时用无头浏览器渲染
              </label>
              <Switch
                id="ai-crawl-render-enabled"
                checked={form.crawlRenderEnabled}
                disabled={!form.webCrawl}
                onCheckedChange={(v) => setForm((f) => ({ ...f, crawlRenderEnabled: v }))}
              />
            </div>
            <p className="text-xs text-muted-foreground">
              需后端配置 RENDERER_WS_ENDPOINT 才生效；关闭时仅做静态抓取。
            </p>

            <div className="space-y-2 md:max-w-xs">
              <Label htmlFor="ai-crawl-render-timeout">渲染超时（毫秒）</Label>
              <Input
                id="ai-crawl-render-timeout"
                type="number"
                min={5000}
                max={60000}
                value={form.crawlRenderTimeoutMs}
                disabled={!form.webCrawl || !form.crawlRenderEnabled}
                onChange={(e) => setForm((f) => ({ ...f, crawlRenderTimeoutMs: Number(e.target.value) || 20000 }))}
              />
              <p className="text-xs text-muted-foreground">5000~60000，默认 20000。</p>
            </div>

            <div className="space-y-2">
              <Label>登录态 Cookie（按域名隔离）</Label>
              <p className="text-xs text-muted-foreground">
                仅对匹配的域名发送（含其子域）。保存后只显示域名，值不会回传；值留空 = 沿用已保存的值。
              </p>
              {form.crawlCookies.map((row, i) => (
                <div key={i} className="flex gap-2">
                  <Input
                    placeholder="zhihu.com"
                    value={row.domain}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        crawlCookies: f.crawlCookies.map((r, j) => (j === i ? { ...r, domain: e.target.value } : r)),
                      }))
                    }
                  />
                  <Input
                    type="password"
                    placeholder="z_c0=..."
                    value={row.value}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        crawlCookies: f.crawlCookies.map((r, j) => (j === i ? { ...r, value: e.target.value } : r)),
                      }))
                    }
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => setForm((f) => ({ ...f, crawlCookies: f.crawlCookies.filter((_, j) => j !== i) }))}
                  >
                    删除
                  </Button>
                </div>
              ))}
              <Button
                type="button"
                variant="outline"
                onClick={() => setForm((f) => ({ ...f, crawlCookies: [...f.crawlCookies, { domain: '', value: '' }] }))}
              >
                添加域名 Cookie
              </Button>
            </div>
```

> `Button` 已在该文件使用（勿重复 import）。若某些行没填值，则该域名不会被提交（保留存量语义）。

- [ ] **Step 3: 构建验证（后台用 Next.js 构建做类型与编译校验）**

Run（`cwd` = `e:\Project\photo_post\lumira-server`）: `pnpm --filter @lumira/admin build`
Expected: 构建成功，无 TS 错误。

- [ ] **Step 4: Commit 并推送两远端**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(admin): AI 设置新增渲染降级开关/超时与按域 cookie 维护"
git push origin master
git push github master
```

---

### Task 9: 后续优化登记 + 全量验收

**Files:**
- Modify: `docs/future-optimizations.md`

- [ ] **Step 1: 登记后续优化项**

在 `docs/future-optimizations.md` 的 `## AI 文本模型通用工具循环 + 网页爬取（2026-09-28）` 一节末尾（P7 之后）追加：

```markdown
### P8 · 渲染次数上限为常量，未做成后台可配

- **模块**：后端 AI 爬取工具（`lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts` 的 `CRAWL_RENDER_MAX_PER_SESSION = 2`）
- **优化点**：单会话渲染次数固定为 2，未开放为配置列，运营无法按站点调整。
- **背景/动机**：`maxPerSession`（默认 3）配合 20s 渲染超时，最坏会把单次会话拖到 60s+；本轮先固定常量以避免新增配置面。
- **目标状态**：与渲染超时一起并入「网页爬取」配置卡片，并在后端做「次数 × 超时 ≤ 会话总预算」的联合夹紧。
- **状态**：⏳ 待优化

### P9 · 渲染容器以 `--no-sandbox` 运行

- **模块**：部署（`deploy/renderer/Dockerfile`）
- **优化点**：容器内 Chromium 以 `--no-sandbox` 启动（否则需要 `SYS_ADMIN`），削弱了浏览器自身的进程隔离。
- **背景/动机**：渲染容器只入 `renderer-net`，且渲染目标由后端在 CDP 请求拦截层做 DNS 私网拦截，因此本轮接受该取舍。
- **目标状态**：评估改用自带用户命名空间的 seccomp/AppArmor profile，或在宿主机层面为渲染容器单独收紧权限。
- **状态**：⏳ 待优化

### P10 · renderer 与 backend 同处 renderer-net（renderer 可反向访问 backend）

- **模块**：部署（`deploy/docker-compose.prod.yml` 的 `renderer-net`）
- **优化点**：backend 需接入 `renderer-net` 才能连 CDP，因此 renderer 容器理论上可访问 `lumira-backend:3000`。
- **背景/动机**：缓解手段是渲染期的 CDP 请求拦截——`lumira-backend` 解析到 Docker 私网地址会被私网判定拦下；但这是「拦截」而非「网络不可达」。
- **目标状态**：评估用 Docker 网络 + iptables 规则（或 egress 策略）在 renderer 出方向上显式阻断到 `lumira-*` 网段的流量，做到网络层不可达。
- **状态**：⏳ 待优化

### P11 · 后台 cookie 只能新增/覆盖，无法单独清空

- **模块**：后台（`lumira-server/packages/admin/src/components/ai-config-form.tsx`）
- **优化点**：表单只在「至少一行填了值」时才提交 `crawlCookies`，因此「删掉所有行并保存」不会清空已保存的域名 cookie；后端 API 传 `{}` 才能清空。
- **背景/动机**：值不回传（只回显域名）导致「留空 = 沿用」与「留空 = 清空」语义冲突，本轮先保证「不会误清空」这一安全侧。
- **目标状态**：为每个域名行提供显式的「清除」动作，提交一个包含域名但值为空的对象（后端按 `{}` 语义处理），或在表单侧维护「已删除域名」集合并拼出最终对象。
- **状态**：⏳ 待优化

### P12 · 渲染 cookie 注入为尽力而为，无回读校验

- **模块**：后端渲染驱动（`lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts`）
- **优化点**：`page.setCookie` 仅按 `{name, value, domain, path:'/'}` 设置，未回读校验是否被浏览器接受，也未处理 `HttpOnly`/`Secure`/`SameSite` 等属性的差异；部分站点可能因属性缺失而不认会话。
- **背景/动机**：cookie 原始串不携带属性（后台只保存字符串），无法还原属性；本轮以求链路可跑通为先。
- **目标状态**：支持按域名保存结构化 cookie（含属性），渲染后回读 `page.cookies()` 做校验，并在失败时给出「cookie 未被接受」的可读提示。
- **状态**：⏳ 待优化

### P13 · 渲染降级无 trace 级成功率观测

- **模块**：后端 AI（`lumira-server/packages/backend/src/modules/ai/llm-trace.ts` 与 `tools/crawl-url.ts`）
- **优化点**：渲染命中仅在既有 `traceCrawlCall` 的 `resultBrief` 里追加「（渲染）」后缀，没有独立的成功/失败计数，无法在后台面板回答「渲染到底救回了多少页面」。
- **背景/动机**：本轮明确不新增 trace 事件类型（避免改动后台流程面板渲染层）。
- **目标状态**：在后台流程面板增加「网页爬取」聚合统计（静态命中 / 渲染命中 / 渲染失败 / 403 未取到），用于评估 renderer 的投入产出。
- **状态**：⏳ 待优化
```

- [ ] **Step 2: 全量回归（必须逐条给出真实输出）**

Run（`cwd` = `e:\Project\photo_post\lumira-server`）: `pnpm --filter @lumira/backend test`
Expected: 0 failed；passed = 635 + 本计划新增用例数；skipped = 3

Run（`cwd` = `e:\Project\photo_post\lumira-server`）: `pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json`
Expected: 恰 3 处既有错误

Run（`cwd` = `e:\Project\photo_post\lumira-server`）: `pnpm --filter @lumira/admin build`
Expected: 成功

- [ ] **Step 3: 人工验收清单（写入最终汇报，未验证项必须标注「未验证」）**

以下**无法在本地自动化验证**，需真实环境确认；不得声称已验证：

1. `docker compose -f deploy/docker-compose.prod.yml --env-file .env up -d --build` 能成功构建 `lumira-renderer` 镜像并启动（本机无 docker 时标注未验证）。
2. `curl -s http://<服务器>:9222/json/version` 不可从宿主机访问（未暴露端口）。
3. 在服务器 `.env` 配置 `CRAWL_COOKIE_SECRET` 后，后台能保存 cookie 并在刷新后只看到域名。
4. 实测 `crawl_website('https://www.zhihu.com/question/xxxx')`：静态 403 → 渲染降级 → 若带有效 cookie 能取到正文；取不到时应返回可读文案而**不卡死**。
5. 关掉「静态抓取失败时用无头浏览器渲染」开关后，403 站点返回可读文案，且不发起渲染。

- [ ] **Step 4: Commit（纯文档，是否推送由用户决定）**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记网页爬取渲染降级的 6 条后续优化项"
```

---

## Self-Review 记录

- **Spec 覆盖**：spec 第一~十二节逐条映射到 T1（SSRF 统一）、T2（cookie 加密/作用域）、T3（渲染容器驱动）、T4（静态优先 + 降级 + 错误优先级）、T5（预算透传）、T6（开关/配置/迁移 050）、T7（容器与 compose、启动告警）、T8（后台）、T9（可观测留观测缺口登记 + 验收）。spec 第八节「不新增 trace 事件类型」由 T5 的 `resultBrief` 追加「（渲染）」落实，观测缺口登记为 P13。
- **占位符扫描**：无 TBD / TODO / 「类似 Task N」；每个代码步骤均给出完整代码。
- **类型一致性**：`CrawlOptions` / `CrawlResult.usedRender` / `RenderFn` / `CRAWL_RENDER_MAX_PER_SESSION` / `selectCookiesForHost` / `assertPublicHttpUrl(raw, deps?)` / `fetchGuarded(url, { timeoutMs, accept?, headers?, lookup? })` / `encryptCookies` / `decryptCookies` / `crawlRenderTimeoutMs` / `crawlCookieDomains` 在各 Task 间命名一致。
- **已知与 spec 的两处显式偏差**（见 Global Constraints）：状态码插值、`res.ok` 门控读体。均在计划内显式声明，且不改变 spec 的目标与验收口径。