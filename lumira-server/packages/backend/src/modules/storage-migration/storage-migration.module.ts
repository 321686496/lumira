// lumira-server/packages/backend/src/modules/storage-migration/storage-migration.module.ts

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { StorageMigrationController } from './storage-migration.controller';
import { StorageMigrationService } from './storage-migration.service';

@Module({
  imports: [DatabaseModule],
  controllers: [StorageMigrationController],
  providers: [StorageMigrationService],
})
export class StorageMigrationModule {}