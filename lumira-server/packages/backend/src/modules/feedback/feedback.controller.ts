// lumira-server/packages/backend/src/modules/feedback/feedback.controller.ts
// App 意见反馈提交（spec 2026-08-18-feedback-design §4.3）

import {
  Controller, Post, Req, Body, UseGuards, BadRequestException,
} from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { FeedbackService } from './feedback.service';
import { CreateFeedbackDto } from './dto/create-feedback.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

interface ParsedFeedback {
  fields: { type: string; content: string; contact: string | null };
  files: FeedbackUploadFile[];
}

export interface FeedbackUploadFile {
  buffer: Buffer;
  filename: string;
  mimetype: string;
}

/** 解析 multipart：文本字段 type/content/contact + 文件字段 screenshots（0~3）*/
export async function parseFeedbackMultipart(req: FastifyRequest): Promise<ParsedFeedback> {
  const fields: Record<string, string> = {};
  const files: FeedbackUploadFile[] = [];
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }
  for await (const part of reqAny.parts()) {
    if (part.type === 'field') {
      fields[part.fieldname as string] = String(part.value ?? '');
    } else if (part.type === 'file') {
      if (part.fieldname === 'screenshots') {
        const buffer = await part.toBuffer();
        files.push({ buffer, filename: part.filename || '', mimetype: part.mimetype || '' });
      }
    }
  }
  if (files.length > 3) {
    throw new BadRequestException('截图最多 3 张');
  }
  return {
    fields: {
      type: fields['type'] ?? '',
      content: fields['content'] ?? '',
      contact: fields['contact'] ? fields['contact'] : null,
    },
    files,
  };
}

@Controller('feedback')
@UseGuards(DeviceAuthGuard)
export class FeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  @Post()
  async submit(@Req() req: FastifyRequest, @DeviceId() deviceId: string, @ClientIp() ip: string) {
    const parsed = await parseFeedbackMultipart(req);
    const dto = plainToInstance(CreateFeedbackDto, parsed.fields);
    const errors = await validate(dto, { skipMissingProperties: false });
    if (errors.length > 0) {
      throw new BadRequestException(
        errors.map((e) => Object.values(e.constraints || {}).join('; ')).join(' | '),
      );
    }
    return this.feedbackService.submit(deviceId, dto, parsed.files, ip);
  }
}