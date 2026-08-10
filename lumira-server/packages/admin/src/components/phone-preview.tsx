'use client';

import * as React from 'react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import IphoneFrame from '@/components/iphone-frame';
import CompositionGrid from '@/components/composition-grid';
import { renderTemplateImage } from '@/lib/template-effects';

interface PhonePreviewProps {
  coverUrl: string | null;
  silhouetteUrl: string | null;
  silhouetteType: string;
  silhouetteBuiltinKey: string;
  positionX: number;
  positionY: number;
  scale: number;
  rotation: number;
  aspectRatio: string;
  cropRatio: string;
  overlayType: string;
  opacity: number;
  lut: string;
  colorBrightness: number;
  colorContrast: number;
  colorSaturation: number;
  colorTemperature: number;
  colorTint: number;
  smoothStrength: number;
  sharpen: number;
  vignette: number;
  grain: number;
  exposureCompensation: number;
  isoMode: string;
  iso: number;
  shutterSpeed: string;
  whiteBalance: string;
  flashMode: string;
  focusMode: string;
  lensSuggestion: string;
  name: string;
  className?: string;
}

/** 竖屏手机屏幕比例（19.5:9），与 IphoneFrame 一致，模拟真机全屏取景 */
const PHONE_SCREEN_RATIO = 393 / 852;

/**
 * 解析比例字符串 → 宽高比。与 App 端 parseAspectRatio / computeTargetRatio 一致：
 * - 'fullscreen' → 手机屏幕比例（App 全屏取景 = 设备屏幕比例）
 * - '4:3' → 3/4（竖屏手机自适应，与 App computeTargetRatio 竖屏行为一致）
 * - 其余 'W:H' 按字面解析（如 '3:4' → 0.75、'9:16' → 9/16）
 * - 'free'/'none'/无法解析返回 null（调用方回退）
 */
function parseRatio(s: string): number | null {
  if (!s) return null;
  const v = s.trim().toLowerCase();
  if (v === 'fullscreen') return PHONE_SCREEN_RATIO;
  if (v === '4:3') return 3 / 4;
  if (v === 'free' || v === 'none') return null;
  const parts = v.split(':');
  const w = parseFloat(parts[0]);
  const h = parseFloat(parts[1]);
  if (!w || !h) return null;
  return w / h;
}

function getAspectRatioLabel(ratio: string): string {
  const map: Record<string, string> = {
    '3:4': '竖屏 3:4',
    '4:3': '横屏 4:3',
    '16:9': '宽屏 16:9',
    '1:1': '方形 1:1',
    '9:16': '全屏 9:16',
    fullscreen: '全屏',
    free: '自由',
    none: '无裁剪',
  };
  return map[ratio] || ratio;
}

function getLutLabel(lut: string): string {
  const map: Record<string, string> = {
    none: '原图',
    cinematic: '电影感',
    vintage: '复古胶片',
    bw: '黑白',
    warm_film: '暖色胶片',
    cool_film: '冷色胶片',
    pastel: '柔色',
    fuji: '富士感',
    portrait: '人像',
    japanese: '日系',
    cyberpunk: '赛博朋克',
    sepia_classic: '褐调',
    mist: '薄雾',
    rouge: '胭脂',
    twilight: '暮光',
    cyan: '青调',
  };
  return map[lut] || lut;
}

function getWhiteBalanceLabel(wb: string): string {
  const map: Record<string, string> = {
    daylight: '日光',
    cloudy: '阴天',
    shade: '阴影',
    tungsten: '白炽灯',
    fluorescent: '荧光灯',
    custom: '自定义',
  };
  return map[wb] || wb;
}

function getLensLabel(l: string): string {
  const map: Record<string, string> = {
    wide: '广角',
    main: '主摄',
    telephoto: '长焦',
    ultra_wide: '超广角',
  };
  return map[l] || l;
}

/** 内置剪影占位图标（与 App Icon(Icons.person_outline) 一致） */
function PersonOutline({ color }: { color: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={1.6} className="w-full h-full">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 20c0-3.5 3.6-6 8-6s8 2.5 8 6" />
    </svg>
  );
}

export default function PhonePreview(props: PhonePreviewProps) {
  const {
    coverUrl, silhouetteUrl, silhouetteType, silhouetteBuiltinKey,
    positionX, positionY, scale, rotation,
    aspectRatio, cropRatio, overlayType, opacity,
    lut, colorBrightness, colorContrast, colorSaturation, colorTemperature, colorTint,
    smoothStrength, sharpen, vignette, grain,
    exposureCompensation, isoMode, iso, shutterSpeed, whiteBalance,
    flashMode, focusMode, lensSuggestion, name, className,
  } = props;

  const areaRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [areaSize, setAreaSize] = useState<{ w: number; h: number } | null>(null);
  const [coverImg, setCoverImg] = useState<HTMLImageElement | null>(null);

  // 与 App 拍摄页真机取景一致：取景比例 = 模板 postProcess.cropRatio
  // （App capture_page 在模板切换时将 aspectRatioProvider 同步为 cropRatio），
  // cropRatio 为空时回退 composition.aspectRatio。
  // 剪影 position.x/y 相对该取景比例框定位（x:0,y:0 = 比例框左上角）。
  const effectiveRatio = cropRatio || aspectRatio;
  const ratio = useMemo(() => {
    const r = parseRatio(effectiveRatio);
    return r ?? 0.75;
  }, [effectiveRatio]);

  // 监听图片区尺寸
  useEffect(() => {
    const el = areaRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) {
        setAreaSize({ w: entry.contentRect.width, h: entry.contentRect.height });
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // 加载封面图
  useEffect(() => {
    if (!coverUrl) {
      setCoverImg(null);
      return;
    }
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => setCoverImg(img);
    img.onerror = () => setCoverImg(null);
    img.src = coverUrl;
    return () => {
      img.onload = null;
      img.onerror = null;
    };
  }, [coverUrl]);

  // 渲染效果到 canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !coverImg || !areaSize || areaSize.w === 0 || areaSize.h === 0) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const backingW = Math.round(areaSize.w * dpr);
    const backingH = Math.round(areaSize.h * dpr);
    renderTemplateImage(canvas, coverImg, {
      width: backingW,
      height: backingH,
      effects: {
        color: {
          brightness: colorBrightness,
          contrast: colorContrast,
          saturation: colorSaturation,
          temperature: colorTemperature,
          tint: colorTint,
        },
        lut,
        smoothStrength,
        sharpen,
        vignette,
        grain,
      },
    });
  }, [coverImg, areaSize, colorBrightness, colorContrast, colorSaturation, colorTemperature, colorTint, lut, smoothStrength, sharpen, vignette, grain]);

  const hasEffects = smoothStrength > 0 || sharpen > 0 || vignette > 0 || grain > 0;
  const hasSilhouette = silhouetteUrl
    || (silhouetteType === 'builtin' && silhouetteBuiltinKey && silhouetteBuiltinKey !== 'none');

  return (
    <div className={cn('flex flex-col items-center', className)}>
      <IphoneFrame width={240}>
        <div className="absolute inset-0 flex items-center justify-center bg-black">
          <div
            ref={areaRef}
            className="relative overflow-hidden bg-black"
            style={{ width: '100%', aspectRatio: String(ratio) }}
          >
            {/* 封面 + 后期效果（Canvas） */}
            <canvas ref={canvasRef} className="absolute inset-0 w-full h-full" />

            {/* 剪影叠加（不受滤镜影响，与 App 层序一致） */}
            {hasSilhouette && (
              <div className="absolute inset-0 pointer-events-none">
                <div
                  className="absolute"
                  style={{
                    left: `${positionX * 100}%`,
                    top: `${positionY * 100}%`,
                    width: '40%',
                    aspectRatio: '1 / 1.6',
                    transform: `translate(-50%, -50%) scale(${scale}) rotate(${rotation}deg)`,
                  }}
                >
                  {silhouetteUrl ? (
                    <img
                      src={silhouetteUrl}
                      alt="剪影"
                      className="w-full h-full object-contain"
                      draggable={false}
                    />
                  ) : (
                    <PersonOutline color="rgba(255,255,255,0.85)" />
                  )}
                </div>
              </div>
            )}

            {/* 构图网格叠加（不受滤镜影响，与 App 层序一致） */}
            <CompositionGrid type={overlayType} opacity={opacity} />
          </div>
        </div>
      </IphoneFrame>

      <div className="mt-4 w-[240px] space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium text-muted-foreground truncate max-w-[60%]">
            {name || '未命名模板'}
          </span>
          <span className="text-[10px] text-muted-foreground/60 bg-muted px-1.5 py-0.5 rounded">
            {getAspectRatioLabel(effectiveRatio)}
          </span>
        </div>

        <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-[11px]">
          {lut !== 'none' && (
            <div className="flex items-center gap-1.5">
              <span className="text-muted-foreground/60">滤镜</span>
              <span className="font-medium">{getLutLabel(lut)}</span>
            </div>
          )}
          <div className="flex items-center gap-1.5">
            <span className="text-muted-foreground/60">曝光</span>
            <span className="font-medium">{exposureCompensation > 0 ? '+' : ''}{exposureCompensation}EV</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-muted-foreground/60">ISO</span>
            <span className="font-medium">{isoMode === 'auto' ? '自动' : iso}</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-muted-foreground/60">快门</span>
            <span className="font-medium">{shutterSpeed}</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-muted-foreground/60">白平衡</span>
            <span className="font-medium truncate">{getWhiteBalanceLabel(whiteBalance)}</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-muted-foreground/60">镜头</span>
            <span className="font-medium">{getLensLabel(lensSuggestion)}</span>
          </div>
        </div>

        {(hasEffects || overlayType !== 'none') && (
          <div className="flex flex-wrap gap-1">
            {overlayType !== 'none' && (
              <span className="text-[10px] bg-primary/10 text-primary px-1.5 py-0.5 rounded">
                构图: {overlayType}
              </span>
            )}
            {smoothStrength > 0 && (
              <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded">平滑 {smoothStrength}</span>
            )}
            {sharpen > 0 && (
              <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded">锐化 {sharpen}</span>
            )}
            {vignette > 0 && (
              <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded">暗角 {vignette}</span>
            )}
            {grain > 0 && (
              <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded">颗粒 {grain}</span>
            )}
          </div>
        )}
      </div>
    </div>
  );
}