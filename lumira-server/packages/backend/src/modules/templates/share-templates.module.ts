import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ShareTemplatesController } from './share-templates.controller';
import { ShareTemplatesService } from './share-templates.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [ShareTemplatesController],
  providers: [ShareTemplatesService],
})
export class ShareTemplatesModule {}