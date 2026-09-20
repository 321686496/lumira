// lumira-server/packages/backend/src/modules/ai/golden-set.data.ts
// Task 11 Golden Set 回归门禁数据集：10~20 个真实高频「生成模板」意图 + 期望验收要点。
// 每次 orchestrator 管线改动后，用黄金集回归校验质量不劣化。
// 类型见 golden-set.service.ts 的 GoldenCase。

import type { GoldenCase } from './golden-set.service';
import type { CategoryNode } from './normalize';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';

const PORTRAIT: CategoryNode = { key: 'portrait', name: '人像', parentKey: null, level: 1 };
const CATS_NONE: CategoryNode[] = [PORTRAIT];

/** 通用最小 fallback 描述（仅作文本意图用例的评分输入占位） */
function scaffold(subject: string): ImageDescription {
  return {
    global: { subject, mood: '', season: '', timeOfDay: '', palette: { dominant: [], tone: '', brightness: '' }, light: {}, composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '3:4', negativeSpace: '', depthOfField: '' }, reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' } },
    people: [],
    scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
    cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
  };
}

/** 通用最小 pose 面片占位（无 poseSheet 时流程兜底） */
function sheet(mood: string): PoseRefSheet {
  return { shared: { outfit: '', scene: '', light: '', aspectRatio: '3:4', mood, palette: '' }, perPose: [] };
}

export const GOLDEN_SET: GoldenCase[] = [
  {
    id: 'golden-01',
    intent: '秋冬清冷感飘窗少女人像',
    creationReq: '室内飘窗，午后窗光，清冷慵懒氛围，暖棕低饱和色调，半身构图，米色针织衫',
    poseCount: 2,
    description: '飘窗+秋日窗光，暖棕低饱和清冷慵懒，半身人像。',
    expectedPoints: ['全局色调暖棕/低饱和', '主光为侧逆窗光+可复现', '构图半身、主体居中偏左下', '白平衡偏暖/日光', 'fillLight 建议开启暖色补光'],
    keywords: ['飘窗', '秋日', '清冷', '低饱和', '半身'], categories: CATS_NONE,
    desc: scaffold('暖棕清冷飘窗少女'), poseSheet: sheet('清冷慵懒'),
  },
  {
    id: 'golden-02',
    intent: '夏日海滩度假比基尼风',
    creationReq: '阳光沙滩，正午强光，度假感，明亮高饱和，全身竖构图，比基尼',
    poseCount: 3,
    description: '海滩正午强光度假感，明亮高饱和、全身比基尼。',
    expectedPoints: ['高饱和明亮色调', '正午顶光可复现（阴影方向一致）', '全身构图、主体居中', 'cameraDirection 侧面', 'LUT 明亮清新'],
    keywords: ['海滩', '度假', '比基尼', '高饱和', '全身'], categories: CATS_NONE,
    desc: scaffold('海滩度假少女'), poseSheet: sheet('明亮度假'),
  },
  {
    id: 'golden-03',
    intent: '奶油系咖啡馆日常',
    creationReq: '室内咖啡馆靠窗座位，奶油色调，自然窗光，半身，浅色衣着，慵懒周末',
    poseCount: 2,
    description: '咖啡馆靠窗自然光，奶油色系，半身慵懒日常。',
    expectedPoints: ['奶油米色为主色调', '自然窗光、观感柔', '构图半身+靠窗框架', 'fillLight 柔和补光', '风格成熟/命名可搜索'],
    keywords: ['咖啡馆', '奶油', '日常', '慵懒', '靠窗'], categories: CATS_NONE,
    desc: scaffold('咖啡店奶油日常'), poseSheet: sheet('慵懒日常'),
  },
  {
    id: 'golden-04',
    intent: '复古港风街拍夜景',
    creationReq: '夜晚霓虹街头，复古港风，红绿补色，全身，走动抓拍感，胶片颗粒',
    poseCount: 3,
    description: '霓虹夜景复古港风，红绿补色胶片颗粒，全身动感街拍。',
    expectedPoints: ['霓虹补色（红/青绿）', '胶片颗粒/暗部', '全身动感、走动抓拍', 'ISO 较高', '短视频平台热点标签'],
    keywords: ['港风', '街拍', '夜景', '霓虹', '胶片'], categories: CATS_NONE,
    desc: scaffold('夜景港风街拍'), poseSheet: sheet('复古动感'),
  },
  {
    id: 'golden-05',
    intent: '校园青春开学季日系',
    creationReq: '校园操场/教室，阳光下午，日系通透，半身，校服或白衬衫，青春感',
    poseCount: 2,
    description: '开学季校园日系通透风，下午阳光半身青春感。',
    expectedPoints: ['日系通透高调', '柔顺侧光', '半身构图、主体清晰', 'WB 自动/日光', '青春感场景引导'],
    keywords: ['校园', '日系', '青春', '开学', '通透'], categories: CATS_NONE,
    desc: scaffold('校园日系少女'), poseSheet: sheet('青春学院'),
  },
  {
    id: 'golden-06',
    intent: '黑森林暗黑高级感',
    creationReq: '夜晚暗调森林，冷色主调，电影感，全身/七分，暗黑成熟，金属饰品',
    poseCount: 3,
    description: '暗调森林冷色电影感暗黑风，全身或七分构图。',
    expectedPoints: ['冷色暗调为主', '低照度、轮廓光', '全身/七分构图', 'ISO 高、暗部拉高', '填光建议暖色克制冷观', '物理合理性肢体自然'],
    keywords: ['暗黑', '森林', '电影感', '冷色', '高级'], categories: CATS_NONE,
    desc: scaffold('暗黑森林氛围'), poseSheet: sheet('暗黑冷感'),
  },
  {
    id: 'golden-07',
    intent: '春日樱花粉治愈系',
    creationReq: '樱花树下，春日柔和逆光，粉白淡雅，半身微笑，治愈清新',
    poseCount: 2,
    description: '樱花树春日逆光，粉白淡雅治愈系半身。',
    expectedPoints: ['粉白甜美、低对比', '柔和逆光+发丝光', '半身构图', 'WB 偏暖', '治愈系场景引导与关键词'],
    keywords: ['樱花', '春日', '粉色', '治愈', '逆光'], categories: CATS_NONE,
    desc: scaffold('樱花粉治愈'), poseSheet: sheet('治愈柔甜'),
  },
  {
    id: 'golden-08',
    intent: '商务职场干练风',
    creationReq: '写字楼/办公室，白天窗光，干练利落，半身，西装，专业职场',
    poseCount: 2,
    description: '办公室白天窗光商务干练，半身正装职场感。',
    expectedPoints: ['干净中性色调', '窗光/顶光均匀', '半身正装', '构图规整、留白少', '参数自洽可复现'],
    keywords: ['商务', '职场', '干练', '办公', '半身'], categories: CATS_NONE,
    desc: scaffold('商务职场人像'), poseSheet: sheet('干练专业'),
  },
  {
    id: 'golden-09',
    intent: '亲子户外露营记录',
    creationReq: '周末营地/草坪，户外自然光，温馨生活感，全身/大半身，亲子互动',
    poseCount: 3,
    description: '露营草坪户外自然光，温馨生活感亲子写真。',
    expectedPoints: ['自然日光、通透温暖', '生活抓拍感', '全身/大半身', '构图稳定主体清晰', '多姿势区分度'],
    keywords: ['亲子', '露营', '户外', '温馨', '自然光'], categories: CATS_NONE,
    desc: scaffold('亲子露营'), poseSheet: sheet('温馨生活'),
  },
  {
    id: 'golden-10',
    intent: '土酷赛博朋克电玩',
    creationReq: '夜晚霓虹/赛博街景，青紫主调，未来感，全身，机械元素，高对比',
    poseCount: 3,
    description: '赛博朋克霓虹街景青紫主调，未来科技感全身人像。',
    expectedPoints: ['青紫霓虹主调', '高对比强霓虹光', '全身/七分构图', '科技感道具元素', '镜头参数与画面自洽'],
    keywords: ['赛博朋克', '霓虹', '未来', '青紫', '电玩'], categories: CATS_NONE,
    desc: scaffold('赛博朋克人像'), poseSheet: sheet('未来酷感'),
  },
  {
    id: 'golden-11',
    intent: '温柔法式编织毛衣写真',
    creationReq: '暖色居家/傍晚窗光，法式温柔，米白编织毛衣，半身，氛围感',
    poseCount: 2,
    description: '暖色傍晚光法式温柔、米白编织毛衣半身氛围写真。',
    expectedPoints: ['暖米色主调', '傍晚窗光柔暖', '半身构图', 'fillLight 暖光开启', '氛围感/可复现'],
    keywords: ['法式', '编织毛衣', '温柔', '暖光', '氛围'], categories: CATS_NONE,
    desc: scaffold('法式温柔毛衣'), poseSheet: sheet('温柔氛围'),
  },
  {
    id: 'golden-12',
    intent: '运动街头嘻哈风',
    creationReq: '街头运动场/城市街景，白天自然光，力量动感，全身，卫衣球鞋，嘻哈',
    poseCount: 3,
    description: '城市街头白天自然光、运动嘻哈力量感全身人像。',
    expectedPoints: ['自然日光照度充足', '高对比有劲', '全身动感姿态', '构图留空有张力', '姿态间差异明显'],
    keywords: ['街头', '运动', '嘻哈', '全身', '力量感'], categories: CATS_NONE,
    desc: scaffold('街头嘻哈人像'), poseSheet: sheet('活力动感'),
  },
];