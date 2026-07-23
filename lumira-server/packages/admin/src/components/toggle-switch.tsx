// src/components/toggle-switch.tsx
'use client';

import { useTransition } from 'react';
import { Switch } from '@/components/ui/switch';
import { toggleBatchAction } from '@/actions/batch';

export function ToggleSwitch({
  batchId,
  isActive,
}: {
  batchId: number;
  isActive: boolean;
}) {
  const [isPending, startTransition] = useTransition();

  return (
    <Switch
      checked={isActive}
      disabled={isPending}
      onCheckedChange={(checked) => {
        startTransition(async () => {
          await toggleBatchAction(batchId, checked);
        });
      }}
    />
  );
}
