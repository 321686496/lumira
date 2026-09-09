// src/app/dashboard/ai-config/page.tsx
// AI 设置页：厂商（qwen/doubao/zhipu/openai）视觉/生图模型配置
import { AiConfigForm } from '@/components/ai-config-form';
import { getAiConfigAction } from '@/actions/ai';

export default async function AiConfigPage() {
  const initial = await getAiConfigAction();
  return (
    <div className="space-y-4">
      <AiConfigForm initial={initial} />
    </div>
  );
}
