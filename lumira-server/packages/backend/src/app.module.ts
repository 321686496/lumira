// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { AdminModule } from './modules/admin/admin.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule, RedeemModule, RewardsModule, AdminModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
