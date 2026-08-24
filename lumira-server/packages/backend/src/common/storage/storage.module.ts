// lumira-server/packages/backend/src/common/storage/storage.module.ts

import { Global, Module } from '@nestjs/common';
import { storageAdapterProvider } from './storage.provider';

@Global()
@Module({
  providers: [storageAdapterProvider],
  exports: [storageAdapterProvider],
})
export class StorageModule {}