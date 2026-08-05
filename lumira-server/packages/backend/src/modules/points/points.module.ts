// lumira-server/packages/backend/src/modules/points/points.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { PointsController } from './points.controller';
import { PointsService } from './points.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [PointsController],
  providers: [PointsService],
  exports: [PointsService], // 导出供 redeem/invite/templates 等模块使用
})
export class PointsModule {}
