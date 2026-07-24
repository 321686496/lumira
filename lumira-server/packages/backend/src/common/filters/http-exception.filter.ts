// lumira-server/packages/backend/src/common/filters/http-exception.filter.ts

import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';

// 不直接 import 'fastify'（pnpm 严格模式下 fastify 未直接安装，直接 import 会导致 tsc 报 TS2307）。
// 这里用结构类型描述 response 上的 status().send() 调用即可。
type HttpResponse = {
  status(code: number): { send(body: unknown): void };
};

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<HttpResponse>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const message =
      typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as any).message || 'Internal server error';

    response.status(status).send({
      code: status,
      message: Array.isArray(message) ? message[0] : message,
    });
  }
}
