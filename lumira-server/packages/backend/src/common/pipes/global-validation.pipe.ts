// lumira-server/packages/backend/src/common/pipes/global-validation.pipe.ts

import { ValidationPipe } from '@nestjs/common';

export const GlobalValidationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});
