// src/components/ai-create/step-silhouette.tsx
// Step4 剪影决策：选源图（封面/示例）→ 线稿/实心 → 可选自动裁剪 → 透明棋盘格预览 → 应用/跳过
// 本地管线端点不依赖 AI 配置（纯服务端计算）

'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { aiGenerateSilhouetteAction } from '@/actions/ai';
import { base64ToFile } from './wizard';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { cn } from '@/lib/utils';

/** 透明底棋盘格背景（CSS 渐变网格） */
const CHECKERBOARD_STYLE: React.CSSProperties = {
  backgroundImage:
    'linear-gradient(45deg, #e5e5e5 25%, transparent 25%), linear-gradient(-45deg, #e5e5e5 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #e5e5e5 75%), linear-gradient(-45deg, transparent 75%, #e5e5e5 75%)',
  backgroundSize: '16px 16px',
  backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
  backgroundColor: '#fafafa',
};

export function StepSilhouette({
  coverFile,
  exampleFile,
  busy,
  onApply,
}: {
  coverFile: File | null;
  exampleFile: File | null;
  busy: boolean;
  onApply: (file: File | null) => void;
}) {
  const { toast } = useToast();
  const [source, setSource] = useState<'cover' | 'example'>('cover');
  const [mode, setMode] = useState<'sketch' | 'solid'>('sketch');
  const [crop, setCrop] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [previewFile, setPreviewFile] = useState<File | null>(null);

  const disabled = busy || generating;
  const sourceFile = source === 'cover' ? coverFile : exampleFile;

  const generate = async () => {
    if (!sourceFile) {
      toast({ variant: 'destructive', title: '缺少源图', description: '请先选择源图' });
      return;
    }
    setGenerating(true);
    const fd = new FormData();
    fd.set('image', sourceFile);
    fd.set('meta', JSON.stringify({ mode, crop }));
    const result = await aiGenerateSilhouetteAction(fd);
    setGenerating(false);
    if ('error' in result) {
      toast({ variant: 'destructive', title: '剪影生成失败', description: result.error });
      return;
    }
    const file = base64ToFile(result.image, result.mimeType, `ai-silhouette-${Date.now()}.png`);
    setPreviewFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>生成姿势剪影</CardTitle>
        <CardDescription>
          从源图自动抠出人物并转为线稿 / 实心剪影（透明底 PNG），替代手工抠图；可跳过后在表单中手动配置。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {/* 源图选择 */}
        <div className="space-y-2">
          <Label>源图</Label>
          <div className="inline-flex rounded-md border border-border p-0.5">
            {([
              { key: 'cover', label: '封面图' },
              { key: 'example', label: '示例图' },
            ] as const)
              .filter((opt) => opt.key !== 'example' || exampleFile !== null)
              .map((opt) => (
              <button
                key={opt.key}
                type="button"
                disabled={disabled}
                onClick={() => setSource(opt.key)}
                className={cn(
                  'rounded px-3 py-1 text-sm transition-colors',
                  source === opt.key
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* 模式选择 */}
        <div className="space-y-2">
          <Label>剪影模式</Label>
          <div className="inline-flex rounded-md border border-border p-0.5">
            {([
              { key: 'sketch', label: '线稿' },
              { key: 'solid', label: '实心' },
            ] as const).map((opt) => (
              <button
                key={opt.key}
                type="button"
                disabled={disabled}
                onClick={() => setMode(opt.key)}
                className={cn(
                  'rounded px-3 py-1 text-sm transition-colors',
                  mode === opt.key
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* 自动裁剪 */}
        <div className="flex items-center justify-between rounded-lg border border-border px-4 py-3">
          <div>
            <div className="text-sm font-medium text-foreground">自动裁剪到人物包围盒</div>
            <div className="text-xs text-muted-foreground">关闭则保留原画面框（剪影位置与原图一致）</div>
          </div>
          <Switch checked={crop} onCheckedChange={setCrop} disabled={disabled} />
        </div>

        <Button disabled={disabled || !sourceFile} onClick={generate}>
          {generating ? '生成中…' : '生成剪影'}
        </Button>

        {/* 透明棋盘格预览 */}
        {previewUrl && (
          <div className="space-y-2">
            <Label>预览（透明底）</Label>
            <div className="inline-block rounded-md border border-border p-2" style={CHECKERBOARD_STYLE}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={previewUrl} alt="剪影预览" className="max-h-72" />
            </div>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <Button disabled={disabled || !previewFile} onClick={() => onApply(previewFile)}>
            应用到姿势 <ArrowRight size={14} className="ml-1" />
          </Button>
          <Button variant="outline" disabled={disabled} onClick={() => onApply(null)}>
            跳过剪影
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
