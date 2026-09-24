// src/components/thumb-image.tsx
// 带兜底的缩略图 <img>：主 URL 为存储域名直连（写入时预生成），加载失败
// （旧数据尚未预生成会 404）时自动回退后端动态端点按需生成，命中即修复。
'use client';

import { useState } from 'react';

export function ThumbImage({
  src,
  fallbackSrc,
  alt,
  className,
}: {
  src: string;
  fallbackSrc?: string | null;
  alt: string;
  className?: string;
}) {
  const [current, setCurrent] = useState(src);
  const [usedFallback, setUsedFallback] = useState(false);

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={current}
      alt={alt}
      loading="lazy"
      decoding="async"
      className={className}
      onError={() => {
        const fb = fallbackSrc;
        if (!usedFallback && fb && fb !== current) {
          setUsedFallback(true);
          setCurrent(fb);
        }
      }}
    />
  );
}
