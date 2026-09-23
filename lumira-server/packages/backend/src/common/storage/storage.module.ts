// lumira-server/packages/backend/src/common/storage/storage.module.ts

import { Global, Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { storageAdapterProvider } from './storage.provider';
import { ImageCompressionService } from './image-compression.service';
import { StorageConfigService } from './storage-config.service';
import { StorageConfigController } from './storage-config.controller';

@Global()
@Module({
  imports: [DatabaseModule],
  controllers: [StorageConfigController],
  providers: [storageAdapterProvider, StorageConfigService, ImageCompressionService],
  exports: [storageAdapterProvider, StorageConfigService, ImageCompressionService],
})
export class StorageModule {}