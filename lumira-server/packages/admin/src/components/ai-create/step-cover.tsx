// src/components/ai-create/step-cover.tsx
// Step3 封面决策：示例图 / AI 生成效果图，可重 roll、多张、排序；首图 = 封面

'use client';

import type { Dispatch, SetStateAction } from 'react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { useToast } from '@/hooks/use-toast';
import { aiGenerateImageStartAction } from '@/actions/ai';
import { pollAiImageTask } from '@/lib/ai-task';
import type { AiImageStatusResult } from '@/types/admin';
import { base64ToFile } from './wizard';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { ImageSquare } from '@phosphor-icons/react/dist/csr/ImageSquare';
import { ArrowLeft } from '@phosphor-icons/react/dist/csr/ArrowLeft';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { X } from '@phosphor-icons/react/dist/csr/X';
import { cn } from '@/lib/utils';

export interface CoverCandidate {
  id: string;
  file: File;
  url: string;
  source: 'example' | 'ai';
}

export function StepCover({
  exampleFile,
  draft,
  candidates,
  setCandidates,
  busy,
  onApply,
}: {
  exampleFile: File | null;
  draft: Record<string, unknown> | null;
  candidates: CoverCandidate[];
  setCandidates: Dispatch<SetStateAction<CoverCandidate[]>>;
  busy: boolean;
  onApply: (files: File[]) => void;
}) {
  const { toast } = useToast();
  const [generating, setGenerating] = useState(false);
  /** 附加提示词：拼接到后端合成 prompt 末尾（用户对封面图的额外要求，权重最高） */
  const [extraPrompt, setExtraPrompt] = useState('');

  const disabled = busy || generating;

  /** 将示例图置顶为封面候选 */
  const rollExampleToTop = () => {
    if (!exampleFile) return;
    setCandidates((prev) => {
      const existing = prev.find((c) => c.source === 'example');
      const exampleCandidate: CoverCandidate = existing ?? {
        id: 'example',
        file: exampleFile,
        url: URL.createObjectURL(exampleFile),
        source: 'example',
      };
      return [exampleCandidate, ...prev.filter((c) => c.source !== 'example')];
    });
  };

  /** 生成同风格效果图（异步任务式：提交 taskId 后轮询结果，避免同步长请求超时；可多次点击重 roll） */
  const generate = async () => {
    if (!draft) return;
    setGenerating(true);
    try {
      const fd = new FormData();
      fd.set('meta', JSON.stringify(draft));
      if (exampleFile) fd.set('reference', exampleFile);
      const extra = extraPrompt.trim();
      if (extra) fd.set('extraPrompt', extra);
      const start = await aiGenerateImageStartAction(fd);
      if ('error' in start) {
        toast({ variant: 'destructive', title: '生成失败', description: start.error });
        return;
      }
      let status: AiImageStatusResult;
      try {
        status = await pollAiImageTask(start.taskId);
      } catch (err) {
        toast({ variant: 'destructive', title: '生成失败', description: (err as Error).message });
        return;
      }
      const file = base64ToFile(status.image!, status.mimeType!, `ai-cover-${Date.now()}.png`);
      setCandidates((prev) => [
        { id: `ai-${Date.now()}-${prev.length}`, file, url: URL.createObjectURL(file), source: 'ai' },
        ...prev,
      ]);
      toast({ title: '已生成效果图', description: '已置顶为封面候选，可继续重 roll 或调整排序' });
    } catch (e) {
      // server action 抛错（网络中断 / 框架层错误）也必须恢复按钮，避免永久"生成中"
      toast({
        variant: 'destructive',
        title: '生成失败',
        description: e instanceof Error ? e.message : String(e),
      });
    } finally {
      setGenerating(false);
    }
  };

  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= candidates.length) return;
    setCandidates((prev) => {
      const c = [...prev];
      [c[i], c[j]] = [c[j], c[i]];
      return c;
    });
  };

  const toTop = (i: number) => {
    if (i === 0) return;
    setCandidates((prev) => {
      const c = [...prev];
      const [item] = c.splice(i, 1);
      c.unshift(item);
      return c;
    });
  };

  const remove = (i: number) => {
    if (candidates.length <= 1) return; // 至少保留一张（封面必填）
    setCandidates((prev) => prev.filter((_, idx) => idx !== i));
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>选择封面</CardTitle>
        <CardDescription>
          首图将作为封面与第一张效果图。可用示例图作封面，或生成效果图（可多次生成、可排序）；无示例图时，效果图即为封面来源。
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex flex-wrap gap-3">
          <Button variant="outline" size="sm" disabled={!exampleFile || disabled} onClick={rollExampleToTop}>
            <ImageSquare size={14} className="mr-1" /> 用示例图（置顶）
          </Button>
          <Button size="sm" disabled={!draft || disabled} onClick={generate}>
            <MagicWand size={14} className="mr-1" /> {generating ? '生成中…' : '生成效果图'}
          </Button>
        </div>

        {/* 附加提示词：拼接到后端合成 prompt 末尾，可多次生成时调整迭代 */}
        <div className="space-y-2">
          <Label htmlFor="ai-extra-prompt">附加提示词（可选）</Label>
          <Textarea
            id="ai-extra-prompt"
            value={extraPrompt}
            onChange={(e) => setExtraPrompt(e.target.value)}
            placeholder="对封面效果图的额外要求，如「人物戴草帽」「天空占比更大」，将附加到 AI 提示词末尾"
            rows={2}
            disabled={busy}
          />
          <p className="text-xs text-muted-foreground">
            留空则按草稿自动合成提示词；填写后每次生成（含重 roll）都会附加该要求
          </p>
        </div>

        {candidates.length > 0 && (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {candidates.map((c, i) => (
              <div
                key={c.id}
                className={cn(
                  'overflow-hidden rounded-md border',
                  i === 0 ? 'border-primary' : 'border-border',
                )}
              >
                <div className="relative">
                  {i === 0 && (
                    <span className="absolute left-2 top-2 z-10 rounded bg-primary px-1.5 py-0.5 text-[10px] font-medium text-primary-foreground">
                      封面
                    </span>
                  )}
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={c.url} alt="封面候选" className="aspect-[3/4] w-full object-cover" />
                </div>
                <div className="flex items-center justify-between border-t border-border bg-card px-1 py-1">
                  <div className="flex">
                    <button
                      type="button"
                      className="rounded p-1 text-muted-foreground hover:text-foreground disabled:opacity-30"
                      disabled={i === 0}
                      onClick={() => move(i, -1)}
                      aria-label="左移"
                    >
                      <ArrowLeft size={14} />
                    </button>
                    <button
                      type="button"
                      className="rounded p-1 text-muted-foreground hover:text-foreground disabled:opacity-30"
                      disabled={i === candidates.length - 1}
                      onClick={() => move(i, 1)}
                      aria-label="右移"
                    >
                      <ArrowRight size={14} />
                    </button>
                  </div>
                  <div className="flex items-center gap-1">
                    {i !== 0 && (
                      <button
                        type="button"
                        className="rounded px-1 text-[10px] text-muted-foreground hover:text-primary"
                        onClick={() => toTop(i)}
                      >
                        设为封面
                      </button>
                    )}
                    <button
                      type="button"
                      className="rounded p-1 text-muted-foreground hover:text-destructive disabled:opacity-30"
                      disabled={candidates.length <= 1}
                      onClick={() => remove(i)}
                      aria-label="删除"
                    >
                      <X size={14} />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <Button disabled={disabled || candidates.length === 0} onClick={() => onApply(candidates.map((c) => c.file))}>
          应用为封面 <ArrowRight size={14} className="ml-1" />
        </Button>
      </CardContent>
    </Card>
  );
}
