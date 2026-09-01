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
import { Upload as UploadIcon } from '@phosphor-icons/react/dist/csr/Upload';
import { X } from '@phosphor-icons/react/dist/csr/X';
import { Plus } from '@phosphor-icons/react/dist/csr/Plus';
import { ArrowLeft } from '@phosphor-icons/react/dist/csr/ArrowLeft';
import { ArrowRight } from '@phosphor-icons/react/dist/csr/ArrowRight';
import { Check } from '@phosphor-icons/react/dist/csr/Check';
import { useToast } from '@/hooks/use-toast';
import { createTemplate, updateTemplate } from '@/actions/templates';
import SilhouettePreview from '@/components/silhouette-preview';
import PhonePreview from '@/components/phone-preview';
import type { AdminTemplateDetail, TemplateCategory } from '@/types/admin';

const OVERLAY_TYPES = ['rule_of_thirds', 'golden_ratio', 'diagonal', 'grid', 'leading_lines', 'center', 'none'] as const;
const ASPECT_RATIOS = ['fullscreen', '3:4', '4:3', '16:9', '1:1', '9:16'] as const;
const SILHOUETTE_TYPES = ['builtin', 'image', 'svg'] as const;
const ISO_MODES = ['auto', 'manual'] as const;
const WHITE_BALANCES = ['daylight', 'cloudy', 'shade', 'tungsten', 'fluorescent', 'custom'] as const;
const FLASH_MODES = ['off', 'on', 'auto', 'torch'] as const;
const FOCUS_MODES = ['auto', 'manual', 'continuous'] as const;
const LENS_SUGGESTIONS = ['wide', 'main', 'telephoto', 'ultra_wide'] as const;
// 相机方向（姿势级，控制套用模板时切换前/后摄；空 = 跟随用户）
const CAMERA_DIRECTIONS = ['front', 'back'] as const;
// 统一滤镜库（单一滤镜库，去重合并系统滤镜与 LUT 预设）
// 既有滤镜合并规则：
//  - 黑白：mono / noir / bw → fine_art_bw（黑白艺术）+ noir（黑白）
//  - 暖色：vivid_warm → warm_film
//  - 冷色：vivid_cool → cool_film
//  - 鲜明：vivid → fuji
const LUTS = [
  'none', 'cinematic', 'vintage', 'warm_film', 'cool_film', 'pastel', 'fuji',
  'portrait', 'japanese', 'japanese_fresh', 'cream', 'cyberpunk', 'night_cyber',
  'hk_neon', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan',
  'noir', 'fine_art_bw', 'silver', 'morandi', 'muted_gray', 'heavy_film',
] as const;

const LUT_LABELS: Record<string, string> = {
  none: '原图',
  cinematic: '电影感',
  vintage: '复古胶片',
  warm_film: '暖色胶片',
  cool_film: '冷色胶片',
  pastel: '柔色',
  fuji: '富士感',
  portrait: '人像',
  japanese: '日系',
  japanese_fresh: '日系清新',
  cream: '奶油感',
  cyberpunk: '赛博朋克',
  night_cyber: '夜景赛博',
  hk_neon: '港风霓虹',
  sepia_classic: '褐调',
  mist: '薄雾',
  rouge: '胭脂',
  twilight: '暮光',
  cyan: '青调',
  noir: '黑白',
  fine_art_bw: '黑白艺术',
  silver: '银盐感',
  morandi: '莫兰迪',
  muted_gray: '低饱和高级灰',
  heavy_film: '浓厚胶片',
};

// 补光预设色（暖白/粉/黄/蓝/绿/紫等常用米色系，点击即选用）
const FILL_LIGHT_COLORS = [
  '#FFE5B4', // 暖白
  '#FFF4D6', // 奶白
  '#FFD9E8', // 粉
  '#FFF0C2', // 柠檬黄
  '#E3F2FF', // 浅蓝
  '#D4F5E4', // 浅绿
  '#F3E8FF', // 淡紫
  '#FFE1CC', // 杏
];

// 高级色彩字段（可空，默认不启用）
const ADVANCED_COLOR_KEYS = ['highlights', 'shadows', 'blackPoint', 'clarity', 'vibrance', 'brilliance'] as const;

const NONE_VALUE = '__none__';

/** 单个姿势的编辑期数据（多姿势编辑器用） */
interface PoseFormData {
  name: string;
  description: string;
  /** 相机方向：'front'（前置）| 'back'（后置）| ''（跟随用户）。套用模板时自动切换前后摄。 */
  cameraDirection: string;
  silhouetteType: string;
  silhouetteBuiltinKey: string;
  /** 新上传的剪影图片文件（提交时随表单发送） */
  silhouetteFile: File | null;
  /** 已存在的剪影 URL（编辑模式，image 类型预览用） */
  silhouetteUrl: string | null;
  positionX: number;
  positionY: number;
  scale: number;
  rotation: number;
}

const SEASONS_OPTIONS = [
  { value: 'spring', label: '春' },
  { value: 'summer', label: '夏' },
  { value: 'autumn', label: '秋' },
  { value: 'winter', label: '冬' },
];

const WEATHERS_OPTIONS = [
  { value: 'sunny', label: '晴' },
  { value: 'cloudy', label: '多云' },
  { value: 'overcast', label: '阴' },
  { value: 'rain', label: '雨' },
  { value: 'snow', label: '雪' },
  { value: 'fog', label: '雾' },
];

const TIME_TONES_OPTIONS = [
  { value: 'goldenHour', label: '黄金小时' },
  { value: 'day', label: '白天' },
  { value: 'night', label: '夜晚' },
  { value: 'warm', label: '暖调' },
  { value: 'cool', label: '冷调' },
];

/** 通用多选渲染：可切换的 checkbox chips */
function AmbienceChecklist({
  id,
  label,
  options,
  value,
  onChange,
}: {
  id: string;
  label: string;
  options: { value: string; label: string }[];
  value: string[];
  onChange: (next: string[]) => void;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="flex flex-wrap gap-2">
        {options.map((opt) => {
          const active = value.includes(opt.value);
          return (
            <button
              key={opt.value}
              type="button"
              onClick={() =>
                onChange(
                  active ? value.filter((v) => v !== opt.value) : [...value, opt.value],
                )
              }
              className={`rounded-full border px-3 py-1 text-sm transition-colors ${
                active
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-input text-muted-foreground hover:bg-accent'
              }`}
            >
              {opt.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

const schema = z.object({
  name: z.string().min(1, '请输入模板名称').max(100),
  category: z.string().min(1, '请选择分类'),
  classificationMajorStyle: z.string().optional().default(NONE_VALUE),
  classificationSubStyle: z.string().optional().default(NONE_VALUE),
  classificationMethod: z.string().optional().default(NONE_VALUE),
  price: z.coerce.number().int().min(0, '价格不能为负'),
  description: z.string().optional().default(''),
  shortDesc: z.string().max(20, '短简介最多 20 字').optional().default(''),
  ambienceSeasons: z.array(z.string()).optional().default([]),
  ambienceWeathers: z.array(z.string()).optional().default([]),
  ambienceTimeTones: z.array(z.string()).optional().default([]),
  author: z.string().optional().default('Lumira'),
  tags: z.string().optional().default(''),
  referenceSource: z.string().optional().default(''),
  silhouetteType: z.enum(SILHOUETTE_TYPES).default('builtin'),
  silhouetteBuiltinKey: z.string().optional().default(''),
  poseDescription: z.string().optional().default(''),
  posePositionX: z.coerce.number().min(0).max(1).default(0.5),
  posePositionY: z.coerce.number().min(0).max(1).default(0.5),
  poseScale: z.coerce.number().min(0.3).max(4.0).default(1.0),
  poseRotation: z.coerce.number().min(-45).max(45).default(0),
  overlayType: z.enum(OVERLAY_TYPES).default('rule_of_thirds'),
  gridType: z.string().optional().default(''),
  // 主体框（subjectFrame）相对坐标 0-1
  subjectFrameX: z.coerce.number().min(0).max(1).optional(),
  subjectFrameY: z.coerce.number().min(0).max(1).optional(),
  subjectFrameW: z.coerce.number().min(0).max(1).optional(),
  subjectFrameH: z.coerce.number().min(0).max(1).optional(),
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
  // 高级色彩（可空，未填则不启用）
  colorHighlights: z.coerce.number().int().min(-100).max(100).optional(),
  colorShadows: z.coerce.number().int().min(-100).max(100).optional(),
  colorBlackPoint: z.coerce.number().int().min(-100).max(100).optional(),
  colorClarity: z.coerce.number().int().min(-100).max(100).optional(),
  colorVibrance: z.coerce.number().int().min(-100).max(100).optional(),
  colorBrilliance: z.coerce.number().int().min(-100).max(100).optional(),
  smoothStrength: z.coerce.number().int().min(0).max(100).default(0),
  sharpen: z.coerce.number().int().min(0).max(100).default(0),
  vignette: z.coerce.number().int().min(0).max(100).default(0),
  grain: z.coerce.number().int().min(0).max(100).default(0),
  lut: z.enum(LUTS).default('none'),
  // 系统滤镜（统一滤镜库的子集，可空；默认 none）
  systemFilter: z.enum(LUTS).optional().default('none'),
  // 补光灯 fillLight（启用时生效）
  fillLightEnabled: z.boolean().optional().default(false),
  fillLightColor: z.string().optional().default('#FFE5B4'),
  fillLightIntensity: z.coerce.number().min(0).max(1).optional().default(0.8),
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

/** File → base64 data URL（多姿势剪影：后端仅对 poses[0] 落盘文件，其余姿势剪影以 data URL 内嵌提交） */
function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
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
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [imagePreviews, setImagePreviews] = useState<string[]>(() => {
    if (templateId && initial?.images) {
      return initial.images
        .map((img) => toAssetUrl(img.url, backendUrl))
        .filter(Boolean) as string[];
    }
    return [];
  });
  const [poseIndex, setPoseIndex] = useState(0);
  const isEdit = Boolean(templateId && initial);

  /** 初始化姿势数组：编辑模式从 initial.poses（缺省用 initial.pose），新建默认单姿势 */
  const buildInitialPoses = (): PoseFormData[] => {
    const fallbackPose = (raw: Record<string, unknown> | undefined): PoseFormData => {
      const silhouette = (raw?.silhouette ?? {}) as Record<string, unknown>;
      const position = (raw?.position ?? {}) as Record<string, unknown>;
      return {
        name: (raw?.name as string) ?? '',
        description: (raw?.description as string) ?? '',
        cameraDirection: (raw?.cameraDirection as string) ?? '',
        silhouetteType: (silhouette.type as string) ?? 'builtin',
        silhouetteBuiltinKey: silhouette.type === 'image' ? '' : ((silhouette.data as string) ?? ''),
        silhouetteFile: null,
        // 保留原始绝对 URL（编辑模式 image 类型回填用），预览时再经 toAssetUrl 转换
        silhouetteUrl: silhouette.type === 'image' ? ((silhouette.url as string) ?? (silhouette.data as string) ?? '') || null : null,
        positionX: num(position.x, 0.5),
        positionY: num(position.y, 0.5),
        scale: num(raw?.scale, 1.0),
        rotation: num(raw?.rotation, 0),
      };
    };
    if (isEdit && initial?.poses && initial.poses.length > 0) {
      return initial.poses.map((p) =>
        fallbackPose(p as unknown as Record<string, unknown>),
      );
    }
    if (isEdit && initial?.pose) {
      return [fallbackPose(initial.pose as Record<string, unknown>)];
    }
    return [{
      name: '',
      description: '',
      cameraDirection: '',
      silhouetteType: 'builtin',
      silhouetteBuiltinKey: '',
      silhouetteFile: null,
      silhouetteUrl: null,
      positionX: 0.5,
      positionY: 0.5,
      scale: 1.0,
      rotation: 0,
    }];
  };

  const [poses, setPoses] = useState<PoseFormData[]>(() => buildInitialPoses());
  const [pptplFile, setPptplFile] = useState<File | null>(null);
  const imageInputRef = React.useRef<HTMLInputElement>(null);
  const pptplInputRef = React.useRef<HTMLInputElement>(null);
  // 裁剪比例是否随构图比例联动：
  // - 默认联动（改构图比例时裁剪比例同步为同值）
  // - 用户单独设置过裁剪比例后解锁（以手动选择为准，不再自动跟随）
  const [cropRatioLinked, setCropRatioLinked] = useState(() => {
    const ar = (initial?.composition?.aspectRatio as string | undefined) ?? '3:4';
    const cr = (initial?.postProcess?.cropRatio as string | undefined) ?? '3:4';
    return ar === cr;
  });

  const buildDefaults = (): FormValues => {
    if (!initial) {
      const typeCategories = categories.filter((c) => c.level === 1);
      return {
        name: '',
        category: typeCategories[0]?.key ?? 'portrait',
        classificationMajorStyle: NONE_VALUE,
        classificationSubStyle: NONE_VALUE,
        classificationMethod: NONE_VALUE,
        price: 0,
        description: '',
        shortDesc: '',
        ambienceSeasons: [],
        ambienceWeathers: [],
        ambienceTimeTones: [],
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
        subjectFrameX: undefined,
        subjectFrameY: undefined,
        subjectFrameW: undefined,
        subjectFrameH: undefined,
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
        colorHighlights: undefined,
        colorShadows: undefined,
        colorBlackPoint: undefined,
        colorClarity: undefined,
        colorVibrance: undefined,
        colorBrilliance: undefined,
        smoothStrength: 0,
        sharpen: 0,
        vignette: 0,
        grain: 0,
        lut: 'none',
        systemFilter: 'none',
        fillLightEnabled: false,
        fillLightColor: '#FFE5B4',
        fillLightIntensity: 0.8,
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
      classificationMajorStyle: initial.classification?.majorStyle || NONE_VALUE,
      classificationSubStyle: initial.classification?.subStyle || NONE_VALUE,
      classificationMethod: initial.classification?.method || NONE_VALUE,
      price: initial.price,
      description: initial.description ?? '',
      shortDesc: initial.shortDesc ?? '',
      ambienceSeasons: initial.ambience?.seasons ?? [],
      ambienceWeathers: initial.ambience?.weathers ?? [],
      ambienceTimeTones: initial.ambience?.timeTones ?? [],
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
      subjectFrameX: (() => { const sf = composition.subjectFrame as Record<string, unknown> | undefined; return sf ? num(sf.x) : undefined; })(),
      subjectFrameY: (() => { const sf = composition.subjectFrame as Record<string, unknown> | undefined; return sf ? num(sf.y) : undefined; })(),
      subjectFrameW: (() => { const sf = composition.subjectFrame as Record<string, unknown> | undefined; return sf ? num(sf.w) : undefined; })(),
      subjectFrameH: (() => { const sf = composition.subjectFrame as Record<string, unknown> | undefined; return sf ? num(sf.h) : undefined; })(),
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
      colorHighlights: color.highlights == null ? undefined : num(color.highlights),
      colorShadows: color.shadows == null ? undefined : num(color.shadows),
      colorBlackPoint: color.blackPoint == null ? undefined : num(color.blackPoint),
      colorClarity: color.clarity == null ? undefined : num(color.clarity),
      colorVibrance: color.vibrance == null ? undefined : num(color.vibrance),
      colorBrilliance: color.brilliance == null ? undefined : num(color.brilliance),
      smoothStrength: num(postProcess.smoothStrength, 0),
      sharpen: num(postProcess.sharpen, 0),
      vignette: num(postProcess.vignette, 0),
      grain: num(postProcess.grain, 0),
      lut: (postProcess.lut as FormValues['lut']) ?? 'none',
      systemFilter: (postProcess.systemFilter as FormValues['systemFilter']) ?? 'none',
      fillLightEnabled: (() => { const fl = postProcess.fillLight as Record<string, unknown> | undefined; return fl ? Boolean(fl.enabled) : false; })(),
      fillLightColor: (() => { const fl = postProcess.fillLight as Record<string, unknown> | undefined; const c = fl?.color != null ? Number(fl.color) : 0xFFFFE5B4; return `#${(c & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase()}`; })(),
      fillLightIntensity: (() => { const fl = postProcess.fillLight as Record<string, unknown> | undefined; return fl?.intensity != null ? Number(fl.intensity) : 0.8; })(),
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
      const sf = (composition.subjectFrame ?? {}) as Record<string, unknown>;
      if (typeof sf.x === 'number') setValue('subjectFrameX', sf.x);
      if (typeof sf.y === 'number') setValue('subjectFrameY', sf.y);
      if (typeof sf.w === 'number') setValue('subjectFrameW', sf.w);
      if (typeof sf.h === 'number') setValue('subjectFrameH', sf.h);

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

      if (typeof postProcess.cropRatio === 'string') {
        setValue('cropRatio', postProcess.cropRatio);
        // 导入模板的裁剪比例与构图比例不同 → 视为单独设置过，解锁联动
        const importedAr =
          typeof composition.aspectRatio === 'string' ? composition.aspectRatio : '3:4';
        if (postProcess.cropRatio !== importedAr) setCropRatioLinked(false);
      }
      if (typeof color.brightness === 'number') setValue('colorBrightness', color.brightness);
      if (typeof color.contrast === 'number') setValue('colorContrast', color.contrast);
      if (typeof color.saturation === 'number') setValue('colorSaturation', color.saturation);
      if (typeof color.temperature === 'number') setValue('colorTemperature', color.temperature);
      if (typeof color.tint === 'number') setValue('colorTint', color.tint);
      if (typeof color.highlights === 'number') setValue('colorHighlights', color.highlights);
      if (typeof color.shadows === 'number') setValue('colorShadows', color.shadows);
      if (typeof color.blackPoint === 'number') setValue('colorBlackPoint', color.blackPoint);
      if (typeof color.clarity === 'number') setValue('colorClarity', color.clarity);
      if (typeof color.vibrance === 'number') setValue('colorVibrance', color.vibrance);
      if (typeof color.brilliance === 'number') setValue('colorBrilliance', color.brilliance);
      if (typeof postProcess.smoothStrength === 'number') setValue('smoothStrength', postProcess.smoothStrength);
      if (typeof postProcess.sharpen === 'number') setValue('sharpen', postProcess.sharpen);
      if (typeof postProcess.vignette === 'number') setValue('vignette', postProcess.vignette);
      if (typeof postProcess.grain === 'number') setValue('grain', postProcess.grain);
      if (postProcess.lut) setValue('lut', postProcess.lut as FormValues['lut']);
      if (postProcess.systemFilter) setValue('systemFilter', postProcess.systemFilter as FormValues['systemFilter']);
      const fl = (postProcess.fillLight ?? {}) as Record<string, unknown>;
      if (typeof fl.enabled === 'boolean') setValue('fillLightEnabled', fl.enabled);
      if (typeof fl.color === 'number') setValue('fillLightColor', `#${(fl.color & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase()}`);
      if (typeof fl.intensity === 'number') setValue('fillLightIntensity', fl.intensity);

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

  /** 预览 URL：新上传的 blob 原样返回，既有绝对/相对 URL 经 toAssetUrl 归一 */
  const poseSilhouettePreview = (p: PoseFormData): string | null => {
    if (!p.silhouetteUrl) return null;
    if (p.silhouetteUrl.startsWith('blob:')) return p.silhouetteUrl;
    return toAssetUrl(p.silhouetteUrl, backendUrl);
  };

  const handleImagePick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []);
    if (files.length === 0) return;
    const processed = await Promise.all(
      files.map((f) => compressImage(f, { maxDim: 1080, quality: 0.8 })),
    );
    setImageFiles((prev) => [...prev, ...processed]);
    setImagePreviews((prev) => [...prev, ...processed.map((f) => URL.createObjectURL(f))]);
    if (e.target) e.target.value = '';
  };

  const removeImage = (i: number) => {
    setImageFiles((prev) => prev.filter((_, idx) => idx !== i));
    setImagePreviews((prev) => prev.filter((_, idx) => idx !== i));
  };

  /** 拖拽前的简单排序：左移/右移（封面始终 = 首张） */
  const moveImage = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= imageFiles.length) return;
    setImageFiles((prev) => {
      const c = [...prev];
      [c[i], c[j]] = [c[j], c[i]];
      return c;
    });
    setImagePreviews((prev) => {
      const c = [...prev];
      [c[i], c[j]] = [c[j], c[i]];
      return c;
    });
  };

  const updatePose = (i: number, patch: Partial<PoseFormData>) =>
    setPoses((prev) => prev.map((p, idx) => (idx === i ? { ...p, ...patch } : p)));

  const addPose = () => {
    setPoses((prev) => [
      ...prev,
      {
        name: '',
        description: '',
        cameraDirection: '',
        silhouetteType: 'builtin',
        silhouetteBuiltinKey: '',
        silhouetteFile: null,
        silhouetteUrl: null,
        positionX: 0.5,
        positionY: 0.5,
        scale: 1.0,
        rotation: 0,
      },
    ]);
    setPoseIndex(poses.length);
  };

  const removePose = (i: number) => {
    if (poses.length <= 1) return;
    setPoses((prev) => prev.filter((_, idx) => idx !== i));
    setPoseIndex((idx) => {
      if (i < idx) return idx - 1;
      if (idx >= poses.length - 1) return poses.length - 2;
      return idx;
    });
  };

  const currentPose = poses[poseIndex] ?? poses[0];

  const onSubmit = async (data: FormValues) => {
    setError(null);

    if (!isEdit && imageFiles.length === 0) {
      setError('请上传封面图片（Step 2）');
      setStep(1);
      return;
    }

    // 各姿势新上传的剪影文件转为 data URL 内嵌进 poses（后端仅对 poses[0] 落盘文件）
    const imageDataUrls = new Array<string | undefined>(poses.length);
    const firstSilhouetteFile =
      poses[0]?.silhouetteType === 'image' ? poses[0].silhouetteFile : null;
    await Promise.all(
      poses.map(async (p, i) => {
        if (p.silhouetteType === 'image' && p.silhouetteFile) {
          imageDataUrls[i] = await fileToDataUrl(p.silhouetteFile);
        }
      }),
    );

    const posesPayload: Record<string, unknown>[] = poses.map((p, i) => ({
      ...(p.name ? { name: p.name } : {}),
      ...(p.description ? { description: p.description } : {}),
      ...(p.cameraDirection ? { cameraDirection: p.cameraDirection } : {}),
      silhouette: {
        type: p.silhouetteType,
        ...(p.silhouetteType === 'builtin'
          ? { data: p.silhouetteBuiltinKey ?? '' }
          : p.silhouetteType === 'image'
            ? imageDataUrls[i]
              ? { data: imageDataUrls[i] }
              : p.silhouetteUrl && !p.silhouetteUrl.startsWith('blob:')
                ? { url: p.silhouetteUrl }
                : {}
            : {}),
      },
      position: { x: p.positionX, y: p.positionY },
      scale: p.scale,
      rotation: p.rotation,
    }));

    const meta: Record<string, unknown> = {
      name: data.name,
      category: data.category,
      price: data.price,
      description: data.description ?? '',
      shortDesc: (data.shortDesc ?? '').trim(),
      ambience: {
        seasons: data.ambienceSeasons ?? [],
        weathers: data.ambienceWeathers ?? [],
        timeTones: data.ambienceTimeTones ?? [],
      },
      author: data.author || 'Lumira',
      referenceSource: data.referenceSource ?? '',
      tags: parseCommaList(data.tags),
      tagIds: [],
      classification: {
        type: data.category,
        majorStyle: data.classificationMajorStyle === NONE_VALUE ? '' : (data.classificationMajorStyle ?? ''),
        style: data.classificationSubStyle === NONE_VALUE ? '' : (data.classificationSubStyle ?? ''),
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
        ...(data.subjectFrameX != null &&
        data.subjectFrameY != null &&
        data.subjectFrameW != null &&
        data.subjectFrameH != null
          ? {
              subjectFrame: {
                x: data.subjectFrameX,
                y: data.subjectFrameY,
                w: data.subjectFrameW,
                h: data.subjectFrameH,
              },
            }
          : {}),
      },
      pose: posesPayload[0],
      poses: posesPayload,
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
          ...(data.colorHighlights != null ? { highlights: data.colorHighlights } : {}),
          ...(data.colorShadows != null ? { shadows: data.colorShadows } : {}),
          ...(data.colorBlackPoint != null ? { blackPoint: data.colorBlackPoint } : {}),
          ...(data.colorClarity != null ? { clarity: data.colorClarity } : {}),
          ...(data.colorVibrance != null ? { vibrance: data.colorVibrance } : {}),
          ...(data.colorBrilliance != null ? { brilliance: data.colorBrilliance } : {}),
        },
        smoothStrength: data.smoothStrength,
        sharpen: data.sharpen,
        vignette: data.vignette,
        grain: data.grain,
        lut: data.lut,
        ...(data.systemFilter && data.systemFilter !== 'none' ? { systemFilter: data.systemFilter } : {}),
        fillLight: (data.fillLightEnabled && data.fillLightColor && data.fillLightIntensity != null)
          ? {
              enabled: data.fillLightEnabled,
              // 存为 32 位不透明 ARGB（补 alpha=0xFF），与 Flutter Color(int) 的 ARGB 语义一致，
              // 避免 24 位值被 Flutter 误判为透明导致补光色发暗/对不上。
              color: (parseInt((data.fillLightColor as string).replace(/^#/, ''), 16) || 0) | 0xFF000000,
              intensity: data.fillLightIntensity,
            }
          : undefined,
      },
    };

    const fd = new FormData();
    fd.set('meta', JSON.stringify(meta));
    // 首图同时作为 cover（后端单图兼容）
    if (imageFiles.length > 0) fd.set('cover', imageFiles[0]);
    // 多效果图：多个同名字段 images
    imageFiles.forEach((f) => fd.append('images', f));
    // 首个姿势的剪影文件走单 silhouette 字段（后端注入 poses[0]）
    if (firstSilhouetteFile) {
      fd.set('silhouette', firstSilhouetteFile);
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

  const watchCategory = watch('category');
  const typeCategories = categories.filter((c) => c.level === 1);
  // 四级动态级联：按父子链逐级展开，父级无子级则该层不显示
  const majorStyleOptions = categories.filter((c) => c.level === 2 && c.parentKey === watchCategory);
  const majStyleField = watch('classificationMajorStyle') || NONE_VALUE;
  const majStyleKey = majStyleField === NONE_VALUE ? '' : majStyleField;
  const subStyleField = watch('classificationSubStyle') || NONE_VALUE;
  const subStyleKey = subStyleField === NONE_VALUE ? '' : subStyleField;
  const subStyleOptions = categories.filter((c) => c.level === 3 && c.parentKey === majStyleKey);
  const methodOptions = categories.filter((c) => c.level === 4 && c.parentKey === subStyleKey);

  // 封面预览 = 效果图首张（PhonePreview 使用）
  const coverPreviewSrc = imagePreviews[0] ?? null;

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
                <Label>分类（四级动态级联）*</Label>
                <div className="grid grid-cols-2 gap-2 md:grid-cols-3">
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
                            setValue('classificationMajorStyle', NONE_VALUE);
                            setValue('classificationSubStyle', NONE_VALUE);
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
                  {majorStyleOptions.length > 0 && (
                    <div className="space-y-1">
                      <Label className="text-xs text-muted-foreground">二级（大风格）</Label>
                      <Controller
                        control={control}
                        name="classificationMajorStyle"
                        render={({ field }) => (
                          <Select
                            value={field.value || NONE_VALUE}
                            onValueChange={(v) => {
                              field.onChange(v);
                              setValue('classificationSubStyle', NONE_VALUE);
                              setValue('classificationMethod', NONE_VALUE);
                            }}
                          >
                            <SelectTrigger><SelectValue placeholder="无" /></SelectTrigger>
                            <SelectContent>
                              <SelectItem value={NONE_VALUE}>无</SelectItem>
                              {majorStyleOptions.map((c) => (
                                <SelectItem key={c.key} value={c.key}>
                                  {c.name} ({c.key})
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}
                      />
                    </div>
                  )}
                  {subStyleOptions.length > 0 && (
                    <div className="space-y-1">
                      <Label className="text-xs text-muted-foreground">三级（子风格）</Label>
                      <Controller
                        control={control}
                        name="classificationSubStyle"
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
                              {subStyleOptions.map((c) => (
                                <SelectItem key={c.key} value={c.key}>
                                  {c.name} ({c.key})
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )}
                      />
                    </div>
                  )}
                  {methodOptions.length > 0 && (
                    <div className="space-y-1">
                      <Label className="text-xs text-muted-foreground">四级（方法）</Label>
                      <Controller
                        control={control}
                        name="classificationMethod"
                        render={({ field }) => (
                          <Select
                            value={field.value || NONE_VALUE}
                            onValueChange={(v) => {
                              field.onChange(v);
                            }}
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
                  )}
                </div>
                {errors.category && <p className="text-sm text-destructive">{errors.category.message}</p>}
                <p className="text-xs text-muted-foreground">
                  题材必选；二/三/四级按父子链动态展开。
                  提交时 category = 一级 key，classification 中 type=一级 / majorStyle=二级 / style=三级 / method=四级。
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

              <div className="space-y-2">
                <Label htmlFor="shortDesc">短简介（≤20字）</Label>
                <div className="relative">
                  <Input
                    id="shortDesc"
                    maxLength={20}
                    placeholder="一句话亮点（≤20字）"
                    {...register('shortDesc')}
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground">
                    {watch('shortDesc')?.length ?? 0}/20
                  </span>
                </div>
              </div>

              <Controller
                control={control}
                name="ambienceSeasons"
                render={({ field }) => (
                  <AmbienceChecklist
                    id="ambienceSeasons"
                    label="适用季节（不选=不限）"
                    options={SEASONS_OPTIONS}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
              <Controller
                control={control}
                name="ambienceWeathers"
                render={({ field }) => (
                  <AmbienceChecklist
                    id="ambienceWeathers"
                    label="适用天气（不选=不限）"
                    options={WEATHERS_OPTIONS}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
              <Controller
                control={control}
                name="ambienceTimeTones"
                render={({ field }) => (
                  <AmbienceChecklist
                    id="ambienceTimeTones"
                    label="时段/色调（不选=不限）"
                    options={TIME_TONES_OPTIONS}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />

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
              {/* 多效果图上传：首张为封面 */}
              <div className="space-y-2">
                <Label>效果图（首张为封面）*</Label>
                <div className="flex gap-2 flex-wrap">
                  {imagePreviews.map((src, i) => (
                    <div
                      key={`${src}-${i}`}
                      className="relative h-[120px] w-[120px] shrink-0 overflow-hidden rounded-md border border-input"
                    >
                      <img src={src} alt={`效果图 ${i + 1}`} className="h-full w-full object-cover" />
                      {i === 0 && (
                        <span className="absolute left-1 top-1 rounded bg-primary px-1.5 py-0.5 text-[10px] font-medium text-primary-foreground">
                          封面
                        </span>
                      )}
                      <button
                        type="button"
                        onClick={() => removeImage(i)}
                        className="absolute right-1 top-1 rounded bg-black/60 p-1 text-white hover:bg-black/80"
                        aria-label="删除效果图"
                      >
                        <X size={12} weight="bold" />
                      </button>
                      {/* 左移 / 右移排序（封面始终为首张） */}
                      <div className="absolute bottom-1 left-1 flex gap-1">
                        {i > 0 && (
                          <button
                            type="button"
                            onClick={() => moveImage(i, -1)}
                            className="rounded bg-black/50 p-0.5 text-white hover:bg-black/80"
                            aria-label="左移"
                          >
                            <ArrowLeft size={10} weight="bold" />
                          </button>
                        )}
                        {i < imagePreviews.length - 1 && (
                          <button
                            type="button"
                            onClick={() => moveImage(i, 1)}
                            className="rounded bg-black/50 p-0.5 text-white hover:bg-black/80"
                            aria-label="右移"
                          >
                            <ArrowRight size={10} weight="bold" />
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={() => imageInputRef.current?.click()}
                    className="flex h-[120px] w-[120px] shrink-0 flex-col items-center justify-center rounded-md border border-dashed border-input text-muted-foreground hover:bg-muted/50"
                  >
                    <Plus size={20} />
                    <span className="mt-1 text-xs">添加</span>
                  </button>
                </div>
                <input
                  ref={imageInputRef}
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  multiple
                  className="hidden"
                  onChange={handleImagePick}
                />
                <p className="text-xs text-muted-foreground">
                  JPG / PNG / WebP，单张 ≤8MB，建议 3:4 竖图。支持多选，首张为封面（删除首张后第二张自动成为封面）。
                </p>
              </div>

              {/* 多姿势编辑器 */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label>姿势剪影（多姿势）</Label>
                  <Button type="button" variant="outline" size="sm" onClick={addPose}>
                    <Plus size={14} className="mr-1" /> 添加姿势
                  </Button>
                </div>

                {poses.length > 0 && (
                  <div className="flex flex-wrap items-center gap-2">
                    {poses.map((p, i) => (
                      <button
                        key={i}
                        type="button"
                        onClick={() => setPoseIndex(i)}
                        className={`flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm transition-colors ${
                          i === poseIndex
                            ? 'border-primary bg-primary text-primary-foreground'
                            : 'border-input text-muted-foreground hover:bg-accent'
                        }`}
                      >
                        Pose {i + 1}
                        {p.silhouetteType === 'image' && <span>{p.silhouetteFile ? '（新）' : ''}</span>}
                      </button>
                    ))}
                  </div>
                )}

                {currentPose && (
                  <div className="space-y-4 rounded-md border border-input p-4">
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-medium">
                        姿势 {poseIndex + 1}（共 {poses.length} 个）
                      </p>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        disabled={poses.length <= 1}
                        onClick={() => removePose(poseIndex)}
                      >
                        <X size={14} className="mr-1" /> 删除当前姿势
                      </Button>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>剪影类型</Label>
                        <Select
                          value={currentPose.silhouetteType}
                          onValueChange={(v) => updatePose(poseIndex, { silhouetteType: v })}
                        >
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            {SILHOUETTE_TYPES.map((v) => (
                              <SelectItem key={v} value={v}>{v}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </div>

                    {currentPose.silhouetteType === 'builtin' && (
                      <div className="space-y-2">
                        <Label htmlFor={`pose-builtin-${poseIndex}`}>内置剪影 key</Label>
                        <Input
                          id={`pose-builtin-${poseIndex}`}
                          placeholder="如：sitting-cafe"
                          value={currentPose.silhouetteBuiltinKey}
                          onChange={(e) => updatePose(poseIndex, { silhouetteBuiltinKey: e.target.value })}
                        />
                      </div>
                    )}

                    {currentPose.silhouetteType === 'image' && (
                      <div className="space-y-4">
                        <FileUpload
                          label="剪影图片"
                          accept="image/png,image/svg+xml"
                          maxSize={8 * 1024 * 1024}
                          value={currentPose.silhouetteFile}
                          onChange={async (file) => {
                            if (!file) {
                              updatePose(poseIndex, { silhouetteFile: null, silhouetteUrl: null });
                              return;
                            }
                            const compressed = await compressImage(file, { maxDim: 640, quality: 0.8 });
                            updatePose(poseIndex, {
                              silhouetteFile: compressed,
                              silhouetteUrl: URL.createObjectURL(compressed),
                            });
                          }}
                          hint="PNG / SVG，≤8MB。上传后自动压缩（PNG 转 WebP 保留透明通道）。"
                        />
                        {poseSilhouettePreview(currentPose) && (
                          <SilhouettePreview
                            silhouetteUrl={poseSilhouettePreview(currentPose)!}
                            positionX={currentPose.positionX}
                            positionY={currentPose.positionY}
                            scale={currentPose.scale}
                            rotation={currentPose.rotation}
                            aspectRatio={watchedValues.aspectRatio}
                            cropRatio={watchedValues.cropRatio}
                            onPositionChange={(x, y) => updatePose(poseIndex, { positionX: x, positionY: y })}
                            onScaleChange={(s) => updatePose(poseIndex, { scale: s })}
                            onRotationChange={(r) => updatePose(poseIndex, { rotation: r })}
                          />
                        )}
                      </div>
                    )}

                    {currentPose.silhouetteType === 'svg' && (
                      <div className="rounded-md bg-muted/30 p-3 text-xs text-muted-foreground">
                        SVG 类型请通过 .pptpl 文件上传内嵌 SVG 内容（pose.silhouette.data 字段）。
                      </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor={`pose-name-${poseIndex}`}>姿势名称（可选）</Label>
                        <Input
                          id={`pose-name-${poseIndex}`}
                          placeholder="如：坐姿 / 站姿"
                          value={currentPose.name}
                          onChange={(e) => updatePose(poseIndex, { name: e.target.value })}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor={`pose-desc-${poseIndex}`}>姿势描述</Label>
                        <Input
                          id={`pose-desc-${poseIndex}`}
                          placeholder="如：主体坐姿，看向镜头"
                          value={currentPose.description}
                          onChange={(e) => updatePose(poseIndex, { description: e.target.value })}
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>相机方向</Label>
                        <Select
                          value={currentPose.cameraDirection || ''}
                          onValueChange={(v) =>
                            updatePose(poseIndex, {
                              cameraDirection: v === '' ? '' : v,
                            })
                          }
                        >
                          <SelectTrigger><SelectValue placeholder="跟随用户（不强制）" /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="">跟随用户（不强制）</SelectItem>
                            {CAMERA_DIRECTIONS.map((v) => (
                              <SelectItem key={v} value={v}>
                                {v === 'front' ? '前置（自拍）' : '后置'}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </div>
                  </div>
                )}
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
                      <Select
                        value={field.value}
                        onValueChange={(v) => {
                          field.onChange(v);
                          // 默认联动：构图比例改动时，裁剪比例同步为同值
                          if (cropRatioLinked) setValue('cropRatio', v);
                        }}
                      >
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ASPECT_RATIOS.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                  <p className="text-xs text-muted-foreground">构图比例用于模板预览展示；裁剪比例决定取景与出片。修改宽高比时裁剪比例将自动同步，除非已单独设置过裁剪比例。</p>
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

              <fieldset className="space-y-3 rounded-md border border-input p-4">
                <legend className="px-2 text-sm font-medium">主体框（subjectFrame，相对坐标 0-1）</legend>
                <p className="text-xs text-muted-foreground">可选。指定画面中主体（人物/物体）所在位置与占比，用于构图引导。全部留空则使用默认居中。</p>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="subjectFrameX">x</Label>
                    <Input id="subjectFrameX" type="number" step={0.01} min={0} max={1} {...register('subjectFrameX')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="subjectFrameY">y</Label>
                    <Input id="subjectFrameY" type="number" step={0.01} min={0} max={1} {...register('subjectFrameY')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="subjectFrameW">w</Label>
                    <Input id="subjectFrameW" type="number" step={0.01} min={0} max={1} {...register('subjectFrameW')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="subjectFrameH">h</Label>
                    <Input id="subjectFrameH" type="number" step={0.01} min={0} max={1} {...register('subjectFrameH')} />
                  </div>
                </div>
              </fieldset>
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
                      <Select
                        value={field.value}
                        onValueChange={(v) => {
                          field.onChange(v);
                          // 单独设置过裁剪比例后解锁联动，以手动选择为准
                          setCropRatioLinked(false);
                        }}
                      >
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          {ASPECT_RATIOS.map((v) => (
                            <SelectItem key={v} value={v}>{v}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                  <p className="text-xs text-muted-foreground">决定取景器与最终出片比例，默认跟随构图比例；单独修改后以手动选择为准。</p>
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
                <legend className="px-2 text-sm font-medium">高级色彩（可选，留空则不启用）</legend>
                <p className="text-xs text-muted-foreground">精细色彩微调，仅在模板预设中用到时填写。</p>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="colorHighlights">高光 (-100~100)</Label>
                    <Input id="colorHighlights" type="number" min={-100} max={100} {...register('colorHighlights')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorShadows">阴影</Label>
                    <Input id="colorShadows" type="number" min={-100} max={100} {...register('colorShadows')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorBlackPoint">黑场</Label>
                    <Input id="colorBlackPoint" type="number" min={-100} max={100} {...register('colorBlackPoint')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorClarity">清晰度</Label>
                    <Input id="colorClarity" type="number" min={-100} max={100} {...register('colorClarity')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorVibrance">自然饱和</Label>
                    <Input id="colorVibrance" type="number" min={-100} max={100} {...register('colorVibrance')} />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="colorBrilliance">光耀度</Label>
                    <Input id="colorBrilliance" type="number" min={-100} max={100} {...register('colorBrilliance')} />
                  </div>
                </div>
              </fieldset>

              <fieldset className="space-y-3 rounded-md border border-input p-4">
                <legend className="px-2 text-sm font-medium">补光（fillLight）</legend>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label>启用</Label>
                    <div className="flex items-center gap-2 h-10">
                      <Controller
                        control={control}
                        name="fillLightEnabled"
                        render={({ field }) => (
                          <input
                            type="checkbox"
                            checked={field.value}
                            onChange={(e) => field.onChange(e.target.checked)}
                            className="h-4 w-4"
                          />
                        )}
                      />
                      <span className="text-sm text-muted-foreground">应用补光</span>
                    </div>
                  </div>
                  <div className="space-y-2 md:col-span-2">
                    <Label htmlFor="fillLightColor">补光色</Label>
                    <div className="flex items-center gap-2">
                      <label
                        className="relative h-9 w-9 shrink-0 cursor-pointer overflow-hidden rounded-md border border-input shadow-sm"
                        title="点击打开系统取色器"
                      >
                        <input
                          id="fillLightColorPicker"
                          type="color"
                          value={/^#[0-9A-Fa-f]{6}$/.test(watch('fillLightColor')) ? watch('fillLightColor') : '#FFE5B4'}
                          onChange={(e) => setValue('fillLightColor', e.target.value.toUpperCase())}
                          disabled={!watch('fillLightEnabled')}
                          className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                        />
                        <span
                          className="absolute inset-0"
                          style={{ backgroundColor: watch('fillLightColor') }}
                        />
                      </label>
                      <Input
                        id="fillLightColor"
                        value={watch('fillLightColor')}
                        onChange={(e) => setValue('fillLightColor', e.target.value)}
                        placeholder="#FFE5B4"
                        disabled={!watch('fillLightEnabled')}
                        className="font-mono uppercase"
                      />
                    </div>
                    {/* 预设色盘：点击即选用 */}
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {FILL_LIGHT_COLORS.map((c) => (
                        <button
                          type="button"
                          key={c}
                          title={c}
                          onClick={() => { if (watch('fillLightEnabled')) setValue('fillLightColor', c); }}
                          disabled={!watch('fillLightEnabled')}
                          className={`h-6 w-6 rounded-full border transition-transform hover:scale-110 ${
                            watch('fillLightColor').toLowerCase() === c.toLowerCase() ? 'ring-2 ring-ring ring-offset-1' : 'border-input'
                          } disabled:opacity-40`}
                          style={{ backgroundColor: c }}
                          aria-label={`补光色 ${c}`}
                        />
                      ))}
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="fillLightIntensity">强度 (0-1)</Label>
                    <Input
                      id="fillLightIntensity"
                      type="number"
                      step={0.05}
                      min={0}
                      max={1}
                      {...register('fillLightIntensity')}
                      disabled={!watch('fillLightEnabled')}
                    />
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
              silhouetteUrl={currentPose ? poseSilhouettePreview(currentPose) : null}
              silhouetteType={currentPose?.silhouetteType ?? 'builtin'}
              silhouetteBuiltinKey={currentPose?.silhouetteBuiltinKey ?? ''}
              positionX={currentPose?.positionX ?? 0.5}
              positionY={currentPose?.positionY ?? 0.5}
              scale={currentPose?.scale ?? 1}
              rotation={currentPose?.rotation ?? 0}
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