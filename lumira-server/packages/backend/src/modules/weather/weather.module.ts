// lumira-server/packages/backend/src/modules/weather/weather.module.ts
//
// 天气代理模块：注册 WeatherService + WeatherController
// 不依赖数据库，纯内存缓存

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { WeatherController } from './weather.controller';
import { WeatherService } from './weather.service';

@Module({
  imports: [
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
