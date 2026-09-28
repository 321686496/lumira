// src/components/ai-config-form.tsx
// AI 厂商配置表单（client）：三模态卡片 —— 视觉模型（共享平台）+ 文本/生图模型（跟随或独立平台）
// + 启用开关 + 连通性测试。文本/生图独立平台为独立 baseUrl/apiKey（OpenAI 兼容接口）。

'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { saveAiConfigAction, testAiConfigAction } from '@/actions/ai';
import type {
  AiConfigTestResult,
  AiConfigTestTarget,
  AiPlatformOverride,
  AiProviderConfigView,
  UpdateAiConfigPayload,
} from '@/types/admin';
import { cn } from '@/lib/utils';

/** 厂商预设：仅供默认值填充，baseUrl / 模型名均可手改覆盖 */
const PROVIDER_PRESETS = {
  qwen: {
    label: '阿里通义',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    textModel: 'qwen-plus',
  },
  doubao: {
    label: '字节豆包',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    visionModel: 'doubao-1.5-vision-pro-32k',
    imageModel: 'doubao-Seedream-4-0-250828',
    textModel: 'doubao-1.5-pro-32k',
  },
  zhipu: {
    label: '智谱 AI',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    visionModel: 'glm-4v-plus',
    imageModel: 'cogview-4',
    textModel: 'glm-4-flash',
  },
  openai: {
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    visionModel: 'gpt-4o',
    imageModel: 'gpt-image-1',
    textModel: 'gpt-4o-mini',
  },
} as const;

type ProviderKey = keyof typeof PROVIDER_PRESETS;
const PROVIDER_KEYS = Object.keys(PROVIDER_PRESETS) as ProviderKey[];

const TEST_TARGET_OPTIONS: { value: AiConfigTestTarget; label: string }[] = [
  { value: 'vision', label: '视觉识别' },
  { value: 'text', label: '文本' },
  { value: 'image', label: '生图' },
  { value: 'silhouette', label: '剪影' },
];
const ALL_TEST_TARGETS = TEST_TARGET_OPTIONS.map((option) => option.value);

/** 搜索方式（研究管线，四选一互斥）：Qwen 官方百炼 / Qwen 三方 MaaS / SearXNG 自建(免费) / 关闭 */
const SEARCH_MODE_OPTIONS: { value: 'qwen-official' | 'qwen' | 'searxng' | 'off'; label: string }[] = [
  { value: 'qwen-official', label: 'Qwen 官方百炼' },
  { value: 'qwen', label: 'Qwen 三方 MaaS' },
  { value: 'searxng', label: 'SearXNG 自建搜索（免费）' },
  { value: 'off', label: '关闭' },
];

interface FormState {
  provider: ProviderKey;
  baseUrl: string;
  apiKey: string; // 留空 = 不修改原值
  visionModel: string;
  imageModel: string;
  textModel: string; // 留空 = 使用视觉模型
  silhouetteModel: string; // 留空 = 与生图模型一致
  enabled: boolean;
  // 研究管线（Agentic）
  searchMode: 'qwen-official' | 'qwen' | 'searxng' | 'off';
  searchSite: string;
  searchBaseUrl: string;
  searchApiKey: string; // 留空 = 不修改原值
  searchQwenBaseUrl: string;
  searchQwenApiKey: string; // 留空 = 不修改原值
  searchQwenModel: string;
  searchQwenOfficialBaseUrl: string;
  searchQwenOfficialApiKey: string; // 留空 = 不修改原值
  searchQwenOfficialModel: string;
  maxIterations: number; // 迭代上限（预算护栏 1~3）
  // 网页爬取（文本通用工具循环，spec 2026-09-28）
  webCrawl: boolean;
  crawlMaxPerSession: number; // 单会话最大爬取次数 1~6
  crawlRenderEnabled: boolean;
  crawlRenderTimeoutMs: number;
  /** 域名 / cookie 行列表（value 留空 = 沿用存量） */
  crawlCookies: Array<{ domain: string; value: string }>;
  // 参考图抓取（spec 2026-09-28 参考图）
  researchImagesEnabled: boolean;
  researchImagesMax: number;
  researchImagesPageFetch: boolean;
  researchImagesSearchFallback: boolean;
  researchImagesVision: boolean;
  researchImagesTtlDays: number;
  // 识别稳定性（spec 2026-09-28）
  llmRetryCount: number; // 失败后额外重试次数 0~3
  llmTimeoutSeconds: number; // 单次调用超时（秒，入库时 ×1000）
  llmMaxTokens: number; // 单次输出 token 上限
}

/** 模态独立平台子表单状态 */
interface OverrideState {
  /** 独立平台开关（false = 跟随视觉平台） */
  independent: boolean;
  provider: ProviderKey;
  baseUrl: string;
  apiKey: string; // 留空 = 不修改原值
}

type Modality = 'text' | 'image' | 'silhouette';

/** 从已保存视图还原独立平台状态（null → 跟随） */
const overrideFromPlatform = (platform: AiPlatformOverride | null): OverrideState =>
  platform
    ? {
        independent: true,
        provider: (platform.provider in PROVIDER_PRESETS
          ? platform.provider
          : 'qwen') as ProviderKey,
        baseUrl: platform.baseUrl,
        apiKey: '',
      }
    : { independent: false, provider: 'qwen', baseUrl: '', apiKey: '' };

/** 厂商预设四卡（modelKey 决定卡片副标题展示的模型名；compact 用于独立平台区） */
function ProviderPresetGrid({
  activeKey,
  modelKey,
  compact,
  onSelect,
}: {
  activeKey: ProviderKey;
  modelKey: 'visionModel' | 'textModel' | 'imageModel';
  compact?: boolean;
  onSelect: (key: ProviderKey) => void;
}) {
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
      {PROVIDER_KEYS.map((key) => {
        const preset = PROVIDER_PRESETS[key];
        const active = activeKey === key;
        return (
          <button
            key={key}
            type="button"
            onClick={() => onSelect(key)}
            className={cn(
              'rounded-lg border text-left transition-colors',
              compact ? 'p-2' : 'p-3',
              active
                ? 'border-primary bg-primary/10'
                : 'border-border hover:bg-accent/40',
            )}
          >
            <div
              className={cn(
                'font-medium',
                compact ? 'text-xs' : 'text-sm',
                active ? 'text-primary' : 'text-foreground',
              )}
            >
              {preset.label}
            </div>
            <div className="mt-1 truncate text-xs text-muted-foreground" title={preset[modelKey]}>
              {preset[modelKey]}
            </div>
          </button>
        );
      })}
    </div>
  );
}

export function AiConfigForm({
  initial,
}: {
  initial: AiProviderConfigView | { configured: false };
}) {
  const { toast } = useToast();
  const configured = initial.configured;
  const initialTextPlatform = configured ? initial.textPlatform : null;
  const initialImagePlatform = configured ? initial.imagePlatform : null;
  const initialSilhouettePlatform = configured ? initial.silhouettePlatform : null;
  const [form, setForm] = useState<FormState>(() =>
    configured
      ? {
          provider: (initial.provider in PROVIDER_PRESETS
            ? initial.provider
            : 'qwen') as ProviderKey,
          baseUrl: initial.baseUrl,
          apiKey: '',
          visionModel: initial.visionModel,
          imageModel: initial.imageModel,
          textModel: initial.textModel,
          silhouetteModel: initial.silhouetteModel ?? '',
          enabled: initial.enabled,
          searchMode: initial.searchEnabled
            ? initial.searchProvider === 'qwen-official'
              ? 'qwen-official'
              : initial.searchProvider === 'qwen'
                ? 'qwen'
                : 'searxng'
            : 'off',
          searchBaseUrl: initial.searchBaseUrl,
          searchSite: initial.searchSite ?? '',
          searchApiKey: '',
          searchQwenBaseUrl: initial.searchQwenBaseUrl,
          searchQwenApiKey: '',
          searchQwenModel: initial.searchQwenModel,
          searchQwenOfficialBaseUrl: initial.searchQwenOfficialBaseUrl,
          searchQwenOfficialApiKey: '',
          searchQwenOfficialModel: initial.searchQwenOfficialModel,
          maxIterations: initial.maxIterations,
          webCrawl: initial.crawlEnabled === true,
          crawlMaxPerSession: initial.crawlMaxPerSession ?? 3,
          crawlRenderEnabled: initial.crawlRenderEnabled ?? false,
          crawlRenderTimeoutMs: initial.crawlRenderTimeoutMs ?? 20000,
          crawlCookies: (initial.crawlCookieDomains ?? []).map((d) => ({ domain: d, value: '' })),
          researchImagesEnabled: initial.researchImagesEnabled,
          researchImagesMax: initial.researchImagesMax,
          researchImagesPageFetch: initial.researchImagesPageFetch,
          researchImagesSearchFallback: initial.researchImagesSearchFallback,
          researchImagesVision: initial.researchImagesVision,
          researchImagesTtlDays: initial.researchImagesTtlDays,
          llmRetryCount: initial.llmRetryCount,
          llmTimeoutSeconds: Math.max(1, Math.round(initial.llmTimeoutMs / 1000)),
          llmMaxTokens: initial.llmMaxTokens,
        }
      : {
          provider: 'qwen',
          baseUrl: PROVIDER_PRESETS.qwen.baseUrl,
          apiKey: '',
          visionModel: PROVIDER_PRESETS.qwen.visionModel,
          imageModel: PROVIDER_PRESETS.qwen.imageModel,
          textModel: PROVIDER_PRESETS.qwen.textModel,
          silhouetteModel: '',
          enabled: false,
          searchMode: 'off',
          searchBaseUrl: '',
          searchSite: '',
          searchApiKey: '',
          searchQwenBaseUrl: '',
          searchQwenApiKey: '',
          searchQwenModel: '',
          searchQwenOfficialBaseUrl: '',
          searchQwenOfficialApiKey: '',
          searchQwenOfficialModel: '',
          maxIterations: 2,
          webCrawl: false,
          crawlMaxPerSession: 3,
          crawlRenderEnabled: false,
          crawlRenderTimeoutMs: 20000,
          crawlCookies: [],
          researchImagesEnabled: false,
          researchImagesMax: 6,
          researchImagesPageFetch: true,
          researchImagesSearchFallback: true,
          researchImagesVision: true,
          researchImagesTtlDays: 7,
          llmRetryCount: 2,
          llmTimeoutSeconds: 300,
          llmMaxTokens: 8192,
        },
  );
  /** 手动改过预设字段的标记：切换厂商时不覆盖 */
  const [touched, setTouched] = useState<
    Record<'baseUrl' | 'visionModel' | 'imageModel' | 'textModel', boolean>
  >({
    baseUrl: configured,
    visionModel: configured,
    imageModel: configured,
    textModel: configured,
  });
  const [apiKeyMasked, setApiKeyMasked] = useState(configured ? initial.apiKeyMasked : '');
  /** 有效文本模型（输入即实时推导：textModel 为空时回退 visionModel） */
  const effectiveTextModel =
    form.textModel.trim() === '' ? form.visionModel.trim() : form.textModel.trim();
  const [textOverride, setTextOverride] = useState<OverrideState>(() =>
    overrideFromPlatform(initialTextPlatform),
  );
  const [imageOverride, setImageOverride] = useState<OverrideState>(() =>
    overrideFromPlatform(initialImagePlatform),
  );
  const [silhouetteOverride, setSilhouetteOverride] = useState<OverrideState>(() =>
    overrideFromPlatform(initialSilhouettePlatform),
  );
  /** 已保存独立平台的脱敏 Key（占位符展示；为空 = 尚未保存过独立平台，保存时要求填 Key） */
  const [textPlatformMasked, setTextPlatformMasked] = useState(
    initialTextPlatform?.apiKeyMasked ?? '',
  );
  const [imagePlatformMasked, setImagePlatformMasked] = useState(
    initialImagePlatform?.apiKeyMasked ?? '',
  );
  const [silhouettePlatformMasked, setSilhouettePlatformMasked] = useState(
    initialSilhouettePlatform?.apiKeyMasked ?? '',
  );
  /** 已保存通用搜索 API 的脱敏 Key（占位符展示）；为空 = 尚未保存过，保存时启用通用 API 需填 Key */
  const [searchApiKeyMasked, setSearchApiKeyMasked] = useState(
    configured ? initial.searchApiKeyMasked : '',
  );
  /** 已保存 Qwen 搜索 API 的脱敏 Key（占位符展示） */
  const [searchQwenApiKeyMasked, setSearchQwenApiKeyMasked] = useState(
    configured ? initial.searchQwenApiKeyMasked : '',
  );
  /** 已保存 Qwen 官方百炼搜索 API 的脱敏 Key（占位符展示） */
  const [searchQwenOfficialApiKeyMasked, setSearchQwenOfficialApiKeyMasked] = useState(
    configured ? initial.searchQwenOfficialApiKeyMasked : '',
  );
  const [testResult, setTestResult] = useState<AiConfigTestResult | null>(null);
  const [testTargets, setTestTargets] = useState<AiConfigTestTarget[]>(ALL_TEST_TARGETS);
  const [savePending, startSave] = useTransition();
  const [testPending, startTest] = useTransition();

  const selectProvider = (key: ProviderKey) => {
    setForm((f) => ({
      ...f,
      provider: key,
      baseUrl: touched.baseUrl ? f.baseUrl : PROVIDER_PRESETS[key].baseUrl,
      visionModel: touched.visionModel ? f.visionModel : PROVIDER_PRESETS[key].visionModel,
      imageModel: touched.imageModel ? f.imageModel : PROVIDER_PRESETS[key].imageModel,
      textModel: touched.textModel ? f.textModel : PROVIDER_PRESETS[key].textModel,
    }));
  };

  const markTouched = (field: 'baseUrl' | 'visionModel' | 'imageModel' | 'textModel') =>
    setTouched((t) => ({ ...t, [field]: true }));

  /** 独立区预设选择：始终覆盖 provider/baseUrl；对应模型仅在为空时填充（避免覆盖用户输入） */
  const selectOverrideProvider = (modality: Modality, key: ProviderKey) => {
    const preset = PROVIDER_PRESETS[key];
    const setOverride =
      modality === 'text'
        ? setTextOverride
        : modality === 'image'
          ? setImageOverride
          : setSilhouetteOverride;
    setOverride((o) => ({ ...o, provider: key, baseUrl: preset.baseUrl }));
    const modelEmpty =
      modality === 'text'
        ? form.textModel.trim() === ''
        : modality === 'image'
          ? form.imageModel.trim() === ''
          : form.silhouetteModel.trim() === '';
    if (modelEmpty) {
      // 文本模态用预设文本模型；生图/剪影模态用预设生图模型（剪影模型不参与 touched，主厂商切换不会覆盖它）
      const model = modality === 'text' ? preset.textModel : preset.imageModel;
      if (modality !== 'silhouette') {
        markTouched(modality === 'text' ? 'textModel' : 'imageModel');
      }
      setForm((f) =>
        modality === 'text'
          ? { ...f, textModel: model }
          : modality === 'image'
            ? { ...f, imageModel: model }
            : { ...f, silhouetteModel: model },
      );
    }
  };

  /** 跟随↔独立切换：开启独立且 baseUrl 为空时预填（文本/生图取自共享平台，剪影取自生图模态）；关闭仅置 independent=false（保留输入便于反悔） */
  const toggleIndependent = (modality: Modality, independent: boolean) => {
    const setOverride =
      modality === 'text'
        ? setTextOverride
        : modality === 'image'
          ? setImageOverride
          : setSilhouetteOverride;
    // 剪影跟随生图模态：启用独立时的预填来源 = 生图独立平台 ?? 共享平台
    const imagePrefill =
      imageOverride.independent && imageOverride.baseUrl.trim() !== ''
        ? { provider: imageOverride.provider, baseUrl: imageOverride.baseUrl }
        : { provider: form.provider, baseUrl: form.baseUrl };
    setOverride((o) => {
      if (!independent) return { ...o, independent: false };
      if (o.baseUrl.trim() === '') {
        return {
          ...o,
          independent: true,
          provider: modality === 'silhouette' ? imagePrefill.provider : form.provider,
          baseUrl: modality === 'silhouette' ? imagePrefill.baseUrl : form.baseUrl,
        };
      }
      return { ...o, independent: true };
    });
    // 剪影启用独立且未指定模型 → 预填生效平台预设的默认生图模型（一次点选即可用）
    if (modality === 'silhouette' && independent && form.silhouetteModel.trim() === '') {
      const provider = silhouetteOverride.independent ? silhouetteOverride.provider : imagePrefill.provider;
      setForm((f) => ({ ...f, silhouetteModel: PROVIDER_PRESETS[provider].imageModel }));
    }
  };

  const handleSave = () => {
    if (!form.baseUrl.trim() || !form.visionModel.trim() || !form.imageModel.trim()) {
      toast({ variant: 'destructive', title: '请填写完整', description: 'baseUrl 与模型名不能为空' });
      return;
    }
    if (!configured && !form.apiKey.trim()) {
      toast({ variant: 'destructive', title: '缺少 API Key', description: '首次配置必须填写 API Key' });
      return;
    }
    if (textOverride.independent && (!textOverride.baseUrl.trim() || !form.textModel.trim())) {
      toast({
        variant: 'destructive',
        title: '请填写完整',
        description: '文本独立平台 baseUrl 与模型名不能为空',
      });
      return;
    }
    if (textOverride.independent && !textPlatformMasked && !textOverride.apiKey.trim()) {
      toast({
        variant: 'destructive',
        title: '缺少 API Key',
        description: '首次配置文本独立平台必须填写 API Key',
      });
      return;
    }
    if (imageOverride.independent && !imageOverride.baseUrl.trim()) {
      toast({
        variant: 'destructive',
        title: '请填写完整',
        description: '生图独立平台 baseUrl 与模型名不能为空',
      });
      return;
    }
    if (imageOverride.independent && !imagePlatformMasked && !imageOverride.apiKey.trim()) {
      toast({
        variant: 'destructive',
        title: '缺少 API Key',
        description: '首次配置生图独立平台必须填写 API Key',
      });
      return;
    }
    if (silhouetteOverride.independent && !silhouetteOverride.baseUrl.trim()) {
      toast({
        variant: 'destructive',
        title: '请填写完整',
        description: '剪影独立平台 baseUrl 与模型名不能为空',
      });
      return;
    }
    if (silhouetteOverride.independent && !silhouettePlatformMasked && !silhouetteOverride.apiKey.trim()) {
      toast({
        variant: 'destructive',
        title: '缺少 API Key',
        description: '首次配置剪影独立平台必须填写 API Key',
      });
      return;
    }
    if (form.searchMode === 'qwen-official') {
      if (!form.searchQwenOfficialBaseUrl.trim()) {
        toast({
          variant: 'destructive',
          title: '请填写完整',
          description: 'Qwen 官方搜索必须填写 baseUrl',
        });
        return;
      }
      if (!searchQwenOfficialApiKeyMasked && !form.searchQwenOfficialApiKey.trim()) {
        toast({
          variant: 'destructive',
          title: '缺少 API Key',
          description: '首次启用 Qwen 官方搜索必须填写 API Key',
        });
        return;
      }
    } else if (form.searchMode === 'qwen') {
      if (!form.searchQwenBaseUrl.trim()) {
        toast({
          variant: 'destructive',
          title: '请填写完整',
          description: 'Qwen 搜索必须填写 baseUrl',
        });
        return;
      }
      if (!searchQwenApiKeyMasked && !form.searchQwenApiKey.trim()) {
        toast({
          variant: 'destructive',
          title: '缺少 API Key',
          description: '首次启用 Qwen 搜索必须填写 API Key',
        });
        return;
      }
    } else if (form.searchMode === 'searxng' && !form.searchBaseUrl.trim()) {
      toast({
        variant: 'destructive',
        title: '缺少 SearXNG Base URL',
        description: 'SearXNG 自建搜索必须填写 Base URL（如 http://lumira-searxng:8080）',
      });
      return;
    }
    startSave(async () => {
      const payload: UpdateAiConfigPayload = {
        provider: form.provider,
        baseUrl: form.baseUrl.trim(),
        apiKey: form.apiKey.trim() || undefined,
        visionModel: form.visionModel.trim(),
        imageModel: form.imageModel.trim(),
        textModel: form.textModel.trim(),
        silhouetteModel: form.silhouetteModel.trim() || undefined,
        enabled: form.enabled,
      };
      if (textOverride.independent) {
        payload.textProvider = textOverride.provider;
        payload.textBaseUrl = textOverride.baseUrl.trim();
        if (textOverride.apiKey.trim()) payload.textApiKey = textOverride.apiKey.trim();
      }
      if (imageOverride.independent) {
        payload.imageProvider = imageOverride.provider;
        payload.imageBaseUrl = imageOverride.baseUrl.trim();
        if (imageOverride.apiKey.trim()) payload.imageApiKey = imageOverride.apiKey.trim();
      }
      if (silhouetteOverride.independent) {
        payload.silhouetteProvider = silhouetteOverride.provider;
        payload.silhouetteBaseUrl = silhouetteOverride.baseUrl.trim();
        if (silhouetteOverride.apiKey.trim()) payload.silhouetteApiKey = silhouetteOverride.apiKey.trim();
      }
      // 研究管线（Agentic）：搜索方式四选一互斥 → provider/sources/字段映射
      payload.searchEnabled = form.searchMode !== 'off';
      payload.crawlEnabled = form.webCrawl;
      payload.crawlMaxPerSession = Number(form.crawlMaxPerSession) || 3;
      payload.crawlRenderEnabled = form.crawlRenderEnabled;
      payload.crawlRenderTimeoutMs = Number(form.crawlRenderTimeoutMs) || 20000;
      // 只提交填了值的行（value 留空 = 沿用存量）；一行都没填则不发该字段（保留存量）
      const filledCookies = Object.fromEntries(
        form.crawlCookies
          .map((r) => ({ domain: r.domain.trim(), value: r.value.trim() }))
          .filter((r) => r.domain && r.value)
          .map((r) => [r.domain, r.value]),
      );
      if (Object.keys(filledCookies).length > 0) payload.crawlCookies = filledCookies;
      payload.maxIterations = form.maxIterations;
      payload.llmRetryCount = form.llmRetryCount;
      payload.llmTimeoutMs = Math.round(form.llmTimeoutSeconds * 1000);
      payload.llmMaxTokens = form.llmMaxTokens;
      payload.researchImagesEnabled = form.researchImagesEnabled;
      payload.researchImagesMax = form.researchImagesMax;
      payload.researchImagesPageFetch = form.researchImagesPageFetch;
      payload.researchImagesSearchFallback = form.researchImagesSearchFallback;
      payload.researchImagesVision = form.researchImagesVision;
      payload.researchImagesTtlDays = form.researchImagesTtlDays;
      if (form.searchMode === 'qwen-official') {
        payload.searchProvider = 'qwen-official';
        payload.searchSources = ['qwen-official'];
        if (form.searchQwenOfficialBaseUrl.trim()) payload.searchQwenOfficialBaseUrl = form.searchQwenOfficialBaseUrl.trim();
        if (form.searchQwenOfficialApiKey.trim()) payload.searchQwenOfficialApiKey = form.searchQwenOfficialApiKey.trim();
        payload.searchQwenOfficialModel = form.searchQwenOfficialModel.trim() || 'qwen-plus';
      } else if (form.searchMode === 'qwen') {
        payload.searchProvider = 'qwen';
        payload.searchSources = ['qwen'];
        if (form.searchQwenBaseUrl.trim()) payload.searchQwenBaseUrl = form.searchQwenBaseUrl.trim();
        if (form.searchQwenApiKey.trim()) payload.searchQwenApiKey = form.searchQwenApiKey.trim();
        payload.searchQwenModel = form.searchQwenModel.trim() || 'qwen-plus';
      } else if (form.searchMode === 'searxng') {
        payload.searchProvider = 'general';
        payload.searchSources = ['searxng'];
        if (form.searchBaseUrl.trim()) payload.searchBaseUrl = form.searchBaseUrl.trim();
        if (form.searchApiKey.trim()) payload.searchApiKey = form.searchApiKey.trim();
        if (form.searchSite.trim()) payload.searchSite = form.searchSite.trim();
      } else {
        payload.searchProvider = 'off';
      }
      const result = await saveAiConfigAction(payload);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '保存失败', description: result.error });
        return;
      }
      const { config } = result;
      setApiKeyMasked(config.apiKeyMasked);
      setTextPlatformMasked(config.textPlatform?.apiKeyMasked ?? '');
      setImagePlatformMasked(config.imagePlatform?.apiKeyMasked ?? '');
      setSilhouettePlatformMasked(config.silhouettePlatform?.apiKeyMasked ?? '');
      setSearchApiKeyMasked(config.searchApiKeyMasked);
      setSearchQwenApiKeyMasked(config.searchQwenApiKeyMasked);
      setSearchQwenOfficialApiKeyMasked(config.searchQwenOfficialApiKeyMasked);
      // 后端为权威：独立开关与平台字段按保存结果回填（被清除时保留输入、仅置回跟随）
      setTextOverride((o) => {
        const saved = overrideFromPlatform(config.textPlatform);
        return saved.independent ? saved : { ...o, independent: false, apiKey: '' };
      });
      setImageOverride((o) => {
        const saved = overrideFromPlatform(config.imagePlatform);
        return saved.independent ? saved : { ...o, independent: false, apiKey: '' };
      });
      setSilhouetteOverride((o) => {
        const saved = overrideFromPlatform(config.silhouettePlatform);
        return saved.independent ? saved : { ...o, independent: false, apiKey: '' };
      });
      setForm((f) => ({ ...f, apiKey: '' }));
      setTouched({ baseUrl: true, visionModel: true, imageModel: true, textModel: true });
      toast({ title: '已保存', description: '新的 AI 请求将使用新配置' });
    });
  };

  const handleTest = () => {
    setTestResult(null);
    startTest(async () => {
      const result = await testAiConfigAction({ targets: testTargets });
      if ('error' in result) {
        toast({ variant: 'destructive', title: '测试请求失败', description: result.error });
        return;
      }
      setTestResult(result);
    });
  };

  const toggleTestTarget = (target: AiConfigTestTarget, checked: boolean) => {
    setTestTargets((current) => (
      checked
        ? [...new Set([...current, target])]
        : current.filter((item) => item !== target)
    ));
  };

  const renderTestResult = () => {
    if (!testResult) return null;
    const entries = TEST_TARGET_OPTIONS
      .map((option) => ({ option, result: testResult[option.value] }))
      .filter((entry) => Boolean(entry.result));
    const allOk = entries.length > 0 && entries.every((entry) => entry.result?.ok);
    return (
      <div
        className={cn(
          'rounded-lg border p-4 text-sm',
          allOk
            ? 'border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200'
            : 'border-destructive/50 bg-destructive/10 text-destructive',
        )}
      >
        <div className="font-medium">
          {allOk ? `已测模型连接成功（${entries.length} 项）` : '测试完成，存在失败项'}
        </div>
        {entries.map(({ option, result }) => (
          <div
            key={option.value}
            className={cn(
              'mt-2 flex items-center justify-between gap-2 rounded-md border p-3',
              result?.ok
                ? 'border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200'
                : 'border-destructive/50 bg-destructive/10 text-destructive',
            )}
          >
            <span>{option.label}模型</span>
            <span className="text-right">
              {result?.ok
                ? `连通 ${result.latencyMs ?? '?'}ms`
                : (result?.error ?? '连接失败')}
            </span>
          </div>
        ))}
        <div className="mt-1 text-xs opacity-70">{testResult.note}</div>
      </div>
    );
  };

  /** 文本/生图/剪影模态区块（跟随 ↔ 独立平台切换；剪影默认跟随生图模态） */
  const renderModalitySection = (modality: Modality) => {
    const isText = modality === 'text';
    const isSilhouette = modality === 'silhouette';
    const override = isText ? textOverride : isSilhouette ? silhouetteOverride : imageOverride;
    const setOverride = isText
      ? setTextOverride
      : isSilhouette
        ? setSilhouetteOverride
        : setImageOverride;
    const masked = isText
      ? textPlatformMasked
      : isSilhouette
        ? silhouettePlatformMasked
        : imagePlatformMasked;
    const modelValue = isText
      ? form.textModel
      : isSilhouette
        ? form.silhouetteModel
        : form.imageModel;
    const modelId = isSilhouette ? 'ai-silhouette-model' : isText ? 'ai-text-model' : 'ai-image-model';
    const followLabel = isSilhouette ? '跟随生图平台' : '跟随视觉平台';
    return (
      <div className="space-y-4 rounded-lg border border-border p-4">
        <div>
          <div className="text-sm font-medium text-foreground">
            {isSilhouette
              ? '剪影模型 · AI 一键建模剪影生成'
              : isText
                ? '文本模型 · 识别与提示词润色'
                : '生图模型 · 封面效果图'}
          </div>
          <div className="mt-0.5 text-xs text-muted-foreground">
            {followLabel}，或切换为独立平台（OpenAI 兼容接口）
          </div>
        </div>

        {/* 跟随/独立切换 */}
        <div className="space-y-2">
          <Label>平台来源</Label>
          <div className="inline-flex rounded-md border border-border p-0.5">
            {([false, true] as const).map((independent) => (
              <button
                key={independent ? 'independent' : 'follow'}
                type="button"
                onClick={() => toggleIndependent(modality, independent)}
                className={cn(
                  'rounded px-3 py-1 text-sm transition-colors',
                  override.independent === independent
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {independent ? '独立平台' : followLabel}
              </button>
            ))}
          </div>
        </div>

        {override.independent ? (
          <>
            <ProviderPresetGrid
              activeKey={override.provider}
              modelKey={isSilhouette || !isText ? 'imageModel' : 'textModel'}
              compact
              onSelect={(key) => selectOverrideProvider(modality, key)}
            />
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor={`ai-${modality}-base-url`}>独立平台 Base URL</Label>
                <Input
                  id={`ai-${modality}-base-url`}
                  value={override.baseUrl}
                  onChange={(e) =>
                    setOverride((o) => ({ ...o, baseUrl: e.target.value }))
                  }
                  placeholder="https://api.example.com/v1"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor={`ai-${modality}-api-key`}>独立平台 API Key</Label>
                <Input
                  id={`ai-${modality}-api-key`}
                  type="password"
                  value={override.apiKey}
                  onChange={(e) =>
                    setOverride((o) => ({ ...o, apiKey: e.target.value }))
                  }
                  placeholder={masked ? `${masked}（留空 = 不修改）` : 'sk-…'}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor={modelId}>
                  {isSilhouette ? '剪影模型' : isText ? '文本模型' : '生图模型'}
                  {isSilhouette ? '（留空 = 默认生图模型）' : '（独立平台必填）'}
                </Label>
                <Input
                  id={modelId}
                  value={modelValue}
                  onChange={(e) => {
                    if (!isSilhouette) markTouched(isText ? 'textModel' : 'imageModel');
                    const value = e.target.value;
                    setForm((f) =>
                      isSilhouette
                        ? { ...f, silhouetteModel: value }
                        : isText
                          ? { ...f, textModel: value }
                          : { ...f, imageModel: value },
                    );
                  }}
                  placeholder={
                    isSilhouette
                      ? '留空 = 默认生图模型'
                      : isText
                        ? '例：qwen-plus / gpt-4o-mini'
                        : override.provider === 'doubao'
                          ? '接入点 ep-xxx 或模型名'
                          : 'wanx2.1-t2i-turbo'
                  }
                />
              </div>
            </div>
          </>
        ) : isSilhouette ? (
          /* 跟随生图平台：保留原「剪影模型 + 同生图模型」交互 */
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label htmlFor="ai-silhouette-model">剪影模型（可选）</Label>
              <button
                type="button"
                className="text-xs text-muted-foreground underline-offset-2 hover:text-foreground hover:underline disabled:opacity-40"
                disabled={!form.imageModel.trim() || form.silhouetteModel.trim() === form.imageModel.trim()}
                onClick={() => setForm((f) => ({ ...f, silhouetteModel: f.imageModel.trim() }))}
              >
                同生图模型
              </button>
            </div>
            <Input
              id="ai-silhouette-model"
              value={form.silhouetteModel}
              onChange={(e) => setForm((f) => ({ ...f, silhouetteModel: e.target.value }))}
              placeholder="留空 = 使用生图模型（用于 AI 一键建模的剪影生成）"
            />
            <p className="text-xs text-muted-foreground">
              AI 一键建模「生成剪影」选用 AI 方式时使用的模型；不填则与生图模型一致，平台与 Key 跟随生图模态
            </p>
          </div>
        ) : isText ? (
          <div className="space-y-2">
            <Label htmlFor="ai-text-model">文本模型</Label>
            <Input
              id="ai-text-model"
              value={form.textModel}
              onChange={(e) => {
                markTouched('textModel');
                setForm((f) => ({ ...f, textModel: e.target.value }));
              }}
              placeholder="留空则使用视觉模型（用于文字识别与生图提示词润色）"
            />
            {form.textModel.trim() === '' && effectiveTextModel && (
              <p className="text-xs text-muted-foreground">当前生效：{effectiveTextModel}</p>
            )}
          </div>
        ) : (
          <div className="space-y-2">
            <Label htmlFor="ai-image-model">生图模型</Label>
            <Input
              id="ai-image-model"
              value={form.imageModel}
              onChange={(e) => {
                markTouched('imageModel');
                setForm((f) => ({ ...f, imageModel: e.target.value }));
              }}
              placeholder={form.provider === 'doubao' ? '接入点 ep-xxx 或模型名' : 'wanx2.1-t2i-turbo'}
            />
          </div>
        )}
      </div>
    );
  };

  return (
    <>
      {!configured && (
        <Card className="border-amber-300 bg-amber-50 dark:border-amber-900 dark:bg-amber-950">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-amber-900 dark:text-amber-200">
              AI 尚未配置
            </CardTitle>
            <CardDescription className="text-amber-800/80 dark:text-amber-300/80">
              完成并保存下方配置后，向导页的「风格识别 / 生成效果图 / AI 剪影」功能才可用（剪影仍可切「本地抠图」，不依赖本配置）。
            </CardDescription>
          </CardHeader>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>AI 服务配置</CardTitle>
          <CardDescription>
            视觉模型用于风格识别，文本/生图模态可切换独立平台（OpenAI 兼容接口），用于 AI
            一键模板录入。配置需保存后新请求才生效。
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* 模态一：视觉模型（共享平台） */}
          <div className="space-y-4 rounded-lg border border-border p-4">
            <div>
              <div className="text-sm font-medium text-foreground">视觉模型 · 风格识别</div>
              <div className="mt-0.5 text-xs text-muted-foreground">
                共享平台，同时是文本/生图模态的默认平台
              </div>
            </div>
            <ProviderPresetGrid
              activeKey={form.provider}
              modelKey="visionModel"
              onSelect={selectProvider}
            />
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="ai-base-url">Base URL</Label>
                <Input
                  id="ai-base-url"
                  value={form.baseUrl}
                  onChange={(e) => {
                    markTouched('baseUrl');
                    setForm((f) => ({ ...f, baseUrl: e.target.value }));
                  }}
                  placeholder="https://api.example.com/v1"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ai-api-key">API Key</Label>
                <Input
                  id="ai-api-key"
                  type="password"
                  value={form.apiKey}
                  onChange={(e) => setForm((f) => ({ ...f, apiKey: e.target.value }))}
                  placeholder={apiKeyMasked ? `${apiKeyMasked}（留空 = 不修改）` : 'sk-…'}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ai-vision-model">视觉模型</Label>
                <Input
                  id="ai-vision-model"
                  value={form.visionModel}
                  onChange={(e) => {
                    markTouched('visionModel');
                    setForm((f) => ({ ...f, visionModel: e.target.value }));
                  }}
                  placeholder={form.provider === 'doubao' ? '接入点 ep-xxx 或模型名' : 'qwen-vl-max'}
                />
              </div>
            </div>
          </div>

          {/* 模态二：文本模型 */}
          {renderModalitySection('text')}

          {/* 模态三：生图模型 */}
          {renderModalitySection('image')}

          {/* 模态四：剪影模型（AI 一键建模「生成剪影」用，默认跟随生图平台） */}
          {renderModalitySection('silhouette')}

          {/* 研究管线（Agentic）：搜索方式四选一（互斥） */}
          <div className="space-y-4 rounded-lg border border-border p-4">
            <div>
              <div className="text-sm font-medium text-foreground">研究管线（Agentic 趋势研究）</div>
              <div className="mt-0.5 text-xs text-muted-foreground">
                生成模板时结合联网趋势研究提升热点 / 真实感。关闭时走原单次识别路径。
              </div>
            </div>

            <div className="space-y-2">
              <Label>搜索方式</Label>
              <div className="inline-flex rounded-md border border-border p-0.5">
                {SEARCH_MODE_OPTIONS.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => setForm((f) => ({ ...f, searchMode: option.value }))}
                    className={cn(
                      'rounded px-3 py-1 text-sm transition-colors',
                      form.searchMode === option.value
                        ? 'bg-primary text-primary-foreground'
                        : 'text-muted-foreground hover:text-foreground',
                    )}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            {form.searchMode === 'qwen-official' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-base-url">Qwen 官方端点（Base URL）</Label>
                  <Input
                    id="ai-qwen-official-base-url"
                    value={form.searchQwenOfficialBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialBaseUrl: e.target.value }))}
                    placeholder="https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-api-key">Qwen 官方 API Key</Label>
                  <Input
                    id="ai-qwen-official-api-key"
                    type="password"
                    value={form.searchQwenOfficialApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialApiKey: e.target.value }))}
                    placeholder={searchQwenOfficialApiKeyMasked ? `${searchQwenOfficialApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-model">Qwen 官方模型</Label>
                  <Input
                    id="ai-qwen-official-model"
                    value={form.searchQwenOfficialModel}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialModel: e.target.value }))}
                    placeholder="qwen-plus"
                  />
                </div>
              </div>
            )}

            {form.searchMode === 'qwen' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-base-url">Qwen 三方 MaaS 端点（Base URL）</Label>
                  <Input
                    id="ai-qwen-base-url"
                    value={form.searchQwenBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenBaseUrl: e.target.value }))}
                    placeholder="https://your-maas-relay.com/v1"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-api-key">Qwen 三方 MaaS API Key</Label>
                  <Input
                    id="ai-qwen-api-key"
                    type="password"
                    value={form.searchQwenApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenApiKey: e.target.value }))}
                    placeholder={searchQwenApiKeyMasked ? `${searchQwenApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-model">Qwen 三方 MaaS 模型</Label>
                  <Input
                    id="ai-qwen-model"
                    value={form.searchQwenModel}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenModel: e.target.value }))}
                    placeholder="qwen-plus"
                  />
                </div>
              </div>
            )}

            {form.searchMode === 'searxng' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-searxng-base-url">SearXNG Base URL</Label>
                  <Input
                    id="ai-searxng-base-url"
                    value={form.searchBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchBaseUrl: e.target.value }))}
                    placeholder="http://lumira-searxng:8080"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-searxng-api-key">SearXNG API Key（可选）</Label>
                  <Input
                    id="ai-searxng-api-key"
                    type="password"
                    value={form.searchApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchApiKey: e.target.value }))}
                    placeholder={searchApiKeyMasked ? `${searchApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="ai-searxng-site">站点限定（可选）</Label>
                  <Input
                    id="ai-searxng-site"
                    value={form.searchSite}
                    onChange={(e) => setForm((f) => ({ ...f, searchSite: e.target.value }))}
                    placeholder="xiaohongshu.com / v.douyin.com，留空 = 默认检索小红书等平台"
                  />
                  <p className="text-xs text-muted-foreground">
                    留空则默认检索小红书、抖音、微博、知乎等社交平台（小红书为主）并辅以全站兜底；填写后仅检索该站点。
                  </p>
                </div>
              </div>
            )}

            {form.searchMode !== 'off' && (
              <div className="space-y-2 md:max-w-xs">
                <Label htmlFor="ai-max-iterations">迭代上限（预算护栏）</Label>
                <Input
                  id="ai-max-iterations"
                  type="number"
                  min={1}
                  max={3}
                  value={form.maxIterations}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      maxIterations: Number(e.target.value) || 1,
                    }))
                  }
                />
                <p className="text-xs text-muted-foreground">
                  质量不达标时依评审建议微调重试，最多迭代该次数；1~3，绝不无限迭代。费用与耗时递增。
                </p>
              </div>
            )}

            <div className="space-y-3 rounded-lg border p-3">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium">参考图抓取</div>
                  <p className="text-xs text-muted-foreground">联网检索后抓取参考网站图片，交给多模态模型转述后注入生图提示词（仅作文本参考，不作底图）</p>
                </div>
                <Switch
                  checked={form.researchImagesEnabled}
                  onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesEnabled: v }))}
                />
              </div>
              {form.researchImagesEnabled ? (
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <Label htmlFor="ri-max">最多保留张数</Label>
                    <Input id="ri-max" type="number" min={1} max={12} value={form.researchImagesMax}
                      onChange={(e) => setForm((s) => ({ ...s, researchImagesMax: Number(e.target.value) || 6 }))} />
                  </div>
                  <div className="space-y-1">
                    <Label htmlFor="ri-ttl">图片保留天数</Label>
                    <Input id="ri-ttl" type="number" min={1} max={90} value={form.researchImagesTtlDays}
                      onChange={(e) => setForm((s) => ({ ...s, researchImagesTtlDays: Number(e.target.value) || 7 }))} />
                  </div>
                  <label className="flex items-center gap-2 text-sm">
                    <Switch checked={form.researchImagesPageFetch}
                      onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesPageFetch: v }))} />
                    抓取命中页面 og:image
                  </label>
                  <label className="flex items-center gap-2 text-sm">
                    <Switch checked={form.researchImagesSearchFallback}
                      onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesSearchFallback: v }))} />
                    图片搜索兜底
                  </label>
                  <label className="flex items-center gap-2 text-sm">
                    <Switch checked={form.researchImagesVision}
                      onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesVision: v }))} />
                    多模态解读
                  </label>
                </div>
              ) : null}
            </div>

            <div className="space-y-4 border-t pt-4">
              <div>
                <p className="text-sm font-medium">识别稳定性</p>
                <p className="text-xs text-muted-foreground">
                  识别步骤（示例图识别 / 草稿生成 / 姿势面片 / 质量评分 / 草稿细化）遇到输出非法 JSON、超时、上游 5xx 或空输出时，
                  会先做结构补救再自动重试；鉴权类错误不重试。
                </p>
              </div>
              <div className="grid gap-4 md:grid-cols-3">
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-retry-count">失败重试次数</Label>
                  <Input
                    id="ai-llm-retry-count"
                    type="number"
                    min={0}
                    max={3}
                    value={form.llmRetryCount}
                    onChange={(e) => setForm((f) => ({ ...f, llmRetryCount: e.target.value === '' ? 2 : Number(e.target.value) }))}
                  />
                  <p className="text-xs text-muted-foreground">0~3，默认 2。总调用次数 ≤ 次数 + 1。</p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-timeout">单次调用超时（秒）</Label>
                  <Input
                    id="ai-llm-timeout"
                    type="number"
                    min={10}
                    max={600}
                    value={form.llmTimeoutSeconds}
                    onChange={(e) => setForm((f) => ({ ...f, llmTimeoutSeconds: Number(e.target.value) || 300 }))}
                  />
                  <p className="text-xs text-muted-foreground">10~600，默认 300（5 分钟）。含图识别建议不低于 120。</p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-max-tokens">单次输出上限（token）</Label>
                  <Input
                    id="ai-llm-max-tokens"
                    type="number"
                    min={1024}
                    max={16384}
                    value={form.llmMaxTokens}
                    onChange={(e) => setForm((f) => ({ ...f, llmMaxTokens: Number(e.target.value) || 8192 }))}
                  />
                  <p className="text-xs text-muted-foreground">1024~16384，默认 8192。穷尽式识别输出大，过低会导致 JSON 被截断。</p>
                </div>
              </div>
            </div>
          </div>

          {/* 网页爬取（文本通用工具循环）：开关 + 单会话次数上限 */}
          <Card className="space-y-4 p-4 shadow-none">
            <div>
              <div className="text-sm font-medium text-foreground">网页爬取</div>
              <div className="mt-0.5 text-xs text-muted-foreground">
                开启后，文本模型可在生成过程中按需抓取搜索结果/用户提供链接的网页正文（仅静态页面，单会话有次数上限）。
              </div>
            </div>

            <div className="flex items-center justify-between">
              <label htmlFor="ai-web-crawl-enabled" className="text-sm font-medium text-foreground">
                启用网页爬取
              </label>
              <Switch
                id="ai-web-crawl-enabled"
                checked={form.webCrawl}
                onCheckedChange={(v) => setForm((f) => ({ ...f, webCrawl: v }))}
              />
            </div>

            <div className="space-y-2 md:max-w-xs">
              <Label htmlFor="ai-crawl-max-per-session">单会话次数上限</Label>
              <Input
                id="ai-crawl-max-per-session"
                type="number"
                min={1}
                max={6}
                value={form.crawlMaxPerSession}
                disabled={!form.webCrawl}
                onChange={(e) =>
                  setForm((f) => ({ ...f, crawlMaxPerSession: Number(e.target.value) || 3 }))
                }
              />
              <p className="text-xs text-muted-foreground">
                1~6，默认 3。单次会话内模型最多调用该次数，超限后仍会产出最终结果。
              </p>
            </div>

            <div className="flex items-center justify-between">
              <label htmlFor="ai-crawl-render-enabled" className="text-sm font-medium text-foreground">
                静态抓取失败时用无头浏览器渲染
              </label>
              <Switch
                id="ai-crawl-render-enabled"
                checked={form.crawlRenderEnabled}
                disabled={!form.webCrawl}
                onCheckedChange={(v) => setForm((f) => ({ ...f, crawlRenderEnabled: v }))}
              />
            </div>
            <p className="text-xs text-muted-foreground">
              需后端配置 RENDERER_WS_ENDPOINT 才生效；关闭时仅做静态抓取。
            </p>

            <div className="space-y-2 md:max-w-xs">
              <Label htmlFor="ai-crawl-render-timeout">渲染超时（毫秒）</Label>
              <Input
                id="ai-crawl-render-timeout"
                type="number"
                min={5000}
                max={60000}
                value={form.crawlRenderTimeoutMs}
                disabled={!form.webCrawl || !form.crawlRenderEnabled}
                onChange={(e) => setForm((f) => ({ ...f, crawlRenderTimeoutMs: Number(e.target.value) || 20000 }))}
              />
              <p className="text-xs text-muted-foreground">5000~60000，默认 20000。</p>
            </div>

            <div className="space-y-2">
              <Label>登录态 Cookie（按域名隔离）</Label>
              <p className="text-xs text-muted-foreground">
                仅对匹配的域名发送（含其子域）。保存后只显示域名，值不会回传；值留空 = 沿用已保存的值。
              </p>
              {form.crawlCookies.map((row, i) => (
                <div key={i} className="flex gap-2">
                  <Input
                    placeholder="zhihu.com"
                    value={row.domain}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        crawlCookies: f.crawlCookies.map((r, j) => (j === i ? { ...r, domain: e.target.value } : r)),
                      }))
                    }
                  />
                  <Input
                    type="password"
                    placeholder="z_c0=..."
                    value={row.value}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        crawlCookies: f.crawlCookies.map((r, j) => (j === i ? { ...r, value: e.target.value } : r)),
                      }))
                    }
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => setForm((f) => ({ ...f, crawlCookies: f.crawlCookies.filter((_, j) => j !== i) }))}
                  >
                    删除
                  </Button>
                </div>
              ))}
              <Button
                type="button"
                variant="outline"
                onClick={() => setForm((f) => ({ ...f, crawlCookies: [...f.crawlCookies, { domain: '', value: '' }] }))}
              >
                添加域名 Cookie
              </Button>
            </div>
          </Card>

          {/* 启用开关 */}
          <div className="flex items-center justify-between rounded-lg border border-border px-4 py-3">
            <div>
              <div className="text-sm font-medium text-foreground">启用 AI 功能</div>
              <div className="text-xs text-muted-foreground">
                关闭后，向导页的识别、生图与 AI 剪影请求将返回「AI 未配置或未启用」；本地抠图剪影不受影响
              </div>
            </div>
            <Switch
              checked={form.enabled}
              onCheckedChange={(checked) => setForm((f) => ({ ...f, enabled: checked }))}
            />
          </div>

          {/* 按钮行 */}
          <div className="space-y-3">
            <div className="flex flex-wrap gap-2">
              {TEST_TARGET_OPTIONS.map((option) => (
                <label
                  key={option.value}
                  className={cn(
                    'flex cursor-pointer items-center gap-2 rounded-md border px-3 py-2 text-sm',
                    testTargets.includes(option.value)
                      ? 'border-primary bg-primary/5 text-foreground'
                      : 'border-border bg-background text-muted-foreground',
                  )}
                >
                  <input
                    type="checkbox"
                    className="h-4 w-4"
                    checked={testTargets.includes(option.value)}
                    disabled={testPending}
                    onChange={(event) => toggleTestTarget(option.value, event.target.checked)}
                  />
                  {option.label}
                </label>
              ))}
            </div>
            <p className="text-xs text-muted-foreground">
              默认全部测试；生图与剪影会产生真实模型调用费用。
            </p>
            <div className="flex items-center gap-3">
              <Button onClick={handleSave} disabled={savePending}>
                {savePending ? '保存中…' : '保存'}
              </Button>
              <Button variant="outline" onClick={handleTest} disabled={testPending || testTargets.length === 0}>
                {testPending ? '测试中…' : '测试连接'}
              </Button>
            </div>
          </div>

          {/* 测试结果 */}
          {renderTestResult()}
        </CardContent>
      </Card>
    </>
  );
}
