'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

interface PhonePreviewProps {
  coverUrl: string | null;
  silhouetteUrl: string | null;
  positionX: number;
  positionY: number;
  scale: number;
  rotation: number;
  aspectRatio: string;
  overlayType: string;
  opacity: number;
  cropRatio: string;
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

function getAspectRatioPadding(ratio: string): string {
  const map: Record<string, string> = {
    '3:4': 'pb-[133.33%]',
    '4:3': 'pb-[75%]',
    '16:9': 'pb-[56.25%]',
    '1:1': 'pb-[100%]',
    '9:16': 'pb-[177.78%]',
  };
  return map[ratio] || 'pb-[133.33%]';
}

function getAspectRatioLabel(ratio: string): string {
  const map: Record<string, string> = {
    '3:4': '竖屏 3:4',
    '4:3': '横屏 4:3',
    '16:9': '宽屏 16:9',
    '1:1': '方形 1:1',
    '9:16': '全屏 9:16',
  };
  return map[ratio] || ratio;
}

function OverlayGrid({ type, opacity }: { type: string; opacity: number }) {
  if (type === 'none' || !type) return null;

  return (
    <div
      className="absolute inset-0 pointer-events-none"
      style={{ opacity }}
    >
      {type === 'rule_of_thirds' && (
        <>
          <div className="absolute left-[33.33%] top-0 bottom-0 border-l border-white/50" />
          <div className="absolute left-[66.66%] top-0 bottom-0 border-l border-white/50" />
          <div className="absolute top-[33.33%] left-0 right-0 border-t border-white/50" />
          <div className="absolute top-[66.66%] left-0 right-0 border-t border-white/50" />
        </>
      )}
      {type === 'golden_ratio' && (
        <>
          <div className="absolute left-[38.2%] top-0 bottom-0 border-l border-yellow-400/60" />
          <div className="absolute left-[61.8%] top-0 bottom-0 border-l border-yellow-400/60" />
          <div className="absolute top-[38.2%] left-0 right-0 border-t border-yellow-400/60" />
          <div className="absolute top-[61.8%] left-0 right-0 border-t border-yellow-400/60" />
        </>
      )}
      {type === 'diagonal' && (
        <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          <line x1="0" y1="0" x2="100" y2="100" stroke="white" strokeWidth="0.5" opacity={0.6} />
          <line x1="100" y1="0" x2="0" y2="100" stroke="white" strokeWidth="0.5" opacity={0.6} />
        </svg>
      )}
      {type === 'grid' && (
        <>
          <div className="absolute left-[25%] top-0 bottom-0 border-l border-white/40" />
          <div className="absolute left-[50%] top-0 bottom-0 border-l border-white/40" />
          <div className="absolute left-[75%] top-0 bottom-0 border-l border-white/40" />
          <div className="absolute top-[25%] left-0 right-0 border-t border-white/40" />
          <div className="absolute top-[50%] left-0 right-0 border-t border-white/40" />
          <div className="absolute top-[75%] left-0 right-0 border-t border-white/40" />
        </>
      )}
      {type === 'leading_lines' && (
        <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
          <line x1="10" y1="0" x2="50" y2="100" stroke="white" strokeWidth="0.5" opacity={0.4} />
          <line x1="90" y1="0" x2="50" y2="100" stroke="white" strokeWidth="0.5" opacity={0.4} />
          <line x1="0" y1="30" x2="100" y2="70" stroke="white" strokeWidth="0.5" opacity={0.3} />
        </svg>
      )}
      {type === 'center' && (
        <>
          <div className="absolute left-1/2 top-0 bottom-0 border-l border-white/50" style={{ transform: 'translateX(-50%)' }} />
          <div className="absolute top-1/2 left-0 right-0 border-t border-white/50" style={{ transform: 'translateY(-50%)' }} />
          <div className="absolute left-1/2 top-1/2 w-8 h-8 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white/60" />
        </>
      )}
    </div>
  );
}

function getLutLabel(lut: string): string {
  const map: Record<string, string> = {
    none: '无滤镜',
    cinematic: '🎬 电影',
    vintage: '📷 复古',
    bw: '⚫ 黑白',
    warm_film: '🌅 暖调胶片',
    cool_film: '🌊 冷调胶片',
    pastel: '🌸 柔和',
    fuji: '📸 富士',
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

function getFlashLabel(f: string): string {
  const map: Record<string, string> = {
    off: '关闭',
    on: '开启',
    auto: '自动',
    torch: '手电筒',
  };
  return map[f] || f;
}

function getFocusLabel(f: string): string {
  const map: Record<string, string> = {
    auto: '自动对焦',
    manual: '手动对焦',
    continuous: '连续对焦',
  };
  return map[f] || f;
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

export default function PhonePreview({
  coverUrl,
  silhouetteUrl,
  positionX,
  positionY,
  scale,
  rotation,
  aspectRatio,
  overlayType,
  opacity,
  cropRatio,
  lut,
  colorBrightness,
  colorContrast,
  colorSaturation,
  colorTemperature,
  colorTint,
  smoothStrength,
  sharpen,
  vignette,
  grain,
  exposureCompensation,
  isoMode,
  iso,
  shutterSpeed,
  whiteBalance,
  flashMode,
  focusMode,
  lensSuggestion,
  name,
  className,
}: PhonePreviewProps) {
  const filterStyle = React.useMemo(() => {
    const filters: string[] = [];
    if (colorBrightness !== 0) filters.push(`brightness(${1 + colorBrightness / 100})`);
    if (colorContrast !== 0) filters.push(`contrast(${1 + colorContrast / 100})`);
    if (colorSaturation !== 0) filters.push(`saturate(${1 + colorSaturation / 100})`);
    if (colorTemperature !== 0) {
      const temp = colorTemperature / 100;
      filters.push(`sepia(${Math.abs(temp) * 0.3})`);
    }
    if (colorTint !== 0) {
      const tint = colorTint / 100;
      filters.push(`hue-rotate(${tint * 30}deg)`);
    }
    return filters.join(' ');
  }, [colorBrightness, colorContrast, colorSaturation, colorTemperature, colorTint]);

  const hasEffects = smoothStrength > 0 || sharpen > 0 || vignette > 0 || grain > 0;

  return (
    <div className={cn('flex flex-col items-center', className)}>
      <div className="w-full max-w-[280px]">
        <div className="relative rounded-[2.5rem] border-[3px] border-border bg-background shadow-xl overflow-hidden">
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-1/3 h-6 bg-black rounded-b-2xl z-20" />
          <div className={cn('relative', getAspectRatioPadding(cropRatio || aspectRatio))}>
            <div className="absolute inset-0 bg-muted flex items-center justify-center overflow-hidden rounded-[2.3rem]">
              {coverUrl ? (
                <img
                  src={coverUrl}
                  alt="封面"
                  className="absolute inset-0 w-full h-full object-cover"
                  style={{ filter: filterStyle || undefined }}
                />
              ) : (
                <div className="text-center text-muted-foreground/40">
                  <svg className="w-12 h-12 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" />
                  </svg>
                  <p className="text-xs">未选择封面</p>
                </div>
              )}

              {silhouetteUrl && (
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                  <div
                    style={{
                      transform: `translate(${(positionX - 0.5) * 100}%, ${(positionY - 0.5) * 100}%) scale(${scale}) rotate(${rotation}deg)`,
                    }}
                  >
                    <img
                      src={silhouetteUrl}
                      alt="剪影"
                      className="max-w-[80%] max-h-[80%] object-contain"
                      draggable={false}
                    />
                  </div>
                </div>
              )}

              <OverlayGrid type={overlayType} opacity={opacity} />
            </div>
          </div>
        </div>

        <div className="mt-3 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground truncate max-w-[60%]">
              {name || '未命名模板'}
            </span>
            <span className="text-[10px] text-muted-foreground/60 bg-muted px-1.5 py-0.5 rounded">
              {getAspectRatioLabel(cropRatio || aspectRatio)}
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
    </div>
  );
}