'use client';

import * as React from 'react';
import { useState, useTransition } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { FileUpload } from '@/components/ui/file-upload';
import { compressImage } from '@/lib/image-compress';
import { toAssetUrl } from '@/lib/asset-url';
import { Upload as UploadIcon, ArrowLeft, ArrowRight, Check } from '@phosphor-icons/react/dist/ssr';
import { useToast } from '@/hooks/use-toast';
import { createTemplate, updateTemplate } from '@/actions/templates';
import SilhouettePreview from '@/components/silhouette-preview';
import PhonePreview from '@/components/phone-preview';
import type { AdminTemplateDetail, TemplateCategory } from '@/types/admin';

const OVERLAY_TYPES = ['rule_of_thirds', 'golden_ratio', 'diagonal', 'grid', 'leading_lines', 'center', 'none'] as const;
const ASPECT_RATIOS = ['3:4', '4:3', '16:9', '1:1', '9:16'] as const;
const SILHOUETTE_TYPES = ['builtin', 'image', 'svg'] as const;
const ISO_MODES = ['auto', 'manual'] as const;
const WHITE_BALANCES = ['daylight', 'cloudy', 'shade', 'tungsten', 'fluorescent', 'custom'] as const;
const FLASH_MODES = ['off', 'on', 'auto', 'torch'] as const;
const FOCUS_MODES = ['auto', 'manual', 'continuous'] as const;
const LENS_SUGGESTIONS = ['wide', 'main', 'telephoto', 'ultra_wide'] as const;
const LUTS = ['none', 'cinematic', 'vintage', 'bw', 'warm_film', 'cool_film', 'pastel', 'fuji', 'portrait', 'japanese', 'cyberpunk', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan'] as const;

const LUT_LABELS: Record<string, string> = {
  none: '原图',
  cinematic: '电影感',
  vintage: '复古胶片',
  bw: '黑白',
  warm_film: '暖色胶片',
  cool_film: '冷色胶片',
  pastel: '柔色',
  fuji: '富士感',
  portrait: '人像',
  japanese: '日系',
  cyberpunk: '赛博朋克',
  sepia_classic: '褐调',
  mist: '薄雾',
  rouge: '胭脂',
  twilight: '暮光',
  cyan: '青调',
};

const NONE_VALUE = '__none__';

const schema = z.object({
  name: z.string().min(1, '请输入模板名称').max(100),
  category: z.string().min(1, '请选择分类'),
  classificationStyle: z.string().optional().default(NONE_VALUE),
  classificationMethod: z.string().optional().default(NONE_VALUE),
  price: z.coerce.number().int().min(0, '价格不能为负'),
  description: z.string().optional().default(''),
  author: z.string().optional().default('Lumira'),
  tags: z.string().optional().default(''),
  referenceSource: z.string().optional().default(''),
  silhouetteType: z.enum(SILHOUETTE_TYPES).default('builtin'),
  silhouetteBuiltinKey: z.string().optional().default(''),
  poseDescription: z.string().optional().default(''),
  posePositionX: z.coerce.number().min(0).max(1).default(0.5),
  posePositionY: z.coerce.number().min(0).max(1).default(0.5),
  poseScale: z.coerce.number().min(0.3).max(2.5).default(1.0),
  poseRotation: z.coerce.number().min(-45).max(45).default(0),
  overlayType: z.enum(OVERLAY_TYPES).default('rule_of_thirds'),
  gridType: z.string().optional().default(''),
  aspectRatio: z.string().default('3:4'),
  opacity: z.coerce.number().min(0).max(1).default(0.5),
  compositionDescription: z.string().optional().default(''),
  exposureCompensation: z.coerce.number().min(-3).max(3).default(0),
  isoMode: z.enum(ISO_MODES).default('auto'),
  iso: z.coerce.number().int().min(0).default(200),
  shutterSpeed: z.string().default('1/200'),
  whiteBalance: z.enum(WHITE_BALANCES).default('daylight'),
  whiteBalanceK: z.coerce.number().int().min(0).default(5500),
  flashMode: z.enum(FLASH_MODES).default('off'),
  focusMode: z.enum(FOCUS_MODES).default('auto'),
  lensType: z.string().optional().default(''),
  lensSuggestion: z.enum(LENS_SUGGESTIONS).default('main'),
  lightDirection: z.string().optional().default(''),
  shootingDistance: z.string().optional().default(''),
  background: z.string().optional().default(''),
  props: z.string().optional().default(''),
  bestTime: z.string().optional().default(''),
  tips: z.string().optional().default(''),
  cropRatio: z.string().default('3:4'),
  colorBrightness: z.coerce.number().int().min(-100).max(100).default(0),
  colorContrast: z.coerce.number().int().min(-100).max(100).default(0),
  colorSaturation: z.coerce.number().int().min(-100).max(100).default(0),
  colorTemperature: z.coerce.number().int().min(-100).max(100).default(0),
  colorTint: z.coerce.number().int().min(-100).max(100).default(0),
  smoothStrength: z.coerce.number().int().min(0).max(100).default(0),
  sharpen: z.coerce.number().int().min(0).max(100).default(0),
  vignette: z.coerce.number().int().min(0).max(100).default(0),
  grain: z.coerce.number().int().min(0).max(100).default(0),
  lut: z.enum(LUTS).default('none'),
  sortOrder: z.coerce.number().int().default(0),
  isActive: z.boolean().default(true),
});

type FormValues = z.infer<typeof schema>;

const STEPS = [
  { title: '基本信息', desc: '名称、分类、价格等' },
  { title: '封面与剪影', desc: '上传封面图、设置剪影' },
  { title: '构图', desc: '叠加层、网格、不透明度' },
  { title: '相机参数', desc: '曝光、ISO、快门、白平衡等' },
  { title: '场景引导', desc: '光线、距离、背景、提示' },
  { title: '后期处理', desc: '裁剪、色彩、滤镜等' },
] as const;

function parseCommaList(raw: string | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(/[,，\n]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function num(v: unknown, fallback = 0): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

interface TemplateFormProps {
  categories: TemplateCategory[];
  initial?: AdminTemplateDetail;
  templateId?: string;
  backendUrl?: string;
}

export default function TemplateForm({
  categories,
  initial,
  templateId,
  backendUrl = 'http://localhost:3000',
}: TemplateFormProps) {
  const { toast } = useToast();
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [silhouetteFile, setSilhouetteFile] = useState<File | null>(null);
  const [pptplFile, setPptplFile] = useState<File | null>(null);
  const pptplInputRef = React.useRef<HTMLInputElement>(null);

  const isEdit = Boolean(templateId && initial);

  const buildDefaults = (): FormValues => {
    if (!initial) {
      const typeCategories = categories.filter((c) => c.level === 1);
      return {
        name: '',
        category: typeCategories[0]?.key ?? 'portrait',
        classificationStyle: NONE_VALUE,
        classificationMethod: NONE_VALUE,
        price: 0,
        description: '',
        author: 'Lumira',
        tags: '',
        referenceSource: '',
        silhouetteType: 'builtin',
        silhouetteBuiltinKey: '',
        poseDescription: '',
        posePositionX: 0.5,
        posePositionY: 0.5,
        poseScale: 1.0,
        poseRotation: 0,
        overlayType: 'rule_of_thirds',
        gridType: '',
        aspectRatio: '3:4',
        opacity: 0.5,
        compositionDescription: '',
        exposureCompensation: 0,
        isoMode: 'auto',
        iso: 200,
        shutterSpeed: '1/200',
        whiteBalance: 'daylight',
        whiteBalanceK: 5500,
        flashMode: 'off',
        focusMode: 'auto',
        lensType: '',
        lensSuggestion: 'main',
        lightDirection: '',
        shootingDistance: '',
        background: '',
        props: '',
        bestTime: '',
        tips: '',
        cropRatio: '3:4',
        colorBrightness: 0,
        colorContrast: 0,
        colorSaturation: 0,
        colorTemperature: 0,
        colorTint: 0,
        smoothStrength: 0,
        sharpen: 0,
        vignette: 0,
        grain: 0,
        lut: 'none',
        sortOrder: 0,
        isActive: true,
      };
    }
    const composition = (initial.composition ?? {}) as Record<string, unknown>;
    const pose = (initial.pose ?? {}) as Record<string, unknown>;
    const silhouette = (pose.silhouette ?? {}) as Record<string, unknown>;
    const position = (pose.position ?? {}) as Record<string, unknown>;
    const camera = (initial.camera ?? {}) as Record<string, unknown>;
    const sceneGuide = (initial.sceneGuide ?? {}) as Record<string, unknown>;
    const postProcess = (initial.postProcess ?? {}) as Record<string, unknown>;
    const color = (postProcess.color ?? {}) as Record<string, unknown>;
    return {
      name: initial.name,
      category: initial.category,
      classificationStyle: initial.classification?.style || NONE_VALUE,
      classificationMethod: initial.classification?.method || NONE_VALUE,
      price: initial.price,
      description: initial.description ?? '',
      author: initial.author ?? 'Lumira',
      tags: (initial.tags ?? []).join(', '),
      referenceSource: initial.referenceSource ?? '',
      silhouetteType: (silhouette.type as FormValues['silhouetteType']) ?? 'builtin',
      silhouetteBuiltinKey: (silhouette.data as string) ?? '',
      poseDescription: (pose.description as string) ?? '',
      posePositionX: num(position.x, 0.5),
      posePositionY: num(position.y, 0.5),
      poseScale: num(pose.scale, 1.0),
      poseRotation: num(pose.rotation, 0),
      overlayType: (composition.overlayType as FormValues['overlayType']) ?? 'rule_of_thirds',
      gridType: (composition.gridType as string) ?? '',
      aspectRatio: (composition.aspectRatio as string) ?? '3:4',
      opacity: num(composition.opacity, 0.5),
      compositionDescription: (composition.description as string) ?? '',
      exposureCompensation: num(camera.exposureCompensation, 0),
      isoMode: (camera.isoMode as FormValues['isoMode']) ?? 'auto',
      iso: num(camera.iso, 200),
      shutterSpeed: (camera.shutterSpeed as string) ?? '1/200',
      whiteBalance: (camera.whiteBalance as FormValues['whiteBalance']) ?? 'daylight',
      whiteBalanceK: num(camera.whiteBalanceK, 5500),
      flashMode: (camera.flashMode as FormValues['flashMode']) ?? 'off',
      focusMode: (camera.focusMode as FormValues['focusMode']) ?? 'auto',
      lensType: (camera.lensType as string) ?? '',
      lensSuggestion: (camera.lensSuggestion as FormValues['lensSuggestion']) ?? 'main',
      lightDirection: (sceneGuide.lightDirection as string) ?? '',
      shootingDistance: (sceneGuide.shootingDistance as string) ?? '',
      background: (sceneGuide.background as string) ?? '',
      props: ((sceneGuide.props as string[]) ?? []).join(', '),
      bestTime: (sceneGuide.bestTime as string) ?? '',
      tips: ((sceneGuide.tips as string[]) ?? []).join(', '),
      cropRatio: (postProcess.cropRatio as string) ?? '3:4',
      colorBrightness: num(color.brightness, 0),
      colorContrast: num(color.contrast, 0),
      colorSaturation: num(color.saturation, 0),
      colorTemperature: num(color.temperature, 0),
      colorTint: num(color.tint, 0),
      smoothStrength: num(postProcess.smoothStrength, 0),
      sharpen: num(postProcess.sharpen, 0),
      vignette: num(postProcess.vignette, 0),
      grain: num(postProcess.grain, 0),
      lut: (postProcess.lut as FormValues['lut']) ?? 'none',
      sortOrder: initial.sortOrder ?? 0,
      isActive: initial.isActive,
    };
  };

  const {
    register, handleSubmit, control, setValue, watch, formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: buildDefaults(),
  });

  const handlePptplUpload = async (file: File | null) => {
    if (!file) return;
    const MAX_PPTPL_BYTES = 25 * 1024 * 1024;
    if (file.size > MAX_PPTPL_BYTES) {
      toast({
        variant: 'destructive',
        title: '文件过大',
        description: `.pptpl 文件不能超过 25MB（当前 ${(file.size / 1024 / 1024).toFixed(2)}MB）`,
      });
      return;
    }
    try {
      const text = await file.text();
      const json = JSON.parse(text) as Record<string, unknown>;
      if (!json || typeof json !== 'object') {
        throw new Error('JSON 解析失败');
      }
      const composition = (json.composition ?? {}) as Record<string, unknown>;
      const pose = (json.pose ?? {}) as Record<string, unknown>;
      const silhouette = (pose.silhouette ?? {}) as Record<string, unknown>;
      const position = (pose.position ?? {}) as Record<string, unknown>;
      const camera = (json.camera ?? {}) as Record<string, unknown>;
      const sceneGuide = (json.sceneGuide ?? {}) as Record<string, unknown>;
      const postProcess = (json.postProcess ?? {}) as Record<string, unknown>;
      const color = (postProcess.color ?? {}) as Record<string, unknown>;

      if (composition.overlayType) setValue('overlayType', composition.overlayType as FormValues['overlayType']);
      if (typeof composition.aspectRatio === 'string') setValue('aspectRatio', composition.aspectRatio);
      if (typeof composition.opacity === 'number') setValue('opacity', composition.opacity);
      if (typeof composition.gridType === 'string') setValue('gridType', composition.gridType);
      if (typeof composition.description === 'string') setValue('compositionDescription', composition.description);

      if (silhouette.type) setValue('silhouetteType', silhouette.type as FormValues['silhouetteType']);
      if (typeof silhouette.data === 'string') setValue('silhouetteBuiltinKey', silhouette.data);
      if (typeof pose.description === 'string') setValue('poseDescription', pose.description);
      if (typeof position.x === 'number') setValue('posePositionX', position.x);
      if (typeof position.y === 'number') setValue('posePositionY', position.y);
      if (typeof pose.scale === 'number') setValue('poseScale', pose.scale);
      if (typeof pose.rotation === 'number') setValue('poseRotation', pose.rotation);

      if (typeof camera.exposureCompensation === 'number') setValue('exposureCompensation', camera.exposureCompensation);
      if (camera.isoMode) setValue('isoMode', camera.isoMode as FormValues['isoMode']);
      if (typeof camera.iso === 'number') setValue('iso', camera.iso);
      if (typeof camera.shutterSpeed === 'string') setValue('shutterSpeed', camera.shutterSpeed);
      if (camera.whiteBalance) setValue('whiteBalance', camera.whiteBalance as FormValues['whiteBalance']);
      if (typeof camera.whiteBalanceK === 'number') setValue('whiteBalanceK', camera.whiteBalanceK);
      if (camera.flashMode) setValue('flashMode', camera.flashMode as FormValues['flashMode']);
      if (camera.focusMode) setValue('focusMode', camera.focusMode as FormValues['focusMode']);
      if (typeof camera.lensType === 'string') setValue('lensType', camera.lensType);
      if (camera.lensSuggestion) setValue('lensSuggestion', camera.lensSuggestion as FormValues['lensSuggestion']);

      if (typeof sceneGuide.lightDirection === 'string') setValue('lightDirection', sceneGuide.lightDirection);
      if (typeof sceneGuide.shootingDistance === 'string') setValue('shootingDistance', sceneGuide.shootingDistance);
      if (typeof sceneGuide.background === 'string') setValue('background', sceneGuide.background);
      if (Array.isArray(sceneGuide.props)) setValue('props', (sceneGuide.props as string[]).join(', '));
      if (typeof sceneGuide.bestTime === 'string') setValue('bestTime', sceneGuide.bestTime);
      if (Array.isArray(sceneGuide.tips)) setValue('tips', (sceneGuide.tips as string[]).join(', '));

      if (typeof postProcess.cropRatio === 'string') setValue('cropRatio', postProcess.cropRatio);
      if (typeof color.brightness === 'number') setValue('colorBrightness', color.brightness);
      if (typeof color.contrast === 'number') setValue('colorContrast', color.contrast);
      if (typeof color.saturation === 'number') setValue('colorSaturation', color.saturation);
      if (typeof color.temperature === 'number') setValue('colorTemperature', color.temperature);
      if (typeof color.tint === 'number') setValue('colorTint', color.tint);
      if (typeof postProcess.smoothStrength === 'number') setValue('smoothStrength', postProcess.smoothStrength);
      if (typeof postProcess.sharpen === 'number') setValue('sharpen', postProcess.sharpen);
      if (typeof postProcess.vignette === 'number') setValue('vignette', postProcess.vignette);
      if (typeof postProcess.grain === 'number') setValue('grain', postProcess.grain);
      if (postProcess.lut) setValue('lut', postProcess.lut as FormValues['lut']);

      setPptplFile(file);
      toast({
        title: '已加载 .pptpl',
        description: '构图 / 剪影 / 相机 / 场景引导 / 后期处理 5 段内容已自动填充，可在后续步骤中校对修改。',
      });
    } catch (e) {
      toast({
        variant: 'destructive',
        title: '解析失败',
        description: `${(e as Error).message}（请确认是合法的 .pptpl JSON 文件）`,
      });
      if (pptplInputRef.current) pptplInputRef.current.value = '';
    }
  };

  const onSubmit = (data: FormValues) => {
    setError(null);

    if (!isEdit && !coverFile) {
      setError('请上传封面图片（Step 2）');
      setStep(1);
      return;
    }

    const pose: Record<string, unknown> = {
      description: data.poseDescription ?? '',
      position: { x: data.posePositionX, y: data.posePositionY },
      scale: data.poseScale,
      rotation: data.poseRotation,
      silhouette: {
        type: data.silhouetteType,
        data: data.silhouetteBuiltinKey ?? '',
      },
    };

    const meta: Record<string, unknown> = {
      name: data.name,
      category: data.category,
      price: data.price,
      description: data.description ?? '',
      author: data.author || 'Lumira',
      referenceSource: data.referenceSource ?? '',
      tags: parseCommaList(data.tags),
      tagIds: [],
      classification: {
        type: data.category,
        style: data.classificationStyle === NONE_VALUE ? '' : (data.classificationStyle ?? ''),
        method: data.classificationMethod === NONE_VALUE ? '' : (data.classificationMethod ?? ''),
      },
      sortOrder: data.sortOrder,
      isActive: data.isActive,
      composition: {
        overlayType: data.overlayType,
        gridType: data.gridType ?? '',
        aspectRatio: data.aspectRatio,
        opacity: data.opacity,
        description: data.compositionDescription ?? '',
      },
      pose,
      camera: {
        exposureCompensation: data.exposureCompensation,
        isoMode: data.isoMode,
        iso: data.iso,
        shutterSpeed: data.shutterSpeed,
        whiteBalance: data.whiteBalance,
        whiteBalanceK: data.whiteBalanceK,
        flashMode: data.flashMode,
        focusMode: data.focusMode,
        lensType: data.lensType ?? '',
        lensSuggestion: data.lensSuggestion,
      },
      sceneGuide: {
        lightDirection: data.lightDirection ?? '',
        shootingDistance: data.shootingDistance ?? '',
        background: data.background ?? '',
        props: parseCommaList(data.props),
        bestTime: data.bestTime ?? '',
        tips: parseCommaList(data.tips),
      },
      postProcess: {
        cropRatio: data.cropRatio,
        color: {
          brightness: data.colorBrightness,
          contrast: data.colorContrast,
          saturation: data.colorSaturation,
          temperature: data.colorTemperature,
          tint: data.colorTint,
        },
        smoothStrength: data.smoothStrength,
        sharpen: data.sharpen,
        vignette: data.vignette,
        grain: data.grain,
        lut: data.lut,
      },
    };

    const fd = new FormData();
    fd.set('meta', JSON.stringify(meta));
    if (coverFile) fd.set('cover', coverFile);
    if (silhouetteFile && data.silhouetteType === 'image') {
      fd.set('silhouette', silhouetteFile);
    }

    startTransition(async () => {
      const result = isEdit
        ? await updateTemplate(templateId as string, fd)
        : await createTemplate(fd);
      if (result?.error) {
        setError(result.error);
      }
    });
  };

  const next = async () => {
    const stepFields: (keyof FormValues)[][] = [
      ['name', 'category', 'price'],
      [],
      [],
      [],
      [],
      [],
    ];
    const fields = stepFields[step] ?? [];
    let hasError = false;
    for (const f of fields) {
      if (errors[f]) hasError = true;
    }
    if (hasError) {
      await handleSubmit(() => undefined)();
      return;
    }
    setStep((s) => Math.min(s + 1, STEPS.length - 1));
  };

  const prev = () => setStep((s) => Math.max(s - 1, 0));

  const watchSilhouetteType = watch('silhouetteType');
  const watchCategory = watch('category');
  const watchStyleField = watch('classificationStyle') || NONE_VALUE;
  const watchStyleKey = watchStyleField === NONE_VALUE ? '' : watchStyleField;

  const typeCategories = categories.filter((c) => c.level === 1);
  const styleOptions = categories.filter((c) => c.level === 2 && c.parentKey === watchCategory);
  const methodOptions = categories.filter((c) => c.level === 3 && c.parentKey === watchStyleKey);

  const coverPreviewUrl = isEdit && initial?.coverUrl
    ? toAssetUrl(initial.coverUrl, backendUrl) ?? undefined
    : undefined;

  // 封面及剪影预览 URL（用于 PhonePreview 和 SilhouettePreview）
  const [coverPreviewSrc, setCoverPreviewSrc] = React.useState<string | null>(coverPreviewUrl ?? null);
  const [silhouettePreviewSrc, setSilhouettePreviewSrc] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (coverFile) {
      const url = URL.createObjectURL(coverFile);
      setCoverPreviewSrc(url);
      return () => URL.revokeObjectURL(url);
    }
    if (coverPreviewUrl) {
      setCoverPreviewSrc(coverPreviewUrl);
    }
    return undefined;
  }, [coverFile, coverPreviewUrl]);

  React.useEffect(() => {
    if (silhouetteFile) {
      const url = URL.createObjectURL(silhouetteFile);
      setSilhouettePreviewSrc(url);
      return () => URL.revokeObjectURL(url);
    }
    if (isEdit && initial?.pose) {
      const pose = initial.pose as Record<string, unknown>;
      const silhouette = pose.silhouette as Record<string, unknown> | undefined;
      if (silhouette?.url) {
        setSilhouettePreviewSrc(toAssetUrl(silhouette.url as string, backendUrl));
      } else {
        setSilhouettePreviewSrc(null);
      }
    }
    return undefined;
  }, [silhouetteFile, isEdit, initial, backendUrl]);

  const watchedValues = watch();

  return (
    <div className="flex gap-6">
      <div className="flex-1 min-w-0 space-y-6">
        <div className="rounded-md border border-dashed border-primary/40 bg-primary/5 p-4">
          <div className="flex items-start gap-3">
            <UploadIcon size={20} className="text-primary mt-0.5" />
            <div className="flex-1">
              <p className="text-sm font-medium text-foreground">从 .pptpl 文件自动填充</p>
              <p className="text-xs text-muted-foreground mt-1">
                上传 Flutter 端导出的 .pptpl 模板文件，自动填充「构图 / 剪影 / 相机 / 场景引导 / 后期处理」5 段字段，可在后续步骤中继续修改。文件仅在浏览器本地解析，不会随模板上传。
              </p>
              <input
                ref={pptplInputRef}
                type="file"
                accept=".pptpl,application/json,application/octet-stream"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0] ?? null;
                  handlePptplUpload(f);
                }}
              />
              <div className="mt-3 flex items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => pptplInputRef.current?.click()}
                >
                  <UploadIcon size={14} className="mr-1" /> 选择 .pptpl 文件
                </Button>
                {pptplFile && (
                  <span className="text-xs text-muted-foreground">
                    已选：{pptplFile.name}（{(pptplFile.size / 1024).toFixed(1)} KB） · 已解析填充到表单字段
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-2">
          {STEPS.map((s, i) => (
            <div key={s.title} className="flex items-center gap-2 shrink-0">
              <button
                type="button"
                onClick={() => setStep(i)}
                className={`flex items-center gap-2 rounded-md px-3 py-1.5 text-sm transition-colors ${
                  i === step
                    ? 'bg-primary text-primary-foreground'
                    : i < step
                      ? 'bg-primary/10 text-primary'
                      : 'bg-muted text-muted-foreground hover:bg-muted/70'
                }`}
              >
                <span className="flex h-5 w-5 items-center justify-center rounded-full border border-current text-[10px]">
                  {i < step ? <Check size={10} /> : i + 1}
                </span>
                <span className="font-medium">{s.title}</span>
              </button>
              {i < STEPS.length - 1 && <span className="text-muted-foreground/50">→</span>}
            </div>
          ))}
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          {step === 0 && (
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">模板名称 *</Label>
                <Input id="name" placeholder="如：秋日森林" {...register('name')} />
                {errors.name && <p className="text-sm text-destructive">{errors.name.message}</p>}
              </div>

              <div className="space-y-2">
                <Label>分类（三级级联）*</Label>
                <div className="grid grid-cols-3 gap-2">
                  <div className="space-y-1">
                    <Label className="text-xs text-muted-foreground">一级（题材）</Label>
                    <Controller
                      control={control}
                      name="category"
                      render={({ field }) => (
                        <Select
                          value={field.value}
                          onValueChange={(v) => {
                            field.onChange(v);
                            setValue('classificationStyle', NONE_VALUE);
                            setValue('classificationMethod', NONE_VALUE);
                          }}
                        >
                          <SelectTrigger><SelectValue placeholder="选择题材" /></SelectTrigger>
                          <SelectContent>
                            {typeCategories.map((c) => (
                              <SelectItem key={c.key} value={c.key}>
                                {c.name} ({c.key})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </div>
                  <div className="space-y-1">
                    <Label className="text-xs text-muted-foreground">二级（风格）</Label>
                    <Controller
                      control={control}
                      name="classificationStyle"
                      render={({ field }) => (
                        <Select
                          value={field.value || NONE_VALUE}
                          onValueChange={(v) => {
                            field.onChange(v);
                            setValue('classificationMethod', NONE_VALUE);
                          }}
                        >
                          <SelectTrigger><SelectValue placeholder="无" /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value={NONE_VALUE}>无</SelectItem>
                            {styleOptions.map((c) => (
                              <SelectItem key={c.key} value={c.key}>
                                {c.name} ({c.key})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </div>
                  <div className="space-y-1">
                    <Label className="text-xs text-muted-foreground">三级（方式）</Label>
                    <Controller
                      control={control}
                      name="classificationMethod"
                      render={({ field }) => (
                        <Select
                          value={field.value || NONE_VALUE}
                          onValueChange={field.onChange}
                          disabled={!watchStyleKey}
                        >
                          <SelectTrigger><SelectValue placeholder="无" /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value={NONE_VALUE}>无</SelectItem>
                            {methodOptions.map((c) => (
                              <SelectItem key={c.key} value={c.key}>
                                {c.name} ({c.key})
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </div>
                </div>
                {errors.category && <p className="text-sm text-destructive">{errors.category.message}</p>}
                <p className="text-xs text-muted-foreground">
                  一级（题材）为必选；二三级可选「无」。提交时 category = 一级 key，classification.type 与之相同。
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="price">价格（积分，0=免费）</Label>
                <Input id="price" type="number" min={0} {...register('price')} />
                {errors.price && <p className="text-sm text-destructive">{errors.price.message}</p>}
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">描述</Label>
                <Textarea id="description" rows={3} {...register('description')} />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="author">作者</Label>
                  <Input id="author" placeholder="Lumira" {...register('author')} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="referenceSource">参考来源</Label>
                  <Input id="referenceSource" placeholder="如：样片 EXIF / 原创" {...register('referenceSource')} />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="tags">标签（逗号分隔）</Label>
                <Input id="tags" placeholder="如：秋季, 森林, 柔光" {...register('tags')} />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="sortOrder">排序</Label>
                  <Input id="sortOrder" type="number" {...register('sortOrder')} />
                </div>
                <div className="space-y-2">
                  <Label>是否上架</Label>
                  <div className="flex items-center gap-2 h-10">
                    <Controller
                      control={control}
                      name="isActive"
                      render={({ field }) => (
                        <input
                          type="checkbox"
                          checked={field.value}
                          onChange={(e) => field.onChange(e.target.checked)}
                          className="h-4 w-4"
                        />
                      )}
                    />
                    <span className="text-sm text-muted-foreground">
                      {watch('isActive') ? '上架（可见）' : '下架（隐藏）'}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {step === 1 && (
            <div className="space-y-6">
              <FileUpload
                label="封面图片 *"
                accept="image/png,image/jpeg,image/webp"
                maxSize={5 * 1024 * 1024}
                value={coverFile}
                onChange={async (file) => {
                  setCoverFile(file ? await compressImage(file, { maxDim: 1080, quality: 0.8 }) : null);
                }}
                hint="JPG / PNG / WebP，≤5MB，建议 3:4 竖图。上传后自动压缩（PNG 转 WebP）。"
                previewUrl={coverPreviewUrl}
              />

              <div className="space-y-2">
                <Label>剪影类型</Label>
                <Controller
                  control={control}
                  name="silhouetteType"
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {SILHOUETTE_TYPES.map((v) => (
                          <SelectItem key={v} value={v}>{v}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </div>

              {watchSilhouetteType === 'builtin' && (
                <div className="space-y-2">
                  <Label htmlFor="silhouetteBuiltinKey">内置剪影 key</Label>
                  <Input id="silhouetteBuiltinKey" placeholder="如：sitting-cafe" {...register('silhouetteBuiltinKey')} />
                </div>
              )}

              {watchSilhouetteType === 'image' && (
                <div className="space-y-4">
                  <FileUpload
                    label="剪影图片"
                    accept="image/png,image/svg+xml"
                    maxSize={5 * 1024 * 1024}
                    value={silhouetteFile}
                    onChange={async (file) => {
                      setSilhouetteFile(file ? await compressImage(file, { maxDim: 640, quality: 0.8 }) : null);
                    }}
                    hint="PNG / SVG，≤5MB。上传后自动压缩（PNG 转 WebP 保留透明通道）。"
                  />

                  {silhouettePreviewSrc && (
                    <SilhouettePreview
                      silhouetteUrl={silhouettePreviewSrc}
                      positionX={watchedValues.posePositionX}
                      positionY={watchedValues.posePositionY}
                      scale={watchedValues.poseScale}
                      rotation={watchedValues.poseRotation}
                      aspectRatio={watchedValues.aspectRatio}
                      cropRatio={watchedValues.cropRatio}
                      onPositionChange={(x, y) => {
                        setValue('posePositionX', x);
                        setValue('posePositionY', y);
                      }}
                      onScaleChange={(s) => setValue('poseScale', s)}
                      onRotationChange={(r) => setValue('poseRotation', r)}
                    />
                  )}
                </div>
              )}

              {watchSilhouetteType === 'svg' && (
                <div className="rounded-md bg-muted/30 p-3 text-xs text-muted-foreground">
                  SVG 类型请通过 .pptpl 文件上传内嵌 SVG 内容（pose.silhouette.data 字段）。
                </div>
              )}

              <div className="space-y-2">
                <Label htmlFor="poseDescription">姿势描述</Label>
                <Textarea id="poseDescription" rows={2} {...register('poseDescription')} />
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>叠加层类型</Label>
                  <Controller
                    control={control}
                    name="overlayType"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {OVERLAY_TYPES.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label>宽高比</Label>
                  <Controller
                    control={control}
                    name="aspectRatio"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ASPECT_RATIOS.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="gridType">网格类型（可选）</Label>
                  <Input id="gridType" placeholder="如：rule_of_thirds" {...register('gridType')} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="opacity">不透明度 (0-1)</Label>
                  <Input id="opacity" type="number" step={0.05} min={0} max={1} {...register('opacity')} />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="compositionDescription">构图描述</Label>
                <Textarea id="compositionDescription" rows={3} {...register('compositionDescription')} />
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="exposureCompensation">曝光补偿 (-3~3)</Label>
                  <Input id="exposureCompensation" type="number" step={0.1} min={-3} max={3} {...register('exposureCompensation')} />
                </div>
                <div className="space-y-2">
                  <Label>ISO 模式</Label>
                  <Controller
                    control={control}
                    name="isoMode"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ISO_MODES.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="iso">ISO</Label>
                  <Input id="iso" type="number" min={0} {...register('iso')} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="shutterSpeed">快门速度</Label>
                  <Input id="shutterSpeed" placeholder="如：1/200" {...register('shutterSpeed')} />
                </div>
                <div className="space-y-2">
                  <Label>白平衡</Label>
                  <Controller
                    control={control}
                    name="whiteBalance"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {WHITE_BALANCES.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="whiteBalanceK">白平衡 K</Label>
                  <Input id="whiteBalanceK" type="number" min={0} {...register('whiteBalanceK')} />
                </div>
                <div className="space-y-2">
                  <Label>闪光模式</Label>
                  <Controller
                    control={control}
                    name="flashMode"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {FLASH_MODES.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label>对焦模式</Label>
                  <Controller
                    control={control}
                    name="focusMode"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {FOCUS_MODES.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label>镜头建议</Label>
                  <Controller
                    control={control}
                    name="lensSuggestion"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {LENS_SUGGESTIONS.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="lensType">镜头类型（可选）</Label>
                  <Input id="lensType" placeholder="如：main / wide" {...register('lensType')} />
                </div>
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="lightDirection">光线方向</Label>
                  <Input id="lightDirection" placeholder="如：侧面柔光 45°" {...register('lightDirection')} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="shootingDistance">拍摄距离</Label>
                  <Input id="shootingDistance" placeholder="如：1.5-2m" {...register('shootingDistance')} />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="background">背景</Label>
                <Input id="background" placeholder="如：咖啡馆窗边 / 绿植背景" {...register('background')} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="props">道具（逗号分隔）</Label>
                <Input id="props" placeholder="如：咖啡杯, 书" {...register('props')} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="bestTime">最佳拍摄时间</Label>
                <Input id="bestTime" placeholder="如：14:00-16:00" {...register('bestTime')} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="tips">提示（逗号分隔）</Label>
                <Textarea id="tips" rows={3} placeholder="如：让模特自然托腮, 利用窗光制造柔光效果" {...register('tips')} />
              </div>
            </div>
          )}

          {step === 5 && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>裁剪比例</Label>
                  <Controller
                    control={control}
                    name="cropRatio"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ASPECT_RATIOS.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
                <div className="space-y-2">
                  <Label>滤镜 LUT</Label>
                  <Controller
                    control={control}
                    name="lut"
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {LUTS.map((v) => (
                            <SelectItem key={v} value={v}>{LUT_LABELS[v] ?? v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                </div>
              </div>

              <fieldset className="space-y-3 rounded-md border border-input p-4">
                <legend className="px-2 text-sm font-medium">色彩调整</legend>
                <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="colorBrightness">亮度 (-100~100)</Label>
                    <Input id="colorBrightness" type="number" min={-100} max={100} {...register('colorBrightness')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorContrast">对比度</Label>
                    <Input id="colorContrast" type="number" min={-100} max={100} {...register('colorContrast')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorSaturation">饱和度</Label>
                    <Input id="colorSaturation" type="number" min={-100} max={100} {...register('colorSaturation')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorTemperature">色温</Label>
                    <Input id="colorTemperature" type="number" min={-100} max={100} {...register('colorTemperature')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorTint">色调</Label>
                    <Input id="colorTint" type="number" min={-100} max={100} {...register('colorTint')} />
                  </div>
                </div>
              </fieldset>

              <fieldset className="space-y-3 rounded-md border border-input p-4">
                <legend className="px-2 text-sm font-medium">效果</legend>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="smoothStrength">平滑 (0-100)</Label>
                    <Input id="smoothStrength" type="number" min={0} max={100} {...register('smoothStrength')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="sharpen">锐化</Label>
                    <Input id="sharpen" type="number" min={0} max={100} {...register('sharpen')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="vignette">暗角</Label>
                    <Input id="vignette" type="number" min={0} max={100} {...register('vignette')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="grain">颗粒</Label>
                    <Input id="grain" type="number" min={0} max={100} {...register('grain')} />
                  </div>
                </div>
              </fieldset>
            </div>
          )}

          {error && <p className="text-sm text-destructive" role="alert">{error}</p>}

          <div className="flex items-center justify-between border-t border-border pt-4">
            <Button
              type="button"
              variant="ghost"
              onClick={prev}
              disabled={step === 0 || isPending}
            >
              <ArrowLeft size={14} className="mr-1" /> 上一步
            </Button>
            <div className="text-xs text-muted-foreground">
              步骤 {step + 1} / {STEPS.length} · {STEPS[step].title}
            </div>
            {step < STEPS.length - 1 ? (
              <Button type="button" onClick={next} disabled={isPending}>
                下一步 <ArrowRight size={14} className="ml-1" />
              </Button>
            ) : (
              <Button type="submit" disabled={isPending}>
                {isPending ? '提交中…' : isEdit ? '保存修改' : '创建模板'}
              </Button>
            )}
          </div>
        </form>
      </div>

      <div className="hidden xl:block w-[300px] shrink-0">
        <div className="sticky top-6 space-y-4">
          <div className="rounded-lg border border-border bg-card p-4">
            <h3 className="text-sm font-medium text-foreground mb-3">模板预览</h3>
            <PhonePreview
              coverUrl={coverPreviewSrc}
              silhouetteUrl={silhouettePreviewSrc}
              silhouetteType={watchedValues.silhouetteType}
              silhouetteBuiltinKey={watchedValues.silhouetteBuiltinKey}
              positionX={watchedValues.posePositionX}
              positionY={watchedValues.posePositionY}
              scale={watchedValues.poseScale}
              rotation={watchedValues.poseRotation}
              aspectRatio={watchedValues.aspectRatio}
              overlayType={watchedValues.overlayType}
              opacity={watchedValues.opacity}
              cropRatio={watchedValues.cropRatio}
              lut={watchedValues.lut}
              colorBrightness={watchedValues.colorBrightness}
              colorContrast={watchedValues.colorContrast}
              colorSaturation={watchedValues.colorSaturation}
              colorTemperature={watchedValues.colorTemperature}
              colorTint={watchedValues.colorTint}
              smoothStrength={watchedValues.smoothStrength}
              sharpen={watchedValues.sharpen}
              vignette={watchedValues.vignette}
              grain={watchedValues.grain}
              exposureCompensation={watchedValues.exposureCompensation}
              isoMode={watchedValues.isoMode}
              iso={watchedValues.iso}
              shutterSpeed={watchedValues.shutterSpeed}
              whiteBalance={watchedValues.whiteBalance}
              flashMode={watchedValues.flashMode}
              focusMode={watchedValues.focusMode}
              lensSuggestion={watchedValues.lensSuggestion}
              name={watchedValues.name}
            />
          </div>
        </div>
      </div>
    </div>
  );
}