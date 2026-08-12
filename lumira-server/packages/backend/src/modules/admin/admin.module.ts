// lumira-server/packages/backend/src/modules/admin/admin.module.ts

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { PointsModule } from '../points/points.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [DatabaseModule, PointsModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
