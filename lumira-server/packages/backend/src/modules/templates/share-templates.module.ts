import { Module } from '@nestjs/common';
import { ShareTemplatesController } from './share-templates.controller';
import { ShareTemplatesService } from './share-templates.service';

@Module({
  controllers: [ShareTemplatesController],
  providers: [ShareTemplatesService],
})
export class ShareTemplatesModule {}