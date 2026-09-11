// lumira-server/packages/backend/src/common/storage/storage.module.ts

import { Global, Module } from '@nestjs/common';
import { storageAdapterProvider } from './storage.provider';
import { ImageCompressionService } from './image-compression.service';

@Global()
@Module({
  providers: [storageAdapterProvider, ImageCompressionService],
  exports: [storageAdapterProvider, ImageCompressionService],
})
export class StorageModule {}
