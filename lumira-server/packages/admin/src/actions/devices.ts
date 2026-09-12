'use server';

import { revalidatePath } from 'next/cache';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';

export async function deleteDeviceAction(
  deviceId: string,
  loginKey: string,
): Promise<{ success?: true; error?: string }> {
  try {
    await api.deleteDevice(deviceId, loginKey);
    revalidatePath('/dashboard/devices');
    revalidatePath(`/dashboard/devices/${deviceId}/profile`);
    revalidatePath(`/dashboard/devices/${deviceId}/points`);
    return { success: true };
  } catch (e) {
    if (e instanceof UnauthenticatedError) {
      return { error: '未登录或会话已过期' };
    }
    return { error: (e as Error).message };
  }
}
