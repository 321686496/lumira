// lumira-server/packages/backend/src/modules/sign-in/sign-in.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { PointsModule } from '../points/points.module';
import { SignInController } from './sign-in.controller';
import { SignInService } from './sign-in.service';

@Module({
  imports: [
    DatabaseModule,
    PointsModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [SignInController],
  providers: [SignInService],
})
export class SignInModule {}
