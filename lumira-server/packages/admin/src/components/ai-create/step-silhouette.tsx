// src/components/ai-create/step-silhouette.tsx
// Step4 剪影决策：以模板表单当前效果图为准，逐张生成透明底剪影；
// AI 引擎走生图模型（silhouette_model 可在 AI 设置中单独指定）；本地引擎为 RMBG-1.4 纯服务端计算。

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

interface SilhouetteResult {
  file: File;
  url: string;
}

export function StepSilhouette({
  images,
  busy,
  onApply,
  aiAvailable,
  silhouetteModelName,
}: {
  /** 模板表单当前实际效果图列表（封面在首位） */
  images: File[];
  busy: boolean;
  onApply: (files: File[] | null) => void;
  /** AI 已配置并启用（engine 默认值 + AI 选项可用性） */
  aiAvailable: boolean;
  /** 生效的剪影模型名（未单独指定 = 生图模型），engine=ai 时展示 */
  silhouetteModelName: string | null;
}) {
  const { toast } = useToast();
  const [mode, setMode] = useState<'sketch' | 'solid'>('sketch');
  const [crop, setCrop] = useState(true);
  const [engine, setEngine] = useState<'ai' | 'local'>(aiAvailable ? 'ai' : 'local');
  const [generating, setGenerating] = useState(false);
  const [progress, setProgress] = useState(0);
  const [results, setResults] = useState<SilhouetteResult[]>([]);

  const disabled = busy || generating;

  const generate = async () => {
    if (images.length === 0) {
      toast({ variant: 'destructive', title: '缺少效果图', description: '请先在表单中上传或生成效果图' });
      return;
    }
    setGenerating(true);
    setProgress(0);
    const generated: SilhouetteResult[] = [];
    try {
      for (let i = 0; i < images.length; i += 1) {
        const fd = new FormData();
        fd.set('image', images[i]);
        fd.set('meta', JSON.stringify({ mode, crop, engine }));
        const result = await aiGenerateSilhouetteAction(fd);
        if (!result || 'error' in result) {
          toast({
            variant: 'destructive',
            title: `第 ${i + 1} 张剪影生成失败`,
            description: `${result.error}${generated.length > 0 ? '；已完成的剪影已保留' : ''}`,
          });
          continue;
        }
        const file = base64ToFile(result.image, result.mimeType, `ai-silhouette-${Date.now()}-${i}.png`);
        generated.push({ file, url: URL.createObjectURL(file) });
        setResults([...generated]);
        setProgress(i + 1);
      }
      if (generated.length === 0) return;
      toast({ title: '剪影生成完成', description: `已生成 ${generated.length}/${images.length} 张剪影` });
    } catch (e) {
      toast({
        variant: 'destructive',
        title: '剪影生成失败',
        description: e instanceof Error ? e.message : String(e),
      });
    } finally {
      setGenerating(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>批量生成姿势剪影</CardTitle>
        <CardDescription>
          以模板表单当前实际效果图为准，逐张生成线稿 / 实心剪影（透明底 PNG），替代手工抠图；可跳过后在表单中手动配置。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="space-y-2">
          <Label>源图（{images.length} 张）</Label>
          {images.length === 0 ? (
            <div className="rounded-md border border-dashed border-border p-4 text-sm text-muted-foreground">
              模板表单当前没有效果图。请先上传/生成效果图后再生成剪影。
            </div>
          ) : (
            <div className="flex flex-wrap gap-2">
              {images.map((file, i) => (
                <div key={`${file.name}-${i}`} className="rounded-md border border-border p-1">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={URL.createObjectURL(file)} alt={`源图 ${i + 1}`} className="h-20 rounded" />
                </div>
              ))}
            </div>
          )}
          <p className="text-xs text-muted-foreground">生成结果按源图顺序依次应用到姿势 1、姿势 2……</p>
        </div>

        <div className="space-y-2">
          <Label>生成方式</Label>
          <div className="inline-flex rounded-md border border-border p-0.5">
            {([
              { key: 'ai', label: 'AI 生成' },
              { key: 'local', label: '本地抠图' },
            ] as const).map((opt) => (
              <button
                key={opt.key}
                type="button"
                disabled={disabled || (opt.key === 'ai' && !aiAvailable)}
                onClick={() => setEngine(opt.key)}
                className={cn(
                  'rounded px-3 py-1 text-sm transition-colors',
                  engine === opt.key
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground',
                  opt.key === 'ai' && !aiAvailable && 'cursor-not-allowed opacity-40',
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">
            {engine === 'ai'
              ? silhouetteModelName
                ? `将使用剪影模型：${silhouetteModelName}（AI 设置中可单独指定，未指定时与生图模型一致）`
                : '将使用生图模型生成白底剪影后自动转透明底'
              : '本地 RMBG-1.4 模型抠像，无需 AI 配置；服务器未安装模型时会返回错误'}
          </p>
        </div>

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

        <div className="flex items-center justify-between rounded-lg border border-border px-4 py-3">
          <div>
            <div className="text-sm font-medium text-foreground">自动裁剪到人物包围盒</div>
            <div className="text-xs text-muted-foreground">关闭则保留原画面框（剪影位置与原图一致）</div>
          </div>
          <Switch checked={crop} onCheckedChange={setCrop} disabled={disabled} />
        </div>

        <Button disabled={disabled || images.length === 0} onClick={generate}>
          {generating ? `生成中…（${progress}/${images.length}）` : `生成 ${images.length} 张剪影`}
        </Button>

        {results.length > 0 && (
          <div className="space-y-2">
            <Label>预览（透明底，{results.length} 张）</Label>
            <div className="flex flex-wrap gap-3">
              {results.map((result, i) => (
                <div
                  key={result.url}
                  className="inline-block rounded-md border border-border p-2"
                  style={CHECKERBOARD_STYLE}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={result.url} alt={`剪影 ${i + 1}`} className="max-h-48" />
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <Button disabled={disabled || results.length === 0} onClick={() => onApply(results.map((r) => r.file))}>
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
