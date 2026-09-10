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

interface FormState {
  provider: ProviderKey;
  baseUrl: string;
  apiKey: string; // 留空 = 不修改原值
  visionModel: string;
  imageModel: string;
  textModel: string; // 留空 = 使用视觉模型
  silhouetteModel: string; // 留空 = 与生图模型一致
  enabled: boolean;
}

/** 模态独立平台子表单状态 */
interface OverrideState {
  /** 独立平台开关（false = 跟随视觉平台） */
  independent: boolean;
  provider: ProviderKey;
  baseUrl: string;
  apiKey: string; // 留空 = 不修改原值
}

type Modality = 'text' | 'image';

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
  /** 已保存独立平台的脱敏 Key（占位符展示；为空 = 尚未保存过独立平台，保存时要求填 Key） */
  const [textPlatformMasked, setTextPlatformMasked] = useState(
    initialTextPlatform?.apiKeyMasked ?? '',
  );
  const [imagePlatformMasked, setImagePlatformMasked] = useState(
    initialImagePlatform?.apiKeyMasked ?? '',
  );
  const [testResult, setTestResult] = useState<AiConfigTestResult | null>(null);
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
    const setOverride = modality === 'text' ? setTextOverride : setImageOverride;
    setOverride((o) => ({ ...o, provider: key, baseUrl: preset.baseUrl }));
    const modelEmpty =
      modality === 'text' ? form.textModel.trim() === '' : form.imageModel.trim() === '';
    if (modelEmpty) {
      const model = modality === 'text' ? preset.textModel : preset.imageModel;
      markTouched(modality === 'text' ? 'textModel' : 'imageModel');
      setForm((f) =>
        modality === 'text' ? { ...f, textModel: model } : { ...f, imageModel: model },
      );
    }
  };

  /** 跟随↔独立切换：开启独立且 baseUrl 为空时从主平台预填；关闭仅置 independent=false（保留输入便于反悔） */
  const toggleIndependent = (modality: Modality, independent: boolean) => {
    const setOverride = modality === 'text' ? setTextOverride : setImageOverride;
    setOverride((o) => {
      if (!independent) return { ...o, independent: false };
      if (o.baseUrl.trim() === '') {
        return { ...o, independent: true, provider: form.provider, baseUrl: form.baseUrl };
      }
      return { ...o, independent: true };
    });
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
      const result = await saveAiConfigAction(payload);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '保存失败', description: result.error });
        return;
      }
      const { config } = result;
      setApiKeyMasked(config.apiKeyMasked);
      setTextPlatformMasked(config.textPlatform?.apiKeyMasked ?? '');
      setImagePlatformMasked(config.imagePlatform?.apiKeyMasked ?? '');
      // 后端为权威：独立开关与平台字段按保存结果回填（被清除时保留输入、仅置回跟随）
      setTextOverride((o) => {
        const saved = overrideFromPlatform(config.textPlatform);
        return saved.independent ? saved : { ...o, independent: false, apiKey: '' };
      });
      setImageOverride((o) => {
        const saved = overrideFromPlatform(config.imagePlatform);
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
      const result = await testAiConfigAction();
      if ('error' in result) {
        toast({ variant: 'destructive', title: '测试请求失败', description: result.error });
        return;
      }
      setTestResult(result);
    });
  };

  /** 文本/生图模态区块（跟随 ↔ 独立平台切换） */
  const renderModalitySection = (modality: Modality) => {
    const isText = modality === 'text';
    const override = isText ? textOverride : imageOverride;
    const setOverride = isText ? setTextOverride : setImageOverride;
    const masked = isText ? textPlatformMasked : imagePlatformMasked;
    const modelValue = isText ? form.textModel : form.imageModel;
    const modelField = isText ? 'textModel' : 'imageModel';
    const modelId = isText ? 'ai-text-model' : 'ai-image-model';
    return (
      <div className="space-y-4 rounded-lg border border-border p-4">
        <div>
          <div className="text-sm font-medium text-foreground">
            {isText ? '文本模型 · 识别与提示词润色' : '生图模型 · 封面效果图'}
          </div>
          <div className="mt-0.5 text-xs text-muted-foreground">
            跟随视觉平台，或切换为独立平台（OpenAI 兼容接口）
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
                {independent ? '独立平台' : '跟随视觉平台'}
              </button>
            ))}
          </div>
        </div>

        {override.independent ? (
          <>
            <ProviderPresetGrid
              activeKey={override.provider}
              modelKey={modelField}
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
                  {isText ? '文本模型' : '生图模型'}（独立平台必填）
                </Label>
                <Input
                  id={modelId}
                  value={modelValue}
                  onChange={(e) => {
                    markTouched(modelField);
                    const value = e.target.value;
                    setForm((f) =>
                      isText ? { ...f, textModel: value } : { ...f, imageModel: value },
                    );
                  }}
                  placeholder={
                    isText
                      ? '例：qwen-plus / gpt-4o-mini'
                      : override.provider === 'doubao'
                        ? '接入点 ep-xxx 或模型名'
                        : 'wanx2.1-t2i-turbo'
                  }
                />
              </div>
            </div>
          </>
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

          {/* 剪影专用模型（AI 一键建模「生成剪影」用，平台跟随生图模态） */}
          <div className="space-y-2 rounded-lg border border-border p-4">
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
          <div className="flex items-center gap-3">
            <Button onClick={handleSave} disabled={savePending}>
              {savePending ? '保存中…' : '保存'}
            </Button>
            <Button variant="outline" onClick={handleTest} disabled={testPending}>
              {testPending ? '测试中…' : '测试连接'}
            </Button>
          </div>

          {/* 测试结果 */}
          {testResult && (
            <div
              className={cn(
                'rounded-lg border p-4 text-sm',
                testResult.vision.ok
                  ? 'border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200'
                  : 'border-destructive/50 bg-destructive/10 text-destructive',
              )}
            >
              <div className="font-medium">
                {testResult.vision.ok
                  ? `视觉模型连接成功（${testResult.vision.latencyMs ?? '?'}ms）`
                  : '视觉模型连接失败'}
              </div>
              {!testResult.vision.ok && testResult.vision.error && (
                <div className="mt-1 break-all">{testResult.vision.error}</div>
              )}
              {testResult.text && (
                <div
                  className={cn(
                    'mt-2 flex items-center justify-between gap-2 rounded-md border p-3',
                    testResult.text.ok
                      ? 'border-emerald-300 bg-emerald-50 text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200'
                      : 'border-destructive/50 bg-destructive/10 text-destructive',
                  )}
                >
                  <span>文本模型</span>
                  <span className="text-right">
                    {testResult.text.ok
                      ? `连通 ${testResult.text.latencyMs ?? '?'}ms`
                      : (testResult.text.error ?? '连接失败')}
                  </span>
                </div>
              )}
              <div className="mt-1 text-xs opacity-70">{testResult.note}</div>
            </div>
          )}
        </CardContent>
      </Card>
    </>
  );
}
