// lumira-server/packages/backend/src/main.ts

import { NestFactory } from "@nestjs/core";
import { FastifyAdapter, NestFastifyApplication } from "@nestjs/platform-fastify";
import * as path from "path";
import * as fs from "fs";
import multipart from "@fastify/multipart";
import fastifyStatic from "@fastify/static";
import { AppModule } from "./app.module";

// Production fail-fast: refuse to boot if security env vars are missing or still
// set to their dev defaults. Dev fallbacks remain in the guards/modules for tests/dev.
if (process.env.NODE_ENV === "production") {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === "dev-secret-change-me") {
    console.error("FATAL: JWT_SECRET must be set to a non-default value in production");
    process.exit(1);
  }
  if (!process.env.ADMIN_TOKEN || process.env.ADMIN_TOKEN === "dev-admin-token") {
    console.error("FATAL: ADMIN_TOKEN must be set to a non-default value in production");
    process.exit(1);
  }
}

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      trustProxy: true,
      bodyLimit: 32 * 1024 * 1024,
    }),
  );

  app.setGlobalPrefix("api/v1");

  // onRequest hook: when a client sends Content-Type: application/json
  // with an empty body (Content-Length: 0), strip the content-type header.
  // This prevents Fastify's default JSON parser from throwing
  // "Body cannot be empty when content-type is set to 'application/json'".
  const fastifyInstance = app.getHttpAdapter().getInstance();
  fastifyInstance.addHook("onRequest", async (request) => {
    const ct = request.headers["content-type"];
    const cl = request.headers["content-length"];
    if (ct && ct.includes("application/json") && cl === "0") {
      delete request.headers["content-type"];
    }
  });

  // CORS
  const corsOrigin = process.env.CORS_ORIGIN || "*";
  app.enableCors({
    origin: corsOrigin === "*" ? true : corsOrigin.split(","),
    methods: ["GET", "POST", "PATCH", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
  });

  // Register multipart plugin
  await app.register(multipart, {
    limits: {
      fileSize: 25 * 1024 * 1024,
      files: 6,
    },
  });

  // Static file serving for uploads
  const uploadRoot = path.resolve(process.env.UPLOAD_DIR || "./data/uploads");
  if (!fs.existsSync(uploadRoot)) {
    fs.mkdirSync(uploadRoot, { recursive: true });
  }
  await app.register(fastifyStatic, {
    root: uploadRoot,
    prefix: "/uploads/",
  });

  // Static file serving for public website
  const publicRoot = path.resolve(__dirname, "../public");
  if (fs.existsSync(publicRoot)) {
    await app.register(fastifyStatic, {
      root: publicRoot,
      prefix: "/",
      decorateReply: false,
    });

    const fastify = app.getHttpAdapter().getInstance();
    const indexPath = path.join(publicRoot, "index.html");
    fastify.get("/", async (_request, reply) => {
      const html = fs.readFileSync(indexPath, "utf-8");
      return reply.type("text/html").send(html);
    });
  }

  const port = parseInt(process.env.PORT || "3000", 10);
  await app.listen(port, "0.0.0.0");
  console.log(`Lumira server running on port ${port}`);
}

bootstrap();
