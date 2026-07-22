// lumira-server/packages/backend/src/common/decorators/current-ip.decorator.ts

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const ClientIp = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.ip || '0.0.0.0';
  },
);
