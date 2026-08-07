'use client';

import * as React from 'react';
import { Upload, X, MagnifyingGlassPlus } from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';
import { useToast } from '@/hooks/use-toast';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogTitle,
} from '@/components/ui/dialog';

export interface FileUploadProps {
  accept?: string;
  maxSize?: number;
  value?: File | null;
  onChange: (file: File | null) => void;
  label?: string;
  hint?: string;
  previewUrl?: string;
  className?: string;
  disabled?: boolean;
}

const DEFAULT_MAX_SIZE = 2 * 1024 * 1024;

export function FileUpload({
  accept = 'image/*',
  maxSize = DEFAULT_MAX_SIZE,
  value,
  onChange,
  label,
  hint,
  previewUrl,
  className,
  disabled,
}: FileUploadProps) {
  const { toast } = useToast();
  const inputRef = React.useRef<HTMLInputElement>(null);
  const [localObjectUrl, setLocalObjectUrl] = React.useState<string | null>(null);
  const [lightboxOpen, setLightboxOpen] = React.useState(false);

  React.useEffect(() => {
    if (value) {
      const url = URL.createObjectURL(value);
      setLocalObjectUrl(url);
      return () => {
        URL.revokeObjectURL(url);
      };
    }
    setLocalObjectUrl(null);
    return undefined;
  }, [value]);

  const handleFile = (file: File | null) => {
    if (!file) {
      onChange(null);
      return;
    }
    if (maxSize && file.size > maxSize) {
      const mb = (maxSize / 1024 / 1024).toFixed(1);
      toast({
        variant: 'destructive',
        title: '文件过大',
        description: `请选择小于 ${mb}MB 的文件（当前 ${(file.size / 1024 / 1024).toFixed(2)}MB）`,
      });
      if (inputRef.current) inputRef.current.value = '';
      return;
    }
    onChange(file);
  };

  const previewSrc = localObjectUrl || previewUrl;
  const hasPreview = Boolean(previewSrc);

  return (
    <div className={cn('space-y-2', className)}>
      {label && (
        <label className="text-sm font-medium leading-none text-foreground">
          {label}
        </label>
      )}
      <div className="relative">
        <label
          className={cn(
            'relative flex flex-col items-center justify-center rounded-md border border-dashed border-input bg-background text-center transition-colors overflow-hidden',
            hasPreview
              ? 'p-0 cursor-default'
              : 'p-6 hover:bg-muted/50 cursor-pointer',
            disabled && 'opacity-50 pointer-events-none',
          )}
          style={hasPreview ? { minHeight: '200px' } : undefined}
        >
          {hasPreview ? (
            <>
              <img
                src={previewSrc}
                alt="预览"
                className="absolute inset-0 h-full w-full object-contain bg-muted/10"
              />
              <div className="absolute inset-0 bg-black/0 hover:bg-black/30 transition-colors group flex items-center justify-center gap-2">
                <div className="opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-2">
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={(e) => {
                      e.preventDefault();
                      setLightboxOpen(true);
                    }}
                  >
                    <MagnifyingGlassPlus size={14} className="mr-1" /> 放大查看
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={(e) => {
                      e.preventDefault();
                      if (inputRef.current) inputRef.current.value = '';
                      onChange(null);
                    }}
                  >
                    <X size={14} className="mr-1" /> 移除
                  </Button>
                </div>
              </div>
              <input
                ref={inputRef}
                type="file"
                accept={accept}
                className="hidden"
                disabled={disabled}
                onChange={(e) => {
                  const file = e.target.files?.[0] ?? null;
                  handleFile(file);
                }}
              />
            </>
          ) : (
            <>
              <Upload size={24} className="text-muted-foreground" />
              <span className="mt-2 text-sm text-muted-foreground">
                点击选择文件{accept ? `（${accept}）` : ''}
              </span>
              {hint && (
                <span className="mt-1 text-xs text-muted-foreground/80">{hint}</span>
              )}
              <input
                ref={inputRef}
                type="file"
                accept={accept}
                className="hidden"
                disabled={disabled}
                onChange={(e) => {
                  const file = e.target.files?.[0] ?? null;
                  handleFile(file);
                }}
              />
            </>
          )}
        </label>
      </div>

      <Dialog open={lightboxOpen} onOpenChange={setLightboxOpen}>
        <DialogContent className="max-w-4xl p-2">
          <DialogTitle className="sr-only">图片预览</DialogTitle>
          <div className="flex items-center justify-center max-h-[80vh] overflow-hidden">
            <img
              src={previewSrc}
              alt="预览"
              className="max-h-[80vh] w-auto object-contain rounded-md"
            />
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default FileUpload;