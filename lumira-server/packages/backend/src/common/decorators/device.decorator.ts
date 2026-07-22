// lumira-server/packages/backend/src/common/decorators/device.decorator.ts

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const DeviceId = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.deviceId;
  },
);
