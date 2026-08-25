// lumira-server/packages/backend/src/modules/templates/templates.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../../database/database.module';
import { PointsModule } from '../points/points.module';
import { TemplatesController } from './templates.controller';
import { TemplatesService } from './templates.service';
import { AdminTemplatesController } from './admin-templates.controller';
import { AdminTemplatesService } from './admin-templates.service';
import { CategoriesController } from './categories.controller';
import { CategoriesService } from './categories.service';
import { AdminCategoriesController } from './admin-categories.controller';
import { AdminCategoriesService } from './admin-categories.service';
import { ThumbsController } from './thumbs.controller';
import { ThumbsService } from './thumbs.service';
import { ShareTemplatesModule } from './share-templates.module';

@Module({
  imports: [
    DatabaseModule,
    PointsModule,
    ShareTemplatesModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [
    TemplatesController,
    CategoriesController,
    AdminTemplatesController,
    AdminCategoriesController,
    ThumbsController,
  ],
  providers: [
    TemplatesService,
    AdminTemplatesService,
    CategoriesService,
    AdminCategoriesService,
    ThumbsService,
  ],
  exports: [TemplatesService],
})
export class TemplatesModule {}
