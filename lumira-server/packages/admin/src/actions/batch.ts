// src/actions/batch.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { toUnixSeconds } from '@/lib/utils';

export async function createBatchAction(formData: FormData) {
  const codesRaw = formData.get('codes') as string;
  const codes = codesRaw
    .split('\n')
    .map(c => c.trim())
    .filter(Boolean);

  if (codes.length === 0) {
    return { error: '请至少输入一个兑换码' };
  }

  try {
    const validFrom = formData.get('validFrom') as string | null;
    const validUntil = formData.get('validUntil') as string | null;

    const result = await api.createBatch({
      campaignName: formData.get('campaignName') as string,
      codes,
      rewardTier: Number(formData.get('rewardTier')),
      maxUsesPerCode: Number(formData.get('maxUsesPerCode')),
      validFrom: validFrom ? toUnixSeconds(validFrom) : undefined,
      validUntil: validUntil ? toUnixSeconds(validUntil) : undefined,
    });

    revalidatePath('/dashboard/redeem-batches');
    redirect(`/dashboard/redeem-batches/${result.batchId}`);
  } catch (e) {
    return { error: (e as Error).message };
  }
}

export async function toggleBatchAction(batchId: number, isActive: boolean) {
  try {
    await api.toggleBatch(batchId, isActive);
    revalidatePath('/dashboard/redeem-batches');
    revalidatePath(`/dashboard/redeem-batches/${batchId}`);
    return { success: true };
  } catch (e) {
    return { error: (e as Error).message };
  }
}
