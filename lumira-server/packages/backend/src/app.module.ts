// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { ProfileModule } from './modules/profile/profile.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { AdminModule } from './modules/admin/admin.module';
import { WeatherModule } from './modules/weather/weather.module';
import { QuestionnaireModule } from './modules/questionnaire/questionnaire.module';
import { TemplatesModule } from './modules/templates/templates.module';
import { SignInModule } from './modules/sign-in/sign-in.module';
import { FeedbackModule } from './modules/feedback/feedback.module';
import { AccountModule } from './modules/account/account.module';
import { HealthController } from './health.controller';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, ProfileModule, InviteModule, RedeemModule, RewardsModule, AdminModule, WeatherModule, QuestionnaireModule, TemplatesModule, SignInModule, FeedbackModule, AccountModule],
  controllers: [HealthController],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
