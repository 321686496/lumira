// lumira-server/packages/backend/src/modules/feedback/admin-feedback.controller.ts
import {
  Controller, Get, Patch, Param, Body, Query, UseGuards, NotFoundException,
} from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';

@Controller('admin/feedbacks')
@UseGuards(AdminAuthGuard)
export class AdminFeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  @Get()
  async list(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('type') type?: string,
    @Query('status') status?: string,
  ) {
    return this.feedbackService.list({
      page: page ? parseInt(page, 10) : 1,
      pageSize: pageSize ? parseInt(pageSize, 10) : 20,
      type: type || undefined,
      status: status || undefined,
    });
  }

  @Patch(':id')
  async updateStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    const status = body.status;
    if (status !== 'pending' && status !== 'handled') {
      throw new NotFoundException('Invalid status');
    }
    try {
      return await this.feedbackService.updateStatus(id, status);
    } catch {
      throw new NotFoundException('Feedback not found');
    }
  }
}