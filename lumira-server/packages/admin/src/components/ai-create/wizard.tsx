// src/components/ai-create/wizard.tsx
// AI 一键建模向导主状态机（/dashboard/templates/ai-create）
// Step1 上传示例图 → Step2 风格识别（草稿回填 TemplateForm）→ Step3 封面决策 → Step4 剪影决策 → Step5 提交
// 支持「全自动生成并上架」：识别 → 生图作封面 → 线稿剪影 → 提交，任一步失败停在对应步骤转人工

'use client';

import * as React from 'react';
import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import TemplateForm, { type TemplateFormAiInjection } from '@/components/template-form';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { compressImage } from '@/lib/image-compress';
import {
  getAiConfigAction,
} from '@/actions/ai';
import { type AiPoseProgress } from '@/lib/ai-task';
import {
  cancelPipelineJob,
  currentPipelineStage,
  fetchPipelineStatus,
  interruptionFromPollError,
  pipelineFiles,
  pipelineStageLabel,
  PipelinePollError,
  pollPipelineJob,
  poseProgressFromEvents,
  resumePipelineJob,
  startPipelineJob,
  toAnalyzeDetail,
  toPoseEvents,
  toRecogEvents,
} from '@/lib/pipeline-task';
import { clearJobRef, readJobRef, saveJobRef } from '@/lib/ai-job-storage';
import { InterruptionBanner } from './interruption-banner';
import type {
  TemplateCategory,
  AiAnalyzeTraceEntry,
  AiAnalyzeStatusResult,
  AiBatchImageTraceEvent,
  AiInterruptionInfo,
  AiPipelineEvent,
  AiPipelineJobMode,
  AiPipelineStage,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';
import { StepCover, type CoverCandidate } from './step-cover';
import { StepSilhouette } from './step-silhouette';
import { AnalyzeResultDialog } from './analyze-result-dialog';
import { GenerateProgressPanel } from './generate-progress-panel';
import { Upload } from '@phosphor-icons/react/dist/csr/Upload';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { Check } from '@phosphor-icons/react/dist/csr/Check';
import { X } from '@phosphor-icons/react/dist/csr/X';
import { CaretDown } from '@phosphor-icons/react/dist/csr/CaretDown';
import { cn } from '@/lib/utils';

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

/** AiPipelineStage → 全自动进度条阶段文案键 */
const AUTO_STAGE_OF: Record<AiPipelineStage, AutoStage> = {
  analyze: 'analyzing',
  image: 'generating-image',
  silhouette: 'generating-silhouette',
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
  const [exampleFiles, setExampleFiles] = useState<File[]>([]);
  const [exampleUrls, setExampleUrls] = useState<string[]>([]);
  const [poseReferenceFiles, setPoseReferenceFiles] = useState<File[]>([]);
  const [poseReferenceUrls, setPoseReferenceUrls] = useState<string[]>([]);
  /** Step1 示例图拖拽悬停中 */
  const [exampleDragActive, setExampleDragActive] = useState(false);
  const [inputText, setInputText] = useState('');
  const [draft, setDraft] = useState<Record<string, unknown> | null>(null);
  /** 研究管线 trace：各阶段（研究/识别/姿势面片/评分）执行轨迹；未开启时缺省 */
  const [trace, setTrace] = useState<AiAnalyzeTraceEntry[] | null>(null);
  /** 识别完成后的全量结果（含 trace/raw/research/events），供数据分析详情弹窗 */
  const [analyzeDetail, setAnalyzeDetail] = useState<AiAnalyzeStatusResult | null>(null);
  /** 识别流程实时事件流（阶段 / 提示词 / 响应，轮询增量累积），识别期间像聊天一样实时出现 */
  const [traceEvents, setTraceEvents] = useState<AiTraceEvent[]>([]);
  const [detailDialogOpen, setDetailDialogOpen] = useState(false);
  /** 模板表单当前实际效果图列表；剪影必须以此为准，避免继续使用已废弃的 Step3 候选缓存 */
  const [formImages, setFormImages] = useState<File[]>([]);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [candidates, setCandidates] = useState<CoverCandidate[]>([]);
  const [silhouetteFile, setSilhouetteFile] = useState<File | null>(null);
  const [injection, setInjection] = useState<TemplateFormAiInjection | null>(null);
  /** 首次识别成功后常驻渲染 TemplateForm（切回 Step1 也不丢表单状态） */
  const [formActivated, setFormActivated] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [errorText, setErrorText] = useState<string | null>(null);
  const [autoState, setAutoState] = useState<{ running: boolean; stage: AutoStage; error?: string } | null>(null);
  /** 全自动「生成封面」阶段实时进度（第 X/Y 张） */
  const [poseProgress, setPoseProgress] = useState<AiPoseProgress | null>(null);
  /** 生成姿势图逐张实时过程事件（喂给常驻面板「姿势图生成」Tab） */
  const [poseTraceEvents, setPoseTraceEvents] = useState<AiBatchImageTraceEvent[]>([]);
  /** 手动 Step3 生成姿势图是否进行中（喂给常驻面板「姿势图生成」Tab） */
  const [poseTraceRunning, setPoseTraceRunning] = useState(false);
  /** 进行中的 pipeline jobId（断点续跑与刷新恢复的锚点） */
  const [jobId, setJobId] = useState<string | null>(null);
  /** 本次 job 的模式（决定识别完成后如何应用产物） */
  const [jobMode, setJobMode] = useState<AiPipelineJobMode>('auto');
  /** 当前 pipeline 阶段（喂进度文案） */
  const [pipelineStage, setPipelineStage] = useState<AiPipelineStage | null>(null);
  /** 中断详情（非空 = 展示断点 Banner 与「继续」） */
  const [interruption, setInterruption] = useState<AiInterruptionInfo | null>(null);
  /** 「继续」请求中 */
  const [resuming, setResuming] = useState(false);
  /** abort 时记录当前阶段（供异常合成为中断详情） */
  const stageRef = useRef<AiPipelineStage>('analyze');
  /** 「AI 生成过程」面板本次是否被手动关闭（仅隐藏展示，不清空已采集过程） */
  const [progressPanelHidden, setProgressPanelHidden] = useState(false);
  /** Step1 附加输入：创作要求 / 姿势个数 / 人物数量（'auto' = AI 自动判断）；主文字描述复用 inputText（同时作为 textDesc 附加输入） */
  const [creationReq, setCreationReq] = useState('');
  const [poseCount, setPoseCount] = useState('auto');
  /** Step1 附加输入：人物数量（'auto' = AI 自动判断；'1'~'3' 固定指定） */
  const [subjectCount, setSubjectCount] = useState('auto');
  /** Step1「高级设置」折叠区是否展开（低频参数：补充创作要求 / 姿势个数 / 人物数量） */
  const [advancedOpen, setAdvancedOpen] = useState(false);
  /** AI 剪影可用性（配置且启用）：Step4 默认引擎 + 全自动流程剪影 engine */
  const [aiSilhouetteAvailable, setAiSilhouetteAvailable] = useState(false);
  /** 生效的剪影模型名（未单独指定 = 生图模型），Step4 展示 */
  const [silhouetteModelName, setSilhouetteModelName] = useState<string | null>(null);
  const stampRef = useRef(0);
  /** 全自动流程的中止控制器（每次 runAutoAll 新建；结束/中止后清空） */
  const abortRef = useRef<AbortController | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const handleImagesChange = useCallback((files: File[]) => setFormImages(files), []);

  /** 预览宿主（TemplateForm portal 目标）与 xl 断点（决定宿主位置：右栏 sticky / stepper 下方） */
  const [previewHost, setPreviewHost] = useState<HTMLDivElement | null>(null);
  const [isXl, setIsXl] = useState(true);
  /** 预览面板是否收起；首次断点测量时按 xl 与否设默认值（<xl 默认收起，xl 默认展开） */
  const [previewCollapsed, setPreviewCollapsed] = useState(false);
  const previewInitRef = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1280px)');
    const update = () => {
      setIsXl(mq.matches);
      if (!previewInitRef.current) {
        previewInitRef.current = true;
        setPreviewCollapsed(!mq.matches);
      }
    };
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, []);

  const busy = analyzing || Boolean(autoState?.running);
  const hasInput = exampleFiles.length > 0 || inputText.trim() !== '';
  /** 高级设置已填项数（用于折叠态提示） */
  const advancedFilledCount =
    (creationReq.trim() !== '' ? 1 : 0) + (poseCount !== 'auto' ? 1 : 0) + (subjectCount !== 'auto' ? 1 : 0);

  /** 挂载时读 AI 配置：Step4 默认引擎、全自动剪影 engine、模型名展示 */
  useEffect(() => {
    let cancelled = false;
    getAiConfigAction()
      .then((cfg) => {
        if (cancelled || cfg.configured !== true) return;
        setAiSilhouetteAvailable(cfg.enabled);
        setSilhouetteModelName(cfg.silhouetteModel ?? cfg.imageModel);
      })
      .catch(() => {
        // best-effort：失败按未配置处理（Step4 默认本地抠图）
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const inject = (partial: Omit<TemplateFormAiInjection, 'stamp'>) =>
    setInjection({ stamp: ++stampRef.current, ...partial });

  const goto = (n: number) => {
    setStep(n);
    setMaxStep((m) => Math.max(m, n));
  };

  /** 换图 / 改文字 = 重置整个下游流程 */
  const resetFlow = () => {
    setDraft(null);
    setTrace(null);
    setWarnings([]);
    setAnalyzeDetail(null);
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setPoseTraceRunning(false);
    setProgressPanelHidden(false);
    setDetailDialogOpen(false);
    setCandidates([]);
    setSilhouetteFile(null);
    setInjection(null);
    setFormActivated(false);
    setAutoState(null);
    setPoseReferenceFiles([]);
    setPoseReferenceUrls([]);
    setStep(1);
    setMaxStep(1);
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    setResuming(false);
    clearJobRef();
  };

  /** 处理已选/拖入的示例图：逐张校验 + 压缩后追加（点击选择与拖拽上传共用；换图 = 重开流程） */
  const processExampleFiles = async (files: File[]) => {
    setErrorText(null);
    const accepted: File[] = [];
    for (const file of files) {
      if (!ACCEPTED_MIME.includes(file.type)) {
        toast({ variant: 'destructive', title: '格式不支持', description: '仅支持 jpg / png / webp 图片' });
        continue;
      }
      if (file.size > MAX_EXAMPLE_BYTES) {
        toast({ variant: 'destructive', title: '文件过大', description: '示例图不能超过 8MB' });
        continue;
      }
      // Vercel Serverless 4.5MB 请求体限制：先压缩；仍 >3MB 则二次更激进压缩
      let processed = await compressImage(file, { maxDim: 1280, quality: 0.8 });
      if (processed.size > 3 * 1024 * 1024) {
        processed = await compressImage(processed, { maxDim: 1024, quality: 0.7 });
      }
      accepted.push(processed);
    }
    if (accepted.length === 0) return;
    setExampleFiles((prev) => [...prev, ...accepted]);
    setExampleUrls((prev) => [...prev, ...accepted.map((f) => URL.createObjectURL(f))]);
    // 换图 = 重新开始整个流程
    resetFlow();
  };

  /** 删除一张示例图（变更参考集合 → 重开流程） */
  const removeExampleFile = (i: number) => {
    URL.revokeObjectURL(exampleUrls[i]);
    setExampleFiles((prev) => prev.filter((_, idx) => idx !== i));
    setExampleUrls((prev) => prev.filter((_, idx) => idx !== i));
    resetFlow();
  };

  const handleExamplePick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files ? Array.from(e.target.files) : [];
    if (files.length > 0) await processExampleFiles(files);
    if (e.target) e.target.value = '';
  };

  /** 拖拽上传示例图（Step1，支持多张） */
  const handleExampleDrop = async (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setExampleDragActive(false);
    if (busy) return;
    const files = e.dataTransfer.files ? Array.from(e.dataTransfer.files) : [];
    if (files.length > 0) await processExampleFiles(files);
  };

  const handleTextChange = (v: string) => {
    setInputText(v);
    setErrorText(null);
    // 流程已启动后修改输入 = 重新开始
    if (formActivated || step > 1) resetFlow();
  };

  /** 识别请求附加输入写入 FormData（trim 后非空才传；poseCount 'auto' = AI 自动判断不传） */
  const setAnalyzeExtras = (fd: FormData) => {
    const text = inputText.trim();
    const req = creationReq.trim();
    if (text) fd.set('textDesc', text);
    if (req) fd.set('creationReq', req);
    if (poseCount !== 'auto') fd.set('poseCount', poseCount);
    if (subjectCount !== 'auto') fd.set('subjectCount', subjectCount);
  };

  /** 组装 pipeline 提交表单（识别/全自动共用：示例图 + 文字 + 附加输入 + 参考图 + jobMode/剪影选项） */
  const buildPipelineFormData = (mode: AiPipelineJobMode): FormData => {
    const fd = new FormData();
    for (const f of exampleFiles) fd.append('image', f);
    if (inputText.trim()) fd.set('text', inputText.trim());
    setAnalyzeExtras(fd);
    fd.set('jobMode', mode);
    if (mode === 'auto') {
      for (const f of poseReferenceFiles) fd.append('reference', f);
      fd.set('silMode', 'sketch');
      fd.set('silCrop', '1');
      fd.set('silEngine', aiSilhouetteAvailable ? 'ai' : 'local');
    }
    return fd;
  };

  /** 把 job 增量事件分流到两个 Tab 并更新阶段/进度（两入口共用） */
  const drivePipelineEvents = (events: AiPipelineEvent[]) => {
    setTraceEvents(toRecogEvents(events));
    setPoseTraceEvents(toPoseEvents(events));
    const p = poseProgressFromEvents(events);
    if (p) setPoseProgress(p);
  };

  /** 把识别产物回填草稿/研究过程（返回是否有草稿） */
  const applyAnalyze = (res: AiPipelineStatusResult): boolean => {
    if (!res.draft) return false;
    setDraft(res.draft);
    setWarnings(res.warnings ?? []);
    setTrace(res.trace ?? []);
    setAnalyzeDetail(toAnalyzeDetail(res));
    return true;
  };

  /** 识别完成 → 示例图作默认封面候选并回填表单（纯文模式候选为空） */
  const finishAnalyzeOnly = (res: AiPipelineStatusResult) => {
    if (!applyAnalyze(res)) {
      setErrorText('识别结果为空，请重试');
      return;
    }
    if (exampleFiles.length > 0) {
      setCandidates(
        exampleFiles.map((f, i) => ({
          id: i === 0 ? 'example' : `example-${i}`,
          file: f,
          url: URL.createObjectURL(f),
          source: 'example',
        })),
      );
      inject({ json: res.draft!, images: exampleFiles, replaceImages: true });
    } else {
      setCandidates([]);
      inject({ json: res.draft! });
    }
    setFormActivated(true);
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    clearJobRef();
    goto(2);
  };

  /** 手动识别（analyze-only job）：只产出草稿，后续步骤走既有手动端点 */
  const handleAnalyze = async () => {
    if (!hasInput) return;
    setAnalyzing(true);
    setErrorText(null);
    setInterruption(null);
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setProgressPanelHidden(false);
    setJobMode('analyze-only');
    stageRef.current = 'analyze';
    try {
      const jobIdLocal = await startPipelineJob(buildPipelineFormData('analyze-only'));
      setJobId(jobIdLocal);
      saveJobRef({ jobId: jobIdLocal, mode: 'analyze-only' });
      const res = await pollPipelineJob(jobIdLocal, {
        onEvents: drivePipelineEvents,
        // 内联 onStatus：避免引用 jobMode state 造成 stale closure（此时 jobMode 仍是上一次的值）
        onStatus: (r) => {
          const stage = currentPipelineStage(r);
          stageRef.current = stage;
          setPipelineStage(stage);
        },
      });
      if (res.status === 'error') {
        // 阶段失败：保留已完成草稿（若可用则允许直接进下一步），展示详细中断并提供「继续」
        if (applyAnalyze(res)) setFormActivated(true);
        setInterruption(res.error ?? interruptionFromPollError(new Error('识别失败'), currentPipelineStage(res)));
        const msg = res.error?.message || '识别失败';
        setErrorText(msg);
        toast({ variant: 'destructive', title: '识别中断', description: msg });
        return;
      }
      finishAnalyzeOnly(res);
    } catch (e) {
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      setErrorText(info.message);
      toast({ variant: 'destructive', title: '识别失败', description: info.message });
    } finally {
      setAnalyzing(false);
    }
  };

  /** 全自动 job 跑完后应用产物：候选封面 + 注入表单 + 剪影 + 触发提交 */
  const finishAuto = (res: AiPipelineStatusResult) => {
    if (!applyAnalyze(res)) {
      setAutoState(null);
      setErrorText('识别结果为空，请重试');
      return;
    }
    setFormActivated(true);
    const draftLocal = res.draft!;
    const exampleCandidates: CoverCandidate[] = exampleFiles.map((f, i) => ({
      id: i === 0 ? 'example' : `example-${i}`,
      file: f,
      url: URL.createObjectURL(f),
      source: 'example',
    }));
    const poseFiles = pipelineFiles(res.poseImages);
    if (poseFiles.length === 0) {
      setCandidates(exampleCandidates);
      if (exampleFiles.length > 0) inject({ json: draftLocal, images: exampleFiles, replaceImages: true });
      else inject({ json: draftLocal });
      goto(3);
      setAutoState({ running: false, stage: 'generating-image', error: '姿势图生成失败' });
      return;
    }
    const generatedCandidates: CoverCandidate[] = poseFiles.map((p) => ({
      id: `ai-${Date.now()}-${p.index}`,
      file: p.file,
      url: URL.createObjectURL(p.file),
      source: 'ai',
    }));
    setCandidates([...generatedCandidates, ...exampleCandidates]);
    inject({ json: draftLocal, images: poseFiles.map((p) => p.file), replaceImages: true });

    const silFiles = pipelineFiles(res.silhouetteImages);
    if (silFiles.length !== poseFiles.length) {
      goto(4);
      setAutoState({
        running: false,
        stage: 'generating-silhouette',
        error: res.silhouetteErrors[0]?.error || '部分剪影生成失败',
      });
      return;
    }
    setSilhouetteFile(silFiles[0]!.file);
    goto(5);
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    clearJobRef();
    setAutoState({ running: true, stage: 'submitting' });
    inject({ silhouettes: silFiles.map((p) => p.file), isActive: true, autoSubmit: true });
  };

  /** 全自动：一个 auto job 提交后只轮询（识别 → 姿势图 → 剪影 → 触发上架） */
  const runAutoAll = async () => {
    if (!hasInput) return;
    setErrorText(null);
    setInterruption(null);
    const controller = new AbortController();
    abortRef.current = controller;
    const { signal } = controller;
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setPoseTraceRunning(false);
    setPoseProgress(null);
    setProgressPanelHidden(false);
    setJobMode('auto');
    stageRef.current = 'analyze';
    setPipelineStage('analyze');
    setAutoState({ running: true, stage: 'analyzing' });
    try {
      const jobIdLocal = await startPipelineJob(buildPipelineFormData('auto'));
      setJobId(jobIdLocal);
      saveJobRef({ jobId: jobIdLocal, mode: 'auto' });
      const res = await pollPipelineJob(jobIdLocal, {
        signal,
        onEvents: drivePipelineEvents,
        onStatus: (r) => {
          const stage = currentPipelineStage(r);
          stageRef.current = stage;
          setPipelineStage(stage);
          setAutoState({ running: true, stage: AUTO_STAGE_OF[stage] });
        },
      });
      if (res.status === 'error') {
        applyAnalyze(res);
        setFormActivated(true);
        const info = res.error ?? interruptionFromPollError(new Error('生成中断'), currentPipelineStage(res));
        setInterruption(info);
        const stage = currentPipelineStage(res);
        stageRef.current = stage;
        setAutoState({ running: false, stage: AUTO_STAGE_OF[stage], error: info.message });
        // 已生成的姿势图/剪影尽量保留在候选与表单里
        if (res.poseImages.length > 0) {
          const poseFiles = pipelineFiles(res.poseImages);
          const exampleCandidates: CoverCandidate[] = exampleFiles.map((f, i) => ({
            id: i === 0 ? 'example' : `example-${i}`,
            file: f,
            url: URL.createObjectURL(f),
            source: 'example',
          }));
          setCandidates([
            ...poseFiles.map((p) => ({
              id: `ai-${Date.now()}-${p.index}`,
              file: p.file,
              url: URL.createObjectURL(p.file),
              source: 'ai' as const,
            })),
            ...exampleCandidates,
          ]);
          inject({ json: res.draft!, images: poseFiles.map((p) => p.file), replaceImages: true });
          setFormActivated(true);
          // 已生成可用姿势图且失败在生图阶段：推进到封面选择步骤，让用户基于已产出图继续
          if (stage === 'image') goto(3);
        }
        toast({ variant: 'destructive', title: `生成中断（${info.code}）`, description: info.message });
        return;
      }
      finishAuto(res);
    } catch (e) {
      const aborted = e instanceof PipelinePollError && e.code === 'aborted';
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      setAutoState({ running: false, stage: AUTO_STAGE_OF[stageRef.current], error: info.message });
      if (!aborted) {
        toast({
          variant: 'destructive',
          title: `全自动在「${AUTO_STAGE_TEXT[AUTO_STAGE_OF[stageRef.current]]}」阶段异常`,
          description: info.message,
        });
      }
    } finally {
      abortRef.current = null;
    }
  };

  /** 断点「继续」：优先重连（后端仍在跑），否则从失败阶段重跑并复用已完成成果 */
  const resumeFromInterruption = async () => {
    if (!jobId) return;
    setResuming(true);
    const wasAuto = jobMode === 'auto';
    const controller = new AbortController();
    abortRef.current = controller;
    try {
      // 后端语义：running → 仅重连；error → 从失败阶段重跑并复用已完成成果。前端只需要结果
      await resumePipelineJob(jobId);
      setInterruption(null);
      if (!wasAuto) setAnalyzing(true);
      else setAutoState({ running: true, stage: AUTO_STAGE_OF[stageRef.current] });
      const res = await pollPipelineJob(jobId, {
        signal: controller.signal,
        onEvents: drivePipelineEvents,
        onStatus: (s) => {
          const stage = currentPipelineStage(s);
          stageRef.current = stage;
          setPipelineStage(stage);
          if (wasAuto) setAutoState({ running: true, stage: AUTO_STAGE_OF[stage] });
        },
      });
      if (res.status === 'error') {
        applyAnalyze(res);
        const info = res.error ?? interruptionFromPollError(new Error('续跑中断'), currentPipelineStage(res));
        setInterruption(info);
        if (wasAuto) setAutoState({ running: false, stage: AUTO_STAGE_OF[currentPipelineStage(res)], error: info.message });
        else setErrorText(info.message);
        return;
      }
      if (wasAuto) finishAuto(res);
      else finishAnalyzeOnly(res);
    } catch (e) {
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      if (wasAuto) setAutoState({ running: false, stage: AUTO_STAGE_OF[stageRef.current], error: info.message });
      else setErrorText(info.message);
    } finally {
      setResuming(false);
      setAnalyzing(false);
      abortRef.current = null;
    }
  };

  /** 放弃本次生成：删除后端 job + 清本地引用 + 重置流程 */
  const discardJob = async () => {
    if (jobId) {
      try {
        await cancelPipelineJob(jobId);
      } catch {
        // 删除失败不影响本地重置（后端有 1 小时 TTL 兜底）
      }
    }
    setInterruption(null);
    resetFlow();
  };

  /** 挂载时恢复上次未完成的 job：running → 重连轮询；error → 展示断点；done → 回填后清理 */
  useEffect(() => {
    const ref = readJobRef();
    if (!ref) return;
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetchPipelineStatus(ref.jobId, 0, true);
        if (cancelled) return;
        setJobId(ref.jobId);
        setJobMode(res.mode);
        const stage = currentPipelineStage(res);
        stageRef.current = stage;
        setPipelineStage(stage);
        if (res.mode === 'auto') setAutoState({ running: res.status === 'running', stage: AUTO_STAGE_OF[stage] });
        else setAnalyzing(res.status === 'running');
        drivePipelineEvents(res.events);
        if (res.status === 'error') {
          applyAnalyze(res);
          setInterruption(res.error ?? interruptionFromPollError(new Error('生成中断'), stage));
          return;
        }
        if (res.status === 'done') {
          if (res.mode === 'auto') finishAuto(res);
          else finishAnalyzeOnly(res);
          return;
        }
        // running：立即重连轮询（job 输入在后端，无需重传）
        const polled = await pollPipelineJob(ref.jobId, {
          onEvents: drivePipelineEvents,
          onStatus: (r) => {
            const s = currentPipelineStage(r);
            stageRef.current = s;
            setPipelineStage(s);
            if (res.mode === 'auto') setAutoState({ running: true, stage: AUTO_STAGE_OF[s] });
          },
        });
        if (cancelled) return;
        if (polled.status === 'error') {
          applyAnalyze(polled);
          setInterruption(polled.error ?? interruptionFromPollError(new Error('生成中断'), currentPipelineStage(polled)));
          return;
        }
        if (polled.mode === 'auto') finishAuto(polled);
        else finishAnalyzeOnly(polled);
      } catch (e) {
        if (cancelled) return;
        // 失效/网络等问题：保留 job 引用并展示断点，让用户决定「继续」或「重新开始」
        setJobId(ref.jobId);
        setJobMode(ref.mode);
        setInterruption(interruptionFromPollError(e, stageRef.current));
      } finally {
        if (!cancelled) {
          setAnalyzing(false);
          setAutoState((prev) => (prev ? { ...prev, running: false } : prev));
        }
      }
    })();
    return () => {
      cancelled = true;
    };
    // 仅在挂载时恢复一次（jobId 锚点来自 localStorage，不需要进依赖）
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /** Step3 应用封面：替换 imageFiles（首图 = 封面）→ Step4 */
  const applyCover = (files: File[]) => {
    if (files.length > 0) inject({ images: files, replaceImages: true });
    goto(4);
  };

  /** Step4 应用剪影（null = 跳过）→ Step5 */
  const applySilhouette = (files: File[] | null) => {
    if (files && files.length > 0) {
      setSilhouetteFile(files[0]);
      inject({ silhouettes: files });
    }
    goto(5);
  };

  const stageIndex = autoState ? AUTO_STAGES.indexOf(autoState.stage) : -1;

  /** 面板收拢态展示的进度文案（运行中优先，缺省回落 Tab 计数；失败时显示「已失败」） */
  const progressStatusText = analyzing
    ? `正在识别…${pipelineStage ? `（${pipelineStageLabel(pipelineStage)}）` : ''}`
    : autoState?.running
      ? `进行中 · ${AUTO_STAGE_TEXT[autoState.stage]}${
          autoState.stage === 'generating-image' && poseProgress
            ? ` ${poseProgress.current}/${poseProgress.total}`
            : ''
        }`
      : interruption
        ? `已中断 · ${interruption.code}`
        : errorText
          ? '识别失败'
          : autoState?.error
            ? '已失败'
            : null;

  /** 常驻预览面板：识别前占位，识别后由 TemplateForm portal 填充宿主 */
  const previewPanel = (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h3 className="text-sm font-medium text-foreground">实时预览</h3>
        <button
          type="button"
          onClick={() => setPreviewCollapsed((o) => !o)}
          className="text-xs text-muted-foreground hover:text-foreground"
        >
          {previewCollapsed ? '展开' : '收起'}
        </button>
      </div>
      {/* 折叠用 hidden 而非卸载，保住 TemplateForm 的 portal 宿主 */}
      <div className={cn(previewCollapsed && 'hidden')}>
        {!formActivated ? (
          <div className="flex h-[480px] items-center justify-center rounded-md border border-dashed border-border px-4 text-center text-sm text-muted-foreground">
            识别完成后此处实时预览参数、姿势与封面效果
          </div>
        ) : (
          <div ref={setPreviewHost} />
        )}
      </div>
      {previewCollapsed && (
        <div className="rounded-md border border-dashed border-border px-4 py-2 text-center text-xs text-muted-foreground">
          预览已收起
        </div>
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

        {/* 常驻 AI 生成过程面板（步骤栏上方、跨步骤可见；运行中展开/结束后收拢；关闭仅隐藏不清空） */}
        {!progressPanelHidden && (
          <GenerateProgressPanel
            recogEvents={traceEvents}
            recogRunning={analyzing || (autoState?.running === true && autoState.stage === 'analyzing')}
            poseEvents={poseTraceEvents}
            poseRunning={poseTraceRunning || (autoState?.running === true && autoState.stage === 'generating-image')}
            statusText={progressStatusText}
            hadError={Boolean(errorText) || Boolean(autoState?.error)}
            onOpenDetail={() => setDetailDialogOpen(true)}
            onClose={() => setProgressPanelHidden(true)}
          />
        )}

        {/* 顶部 stepper */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {WIZARD_STEPS.map((s, i) => {
            const reached = s.n <= maxStep;
            const isCurrent = s.n === step;
            const isDone = s.n < step;
            return (
              <div key={s.n} className="flex items-center gap-2 shrink-0">
                <button
                  type="button"
                  disabled={busy || !reached}
                  onClick={() => setStep(s.n)}
                  className={cn(
                    'flex items-center gap-2 rounded-md px-3 py-1.5 text-sm transition-colors',
                    isCurrent
                      ? 'bg-primary text-primary-foreground'
                      : isDone
                        ? 'bg-primary/10 text-primary'
                        : reached
                          ? 'border border-border text-foreground'
                          : 'bg-muted text-muted-foreground',
                  )}
                >
                  <span className="flex h-5 w-5 items-center justify-center rounded-full border border-current text-[10px]">
                    {isDone ? <Check size={10} /> : s.n}
                  </span>
                  <span className="font-medium">{s.title}</span>
                </button>
                {i < WIZARD_STEPS.length - 1 && (
                  <span className={cn(isDone ? 'text-primary/40' : 'text-muted-foreground/50')}>→</span>
                )}
              </div>
            );
          })}
        </div>

        {/* 非 xl：预览面板置于 stepper 下方 */}
        {!isXl && previewPanel}

        {/* 全自动进度 / 失败提示 */}
        {autoState?.running && (
          <div className="rounded-md border border-primary/40 bg-primary/5 p-4">
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
              <MagicWand size={16} /> 全自动进行中：{AUTO_STAGE_TEXT[autoState.stage]}
              {autoState.stage === 'generating-image' && poseProgress
                ? `（第 ${poseProgress.current}/${poseProgress.total} 张）`
                : ''}
              <button
                type="button"
                onClick={() => abortRef.current?.abort()}
                className="ml-auto shrink-0 rounded border border-primary/40 px-2 py-0.5 text-xs text-primary transition-colors hover:bg-primary/10"
              >
                中止
              </button>
            </div>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-primary/20">
              <div
                className="h-full bg-primary transition-all"
                style={{
                  width: `${
                    autoState.stage === 'generating-image' && poseProgress
                      ? (poseProgress.current / Math.max(poseProgress.total, 1)) * 100
                      : ((stageIndex + 1) / AUTO_STAGES.length) * 100
                  }%`,
                }}
              />
            </div>
          </div>
        )}
        {interruption && !busy && (
          <InterruptionBanner
            info={interruption}
            resuming={resuming}
            canResume={Boolean(jobId)}
            onResume={resumeFromInterruption}
            onRestart={resetFlow}
            onDismiss={discardJob}
          />
        )}
        {autoState && !autoState.running && autoState.error && !interruption && (
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
              <CardDescription>jpg / png / webp，≤ 8MB；可多张，上传后自动压缩（服务端请求体限制）。</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                multiple
                className="hidden"
                onChange={handleExamplePick}
              />
              <div
                className={cn(
                  'rounded-lg border border-dashed p-4 transition-colors',
                  exampleDragActive ? 'border-primary bg-primary/5' : 'border-border',
                )}
                onDragOver={(e) => {
                  e.preventDefault();
                  if (!busy) setExampleDragActive(true);
                }}
                onDragLeave={(e) => {
                  // 仅当离开整个拖拽区域时才取消高亮（进入子元素会触发 leave）
                  if (e.currentTarget.contains(e.relatedTarget as Node)) return;
                  setExampleDragActive(false);
                }}
                onDrop={handleExampleDrop}
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium text-foreground">示例图（可选，该风格的成片参考，可多张）</p>
                    <p className="mt-0.5 text-xs text-muted-foreground">
                      AI 将分析全部画面中的风格 / 构图 / 光线 / 主体，生成可上线的模板表单草稿
                    </p>
                    <p className="mt-1 text-xs text-muted-foreground/80">支持多张；或将图片拖拽到此处上传</p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={busy}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    <Upload size={14} className="mr-1" /> {exampleFiles.length > 0 ? '继续添加' : '选择图片'}
                  </Button>
                </div>
                {exampleUrls.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-2">
                    {exampleUrls.map((url, i) => (
                      <div key={i} className="relative">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={url}
                          alt={`示例图 ${i + 1}`}
                          className="h-24 w-24 rounded-md border object-cover"
                        />
                        <button
                          type="button"
                          title={`删除第 ${i + 1} 张示例图`}
                          aria-label={`删除第 ${i + 1} 张示例图`}
                          className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full bg-foreground/70 text-background transition-colors hover:bg-destructive"
                          onClick={() => removeExampleFile(i)}
                        >
                          <X size={10} />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* 附加输入：低频参数收进折叠区，避免与主文字描述语义重复 */}
              <div className="rounded-lg border border-border">
                <button
                  type="button"
                  onClick={() => setAdvancedOpen((o) => !o)}
                  className="flex w-full items-center gap-2 px-4 py-3 text-left"
                >
                  <span className="text-sm font-medium text-foreground">高级设置（可选）</span>
                  {advancedFilledCount > 0 && (
                    <span className="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] text-primary">
                      已填 {advancedFilledCount} 项
                    </span>
                  )}
                  <CaretDown
                    size={14}
                    className={cn('ml-auto text-muted-foreground transition-transform', advancedOpen && 'rotate-180')}
                  />
                </button>
                {advancedOpen && (
                  <div className="space-y-4 border-t border-border p-4">
                    <div className="space-y-2">
                      <Label htmlFor="ai-creation-req">补充创作要求（可选）</Label>
                      <Textarea
                        id="ai-creation-req"
                        value={creationReq}
                        onChange={(e) => setCreationReq(e.target.value)}
                        placeholder="对 AI 的额外创作指令，如「偏胶片感」「避开正午顶光」"
                        rows={3}
                        disabled={busy}
                      />
                    </div>

                    <div className="space-y-2 md:max-w-xs">
                      <Label>姿势个数</Label>
                      <Select value={poseCount} onValueChange={setPoseCount} disabled={busy}>
                        <SelectTrigger className="w-full">
                          <SelectValue placeholder="AI 自动判断" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="auto">AI 自动判断</SelectItem>
                          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => (
                            <SelectItem key={n} value={String(n)}>
                              固定 {n} 个
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <p className="text-xs text-muted-foreground">
                        选「AI 自动判断」时，将结合文字描述 / 补充创作要求（含示例图中可见的文字要求）在 1~9 个范围内决定姿势数量
                      </p>
                    </div>

                    <div className="space-y-2 md:max-w-xs">
                      <Label>人物数量</Label>
                      <Select value={subjectCount} onValueChange={setSubjectCount} disabled={busy}>
                        <SelectTrigger className="w-full">
                          <SelectValue placeholder="AI 自动判断" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="auto">AI 自动判断</SelectItem>
                          <SelectItem value="1">1 人</SelectItem>
                          <SelectItem value="2">2 人（情侣 / 双人）</SelectItem>
                          <SelectItem value="3">3 人（合影 / 全家福）</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                )}
              </div>

              <div className="rounded-lg border border-border p-4">
                <Label htmlFor="ai-input-text" className="text-sm font-medium text-foreground">
                  文字描述（可选）
                </Label>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  无示例图时可仅用文字描述；也可与示例图同用，AI 将向你的要求倾斜
                </p>
                <textarea
                  id="ai-input-text"
                  className="mt-2 min-h-[88px] w-full rounded-md border border-border bg-background p-2 text-sm"
                  maxLength={1500}
                  placeholder="例：日系田园风，午后侧逆光，少女侧身回眸，画面清新通透"
                  value={inputText}
                  onChange={(e) => handleTextChange(e.target.value)}
                />
                <div className="mt-1 text-right text-xs text-muted-foreground">{inputText.length}/1500</div>
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

              <div className="flex flex-wrap items-start gap-4">
                <div className="space-y-1">
                  <Button disabled={!hasInput || busy} onClick={handleAnalyze}>
                    {analyzing ? '识别中…' : '开始识别'}
                  </Button>
                  <p className="text-xs text-muted-foreground">只产出草稿，后续步骤可逐步确认</p>
                </div>
                <div className="space-y-1">
                  <Button variant="outline" disabled={!hasInput || busy} onClick={runAutoAll}>
                    <MagicWand size={14} className="mr-1" /> 一键生成并上架
                  </Button>
                  <p className="max-w-xs text-xs text-muted-foreground">
                    识别 → 生图作封面 → 线稿剪影 → 创建上架；任一步失败停在对应步骤转人工，已成功资产保留
                  </p>
                </div>
              </div>
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

              {/* 研究过程 / 质量分（orchestrator trace；缺省降级为提示） */}
              <div className="rounded-md border border-border p-3">
                <div className="flex items-center justify-between">
                  <h4 className="text-sm font-semibold text-foreground">研究过程 / 质量分</h4>
                  {trace && trace.some((t) => typeof t.score === 'number') && (
                    <span className="text-xs text-muted-foreground">
                      最终质量分：
                      {trace
                        .filter((t) => typeof t.score === 'number')
                        .slice(-1)[0]?.score?.toFixed(2)}
                    </span>
                  )}
                </div>
                {!trace || trace.length === 0 ? (
                  <p className="mt-1 text-xs text-muted-foreground">
                    本次识别走标准单次路径（研究管线未启用）。如在「AI 设置」开启「趋势研究」开关并配置搜索来源，可获取研究来源与逐阶段质量分。
                  </p>
                ) : (
                  <ol className="mt-2 space-y-1.5">
                    {trace.map((t, i) => {
                      const label =
                        t.step === 'research' ? '趋势研究'
                        : t.step === 'describe' ? '示例图识别'
                        : t.step === 'poseRefSheet' ? '姿势参考面片'
                        : t.step === 'paramValidate' ? '参数校准'
                        : t.step === 'imageScore' ? '质量评分'
                        : t.step;
                      const isSkip = String(t.resultBrief).startsWith('skip');
                      const isFail = String(t.resultBrief).startsWith('fail');
                      return (
                        <li key={i} className="flex items-start gap-2 text-xs">
                          <span className="mt-0.5 text-muted-foreground">{i + 1}.</span>
                          <div className="min-w-0 flex-1">
                            <div className="flex items-center gap-2">
                              <span className="font-medium text-foreground">{label}</span>
                              {typeof t.score === 'number' && (
                                <span className="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] text-primary">
                                  {t.score.toFixed(2)}
                                </span>
                              )}
                            </div>
                            <div className={`truncate ${isFail ? 'text-destructive' : isSkip ? 'text-muted-foreground' : 'text-muted-foreground'}`}>
                              {t.resultBrief}
                            </div>
                          </div>
                        </li>
                      );
                    })}
                  </ol>
                )}
              </div>
              <div className="flex flex-wrap items-center gap-3">
                <Button disabled={busy} onClick={() => goto(3)}>
                  下一步：选择封面 <ArrowRight size={14} className="ml-1" />
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Step3 封面决策 */}
        {step === 3 && (
          <StepCover
            exampleFiles={exampleFiles}
            referenceFiles={poseReferenceFiles}
            referenceUrls={poseReferenceUrls}
            onReferenceChange={(files, urls) => {
              setPoseReferenceFiles(files);
              setPoseReferenceUrls(urls);
            }}
            draft={draft}
            research={analyzeDetail?.research ?? null}
            researchBrief={analyzeDetail?.researchBrief ?? null}
            researchVision={analyzeDetail?.researchVision ?? null}
            candidates={candidates}
            setCandidates={setCandidates}
            busy={busy}
            onApply={applyCover}
            onPoseEvents={setPoseTraceEvents}
            onPoseRunningChange={setPoseTraceRunning}
          />
        )}

        {/* Step4 剪影决策 */}
        {step === 4 && (
          <StepSilhouette
            images={formImages}
            busy={busy}
            onApply={applySilhouette}
            aiAvailable={aiSilhouetteAvailable}
            silhouetteModelName={silhouetteModelName}
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
              <p>· {silhouetteFile ? '剪影已按源图顺序应用到各姿势，可在表单「姿势与剪影」步骤微调位置 / 缩放' : '未生成剪影，可在表单「姿势与剪影」步骤手动补充'}</p>
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
              onImagesChange={handleImagesChange}
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

      {/* 识别结果详情弹窗（数据分析：过程 trace / 原始结构数据 / 参考 URL） */}
      <AnalyzeResultDialog
        open={detailDialogOpen}
        onOpenChange={setDetailDialogOpen}
        result={analyzeDetail}
      />
    </div>
  );
}
