// lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts
// AI 模板制作端点（Task 5：ai-analyze 识别；Task 7/9 再并入生图 / 剪影端点）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第三节

import { Controller, Post, Get, Delete, Param, Query, Req, UseGuards, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeTaskService } from './ai-analyze-task.service';
import { AiImageTaskService } from './ai-image-task.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiSilhouetteTaskService } from './ai-silhouette-task.service';
import { AiPipelineJobService } from './ai-pipeline-job.service';
import type { JobMode } from './ai-pipeline-job.service';

@Controller('admin/templates')
@UseGuards(AdminAuthGuard)
export class AiTemplatesController {
  constructor(
    private readonly aiAnalyzeTaskService: AiAnalyzeTaskService,
    private readonly aiImageTaskService: AiImageTaskService,
    private readonly aiSilhouetteService: AiSilhouetteService,
    private readonly aiSilhouetteTaskService: AiSilhouetteTaskService,
    private readonly aiPipelineJobService: AiPipelineJobService,
  ) {}

  /**
   * AI 识别 → 模板草稿（异步任务式：multipart：image 文件与 text/textDesc 文本至少一项；creationReq/poseCount 可选）
   * 返回 { taskId }，前端轮询 GET ai-analyze/tasks/:taskId 获取结果（避免同步长请求超时）。
   */
  @Post('ai-analyze')
  async analyze(@Req() req: FastifyRequest) {
    const { images, text, textDesc, creationReq, poseCount, subjectCount } = await parseAiMultipart(req);
    return this.aiAnalyzeTaskService.submit(images, text ?? textDesc ?? undefined, {
      textDesc,
      creationReq,
      poseCount,
      subjectCount,
    });
  }

  /**
   * 查询识别任务状态（done 带 draft/warnings，error 带 error；任务不存在则 404）。
   * events = 实时流程事件（阶段/提示词/响应，按 seq 递增）；传 since=上个 seq 只取增量，
   * 后台据此像聊天一样实时渲染"走到哪一步、这一步提示词与响应是什么"。
   */
  @Get('ai-analyze/tasks/:taskId')
  async getAnalyzeTask(@Param('taskId') taskId: string, @Query('since') since?: string) {
    const task = this.aiAnalyzeTaskService.get(taskId);
    if (!task) throw new NotFoundException('Analyze task not found');
    const sinceSeq = Number.isFinite(Number(since)) ? Number(since) : 0;
    return {
      taskId: task.id,
      status: task.status,
      draft: task.result?.draft ?? null,
      warnings: task.result?.warnings ?? [],
      trace: task.result?.trace ?? [],
      raw: task.result?.raw ?? null,
      research: task.result?.research ?? [],
      researchBrief: task.result?.brief ?? null,
      researchImages: task.result?.researchImages ?? [],
      researchVision: task.result?.researchVision ?? null,
      /** 增量流程事件（seq > since）；since 缺省返回全部 */
      events: task.events.filter((e) => e.seq > sinceSeq),
      /** 已产生的最大 seq（前端下次拉取的 since） */
      lastSeq: task.events.length ? task.events[task.events.length - 1]!.seq : 0,
      error: task.error,
    };
  }

  /**
   * AI 生成模板效果图（异步任务式：multipart meta 草稿 JSON 文本语义 + reference 参考图可选 + extraPrompt 附加提示词可选 + research 识别研究结果 JSON 可选）
   * research 现为 `{ items, brief }`（识别阶段透传），兼容旧的纯数组（ResearchItem[]）形态。
   * 返回 { taskId }，前端轮询 GET ai-generate-image/tasks/:taskId 获取结果（避免同步长请求超时）。
   */
  @Post('ai-generate-image')
  async generateImage(@Req() req: FastifyRequest) {
    const { references, meta, extraPrompt, research } = await parseAiMultipart(req);
    return this.aiImageTaskService.submit(references, meta, extraPrompt, research);
  }

  /**
   * 批量姿势图：一次提交返回单一 batchId。后端内部控制锚点先后、并发上限与逐张进度，
   * 前端只需轮询 GET batch/:batchId 一个接口即可拿到全量进度与结果。
   * multipart 字段同 ai-generate-image（research 为 `{ items, brief }`，兼容旧纯数组）。
   */
  @Post('ai-generate-image/batch')
  async generateImageBatch(@Req() req: FastifyRequest) {
    const { references, meta, extraPrompt, research } = await parseAiMultipart(req);
    return this.aiImageTaskService.submitBatch(references, meta, extraPrompt, research);
  }

  /** 查询批量姿势图进度（total/completed/current/status/results/events）；支持 ?since= 增量拉取事件；批次不存在则 404 */
  @Get('ai-generate-image/batch/:batchId')
  async getImageBatch(@Param('batchId') batchId: string, @Query('since') since?: string) {
    const batch = this.aiImageTaskService.getBatch(batchId, since ? Number(since) : undefined);
    if (!batch) throw new NotFoundException('Image batch not found');
    return batch;
  }

  /** 查询生图任务状态（done 带 image/mimeType，error 带 error；任务不存在则 404） */
  @Get('ai-generate-image/tasks/:taskId')
  async getImageTask(@Param('taskId') taskId: string) {
    const task = this.aiImageTaskService.get(taskId);
    if (!task) throw new NotFoundException('Image task not found');
    return {
      taskId: task.id,
      status: task.status,
      image: task.result?.image,
      mimeType: task.result?.mimeType,
      error: task.error,
    };
  }

  /** AI 生成剪影（multipart：image 文件 + meta JSON 可选；engine=local 本地计算 / ai 走生图模型） */
  @Post('ai-generate-silhouette')
  async generateSilhouette(@Req() req: FastifyRequest) {
    const { image, meta } = await parseAiMultipart(req);
    if (!image) {
      throw new BadRequestException('Missing "image" file');
    }
    // 入口即打日志：本地 ONNX 推理慢，NestJS 默认 logger 只在完成时输出，
    // 进行中的请求无日志会被误判为"API 未被调用"
    Logger.log(
      `ai-generate-silhouette: request received (${(image.buffer.length / 1024).toFixed(0)}KB, meta=${meta ?? 'null'})`,
      'AiTemplatesController',
    );
    const startedAt = Date.now();
    const result = await this.aiSilhouetteService.generate(image, meta);
    Logger.log(`ai-generate-silhouette: done in ${Date.now() - startedAt}ms`, 'AiTemplatesController');
    return result;
  }

  /**
   * AI 剪影异步任务（multipart 与同步端点一致）：立即返回 taskId，前端轮询结果。
   * 网关对 Server Action / 后端请求有 504 超时，同步端点仅供兼容保留。
   */
  @Post('ai-generate-silhouette/tasks')
  async submitSilhouetteTask(@Req() req: FastifyRequest) {
    const { image, meta } = await parseAiMultipart(req);
    if (!image) throw new BadRequestException('Missing "image" file');
    return this.aiSilhouetteTaskService.submit(image, meta);
  }

  /** 查询剪影任务状态（done 带 image/mimeType，error 带 error；任务不存在则 404） */
  @Get('ai-generate-silhouette/tasks/:taskId')
  async getSilhouetteTask(@Param('taskId') taskId: string) {
    const task = this.aiSilhouetteTaskService.get(taskId);
    if (!task) throw new NotFoundException('Silhouette task not found');
    return {
      taskId: task.id,
      status: task.status,
      image: task.result?.image,
      mimeType: task.result?.mimeType,
      error: task.error,
    };
  }

  /**
   * 创建 AI 流水线 job（识别 → 姿势图 → 剪影）：multipart 字段同 ai-analyze（image/images + text/textDesc +
   * creationReq/poseCount/subjectCount）+ reference/references（姿势参考图）+ extraPrompt，
   * 另加 jobMode（auto / analyze-only）、silMode / silCrop / silEngine（剪影选项）。
   * 立即返回 { jobId }，前端轮询 GET ai-job/:jobId。
   */
  @Post('ai-job')
  async createAiJob(@Req() req: FastifyRequest) {
    const p = await parseAiMultipart(req);
    const mode: JobMode = p.jobMode === 'analyze-only' ? 'analyze-only' : 'auto';
    return this.aiPipelineJobService.create({
      images: p.images,
      text: p.text ?? p.textDesc ?? undefined,
      extra: {
        textDesc: p.textDesc,
        creationReq: p.creationReq,
        poseCount: p.poseCount,
        subjectCount: p.subjectCount,
      },
      references: p.references,
      referenceAnchor: p.refAnchor !== '0',
      extraPrompt: p.extraPrompt,
      mode,
      silhouette: {
        mode: p.silMode === 'solid' ? 'solid' : 'sketch',
        crop: p.silCrop !== '0',
        engine: p.silEngine === 'ai' ? 'ai' : 'local',
      },
    });
  }

  /**
   * 查询 job 状态：running 态响应体收敛（事件按 since 增量、长文本收紧、不返回 base64 产物），
   * 终态或 verbose=1 返回完整事件与全部产物；job 不存在（后端重启/超期清理）→ 404。
   */
  @Get('ai-job/:jobId')
  async getAiJob(@Param('jobId') jobId: string, @Query('since') since?: string, @Query('verbose') verbose?: string) {
    const job = this.aiPipelineJobService.get(jobId);
    if (!job) throw new NotFoundException('AI pipeline job not found');
    const sinceSeq = Number.isFinite(Number(since)) ? Number(since) : 0;
    return this.aiPipelineJobService.serialize(job, sinceSeq, verbose === '1');
  }

  /** 续跑：running → 不重跑（前端重连）；error → 从失败阶段重跑并复用上游产物；不存在 → 404 */
  @Post('ai-job/:jobId/resume')
  async resumeAiJob(@Param('jobId') jobId: string) {
    const result = await this.aiPipelineJobService.resume(jobId);
    if (!result) throw new NotFoundException('AI pipeline job not found');
    return result;
  }

  /** 放弃本次生成：删除 job（幂等） */
  @Delete('ai-job/:jobId')
  async deleteAiJob(@Param('jobId') jobId: string) {
    this.aiPipelineJobService.remove(jobId);
    return { ok: true };
  }
}

// ===== 模块内小型 multipart 助手 =====
// 不复用 admin-templates.controller 的专用解析器（其字段名固定 cover/silhouette/pptpl/icon/images）；
// AI 端点解析：meta / textDesc / creationReq / poseCount / subjectCount / extraPrompt / research（文本）+ image / reference（文件）。

/** AI 端点 multipart 解析结果 */
export interface ParsedAiMultipart {
  meta: string | null;
  /** 用户文字描述/创作要求（多输入模式 Step1 主文本，兼容字段） */
  text?: string;
  /** Step1 文字描述（可选，注入识别提示词） */
  textDesc: string | null;
  /** Step1 创作要求（可选，注入识别提示词） */
  creationReq: string | null;
  /** Step1 姿势个数（可选：'1'~'9' 固定指定；空 = AI 自动判断） */
  poseCount: string | null;
  /** Step1 主体人数（可选：'1'~'8' 固定指定；空 = AI 自动推断） */
  subjectCount: string | null;
  /** Step3 附加提示词（可选，拼接到封面生图提示词末尾） */
  extraPrompt: string | null;
  /** 识别阶段研究结果 JSON（可选，`{ items, brief }`，兼容旧的纯数组 ResearchItem[]；透传给生图提示词组织器） */
  research: string | null;
  /** 风格识别参考图（示例图）文件：兼容单文件（首张）；多图识别走 images */
  image?: UploadFile;
  /** 风格识别参考图（示例图）多文件集合（Step1 多图上传 → 图片识别大模型识别全部） */
  images?: UploadFile[];
  /** 姿势参考图文件：兼容单文件（首张）；多图识别走 references */
  reference?: UploadFile;
  /** 姿势参考图多文件集合（Step3 多图上传 → 图片识别大模型识别全部） */
  references?: UploadFile[];
  /** pipeline job 模式：'auto'（一键全自动）/ 'analyze-only'（仅识别）；缺省按 auto */
  jobMode?: string;
  /** 剪影模式：'sketch' / 'solid'；缺省 sketch */
  silMode?: string;
  /** 剪影是否自动裁剪：'0' 关闭，其余视为开启；缺省开启 */
  silCrop?: string;
  /** 剪影引擎：'ai' / 'local'；缺省 local */
  silEngine?: string;
  /** 参考图是否兼作图生图底图：'0' 仅作视觉识别参考；其余（缺省）兼作底图 */
  refAnchor?: string;
}

/** 文本字段名集合（multipart 循环内按字段名收集） */
const TEXT_FIELDS = ['meta', 'text', 'textDesc', 'creationReq', 'poseCount', 'subjectCount', 'extraPrompt', 'research', 'jobMode', 'silMode', 'silCrop', 'silEngine', 'refAnchor'] as const;

/**
 * 解析 AI 端点 multipart 请求，提取文本字段（meta / textDesc / creationReq / poseCount / subjectCount / extraPrompt / research）
 * 和 `image` / `reference` 文件字段。
 * 使用 @fastify/multipart 的 request.parts() 异步迭代器（同 admin-templates.controller）。
 */
export async function parseAiMultipart(req: FastifyRequest): Promise<ParsedAiMultipart> {
  const result: ParsedAiMultipart = { meta: null, textDesc: null, creationReq: null, poseCount: null, subjectCount: null, extraPrompt: null, research: null };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }

  for await (const part of reqAny.parts()) {
    if (part.type === 'field') {
      const fieldname = part.fieldname as (typeof TEXT_FIELDS)[number];
      if ((TEXT_FIELDS as readonly string[]).includes(fieldname)) {
        result[fieldname] = part.value as string;
      }
    } else if (part.type === 'file') {
      const fieldname = part.fieldname as string;
      const buffer = await part.toBuffer();
      const file: UploadFile = {
        buffer,
        filename: part.filename || '',
        mimetype: part.mimetype || '',
      };
      if (fieldname === 'image') {
        // 兼容单文件读取（剪影等端点仍用 image）；多图场景收集进 images 数组
        if (!result.image) result.image = file;
        (result.images ??= []).push(file);
      } else if (fieldname === 'reference') {
        if (!result.reference) result.reference = file;
        (result.references ??= []).push(file);
      }
      // 其他字段名忽略
    }
  }

  return result;
}
