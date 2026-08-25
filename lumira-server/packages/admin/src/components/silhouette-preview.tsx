'use client';

import * as React from 'react';
import { MagnifyingGlassPlus } from '@phosphor-icons/react/dist/csr/MagnifyingGlassPlus';
import { cn } from '@/lib/utils';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogTitle,
} from '@/components/ui/dialog';
import IphoneFrame from '@/components/iphone-frame';

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

interface SilhouettePreviewProps {
  silhouetteUrl: string | null;
  positionX: number;
  positionY: number;
  scale: number;
  rotation: number;
  aspectRatio: string;
  cropRatio?: string;
  onPositionChange: (x: number, y: number) => void;
  onScaleChange: (scale: number) => void;
  onRotationChange: (rotation: number) => void;
  className?: string;
}

export default function SilhouettePreview({
  silhouetteUrl,
  positionX,
  positionY,
  scale,
  rotation,
  aspectRatio,
  cropRatio,
  onPositionChange,
  onScaleChange,
  onRotationChange,
  className,
}: SilhouettePreviewProps) {
  const areaRef = React.useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = React.useState(false);
  const [lightboxOpen, setLightboxOpen] = React.useState(false);
  const dragStart = React.useRef({ x: 0, y: 0, posX: 0, posY: 0 });

  // 与 App 拍摄页真机取景一致：取景比例 = 模板 postProcess.cropRatio
  // （App capture_page 在模板切换时将 aspectRatioProvider 同步为 cropRatio），
  // cropRatio 为空时回退 composition.aspectRatio。
  // 剪影 position.x/y 相对该取景比例框定位（x:0,y:0 = 比例框左上角）。
  const effectiveRatio = cropRatio || aspectRatio;
  const ratio = React.useMemo(() => {
    const r = parseRatio(effectiveRatio);
    return r ?? 0.75;
  }, [effectiveRatio]);

  const handleMouseDown = (e: React.MouseEvent) => {
    if (!silhouetteUrl) return;
    e.preventDefault();
    setIsDragging(true);
    dragStart.current = {
      x: e.clientX,
      y: e.clientY,
      posX: positionX,
      posY: positionY,
    };
  };

  const handleMouseMove = React.useCallback(
    (e: MouseEvent) => {
      if (!isDragging || !areaRef.current) return;
      const rect = areaRef.current.getBoundingClientRect();
      const dx = (e.clientX - dragStart.current.x) / rect.width;
      const dy = (e.clientY - dragStart.current.y) / rect.height;
      const newX = Math.max(0, Math.min(1, dragStart.current.posX + dx));
      const newY = Math.max(0, Math.min(1, dragStart.current.posY + dy));
      onPositionChange(newX, newY);
    },
    [isDragging, onPositionChange],
  );

  const handleMouseUp = React.useCallback(() => {
    setIsDragging(false);
  }, []);

  React.useEffect(() => {
    if (!isDragging) return;
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, handleMouseMove, handleMouseUp]);

  return (
    <div className={cn('space-y-4', className)}>
      <Label>剪影预览（可拖动调整位置）</Label>
      <div className="flex justify-center">
        <IphoneFrame width={240}>
          <div className="absolute inset-0 flex items-center justify-center bg-black">
            <div
              ref={areaRef}
              className="relative overflow-hidden bg-[#14151a]"
              style={{ width: '100%', aspectRatio: String(ratio) }}
            >
              {/* 占位网格背景 */}
              <div className="absolute inset-0 opacity-20">
                <div className="absolute left-1/2 top-0 bottom-0 border-l border-white/30" />
                <div className="absolute top-1/2 left-0 right-0 border-t border-white/30" />
              </div>

              <div className="absolute inset-0 flex items-center justify-center">
                <div className="text-center text-muted-foreground/30 pointer-events-none">
                  <p className="text-[10px]">取景区域 {effectiveRatio}</p>
                </div>
              </div>

              {silhouetteUrl && (
                <div
                  className={cn(
                    'absolute inset-0',
                    isDragging ? 'cursor-grabbing' : 'cursor-grab',
                  )}
                  onMouseDown={handleMouseDown}
                  style={{ touchAction: 'none' }}
                >
                  <div
                    className="absolute"
                    style={{
                      left: `${positionX * 100}%`,
                      top: `${positionY * 100}%`,
                      width: '40%',
                      aspectRatio: '1 / 1.6',
                      transform: `translate(-50%, -50%) scale(${scale}) rotate(${rotation}deg)`,
                      transition: isDragging ? 'none' : 'transform 0.15s ease-out',
                    }}
                  >
                    <img
                      src={silhouetteUrl}
                      alt="剪影"
                      className="w-full h-full object-contain pointer-events-none"
                      draggable={false}
                    />
                  </div>
                </div>
              )}
            </div>
          </div>

          {silhouetteUrl && (
            <Button
              type="button"
              variant="secondary"
              size="icon"
              className="absolute top-8 right-2 h-7 w-7 opacity-70 hover:opacity-100 z-10"
              onClick={(e) => {
                e.stopPropagation();
                setLightboxOpen(true);
              }}
            >
              <MagnifyingGlassPlus size={14} />
            </Button>
          )}
        </IphoneFrame>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground">位置 X ({positionX.toFixed(2)})</Label>
          <Input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={positionX}
            onChange={(e) => onPositionChange(Number(e.target.value), positionY)}
            className="h-2"
          />
        </div>
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground">位置 Y ({positionY.toFixed(2)})</Label>
          <Input
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={positionY}
            onChange={(e) => onPositionChange(positionX, Number(e.target.value))}
            className="h-2"
          />
        </div>
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground">缩放 ({scale.toFixed(2)})</Label>
          <Input
            type="range"
            min={0.3}
            max={2.5}
            step={0.01}
            value={scale}
            onChange={(e) => onScaleChange(Number(e.target.value))}
            className="h-2"
          />
        </div>
      </div>

      <div className="flex items-center gap-2">
        <Label className="text-xs text-muted-foreground shrink-0">旋转 ({rotation}°)</Label>
        <Input
          type="range"
          min={-45}
          max={45}
          step={1}
          value={rotation}
          onChange={(e) => onRotationChange(Number(e.target.value))}
          className="h-2 flex-1"
        />
      </div>

      <Dialog open={lightboxOpen} onOpenChange={setLightboxOpen}>
        <DialogContent className="max-w-2xl p-2">
          <DialogTitle className="sr-only">剪影预览</DialogTitle>
          <div className="flex items-center justify-center max-h-[80vh] overflow-hidden">
            <img
              src={silhouetteUrl ?? ''}
              alt="剪影"
              className="max-h-[80vh] w-auto object-contain rounded-md"
            />
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}