// lumira-server/packages/backend/src/common/guards/admin-auth.guard.ts

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class AdminAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing admin token');
    }

    const token = authHeader.substring(7);
    const adminToken = process.env.ADMIN_TOKEN || 'dev-admin-token';

    if (token !== adminToken) {
      throw new UnauthorizedException('Invalid admin token');
    }

    return true;
  }
}
