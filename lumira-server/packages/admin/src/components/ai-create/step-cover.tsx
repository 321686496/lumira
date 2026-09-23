// src/components/ai-create/step-cover.tsx
// Step3 封面决策：示例图 / AI 生成效果图，可重 roll、多张、排序；首图 = 封面

'use client';

import type { Dispatch, SetStateAction } from 'react';
import { useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';
import { generateAiPoseImages, type AiPoseProgress } from '@/lib/ai-task';
import type { AiResearchRef } from '@/types/admin';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { ImageSquare } from '@phosphor-icons/react/dist/csr/ImageSquare';
import { ArrowLeft } from '@phosphor-icons/react/dist/csr/ArrowLeft';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { X } from '@phosphor-icons/react/dist/csr/X';
import { DownloadSimple } from '@phosphor-icons/react/dist/csr/DownloadSimple';
import { cn } from '@/lib/utils';
import { compressImage } from '@/lib/image-compress';

export interface CoverCandidate {
  id: string;
  file: File;
  url: string;
  source: 'example' | 'ai';
}

export function StepCover({
  exampleFile,
  referenceFile,
  referenceUrl,
  onReferenceChange,
  draft,
  research,
  candidates,
  setCandidates,
  busy,
  onApply,
}: {
  exampleFile: File | null;
  referenceFile: File | null;
  referenceUrl: string | null;
  onReferenceChange: (file: File | null, url: string | null) => void;
  draft: Record<string, unknown> | null;
  /** 识别阶段的网络趋势研究结果（生成时透传给后端提示词组织器，与草稿同源） */
  research?: AiResearchRef[] | null;
  candidates: CoverCandidate[];
  setCandidates: Dispatch<SetStateAction<CoverCandidate[]>>;
  busy: boolean;
  onApply: (files: File[]) => void;
}) {
  const { toast } = useToast();
  const [generating, setGenerating] = useState(false);
  /** 实时生成进度（第 current/total 张） */
  const [poseProgress, setPoseProgress] = useState<AiPoseProgress | null>(null);
  /** 预览放大：当前查看的候选索引（null = 关闭） */
  const [viewIndex, setViewIndex] = useState<number | null>(null);
  /** 附加提示词：拼接到后端合成 prompt 末尾（用户对封面图的额外要求，权重最高） */
  const [extraPrompt, setExtraPrompt] = useState('');
  const referenceInputRef = useRef<HTMLInputElement>(null);

  const disabled = busy || generating;

  /** 保存候选图到本地：优先用原始 File 生成 blob（objectURL 同源可下载） */
  const downloadCandidate = (c: CoverCandidate) => {
    const url = URL.createObjectURL(c.file);
    const a = document.createElement('a');
    a.href = url;
    a.download = c.file.name || `pose-${Date.now()}.png`;
    a.click();
    URL.revokeObjectURL(url);
    toast({ title: '已开始下载', description: c.file.name || '姿势图' });
  };

  const viewing = viewIndex != null ? candidates[viewIndex] : null;

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

  /** 按姿势并行生成效果图；每个姿势独立任务并轮询结果，单张失败不影响其它任务。 */
  const generate = async () => {
    if (!draft) return;
    setGenerating(true);
    setPoseProgress(null);
    try {
      const results = await generateAiPoseImages({
        draft,
        referenceFile: referenceFile ?? exampleFile,
        extraPrompt,
        research,
        onProgress: setPoseProgress,
        onResult: (result) => {
          if (!result.file) return;
          const generated: CoverCandidate = {
            id: `ai-${Date.now()}-${result.index}-${candidates.length}`,
            file: result.file,
            url: URL.createObjectURL(result.file),
            source: 'ai',
          };
          setCandidates((prev) => [generated, ...prev]);
        },
      });
      const files = results
        .filter((result): result is { index: number; file: File } => Boolean(result.file))
        .sort((a, b) => a.index - b.index)
        .map((result) => result.file);
      const errors = results.filter((result) => result.error);
      if (errors.length > 0) {
        // 调试排查：完整明细进控制台。index 0 为锚点，其 error 是真实根因；index≥1 多为「锚点失败」的连锁文案。
        console.log(
          '[ai-pose] 生成结果明细',
          results.map((r) => ({ index: r.index, error: r.error ?? null })),
        );
      }
      if (files.length > 0) {
        toast({ title: '姿势图生成完成', description: `成功 ${files.length} 张，已置顶为封面候选` });
      }
      if (errors.length > 0) {
        // 聚合为单条且「不自动关闭」的错误提示（需点右上角 × 手动关闭），优先展示 index 最小（即锚点）的真实错误
        const real = [...errors].sort((a, b) => a.index - b.index)[0];
        toast({
          variant: 'destructive',
          duration: Infinity, // 不自动关闭，避免用户来不及看到真实原因
          title: `姿势图生成失败（${errors.length}/${results.length} 张）`,
          description: real?.error || '请稍后重试',
        });
      }
    } catch (e) {
      // server action 抛错（网络中断 / 框架层错误）也必须恢复按钮，避免永久"生成中"
      toast({
        variant: 'destructive',
        title: '生成失败',
        description: e instanceof Error ? e.message : String(e),
      });
    } finally {
      setGenerating(false);
      setPoseProgress(null);
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
        <div className="space-y-2">
          <Label htmlFor="ai-pose-reference">姿势参考图（可选）</Label>
          <p className="text-xs text-muted-foreground">
            可上传一张姿势参考图，或点击候选图「设为参考」。生成时第一张会以它为基准，后续姿势自动用第一张结果保持人物与场景一致。
          </p>
          <div className="flex flex-wrap items-center gap-3">
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={disabled}
              onClick={() => referenceInputRef.current?.click()}
            >
              <ImageSquare size={14} className="mr-1" />
              选择参考图
            </Button>
            {referenceFile && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                disabled={disabled}
                onClick={() => {
                  onReferenceChange(null, null);
                  if (referenceInputRef.current) referenceInputRef.current.value = '';
                }}
              >
                清除参考
              </Button>
            )}
            {referenceUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={referenceUrl}
                alt="姿势参考图"
                className="h-20 w-16 rounded-md border object-cover"
              />
            )}
          </div>
          <Input
            id="ai-pose-reference"
            ref={referenceInputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="hidden"
            disabled={busy}
            onChange={async (event) => {
              const file = event.target.files?.[0];
              if (!file) return;
              if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
                toast({ variant: 'destructive', title: '格式不支持', description: '参考图仅支持 jpg / png / webp' });
                return;
              }
              const compressed = await compressImage(file, {
                maxDim: 1280,
                quality: 0.8,
                maxBytes: 512 * 1024,
              });
              onReferenceChange(compressed, URL.createObjectURL(compressed));
              if (event.target) event.target.value = '';
            }}
          />
        </div>

        <div className="flex flex-wrap gap-3">
          <Button variant="outline" size="sm" disabled={!exampleFile || disabled} onClick={rollExampleToTop}>
            <ImageSquare size={14} className="mr-1" /> 用示例图（置顶）
          </Button>
          <Button size="sm" disabled={!draft || disabled} onClick={generate}>
            <MagicWand size={14} className="mr-1" />
            {generating
              ? `生成姿势图 ${poseProgress?.current ?? 0}/${poseProgress?.total ?? 0}…`
              : Array.isArray(draft?.pose) && draft.pose.length > 0
                ? `并行生成 ${draft.pose.length} 张姿势图`
                : '生成姿势图'}
          </Button>
        </div>

        {/* 实时生成进度条 */}
        {generating && poseProgress && (
          <div className="space-y-1">
            <div className="flex items-center justify-between text-xs text-muted-foreground">
              <span>
                正在生成第 {poseProgress.current}/{poseProgress.total} 张
                {poseProgress.status === 'done' ? '（完成）' : ''}
              </span>
              <span>{Math.round((poseProgress.current / poseProgress.total) * 100)}%</span>
            </div>
            <div className="h-1.5 overflow-hidden rounded-full bg-primary/20">
              <div
                className="h-full bg-primary transition-all"
                style={{ width: `${(poseProgress.current / Math.max(poseProgress.total, 1)) * 100}%` }}
              />
            </div>
          </div>
        )}

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
                  {/* 点击放大查看 */}
                  <button
                    type="button"
                    className="block w-full cursor-zoom-in"
                    onClick={() => setViewIndex(i)}
                    aria-label={`放大查看第 ${i + 1} 张候选图`}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={c.url} alt="封面候选" className="aspect-[3/4] w-full object-cover" />
                  </button>
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
                    <button
                      type="button"
                      className="rounded px-1 text-[10px] text-muted-foreground hover:text-primary disabled:opacity-30"
                      disabled={disabled}
                      onClick={() => onReferenceChange(c.file, c.url)}
                    >
                      设为参考
                    </button>
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

        {/* 放大查看 + 保存到本地 */}
        <Dialog open={viewing != null} onOpenChange={(open) => { if (!open) setViewIndex(null); }}>
          <DialogContent className="max-w-3xl p-2">
            <div className="flex items-center justify-between px-1 pt-1">
              <DialogTitle className="sr-only">候选图放大预览</DialogTitle>
              <DialogDescription className="sr-only">姿势图/封面候选图放大预览</DialogDescription>
              <span className="text-sm text-muted-foreground">
                {viewing && viewIndex != null ? `候选图 ${viewIndex + 1} / ${candidates.length}` : ''}
              </span>
              {viewing && (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => downloadCandidate(viewing)}
                >
                  <DownloadSimple size={14} className="mr-1" /> 保存到本地
                </Button>
              )}
            </div>
            <div className="flex items-center justify-center max-h-[80vh] overflow-hidden">
              {viewing && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={viewing.url}
                  alt="候选图"
                  className="max-h-[80vh] w-auto object-contain rounded-md"
                />
              )}
            </div>
          </DialogContent>
        </Dialog>
      </CardContent>
    </Card>
  );
}
