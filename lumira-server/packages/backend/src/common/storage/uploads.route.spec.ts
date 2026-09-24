// lumira-server/packages/backend/src/common/storage/uploads.route.spec.ts
// /uploads/* 读取路由单测：本地激活 / 远端激活 / 远端缺失回落本地 / 非法路径 404。

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { Readable } from 'stream';
import type { FastifyInstance } from 'fastify';
import { registerUploadsRoute } from './uploads.route';
import { seedAdapter, setRuntimeConfig } from './runtime-storage';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';

/** 内存假适配器：只有 keys 里的 storageKey 可读 */
class FakeAdapter implements StorageAdapter {
  constructor(private readonly files: Record<string, Buffer>) {}
  async write(_c: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string> {
    this.files[`/uploads/x/${id}/${filename}`] = buffer;
    return `/uploads/x/${id}/${filename}`;
  }
  async deleteByDir(): Promise<void> {}
  async readBuffer(storageKey: string): Promise<Buffer> {
    const buf = this.files[storageKey];
    if (!buf) throw new Error(`NoSuchKey: ${storageKey}`);
    return buf;
  }
  async exists(storageKey: string): Promise<boolean> {
    return !!this.files[storageKey];
  }
  async listKeys(): Promise<string[]> {
    return Object.keys(this.files);
  }
}

interface Sent {
  payload?: unknown;
  type?: string;
  cacheControl?: string;
}

function makeHarness(uploadRoot: string) {
  const sent: Sent[] = [];
  let notFound = false;
  const reply = {
    header: (name: string, value: string) => {
      if (name === 'Cache-Control') sent[sent.length - 1].cacheControl = value;
      return reply;
    },
    type: (t: string) => {
      sent[sent.length - 1].type = t;
      return reply;
    },
    send: (payload: unknown) => {
      sent[sent.length - 1].payload = payload;
      return reply;
    },
    callNotFound: () => {
      notFound = true;
      return reply;
    },
  };
  let handler!: (req: { url: string }, rep: unknown) => Promise<unknown>;
  const app = {
    get: (_route: string, h: typeof handler) => {
      handler = h;
    },
  } as unknown as FastifyInstance;

  registerUploadsRoute(app, uploadRoot);

  /** 每次请求前压入一条 sent 记录，供 header/type/send 回填 */
  const request = async (url: string) => {
    sent.push({});
    notFound = false;
    await handler({ url }, reply);
    return { last: sent[sent.length - 1], notFound };
  };
  return { request, sent };
}

async function readStream(stream: Readable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const c of stream) chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c as string));
  return Buffer.concat(chunks);
}

describe('registerUploadsRoute', () => {
  let uploadRoot: string;

  beforeAll(() => {
    uploadRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'lumira-uploads-'));
    fs.mkdirSync(path.join(uploadRoot, 'templates', 'tpl1'), { recursive: true });
    fs.writeFileSync(path.join(uploadRoot, 'templates', 'tpl1', 'cover.jpg'), 'LOCAL-BYTES');
  });

  afterAll(() => {
    fs.rmSync(uploadRoot, { recursive: true, force: true });
    setRuntimeConfig('local', ''); // 还原激活存储，避免影响其它单测
  });

  it('激活=本地：直接读本地磁盘，带 immutable 缓存头', async () => {
    setRuntimeConfig('local', '');
    const { request } = makeHarness(uploadRoot);
    const { last, notFound } = await request('/uploads/templates/tpl1/cover.jpg');
    expect(notFound).toBe(false);
    expect(last.type).toBe('image/jpeg');
    expect(last.cacheControl).toBe('public, max-age=31536000, immutable');
    expect(await readStream(last.payload as Readable)).toEqual(Buffer.from('LOCAL-BYTES'));
  });

  it('激活=远端：从当前激活存储读取', async () => {
    seedAdapter('r2', new FakeAdapter({ '/uploads/templates/tpl2/cover.png': Buffer.from('R2-BYTES') }));
    setRuntimeConfig('r2', '');
    const { request } = makeHarness(uploadRoot);
    const { last, notFound } = await request('/uploads/templates/tpl2/cover.png');
    expect(notFound).toBe(false);
    expect(last.type).toBe('image/png');
    expect(last.payload).toEqual(Buffer.from('R2-BYTES'));
  });

  it('激活=远端但远端缺失：回落本地磁盘（迁移过渡期）', async () => {
    seedAdapter('r2', new FakeAdapter({})); // 远端空
    setRuntimeConfig('r2', '');
    const { request } = makeHarness(uploadRoot);
    const { last, notFound } = await request('/uploads/templates/tpl1/cover.jpg');
    expect(notFound).toBe(false);
    expect(await readStream(last.payload as Readable)).toEqual(Buffer.from('LOCAL-BYTES'));
  });

  it('本地与远端都没有：404', async () => {
    setRuntimeConfig('r2', '');
    const { request } = makeHarness(uploadRoot);
    const { notFound } = await request('/uploads/templates/none/cover.png');
    expect(notFound).toBe(true);
  });

  it('路径穿越（含百分号编码）：404', async () => {
    setRuntimeConfig('local', '');
    const { request } = makeHarness(uploadRoot);
    expect((await request('/uploads/../secret.txt')).notFound).toBe(true);
    expect((await request('/uploads/%2e%2e/secret.txt')).notFound).toBe(true);
    expect((await request('/uploads/templates/%zz/bad.jpg')).notFound).toBe(true);
  });
});
