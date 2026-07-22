// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
