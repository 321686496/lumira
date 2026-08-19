// lumira-server/packages/backend/src/common/guards/device-auth.guard.ts

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';

@Injectable()
export class DeviceAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly dbService: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid authorization header');
    }

    const token = authHeader.substring(7);
    let payload: { deviceId: string; epoch?: number };
    try {
      payload = this.jwtService.verify(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }

    const row = await this.dbService.getDb().query.devices.findFirst({
      where: eq(devices.deviceId, payload.deviceId),
    });
    if (!row) {
      throw new UnauthorizedException('Device not found');
    }
    if ((payload.epoch ?? 0) !== row.sessionEpoch) {
      throw new UnauthorizedException('Session has been invalidated');
    }

    request.deviceId = payload.deviceId;
    return true;
  }
}