// src/components/ai-create/wizard.tsx
// AI 一键建模向导主状态机（/dashboard/templates/ai-create）
// Step1 上传示例图 → Step2 风格识别（草稿回填 TemplateForm）→ Step3 封面决策 → Step4 剪影决策 → Step5 提交
// 支持「全自动生成并上架」：识别 → 生图作封面 → 线稿剪影 → 提交，任一步失败停在对应步骤转人工

'use client';

import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import TemplateForm, { type TemplateFormAiInjection } from '@/components/template-form';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { useToast } from '@/hooks/use-toast';
import { compressImage } from '@/lib/image-compress';
import { aiAnalyzeAction, aiGenerateImageAction, aiGenerateSilhouetteAction } from '@/actions/ai';
import type { TemplateCategory } from '@/types/admin';
import { StepCover, type CoverCandidate } from './step-cover';
import { StepSilhouette } from './step-silhouette';
import { Upload } from '@phosphor-icons/react/dist/csr/Upload';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { Check } from '@phosphor-icons/react/dist/csr/Check';
import { cn } from '@/lib/utils';

/** base64 → File（生图 / 剪影结果进入 imageFiles / 姿势编辑器），供 step-cover / step-silhouette 复用 */
export function base64ToFile(b64: string, mime: string, name: string): File {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new File([bytes], name, { type: mime });
}

const WIZARD_STEPS = [
  { n: 1, title: '上传示例图' },
  { n: 2, title: '风格识别' },
  { n: 3, title: '封面决策' },
  { n: 4, title: '剪影决策' },
  { n: 5, title: '提交' },
] as const;

type AutoStage = 'analyzing' | 'generating-image' | 'generating-silhouette' | 'submitting';
const AUTO_STAGES: AutoStage[] = ['analyzing', 'generating-image', 'generating-silhouette', 'submitting'];

const AUTO_STAGE_TEXT: Record<AutoStage, string> = {
  analyzing: '① 正在识别示例图风格…',
  'generating-image': '② 正在生成封面效果图…',
  'generating-silhouette': '③ 正在生成剪影…',
  submitting: '④ 正在提交上架…',
};

const ACCEPTED_MIME = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_EXAMPLE_BYTES = 8 * 1024 * 1024;

export function AiCreateWizard({
  categories,
  backendUrl,
}: {
  categories: TemplateCategory[];
  backendUrl: string;
}) {
  const { toast } = useToast();
  const [step, setStep] = useState(1);
  const [maxStep, setMaxStep] = useState(1);
  const [exampleFile, setExampleFile] = useState<File | null>(null);
  const [exampleUrl, setExampleUrl] = useState<string | null>(null);
  const [inputText, setInputText] = useState('');
  const [draft, setDraft] = useState<Record<string, unknown> | null>(null);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [candidates, setCandidates] = useState<CoverCandidate[]>([]);
  const [silhouetteFile, setSilhouetteFile] = useState<File | null>(null);
  const [injection, setInjection] = useState<TemplateFormAiInjection | null>(null);
  /** 首次识别成功后常驻渲染 TemplateForm（切回 Step1 也不丢表单状态） */
  const [formActivated, setFormActivated] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [autoState, setAutoState] = useState<{ running: boolean; stage: AutoStage; error?: string } | null>(null);
  const stampRef = useRef(0);
  const fileInputRef = useRef<HTMLInputElement>(null);

  /** 预览宿主（TemplateForm portal 目标）与 xl 断点（决定宿主位置：右栏 sticky / stepper 下方） */
  const [previewHost, setPreviewHost] = useState<HTMLDivElement | null>(null);
  const [isXl, setIsXl] = useState(true);

  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1280px)');
    const update = () => setIsXl(mq.matches);
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, []);

  const busy = analyzing || Boolean(autoState?.running);
  const hasInput = Boolean(exampleFile) || inputText.trim() !== '';

  const inject = (partial: Omit<TemplateFormAiInjection, 'stamp'>) =>
    setInjection({ stamp: ++stampRef.current, ...partial });

  const goto = (n: number) => {
    setStep(n);
    setMaxStep((m) => Math.max(m, n));
  };

  /** 换图 / 改文字 = 重置整个下游流程 */
  const resetFlow = () => {
    setDraft(null);
    setWarnings([]);
    setCandidates([]);
    setSilhouetteFile(null);
    setInjection(null);
    setFormActivated(false);
    setAutoState(null);
    setStep(1);
    setMaxStep(1);
  };

  const handleExamplePick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setErrorText(null);
    if (!ACCEPTED_MIME.includes(file.type)) {
      toast({ variant: 'destructive', title: '格式不支持', description: '仅支持 jpg / png / webp 图片' });
      return;
    }
    if (file.size > MAX_EXAMPLE_BYTES) {
      toast({ variant: 'destructive', title: '文件过大', description: '示例图不能超过 8MB' });
      return;
    }
    // Vercel Serverless 4.5MB 请求体限制：先压缩；仍 >3MB 则二次更激进压缩
    let processed = await compressImage(file, { maxDim: 1280, quality: 0.8 });
    if (processed.size > 3 * 1024 * 1024) {
      processed = await compressImage(processed, { maxDim: 1024, quality: 0.7 });
    }
    setExampleFile(processed);
    setExampleUrl(URL.createObjectURL(processed));
    // 换图 = 重新开始整个流程
    resetFlow();
    if (e.target) e.target.value = '';
  };

  const handleTextChange = (v: string) => {
    setInputText(v);
    setErrorText(null);
    // 流程已启动后修改输入 = 重新开始
    if (formActivated || step > 1) resetFlow();
  };

  /** 手动识别：成功后草稿回填 + 示例图作默认封面候选（纯文模式候选为空）→ Step2 */
  const handleAnalyze = async () => {
    if (!hasInput) return;
    setAnalyzing(true);
    setErrorText(null);
    const analyzeFd = new FormData();
    if (exampleFile) analyzeFd.set('image', exampleFile);
    if (inputText.trim()) analyzeFd.set('text', inputText.trim());
    const result = await aiAnalyzeAction(analyzeFd);
    setAnalyzing(false);
    if ('error' in result) {
      setErrorText(result.error);
      return;
    }
    setDraft(result.draft);
    setWarnings(result.warnings);
    if (exampleFile) {
      setCandidates([{
        id: 'example',
        file: exampleFile,
        url: URL.createObjectURL(exampleFile),
        source: 'example',
      }]);
      inject({ json: result.draft, images: [exampleFile], replaceImages: true });
    } else {
      setCandidates([]);
      inject({ json: result.draft });
    }
    setFormActivated(true);
    goto(2);
  };

  /** 全自动：识别 → 生图作封面 → 线稿剪影 → 创建并上架；失败停在对应步骤转人工，已成功资产保留 */
  const runAutoAll = async () => {
    if (!hasInput) return;
    setErrorText(null);
    setAutoState({ running: true, stage: 'analyzing' });

    // ① 识别
    const analyzeFd = new FormData();
    if (exampleFile) analyzeFd.set('image', exampleFile);
    if (inputText.trim()) analyzeFd.set('text', inputText.trim());
    const analyzeResult = await aiAnalyzeAction(analyzeFd);
    if ('error' in analyzeResult) {
      setAutoState(null);
      setErrorText(analyzeResult.error);
      return;
    }
    const draftLocal = analyzeResult.draft;
    setDraft(draftLocal);
    setWarnings(analyzeResult.warnings);
    setFormActivated(true);
    let exampleCandidate: CoverCandidate | null = null;
    if (exampleFile) {
      exampleCandidate = {
        id: 'example',
        file: exampleFile,
        url: URL.createObjectURL(exampleFile),
        source: 'example',
      };
    }

    // ② 生图作封面（参考图 = 示例图，纯文模式无参考图）
    setAutoState({ running: true, stage: 'generating-image' });
    const genFd = new FormData();
    genFd.set('meta', JSON.stringify(draftLocal));
    if (exampleFile) genFd.set('reference', exampleFile);
    const genResult = await aiGenerateImageAction(genFd);
    if ('error' in genResult) {
      // 停在 Step3 转人工：示例图保底作封面，草稿保留（纯文模式候选为空）
      setCandidates(exampleCandidate ? [exampleCandidate] : []);
      if (exampleFile) {
        inject({ json: draftLocal, images: [exampleFile], replaceImages: true });
      } else {
        inject({ json: draftLocal });
      }
      goto(3);
      setAutoState({ running: false, stage: 'generating-image', error: genResult.error });
      return;
    }
    const aiCover = base64ToFile(genResult.image, genResult.mimeType, `ai-cover-${Date.now()}.png`);
    setCandidates([
      { id: `ai-${Date.now()}`, file: aiCover, url: URL.createObjectURL(aiCover), source: 'ai' },
      ...(exampleCandidate ? [exampleCandidate] : []),
    ]);
    inject({ json: draftLocal, images: [aiCover], replaceImages: true });

    // ③ 剪影（源 = 生成的封面图，线稿模式 + 自动裁剪）
    setAutoState({ running: true, stage: 'generating-silhouette' });
    const silFd = new FormData();
    silFd.set('image', aiCover);
    silFd.set('meta', JSON.stringify({ mode: 'sketch', crop: true }));
    const silResult = await aiGenerateSilhouetteAction(silFd);
    if ('error' in silResult) {
      // 停在 Step4 转人工：剪影留空
      goto(4);
      setAutoState({ running: false, stage: 'generating-silhouette', error: silResult.error });
      return;
    }
    const sil = base64ToFile(silResult.image, silResult.mimeType, `ai-silhouette-${Date.now()}.png`);
    setSilhouetteFile(sil);
    goto(5);

    // ④ 提交上架（由 TemplateForm 完成提交并 redirect 到模板列表）
    setAutoState({ running: true, stage: 'submitting' });
    inject({ silhouette: sil, isActive: true, autoSubmit: true });
  };

  /** Step3 应用封面：替换 imageFiles（首图 = 封面）→ Step4 */
  const applyCover = (files: File[]) => {
    if (files.length > 0) inject({ images: files, replaceImages: true });
    goto(4);
  };

  /** Step4 应用剪影（null = 跳过）→ Step5 */
  const applySilhouette = (file: File | null) => {
    if (file) {
      setSilhouetteFile(file);
      inject({ silhouette: file });
    }
    goto(5);
  };

  const stageIndex = autoState ? AUTO_STAGES.indexOf(autoState.stage) : -1;

  /** 常驻预览面板：识别前占位，识别后由 TemplateForm portal 填充宿主 */
  const previewPanel = (
    <div className="rounded-lg border border-border bg-card p-4">
      <h3 className="text-sm font-medium text-foreground mb-3">实时预览</h3>
      {!formActivated ? (
        <div className="flex h-[480px] items-center justify-center rounded-md border border-dashed border-border px-4 text-center text-sm text-muted-foreground">
          识别完成后此处实时预览参数、姿势与封面效果
        </div>
      ) : (
        <div ref={setPreviewHost} />
      )}
    </div>
  );

  return (
    <div className="flex flex-col gap-4 xl:flex-row">
      {/* 左列：向导主体 */}
      <div className="min-w-0 flex-1 space-y-4">
        <div>
          <h1 className="text-xl font-semibold text-foreground">AI 一键建模</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            上传示例图或输入文字描述，AI 自动识别 / 构思风格、分类、相机与后期参数生成模板草稿，并可生成封面效果图与姿势剪影。
          </p>
        </div>

        {/* 顶部 stepper */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {WIZARD_STEPS.map((s, i) => (
            <div key={s.n} className="flex items-center gap-2 shrink-0">
              <button
                type="button"
                disabled={busy || s.n > maxStep}
                onClick={() => setStep(s.n)}
                className={cn(
                  'flex items-center gap-2 rounded-md px-3 py-1.5 text-sm transition-colors',
                  s.n === step
                    ? 'bg-primary text-primary-foreground'
                    : s.n < step || s.n <= maxStep
                      ? 'bg-primary/10 text-primary'
                      : 'bg-muted text-muted-foreground',
                )}
              >
                <span className="flex h-5 w-5 items-center justify-center rounded-full border border-current text-[10px]">
                  {s.n < step ? <Check size={10} /> : s.n}
                </span>
                <span className="font-medium">{s.title}</span>
              </button>
              {i < WIZARD_STEPS.length - 1 && <span className="text-muted-foreground/50">→</span>}
            </div>
          ))}
        </div>

        {/* 非 xl：预览面板置于 stepper 下方 */}
        {!isXl && previewPanel}

        {/* 全自动进度 / 失败提示 */}
        {autoState?.running && (
          <div className="rounded-md border border-primary/40 bg-primary/5 p-4">
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
              <MagicWand size={16} /> 全自动进行中：{AUTO_STAGE_TEXT[autoState.stage]}
            </div>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-primary/20">
              <div
                className="h-full bg-primary transition-all"
                style={{ width: `${((stageIndex + 1) / AUTO_STAGES.length) * 100}%` }}
              />
            </div>
          </div>
        )}
        {autoState && !autoState.running && autoState.error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            全自动在「{AUTO_STAGE_TEXT[autoState.stage]}」阶段失败：{autoState.error}
            。已停在当前步骤，可人工继续或调整后重试，已生成的草稿 / 封面已保留。
          </div>
        )}

        {/* Step1 上传示例图 */}
        {step === 1 && (
          <Card>
            <CardHeader>
              <CardTitle>上传示例图</CardTitle>
              <CardDescription>jpg / png / webp，≤ 8MB；上传后自动压缩（服务端请求体限制）。</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="hidden"
                onChange={handleExamplePick}
              />
              <div className="rounded-lg border border-dashed border-border p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium text-foreground">示例图（可选，该风格的成片参考）</p>
                    <p className="mt-0.5 text-xs text-muted-foreground">
                      AI 将分析画面中的风格 / 构图 / 光线 / 主体，生成可上线的模板表单草稿
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={busy}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    <Upload size={14} className="mr-1" /> {exampleFile ? '重新选择' : '选择图片'}
                  </Button>
                </div>
                {exampleUrl && (
                  <div className="mt-3">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={exampleUrl}
                      alt="示例图预览"
                      className="max-h-72 rounded-md border border-border object-contain"
                    />
                  </div>
                )}
              </div>

              <div className="rounded-lg border border-border p-4">
                <Label htmlFor="ai-input-text" className="text-sm font-medium text-foreground">
                  文字描述 / 创作要求（可选）
                </Label>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  无示例图时可仅用文字描述；也可与示例图同用，AI 将向你的要求倾斜
                </p>
                <textarea
                  id="ai-input-text"
                  className="mt-2 min-h-[88px] w-full rounded-md border border-border bg-background p-2 text-sm"
                  maxLength={500}
                  placeholder="例：日系田园风，午后侧逆光，少女侧身回眸，画面清新通透"
                  value={inputText}
                  onChange={(e) => handleTextChange(e.target.value)}
                />
                <div className="mt-1 text-right text-xs text-muted-foreground">{inputText.length}/500</div>
              </div>

              {errorText && (
                <div className="text-sm text-destructive">
                  {errorText}
                  {errorText.includes('AI 设置') && (
                    <>
                      {' '}前往{' '}
                      <Link className="underline underline-offset-2" href="/dashboard/ai-config">
                        AI 设置
                      </Link>{' '}
                      完成配置并启用
                    </>
                  )}
                </div>
              )}

              <div className="flex flex-wrap items-center gap-3">
                <Button disabled={!hasInput || busy} onClick={handleAnalyze}>
                  {analyzing ? '识别中…' : '开始识别'}
                </Button>
                <Button variant="outline" disabled={!hasInput || busy} onClick={runAutoAll}>
                  <MagicWand size={14} className="mr-1" /> 全自动生成并上架
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                全自动：识别 → 生图作封面 → 生成线稿剪影 → 创建并上架；任一步失败将停在对应步骤转人工，已成功的资产（草稿 / 封面）保留。
              </p>
            </CardContent>
          </Card>
        )}

        {/* Step2 风格识别结果 */}
        {step === 2 && (
          <Card>
            <CardHeader>
              <CardTitle>风格识别完成</CardTitle>
              <CardDescription>草稿已回填到下方表单，全部字段可修改。</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {warnings.length > 0 && (
                <div className="rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
                  <div className="font-medium">AI 修正了以下内容，请重点复核：</div>
                  <ul className="mt-1 list-disc space-y-0.5 pl-5">
                    {warnings.map((w, i) => (
                      <li key={i}>{w}</li>
                    ))}
                  </ul>
                </div>
              )}
              <Button disabled={busy} onClick={() => goto(3)}>
                下一步：选择封面 <ArrowRight size={14} className="ml-1" />
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Step3 封面决策 */}
        {step === 3 && (
          <StepCover
            exampleFile={exampleFile}
            draft={draft}
            candidates={candidates}
            setCandidates={setCandidates}
            busy={busy}
            onApply={applyCover}
          />
        )}

        {/* Step4 剪影决策 */}
        {step === 4 && (
          <StepSilhouette
            coverFile={candidates[0]?.file ?? exampleFile}
            exampleFile={exampleFile}
            busy={busy}
            onApply={applySilhouette}
          />
        )}

        {/* Step5 提交说明（提交按钮在 TemplateForm 底部） */}
        {step === 5 && (
          <Card>
            <CardHeader>
              <CardTitle>确认并提交</CardTitle>
              <CardDescription>
                确认无误后，在下方表单底部（最后一步「后期处理」）点击「上架」或「保存为未上架」完成提交。
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-1 text-sm text-muted-foreground">
              <p>· 封面与效果图已注入表单 Step2「效果图」区，可继续调整排序</p>
              <p>· {silhouetteFile ? 'AI 剪影已应用到姿势 1，可在表单「姿势与剪影」步骤微调位置 / 缩放' : '未生成剪影，可在表单「姿势与剪影」步骤手动补充'}</p>
              <p>· 提交成功后将跳转到模板列表</p>
            </CardContent>
          </Card>
        )}

        {/* 模板表单（识别成功后常驻，供各步骤随时查看/修改） */}
        {formActivated && (
          <div className="pt-2">
            <h2 className="mb-3 text-base font-semibold text-foreground">模板表单（AI 草稿已回填，全部可修改）</h2>
            <TemplateForm
              categories={categories}
              backendUrl={backendUrl}
              wizardMode
              aiInjection={injection}
              previewPortalTarget={previewHost}
            />
          </div>
        )}
      </div>

      {/* xl：右栏 sticky 预览 */}
      {isXl && (
        <div className="hidden w-[300px] shrink-0 xl:block">
          <div className="sticky top-6">{previewPanel}</div>
        </div>
      )}
    </div>
  );
}
