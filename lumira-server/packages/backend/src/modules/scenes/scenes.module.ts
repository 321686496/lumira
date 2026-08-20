import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { UsageModule } from '../usage/usage.module';
import { ScenesController } from './scenes.controller';
import { AdminScenesController } from './admin-scenes.controller';
import { ScenesService } from './scenes.service';
@Module({
  imports: [DatabaseModule, UsageModule],
  controllers: [ScenesController, AdminScenesController],
  providers: [ScenesService],
  exports: [ScenesService],
})
export class ScenesModule {}