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

  // preParsing hook: intercept empty body before Fastify''s default JSON
  // parser sees it. When a client sends Content-Type: application/json with
  // an empty body, Fastify throws "Body cannot be empty...". This hook
  // replaces the empty payload with "{}" so the parser succeeds.
  // Uses a preParsing hook instead of addContentTypeParser to avoid
  // conflicting with NestJS''s own parser registration during app.listen().
  const fastifyInstance = app.getHttpAdapter().getInstance();
  fastifyInstance.addHook("preParsing", async (request, _reply, payload) => {
    if (!payload) return payload;
    const ct = request.headers["content-type"];
    if (ct && ct.includes("application/json")) {
      const chunks: Buffer[] = [];
      for await (const chunk of payload) {
        chunks.push(chunk);
      }
      const body = Buffer.concat(chunks).toString("utf-8");
      if (!body || body.trim() === "") {
        return "{}";
      }
      return body;
    }
    return payload;
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
