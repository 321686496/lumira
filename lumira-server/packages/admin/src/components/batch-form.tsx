// src/components/batch-form.tsx
'use client';

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
import { createBatchAction } from '@/actions/batch';

const schema = z.object({
  campaignName: z.string().min(1, '请输入 Campaign 名称').max(100),
  codes: z.string().refine(
    (v) => v.split('\n').map(s => s.trim()).filter(Boolean).length > 0,
    '请至少输入一个兑换码',
  ),
  rewardTier: z.coerce.number().int().min(1),
  maxUsesPerCode: z.coerce.number().int().min(1),
  validFrom: z.string().optional(),
  validUntil: z.string().optional(),
});

type FormValues = z.infer<typeof schema>;

export default function BatchForm() {
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const { register, handleSubmit, control, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      campaignName: '',
      codes: '',
      rewardTier: 1,
      maxUsesPerCode: 1,
    },
  });

  const onSubmit = (data: FormValues) => {
    setError(null);
    const formData = new FormData();
    formData.set('campaignName', data.campaignName);
    formData.set('codes', data.codes);
    formData.set('rewardTier', String(data.rewardTier));
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
          <Label htmlFor="rewardTier">关联奖励阶梯 *</Label>
          <Controller
            control={control}
            name="rewardTier"
            render={({ field }) => (
              <Select value={String(field.value)} onValueChange={(v) => field.onChange(Number(v))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="1">Tier 1（1 次邀请）</SelectItem>
                  <SelectItem value="3">Tier 3（3 次邀请）</SelectItem>
                  <SelectItem value="5">Tier 5（5 次邀请）</SelectItem>
                  <SelectItem value="10">Tier 10（10 次邀请）</SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="maxUsesPerCode">每码最大使用次数 *</Label>
          <Input id="maxUsesPerCode" type="number" min={1} {...register('maxUsesPerCode')} />
        </div>
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
