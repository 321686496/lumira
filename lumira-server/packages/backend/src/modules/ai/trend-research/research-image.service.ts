// lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.ts
// 参考图抓取编排（spec 5.1~5.4）：三层递进（条目自带图 → 页面 og:image → 图片搜索兜底），
// 并发 3、整体软预算 20s、URL + 内容双哈希去重、任何失败静默降级不阻断识别。
// 另负责落盘图片的 TTL 清理（启动兜底 + 每小时一次）。

import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import {
  DEFAULT_RESEARCH_IMAGES_CONFIG,
  RESEARCH_IMAGE_CONCURRENCY,
  RESEARCH_IMAGE_PAGE_TIMEOUT_MS,
  RESEARCH_IMAGE_TOTAL_BUDGET_MS,
} from './research-image';
import type {
  ImageCandidate,
  ResearchImage,
  ResearchImagesConfig,
  ResearchImagesResult,
} from './research-image';
import type { ResearchItem } from './research-item';
import { extractPageImages, extractPageImageUrl, extractPageText, fetchImageSafely, fetchPageHtml } from './research-image-fetch';
import { cleanupResearchImages, hashBuffer, hashUrl, readResearchImage, writeResearchImage } from './research-image-store';

const logger = new Logger('ResearchImageService');
/** 定时清理间隔：每小时 */
const CLEANUP_INTERVAL_MS = 3600 * 1000;

/** 有界并发执行器（保持输入顺序无关，仅限制在跑数量） */
async function runPool<T>(items: T[], limit: number, worker: (item: T) => Promise<void>): Promise<void> {
  let cursor = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    for (;;) {
      const idx = cursor;
      cursor += 1;
      if (idx >= items.length) return;
      await worker(items[idx]);
    }
  });
  await Promise.all(runners);
}

/** 取 URL 的域名（失败回退为原串） */
function hostOf(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

@Injectable()
export class ResearchImageService implements OnModuleInit, OnModuleDestroy {
  /** 测试可替换：下载一张图（默认走 SSRF 受控抓取） */
  fetchImage: (url: string) => Promise<{ buffer: Buffer; mime: string }> = fetchImageSafely;
  /** 测试可替换：抓页面 HTML */
  fetchPage: (url: string, timeoutMs: number) => Promise<string> = fetchPageHtml;

  private timer?: ReturnType<typeof setInterval>;

  constructor(private readonly aiConfigService: AiConfigService) {}

  /** 启动兜底清扫 + 每小时 TTL 清理（不引入 @nestjs/schedule） */
  async onModuleInit(): Promise<void> {
    await this.sweep();
    this.timer = setInterval(() => void this.sweep(), CLEANUP_INTERVAL_MS);
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** 按配置 TTL 清扫过期图片；配置读取失败用默认 7 天 */
  private async sweep(): Promise<void> {
    try {
      const cfg = await this.aiConfigService.getSearchConfig?.();
      // 参考图配置由后续任务合并进搜索配置，此处对 images 做类型安全兜底读取
      const ttl = (cfg as { images?: { ttlDays?: number } } | null | undefined)?.images?.ttlDays
        ?? DEFAULT_RESEARCH_IMAGES_CONFIG.ttlDays;
      const removed = await cleanupResearchImages(ttl);
      if (removed) logger.log(`清理过期参考图 ${removed} 张（TTL ${ttl} 天）`);
    } catch {
      // 清理失败不影响服务
    }
  }

  /** 读回落盘图片 → base64（多模态解读用） */
  async readBase64(id: string): Promise<{ base64: string; mime: string } | null> {
    const buf = await readResearchImage(id);
    if (!buf) return null;
    return { base64: buf.toString('base64'), mime: 'image/jpeg' };
  }

  /**
   * 三层递进抓取参考图（检索链路专用；用户显式参考页面走 collectUserPage）。
   * - items：检索命中条目（第一层用 imgUrl、第二层用 url 抓页面）
   * - queries：本次检索词（第三层图片搜索用第一组）
   * - imagesSearch：第三层图片搜索（由 TrendResearchService 注入；缺省则该层跳过）
   */
  async collect(input: {
    items: ResearchItem[];
    queries: string[];
    imagesSearch?: ((query: string) => Promise<ResearchItem[]>) | null;
    cfg: ResearchImagesConfig;
    now?: () => number;
  }): Promise<ResearchImagesResult> {
    const { items, queries, imagesSearch } = input;
    const cfg = input.cfg;
    const now = input.now ?? Date.now;
    const images: ResearchImage[] = [];
    const errors: { name: string; error: string }[] = [];
    const startedAt = now();
    const overBudget = (): boolean => now() - startedAt > RESEARCH_IMAGE_TOTAL_BUDGET_MS;

    /** 已处理的 URL 哈希（跨层去重） */
    const seenUrl = new Set<string>();
    /** 已落盘的内容哈希（同图不同 URL 去重） */
    const seenContent = new Set<string>();

    /** 处理一批候选：逐张下载 → 压缩落盘 → 计入结果；返回是否达到 max */
    const drain = async (candidates: ImageCandidate[]): Promise<boolean> => {
      const pending: ImageCandidate[] = [];
      for (const c of candidates) {
        const key = hashUrl(c.sourceUrl);
        if (seenUrl.has(key)) continue;
        seenUrl.add(key);
        pending.push(c);
        if (images.length + pending.length >= cfg.max) break;
      }
      await runPool(pending, RESEARCH_IMAGE_CONCURRENCY, async (c) => {
        if (images.length >= cfg.max || overBudget()) return;
        try {
          const { buffer } = await this.fetchImage(c.sourceUrl);
          const contentKey = hashBuffer(buffer);
          if (seenContent.has(contentKey)) return;
          seenContent.add(contentKey);
          const id = contentKey;
          const written = await writeResearchImage(id, buffer);
          if (!written) return; // 尺寸不达标：静默跳过
          images.push({
            id,
            url: written.url,
            sourceUrl: c.sourceUrl,
            pageUrl: c.pageUrl,
            source: c.source,
            query: c.query,
            layer: c.layer,
            width: written.width,
            height: written.height,
            bytes: written.bytes,
          });
        } catch {
          // SSRF / MIME / 体积 / 超时 / 落盘失败：丢弃该候选，静默继续
        }
      });
      return images.length >= cfg.max;
    };

    // ===== 第一层：检索条目自带图 =====
    const l1: ImageCandidate[] = items
      .filter((it) => typeof it.imgUrl === 'string' && /^https?:\/\//i.test(it.imgUrl))
      .map((it) => ({
        sourceUrl: it.imgUrl as string,
        pageUrl: it.url,
        source: it.source,
        query: queries[0],
        layer: 'metadata' as const,
      }));
    if (l1.length && (await drain(l1))) return { images, errors };

    // ===== 第二层：抓命中页面 og:image =====
    if (cfg.pageFetch && !overBudget()) {
      const pages = items.filter((it) => typeof it.url === 'string' && /^https?:\/\//i.test(it.url ?? ''));
      await runPool(pages, RESEARCH_IMAGE_CONCURRENCY, async (it) => {
        if (images.length >= cfg.max || overBudget()) return;
        const pageUrl = it.url as string;
        try {
          const html = await this.fetchPage(pageUrl, RESEARCH_IMAGE_PAGE_TIMEOUT_MS);
          const imgUrl = extractPageImageUrl(html, pageUrl);
          if (!imgUrl) return;
          const key = hashUrl(imgUrl);
          if (seenUrl.has(key)) return;
          seenUrl.add(key);
          const { buffer } = await this.fetchImage(imgUrl);
          const contentKey = hashBuffer(buffer);
          if (seenContent.has(contentKey)) return;
          seenContent.add(contentKey);
          const written = await writeResearchImage(contentKey, buffer);
          if (!written) return;
          images.push({
            id: contentKey,
            url: written.url,
            sourceUrl: imgUrl,
            pageUrl,
            source: it.source,
            query: queries[0],
            layer: 'page',
            width: written.width,
            height: written.height,
            bytes: written.bytes,
          });
        } catch (err) {
          errors.push({ name: hostOf(pageUrl), error: err instanceof Error ? err.message : String(err) });
        }
      });
    }
    if (images.length >= cfg.max) return { images, errors };

    // ===== 第三层：图片搜索兜底 =====
    if (cfg.searchFallback && imagesSearch && queries[0] && !overBudget()) {
      try {
        const hits = await imagesSearch(queries[0]);
        const l3: ImageCandidate[] = hits
          .filter((it) => typeof it.imgUrl === 'string' && /^https?:\/\//i.test(it.imgUrl))
          .map((it) => ({
            sourceUrl: it.imgUrl as string,
            pageUrl: it.url,
            source: it.source,
            query: queries[0],
            layer: 'image-search' as const,
          }));
        await drain(l3);
      } catch (err) {
        errors.push({ name: 'image-search', error: err instanceof Error ? err.message : String(err) });
      }
    }

    return { images, errors };
  }

  /**
   * 确定性抓取「用户显式参考页面」（创作要求里直接给的 URL，不受 search/images 开关限制）：
   * 逐页提取正文文本 → 组装 ResearchItem；整页解析候选图（og/twitter/JSON-LD/正文 img）
   * → 下载落盘 → ResearchImage。沿用 URL + 内容双哈希去重与 max 截断，任何失败静默跳过。
   */
  async collectUserPage(input: {
    urls: string[];
    max?: number;
    now?: () => number;
  }): Promise<{
    items: ResearchItem[];
    images: ResearchImage[];
    errors: { name: string; error: string }[];
  }> {
    const urls = input.urls ?? [];
    const max = input.max ?? DEFAULT_RESEARCH_IMAGES_CONFIG.max;
    const now = input.now ?? Date.now;
    const items: ResearchItem[] = [];
    const images: ResearchImage[] = [];
    const errors: { name: string; error: string }[] = [];
    const startedAt = now();
    const overBudget = (): boolean => now() - startedAt > RESEARCH_IMAGE_TOTAL_BUDGET_MS;

    /** 已处理的 URL 哈希（跨页/跨图去重） */
    const seenUrl = new Set<string>();
    /** 已落盘的内容哈希（同图不同 URL 去重） */
    const seenContent = new Set<string>();

    await runPool(urls, RESEARCH_IMAGE_CONCURRENCY, async (pageUrl) => {
      if (overBudget()) return;
      const pageKey = hashUrl(pageUrl);
      if (seenUrl.has(pageKey)) return;
      seenUrl.add(pageKey);
      try {
        const html = await this.fetchPage(pageUrl, RESEARCH_IMAGE_PAGE_TIMEOUT_MS);
        const { title, text } = extractPageText(html, pageUrl);
        if (text.trim()) {
          items.push({
            source: 'user-reference',
            title: title || pageUrl,
            snippet: text.trim(),
            keywords: [],
            url: pageUrl,
          });
        }
        const imgUrls = extractPageImages(html, pageUrl, max - images.length);
        for (const imgUrl of imgUrls) {
          if (images.length >= max || overBudget()) return;
          const key = hashUrl(imgUrl);
          if (seenUrl.has(key)) continue;
          seenUrl.add(key);
          try {
            const { buffer } = await this.fetchImage(imgUrl);
            const contentKey = hashBuffer(buffer);
            if (seenContent.has(contentKey)) continue;
            seenContent.add(contentKey);
            const written = await writeResearchImage(contentKey, buffer);
            if (!written) continue;
            images.push({
              id: contentKey,
              url: written.url,
              sourceUrl: imgUrl,
              pageUrl,
              source: 'user-reference',
              layer: 'user-reference',
              width: written.width,
              height: written.height,
              bytes: written.bytes,
            });
          } catch {
            // 单张下载失败：继续下一张候选
          }
        }
      } catch (err) {
        errors.push({ name: hostOf(pageUrl), error: err instanceof Error ? err.message : String(err) });
      }
    });

    return { items, images, errors };
  }
}
