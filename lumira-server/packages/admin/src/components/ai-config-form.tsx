// src/components/ai-config-form.tsx
// AI 厂商配置表单（client）：四厂商预设卡片 + baseUrl/apiKey/模型名/启用开关 + 连通性测试

'use client';

import { useState, useTransition } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { saveAiConfigAction, testAiConfigAction } from '@/actions/ai';
import type { AiProviderConfigView, AiConfigTestResult } from '@/types/admin';
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
  enabled: boolean;
}

export function AiConfigForm({
  initial,
}: {
  initial: AiProviderConfigView | { configured: false };
}) {
  const { toast } = useToast();
  const configured = initial.configured;
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
          enabled: initial.enabled,
        }
      : {
          provider: 'qwen',
          baseUrl: PROVIDER_PRESETS.qwen.baseUrl,
          apiKey: '',
          visionModel: PROVIDER_PRESETS.qwen.visionModel,
          imageModel: PROVIDER_PRESETS.qwen.imageModel,
          textModel: PROVIDER_PRESETS.qwen.textModel,
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
  /** 已保存配置的有效文本模型（textModel 为空时的回退提示） */
  const [effectiveTextModel, setEffectiveTextModel] = useState(
    configured ? initial.effectiveTextModel : '',
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

  const handleSave = () => {
    if (!form.baseUrl.trim() || !form.visionModel.trim() || !form.imageModel.trim()) {
      toast({ variant: 'destructive', title: '请填写完整', description: 'baseUrl 与模型名不能为空' });
      return;
    }
    if (!configured && !form.apiKey.trim()) {
      toast({ variant: 'destructive', title: '缺少 API Key', description: '首次配置必须填写 API Key' });
      return;
    }
    startSave(async () => {
      const result = await saveAiConfigAction({
        provider: form.provider,
        baseUrl: form.baseUrl.trim(),
        apiKey: form.apiKey.trim() || undefined,
        visionModel: form.visionModel.trim(),
        imageModel: form.imageModel.trim(),
        textModel: form.textModel.trim(),
        enabled: form.enabled,
      });
      if ('error' in result) {
        toast({ variant: 'destructive', title: '保存失败', description: result.error });
        return;
      }
      setApiKeyMasked(result.config.apiKeyMasked);
      setEffectiveTextModel(result.config.effectiveTextModel);
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

  return (
    <>
      {!configured && (
        <Card className="border-amber-300 bg-amber-50 dark:border-amber-900 dark:bg-amber-950">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-amber-900 dark:text-amber-200">
              AI 尚未配置
            </CardTitle>
            <CardDescription className="text-amber-800/80 dark:text-amber-300/80">
              完成并保存下方配置后，向导页的「风格识别 / 生成效果图」功能才可用（剪影生成不依赖本配置）。
            </CardDescription>
          </CardHeader>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>AI 服务配置</CardTitle>
          <CardDescription>
            选用视觉大模型与生图模型（OpenAI 兼容接口），用于 AI 一键模板录入。配置需保存后新请求才生效。
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* 厂商四卡 */}
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {PROVIDER_KEYS.map((key) => {
              const preset = PROVIDER_PRESETS[key];
              const active = form.provider === key;
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => selectProvider(key)}
                  className={cn(
                    'rounded-lg border p-3 text-left transition-colors',
                    active
                      ? 'border-primary bg-primary/10'
                      : 'border-border hover:bg-accent/40',
                  )}
                >
                  <div className={cn('text-sm font-medium', active ? 'text-primary' : 'text-foreground')}>
                    {preset.label}
                  </div>
                  <div className="mt-1 truncate text-xs text-muted-foreground" title={preset.visionModel}>
                    {preset.visionModel}
                  </div>
                </button>
              );
            })}
          </div>

          {/* 字段 */}
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
              <Label htmlFor="ai-vision-model">视觉模型（识别）</Label>
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
            <div className="space-y-2">
              <Label htmlFor="ai-text-model">文本模型（可选）</Label>
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
            <div className="space-y-2">
              <Label htmlFor="ai-image-model">生图模型（封面效果图）</Label>
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
          </div>

          {/* 启用开关 */}
          <div className="flex items-center justify-between rounded-lg border border-border px-4 py-3">
            <div>
              <div className="text-sm font-medium text-foreground">启用 AI 功能</div>
              <div className="text-xs text-muted-foreground">
                关闭后，向导页的识别与生图请求将返回「AI 未配置或未启用」；剪影生成不受影响
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
