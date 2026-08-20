// lumira-server/packages/backend/src/modules/profile/profile.controller.ts

import { Controller, Get, Post, Req, Patch, Body, UseGuards, BadRequestException } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { ProfileService } from './profile.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

const ALLOWED_AVATAR_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const MAX_AVATAR_BYTES = 10 * 1024 * 1024; // 10MB

async function parseAvatarMultipart(req: FastifyRequest): Promise<{ buffer: Buffer; ext: string }> {
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }
  let buffer: Buffer | null = null;
  let filename = '';
  let mimetype = '';
  for await (const part of reqAny.parts()) {
    if (part.type === 'file' && part.fieldname === 'avatar') {
      buffer = await part.toBuffer();
      filename = part.filename || '';
      mimetype = part.mimetype || '';
      break;
    }
  }
  if (!buffer) throw new BadRequestException('缺少头像文件（字段名 avatar）');
  if (!ALLOWED_AVATAR_MIME.has(mimetype)) throw new BadRequestException('仅支持 jpg/png/webp/gif');
  if (buffer.length > MAX_AVATAR_BYTES) throw new BadRequestException('头像大小不能超过 10MB');
  const dot = filename.lastIndexOf('.');
  const rawExt = dot >= 0 ? filename.slice(dot + 1).toLowerCase() : '';
  const ext = /^[a-z0-9]+$/.test(rawExt) ? rawExt : 'png';
  return { buffer, ext };
}

@Controller('profile')
@UseGuards(DeviceAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  async get(@DeviceId() deviceId: string) {
    return this.profileService.getOrCreateProfile(deviceId);
  }

  @Patch()
  async update(@DeviceId() deviceId: string, @Body() dto: UpdateProfileDto) {
    return this.profileService.updateProfile(deviceId, dto);
  }

  @Post('avatar')
  async uploadAvatar(@Req() req: FastifyRequest, @DeviceId() deviceId: string) {
    const file = await parseAvatarMultipart(req);
    return this.profileService.saveAvatar(deviceId, file.buffer, file.ext);
  }
}
