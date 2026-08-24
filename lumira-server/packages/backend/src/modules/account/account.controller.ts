import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { AccountService } from './account.service';
import { RecoverByQrDto } from './dto/recover-by-qr.dto';
import { SendCodeDto } from './dto/send-code.dto';
import { EmailCodeDto } from './dto/email-code.dto';

@Controller('account')
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Get('status')
  @UseGuards(DeviceAuthGuard)
  status(@Req() req: any) {
    return this.accountService.getStatus(req.deviceId);
  }

  @Post('recover-by-qr')
  recoverByQr(@Body() dto: RecoverByQrDto) {
    return this.accountService.recoverByQr(dto.secret);
  }

  @Post('email/send-code')
  sendCode(@Body() dto: SendCodeDto) {
    return this.accountService.sendEmailCode(dto.email, dto.purpose);
  }

  @Post('email/bind')
  @UseGuards(DeviceAuthGuard)
  bind(@Req() req: any, @Body() dto: EmailCodeDto) {
    return this.accountService.bindEmail(req.deviceId, dto.email, dto.code);
  }

  @Post('email/recover')
  recoverByEmail(@Body() dto: EmailCodeDto) {
    return this.accountService.recoverByEmail(dto.email, dto.code);
  }
}