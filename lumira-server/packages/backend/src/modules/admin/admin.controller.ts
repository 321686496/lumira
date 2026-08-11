// lumira-server/packages/backend/src/modules/admin/admin.controller.ts

import { Controller, Get, Post, Patch, Body, Param, Query, ParseIntPipe, UseGuards, NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { CreateBatchDto } from './dto/create-batch.dto';
import { ToggleBatchDto } from './dto/toggle-batch.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';

@Controller('admin')
@UseGuards(AdminAuthGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  async getStats() {
    return this.adminService.getStats();
  }

  @Get('devices')
  async getDeviceList(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('search') search?: string,
  ) {
    return this.adminService.getDeviceList(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      search,
    );
  }

  @Get('invites')
  async getInviteRecords(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getInviteRecords(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }

  @Get('redeem-batches')
  async getBatches() {
    return this.adminService.getBatches();
  }

  @Post('redeem-batches')
  async createBatch(@Body() dto: CreateBatchDto) {
    return this.adminService.createBatch(dto);
  }

  @Get('redeem-batches/templates')
  async getBatchTemplates() {
    return this.adminService.getAllActiveTemplates();
  }

  @Get('redeem-batches/:id')
  async getBatchDetail(@Param('id', ParseIntPipe) id: number) {
    const result = await this.adminService.getBatchDetail(id);
    if (!result) {
      throw new NotFoundException('Batch not found');
    }
    return result;
  }

  @Patch('redeem-batches/:id')
  async toggleBatch(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ToggleBatchDto,
  ) {
    return this.adminService.toggleBatch(id, dto.isActive);
  }

  @Get('rewards')
  async getRewardUnlocks(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getRewardUnlocks(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }

  @Get('questionnaire')
  async getQuestionnaireList(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getQuestionnaireList(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }

  @Get('questionnaire/stats')
  async getQuestionnaireStats() {
    return this.adminService.getQuestionnaireStats();
  }

  @Get('questionnaire/:deviceId')
  async getQuestionnaireHistory(@Param('deviceId') deviceId: string) {
    return this.adminService.getQuestionnaireHistory(deviceId);
  }
}
