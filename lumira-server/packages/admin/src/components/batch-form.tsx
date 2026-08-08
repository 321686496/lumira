'use client';

import { useState, useTransition, useEffect } from 'react';
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import { createBatchAction } from '@/actions/batch';
import { api } from '@/lib/api';
import type { TemplateOption } from '@/types/admin';

const schema = z.object({
  campaignName: z.string().min(1, '请输入 Campaign 名称').max(100),
  codes: z.string().refine(
    (v) => v.split('\n').map(s => s.trim()).filter(Boolean).length > 0,
    '请至少输入一个兑换码',
  ),
  rewardPoints: z.coerce.number().int().min(0, '积分不能为负'),
  rewardTemplates: z.array(z.string()).optional(),
  maxUsesPerCode: z.coerce.number().int().min(1),
  validFrom: z.string().optional(),
  validUntil: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export default function BatchForm() {
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [templates, setTemplates] = useState<TemplateOption[]>([]);
  const [loadingTemplates, setLoadingTemplates] = useState(true);
  const { register, handleSubmit, control, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      campaignName: '',
      codes: '',
      rewardPoints: 0,
      rewardTemplates: [],
      maxUsesPerCode: 1,
    },
  });

  useEffect(() => {
    api.getBatchTemplates()
      .then(setTemplates)
      .catch(() => setTemplates([]))
      .finally(() => setLoadingTemplates(false));
  }, []);

  const onSubmit = (data: FormValues) => {
    setError(null);
    const formData = new FormData();
    formData.set('campaignName', data.campaignName);
    formData.set('codes', data.codes);
    formData.set('rewardPoints', String(data.rewardPoints));
    formData.set('rewardTemplates', JSON.stringify(data.rewardTemplates ?? []));
    formData.set('maxUsesPerCode', String(data.maxUsesPerCode));
    if (data.validFrom) formData.set('validFrom', data.validFrom);
    if (data.validUntil) formData.set('validUntil', data.validUntil);

    startTransition(async () => {
      const result = await createBatchAction(formData);
      if (result?.error) setError(result.error);
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5 max-w-2xl">
      <div className="space-y-2">
        <Label htmlFor="campaignName">Campaign 名称 *</Label>
        <Input id="campaignName" {...register('campaignName')} placeholder="如：双十一福利" />
        {errors.campaignName && <p className="text-sm text-destructive">{errors.campaignName.message}</p>}
      </div>

      <div className="space-y-2">
        <Label htmlFor="codes">兑换码列表（每行一个）*</Label>
        <Textarea
          id="codes"
          {...register('codes')}
          rows={8}
          placeholder={'CODE001\nCODE002\nCODE003'}
          className="font-mono text-sm"
        />
        {errors.codes && <p className="text-sm text-destructive">{errors.codes.message}</p>}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="maxUsesPerCode">每码最大使用次数 *</Label>
          <Input id="maxUsesPerCode" type="number" min={1} {...register('maxUsesPerCode')} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="rewardPoints">奖励积分</Label>
          <Input id="rewardPoints" type="number" min={0} {...register('rewardPoints')} placeholder="0 表示不给积分" />
        </div>
      </div>

      <div className="space-y-2">
        <Label>奖励模板（可多选）</Label>
        {loadingTemplates ? (
          <p className="text-sm text-muted-foreground">加载模板中...</p>
        ) : templates.length === 0 ? (
          <p className="text-sm text-muted-foreground">暂无可用模板，请先创建模板</p>
        ) : (
          <Controller
            control={control}
            name="rewardTemplates"
            render={({ field }) => (
              <div className="h-48 overflow-y-auto rounded-md border border-border p-2 space-y-1">
                {templates.map((tpl) => {
                  const selected = field.value?.includes(tpl.id) ?? false;
                  return (
                    <div
                      key={tpl.id}
                      onClick={() => {
                        const current = field.value ?? [];
                        if (selected) {
                          field.onChange(current.filter((id) => id !== tpl.id));
                        } else {
                          field.onChange([...current, tpl.id]);
                        }
                      }}
                      className={cn(
                        'flex items-center gap-3 p-2 rounded-md cursor-pointer transition-colors',
                        selected ? 'bg-primary/10 border border-primary/30' : 'hover:bg-muted/50 border border-transparent',
                      )}
                    >
                      <div className={cn(
                        'w-4 h-4 rounded border flex items-center justify-center flex-shrink-0',
                        selected ? 'bg-primary border-primary' : 'border-muted-foreground/30',
                      )}>
                        {selected && (
                          <svg className="w-3 h-3 text-primary-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{tpl.name}</p>
                        <p className="text-xs text-muted-foreground truncate">{tpl.id}</p>
                      </div>
                      <span className="text-xs text-muted-foreground whitespace-nowrap">
                        {tpl.price > 0 ? `${tpl.price} 积分` : '免费'}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          />
        )}
        <p className="text-xs text-muted-foreground">不选择则只发放积分（如有）</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="validFrom">有效期起（可选）</Label>
          <Input id="validFrom" type="datetime-local" {...register('validFrom')} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="validUntil">有效期止（可选）</Label>
          <Input id="validUntil" type="datetime-local" {...register('validUntil')} />
        </div>
      </div>

      {error && <p className="text-sm text-destructive" role="alert">{error}</p>}

      <Button type="submit" disabled={isPending}>
        {isPending ? '提交中…' : '创建批次'}
      </Button>
    </form>
  );
}