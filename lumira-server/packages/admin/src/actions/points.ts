'use server';

import { revalidatePath } from 'next/cache';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';

export async function grantPointsAction(
  deviceId: string,
  delta: number,
  reason: string,
) {
  try {
    const result = await api.grantPoints(deviceId, delta, reason);
    revalidatePath(`/dashboard/devices/${deviceId}/points`);
    return { success: true, balance: result.balance };
  } catch (e) {
    if (e instanceof UnauthenticatedError) return { error: '未登录或会话已过期' };
    return { error: (e as Error).message };
  }
}