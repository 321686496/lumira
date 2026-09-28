// 参考图缩略图网格：来源域名 / 命中检索词 / 「已采用」徽标 / 点击看大图 / 加载失败占位。
'use client';

import { useState } from 'react';
import type { AiTraceImage } from '@/types/admin';
import { cn } from '@/lib/utils';

/** 从 URL 取域名用于展示 */
function hostOf(url?: string): string {
  if (!url) return '';
  try {
    return new URL(url).hostname;
  } catch {
    return '';
  }
}

export function TraceImageGrid({
  images,
  adoptedImageIds,
  className,
}: {
  images: AiTraceImage[];
  adoptedImageIds?: string[];
  className?: string;
}) {
  const [preview, setPreview] = useState<AiTraceImage | null>(null);
  if (!images.length) return null;
  const adopted = new Set(adoptedImageIds ?? []);

  return (
    <div className={cn('space-y-2', className)}>
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-6">
        {images.map((img) => {
          const isAdopted = adopted.has(img.id);
          const host = hostOf(img.pageUrl ?? img.sourceUrl);
          return (
            <button
              key={img.id}
              type="button"
              onClick={() => setPreview(img)}
              className={cn(
                'group relative overflow-hidden rounded-md border bg-muted text-left',
                isAdopted ? 'border-primary ring-1 ring-primary/40' : 'border-border',
              )}
              title={img.sourceUrl ?? img.url}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={img.url}
                alt={img.query ?? '参考图'}
                loading="lazy"
                className="h-20 w-full object-cover transition-transform group-hover:scale-105"
              />
              {isAdopted ? (
                <span className="absolute left-1 top-1 rounded bg-primary px-1 py-0.5 text-[10px] font-medium text-primary-foreground">
                  已采用
                </span>
              ) : null}
              <span className="block truncate px-1 py-0.5 text-[10px] text-muted-foreground">
                {host}
                {img.query ? ` · ${img.query}` : ''}
              </span>
            </button>
          );
        })}
      </div>

      {preview ? (
        <div
          role="presentation"
          onClick={() => setPreview(null)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={preview.url} alt={preview.query ?? '参考图'} className="max-h-[80vh] max-w-[90vw] object-contain" />
        </div>
      ) : null}
    </div>
  );
}
