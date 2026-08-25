import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { ShareTemplatesController } from './share-templates.controller';
import { ShareTemplatesService } from './share-templates.service';

@Module({
  imports: [
    DatabaseModule,
    // DeviceAuthGuard 依赖 JwtService 校验 token，模块需自行提供 JwtModule
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [ShareTemplatesController],
  providers: [ShareTemplatesService],
})
export class ShareTemplatesModule {}