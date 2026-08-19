// lumira-server/packages/backend/src/modules/weather/weather.module.ts
//
// 天气代理模块：注册 WeatherService + WeatherController
// 依赖数据库（DeviceAuthGuard 需要 DatabaseService 校验 session_epoch）

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { WeatherController } from './weather.controller';
import { WeatherService } from './weather.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [WeatherController],
  providers: [WeatherService],
  exports: [WeatherService],
})
export class WeatherModule {}
