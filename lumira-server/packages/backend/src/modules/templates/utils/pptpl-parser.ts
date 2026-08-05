// lumira-server/packages/backend/src/modules/templates/utils/pptpl-parser.ts
// 解析 .pptpl JSON 文件，提取 5 段模板内容（spec 3.6）

export interface PptplContent {
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}

/**
 * 解析 .pptpl 文件缓冲区，返回 5 段模板内容。
 * .pptpl 文件格式为 JSON，必须含 `format: 'pptpl'` 字段。
 *
 * @throws Error 当 JSON 解析失败或 format 字段不匹配时
 */
export function parsePptpl(buffer: Buffer): PptplContent {
  let json: Record<string, unknown>;
  try {
    json = JSON.parse(buffer.toString('utf-8'));
  } catch (e) {
    throw new Error('Invalid pptpl format: JSON parse failed');
  }

  if (json.format !== 'pptpl') {
    throw new Error('Invalid pptpl format: missing or mismatched "format" field');
  }

  return {
    composition: (json.composition as Record<string, unknown>) || {},
    pose: (json.pose as Record<string, unknown>) || {},
    camera: (json.camera as Record<string, unknown>) || {},
    sceneGuide: (json.sceneGuide as Record<string, unknown>) || {},
    postProcess: (json.postProcess as Record<string, unknown>) || {},
  };
}
