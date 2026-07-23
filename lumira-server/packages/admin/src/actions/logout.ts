// src/actions/logout.ts
'use server';

import { redirect } from 'next/navigation';
import { clearAuthToken } from '@/lib/auth';

export async function logoutAction() {
  clearAuthToken();
  redirect('/login');
}
