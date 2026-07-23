// src/app/dashboard/redeem-batches/new/page.tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import BatchForm from '@/components/batch-form';

export default function NewBatchPage() {
  return (
    <Card className="max-w-3xl">
      <CardHeader>
        <CardTitle className="text-left">创建兑换码批次</CardTitle>
      </CardHeader>
      <CardContent>
        <BatchForm />
      </CardContent>
    </Card>
  );
}
