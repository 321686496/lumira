import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';
import { ShareTemplateDto } from './dto/share-template.dto';
import { ShareTemplatesService, GET_RATE_LIMIT } from './share-templates.service';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class ShareTemplatesController {
  constructor(private readonly shares: ShareTemplatesService) {}

  @Post('share')
  async create(@Body() dto: ShareTemplateDto, @DeviceId() deviceId: string) {
    try {
      return await this.shares.create(dto.payload, dto.expiresInSeconds, deviceId);
    } catch (err) {
      const message = (err as Error).message;
      if (message === 'empty_payload' || message === 'payload_too_large' || message === 'invalid_ttl') {
        throw new BadRequestException(message);
      }
      throw err;
    }
  }

  @Get('share/:token')
  async read(@Param('token') token: string, @DeviceId() deviceId: string) {
    try {
      await this.shares.checkRateLimit(deviceId);
    } catch (err) {
      if ((err as Error).message === 'rate_limited') {
        throw new HttpException(`limit_${GET_RATE_LIMIT}_per_minute`, HttpStatus.TOO_MANY_REQUESTS);
      }
      throw err;
    }
    const found = await this.shares.get(token);
    if (!found) throw new NotFoundException('share_not_found_or_expired');
    return found;
  }

  @Delete('share/:token')
  async revoke(@Param('token') token: string, @DeviceId() deviceId: string) {
    const deleted = await this.shares.revoke(token, deviceId);
    if (!deleted) throw new NotFoundException('share_not_found_or_expired');
    return { deleted: true };
  }
}