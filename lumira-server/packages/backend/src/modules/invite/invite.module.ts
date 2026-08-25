// lumira-server/packages/backend/src/modules/invite/invite.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { PointsModule } from '../points/points.module';
import { InviteController } from './invite.controller';
import { InviteService } from './invite.service';

@Module({
  imports: [
    DatabaseModule,
    PointsModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [InviteController],
  providers: [InviteService],
})
export class InviteModule {}
