import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { DeviceModule } from '../device/device.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { MailService } from './mail.service';

@Module({
  imports: [DatabaseModule, DeviceModule],
  controllers: [AccountController],
  providers: [AccountService, MailService],
  exports: [AccountService],
})
export class AccountModule {}