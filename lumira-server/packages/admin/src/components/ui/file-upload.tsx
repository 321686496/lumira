// src/components/ui/file-upload.tsx
'use client';

import * as React from 'react';
import { Upload, X } from '@phosphor-icons/react/dist/ssr';
import { cn } from '@/lib/utils';
import { useToast } from '@/hooks/use-toast';
import { Button } from '@/components/ui/button';

export interface FileUploadProps {
  /** File input accept attribute, e.g. 'image/*' */
  accept?: string;
  /** Max file size in bytes. Default 2MB. */
  maxSize?: number;
  /** Controlled file value (or null when empty). */
  value?: File | null;
  /** Called when user picks / clears a file. */
  onChange: (file: File | null) => void;
  /** Label shown above the dropzone. */
  label?: string;
  /** Hint shown below the dropzone. */
  hint?: string;
  /** Optional preview URL override (e.g. existing remote cover URL). */
  previewUrl?: string;
  className?: string;
  disabled?: boolean;
}

const DEFAULT_MAX_SIZE = 2 * 1024 * 1024; // 2MB

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

  // 当 value 变化时维护 object URL（用于本地预览）
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
  const showPreview = Boolean(previewSrc);

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
            'flex flex-col items-center justify-center rounded-md border border-dashed border-input bg-background p-6 text-center transition-colors',
            'hover:bg-muted/50 cursor-pointer',
            disabled && 'opacity-50 pointer-events-none',
          )}
        >
          <Upload size={20} className="text-muted-foreground" />
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
        </label>
        {showPreview && (
          <div className="mt-2 flex items-start gap-3 rounded-md border border-input bg-muted/20 p-3">
            {/* 预览图 */}
            <div className="h-16 w-16 shrink-0 overflow-hidden rounded-md bg-background border border-input">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={previewSrc}
                alt="预览"
                className="h-full w-full object-cover"
              />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate text-foreground">
                {value?.name || '当前文件'}
              </p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {value
                  ? `${(value.size / 1024).toFixed(1)} KB`
                  : previewUrl
                    ? '已有远程文件，重新选择将覆盖'
                    : ''}
              </p>
            </div>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="h-7 w-7"
              onClick={() => {
                if (inputRef.current) inputRef.current.value = '';
                handleFile(null);
              }}
              disabled={disabled}
              aria-label="移除文件"
            >
              <X size={14} />
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}

export default FileUpload;
