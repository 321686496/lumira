'use client';

import * as React from 'react';
import { ArrowsOut, MagnifyingGlassPlus } from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogTitle,
} from '@/components/ui/dialog';

interface SilhouettePreviewProps {
  silhouetteUrl: string | null;
  positionX: number;
  positionY: number;
  scale: number;
  rotation: number;
  aspectRatio: string;
  onPositionChange: (x: number, y: number) => void;
  onScaleChange: (scale: number) => void;
  onRotationChange: (rotation: number) => void;
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

export default function SilhouettePreview({
  silhouetteUrl,
  positionX,
  positionY,
  scale,
  rotation,
  aspectRatio,
  onPositionChange,
  onScaleChange,
  onRotationChange,
  className,
}: SilhouettePreviewProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = React.useState(false);
  const [lightboxOpen, setLightboxOpen] = React.useState(false);
  const dragStart = React.useRef({ x: 0, y: 0, posX: 0, posY: 0 });

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
      if (!isDragging || !containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
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
      <Label>剪影预览</Label>
      <div className="flex items-center justify-center bg-muted/20 rounded-lg p-4">
        <div
          ref={containerRef}
          className={cn(
            'relative w-full max-w-[240px] rounded-2xl border-2 border-border bg-muted overflow-hidden select-none',
            getAspectRatioPadding(aspectRatio),
          )}
        >
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center text-muted-foreground/40">
              <ArrowsOut size={32} className="mx-auto mb-1" />
              <p className="text-xs">手机屏幕</p>
            </div>
          </div>

          {silhouetteUrl && (
            <div
              className={cn(
                'absolute inset-0 flex items-center justify-center',
                isDragging ? 'cursor-grabbing' : 'cursor-grab',
              )}
              onMouseDown={handleMouseDown}
              style={{ touchAction: 'none' }}
            >
              <div
                className="relative"
                style={{
                  transform: `translate(${(positionX - 0.5) * 100}%, ${(positionY - 0.5) * 100}%) scale(${scale}) rotate(${rotation}deg)`,
                  transition: isDragging ? 'none' : 'transform 0.15s ease-out',
                }}
              >
                <img
                  src={silhouetteUrl}
                  alt="剪影"
                  className="max-w-[80%] max-h-[80%] object-contain pointer-events-none"
                  draggable={false}
                />
              </div>
            </div>
          )}

          {silhouetteUrl && (
            <Button
              type="button"
              variant="secondary"
              size="icon"
              className="absolute top-2 right-2 h-7 w-7 opacity-70 hover:opacity-100 z-10"
              onClick={(e) => {
                e.stopPropagation();
                setLightboxOpen(true);
              }}
            >
              <MagnifyingGlassPlus size={14} />
            </Button>
          )}
        </div>
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
            min={0.5}
            max={1.5}
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