// lumira-server/packages/backend/src/health.controller.ts

import { Controller, Get } from '@nestjs/common';

/**
 * 健康检查端点
 *
 * 用于 Docker healthcheck 和外部监控探活。
 * 路径：GET /api/v1/health（受 app.setGlobalPrefix('api/v1') 影响）
 *
 * 不依赖数据库或其他服务，仅表示进程存活。
 * 如果需要深度健康检查（含 DB 连通性），可扩展为检查 sqlite 文件是否可读写。
 */
@Controller('health')
export class HealthController {
  @Get()
  check(): { status: string; uptime: number; timestamp: string } {
    return {
      status: 'ok',
      uptime: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }
}
