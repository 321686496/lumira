// lumira-server/packages/backend/src/common/storage/mime.ts
// 上传图片文件名 → Content-Type。写入（S3 PutObject）与读取（/uploads 路由）共用。

const MIME_MAP: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  svg: 'image/svg+xml',
  avif: 'image/avif',
  bmp: 'image/bmp',
  ico: 'image/x-icon',
};

export function mimeOf(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  return MIME_MAP[ext] ?? 'application/octet-stream';
}
