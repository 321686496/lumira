import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ScenesService } from './scenes.service';
import { CreateSceneDto } from './dto/create-scene.dto';
import { UpdateSceneDto } from './dto/update-scene.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
@Controller('admin/scenes')
@UseGuards(AdminAuthGuard)
export class AdminScenesController {
  constructor(private readonly scenesService: ScenesService) {}
  @Get() list() { return this.scenesService.listAdmin(); }
  @Post() create(@Body() dto: CreateSceneDto) { return this.scenesService.create(dto); }
  @Patch(':id') update(@Param('id') id: string, @Body() dto: UpdateSceneDto) { return this.scenesService.update(id, dto); }
  @Delete(':id') remove(@Param('id') id: string) { return this.scenesService.remove(id); }
  @Post(':id/toggle') toggle(@Param('id') id: string) { return this.scenesService.toggleActive(id); }
}