import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { UsageModule } from '../usage/usage.module';
import { ScenesController } from './scenes.controller';
import { AdminScenesController } from './admin-scenes.controller';
import { ScenesService } from './scenes.service';
@Module({
  imports: [
    DatabaseModule,
    UsageModule,
    // DeviceAuthGuard 依赖 JwtService 校验 token，模块需自行提供 JwtModule
    // （UsageModule 未导出 JwtModule，故此处需独立导入）
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [ScenesController, AdminScenesController],
  providers: [ScenesService],
  exports: [ScenesService],
})
export class ScenesModule {}