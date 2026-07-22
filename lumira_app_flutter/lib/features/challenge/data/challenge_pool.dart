import 'challenge_models.dart';

/// 内置挑战题库，按 7 个分类分组，每分类 6 题，共 42 题
class ChallengePool {
  static const List<ChallengePoolItem> all = [
    // 人像 portrait
    ChallengePoolItem(id: 'portrait_001', category: ChallengeCategory.portrait, title: '拍一张窗边侧光人像', description: '利用窗户自然光，从侧面照射模特脸部，打造柔和的明暗对比', rewardXP: 50, tip: '让模特面朝窗户 45 度，光线从侧面打来形成伦勃朗光', tags: ['自然光', '侧光', '室内']),
    ChallengePoolItem(id: 'portrait_002', category: ChallengeCategory.portrait, title: '用逆光拍一张剪影人像', description: '在日落或强光源前拍摄人物剪影，强调轮廓线条', rewardXP: 60, tip: '对准亮部曝光，让人物完全变暗形成剪影', tags: ['逆光', '剪影', '创意']),
    ChallengePoolItem(id: 'portrait_003', category: ChallengeCategory.portrait, title: '拍摄一组表情对比照', description: '同一场景下拍摄模特 3 种不同情绪表情，展现情绪张力', rewardXP: 55, tip: '快速连拍捕捉自然表情变化，避免摆拍感', tags: ['情绪', '连拍', '对比']),
    ChallengePoolItem(id: 'portrait_004', category: ChallengeCategory.portrait, title: '拍一张黑白质感人像', description: '去除色彩干扰，专注于光影结构和面部纹理', rewardXP: 50, tip: '后期降低饱和度，提升对比度强化面部轮廓', tags: ['黑白', '质感', '后期']),
    ChallengePoolItem(id: 'portrait_005', category: ChallengeCategory.portrait, title: '利用镜子拍摄双人像', description: '通过镜面反射创作虚实结合的构图', rewardXP: 65, tip: '注意镜中与镜外人物的眼神方向，制造故事感', tags: ['镜面', '创意', '构图']),
    ChallengePoolItem(id: 'portrait_006', category: ChallengeCategory.portrait, title: '拍摄一组手部特写', description: '聚焦手部细节，通过手势讲述故事', rewardXP: 45, tip: '用大光圈虚化背景，突出手指线条和皮肤纹理', tags: ['特写', '细节', '大光圈']),
    // 风光 landscape
    ChallengePoolItem(id: 'landscape_001', category: ChallengeCategory.landscape, title: '拍摄日落时分的云层层次', description: '捕捉黄金时刻天空的丰富色彩和云层纹理', rewardXP: 55, tip: '使用小光圈 f/8-f/11，保留云层高光细节', tags: ['日落', '黄金时刻', '云层']),
    ChallengePoolItem(id: 'landscape_002', category: ChallengeCategory.landscape, title: '用前景构图拍一张风景', description: '加入前景元素增强画面纵深感和层次', rewardXP: 50, tip: '低角度拍摄，用花草岩石做前景引导视线', tags: ['前景', '构图', '纵深']),
    ChallengePoolItem(id: 'landscape_003', category: ChallengeCategory.landscape, title: '雨天拍一张水墨感风景', description: '利用雨雾天气营造水墨画般的意境', rewardXP: 60, tip: '提高曝光补偿，后期降饱和度模拟水墨效果', tags: ['雨天', '意境', '水墨']),
    ChallengePoolItem(id: 'landscape_004', category: ChallengeCategory.landscape, title: '拍摄水面倒影构图', description: '利用平静水面创造对称镜像效果', rewardXP: 55, tip: '无风时拍摄，低角度贴近水面增强倒影', tags: ['倒影', '对称', '水面']),
    ChallengePoolItem(id: 'landscape_005', category: ChallengeCategory.landscape, title: '拍一张城市天际线', description: '在高处俯瞰城市建筑群轮廓', rewardXP: 50, tip: '黄昏蓝调时刻拍摄，天空与建筑层次分明', tags: ['城市', '天际线', '俯拍']),
    ChallengePoolItem(id: 'landscape_006', category: ChallengeCategory.landscape, title: '拍摄森林中的光斑', description: '捕捉树叶间漏下的丁达尔光束', rewardXP: 65, tip: '清晨雾气浓时拍摄，侧逆光角度捕捉光斑', tags: ['森林', '光斑', '雾气']),
    // 美食 food
    ChallengePoolItem(id: 'food_001', category: ChallengeCategory.food, title: '俯拍一杯咖啡的拉花', description: '从正上方拍摄咖啡拉花图案', rewardXP: 45, tip: '保持手机水平，用自然光从侧面补光', tags: ['咖啡', '俯拍', '拉花']),
    ChallengePoolItem(id: 'food_002', category: ChallengeCategory.food, title: '侧光拍摄早餐的质感', description: '利用侧光突出食物的纹理和质感', rewardXP: 50, tip: '窗户旁 45 度侧光，突出面包酥脆感', tags: ['早餐', '侧光', '质感']),
    ChallengePoolItem(id: 'food_003', category: ChallengeCategory.food, title: '拍一张蒸汽升腾的热食', description: '捕捉食物热气蒸腾的瞬间', rewardXP: 60, tip: '逆光拍摄蒸汽更明显，深色背景突出烟缕', tags: ['蒸汽', '逆光', '热食']),
    ChallengePoolItem(id: 'food_004', category: ChallengeCategory.food, title: '拍摄一组色彩对比餐盘', description: '利用不同色系食材制造视觉冲击', rewardXP: 55, tip: '红绿对比或冷暖对比，俯拍展现色彩布局', tags: ['色彩', '对比', '俯拍']),
    ChallengePoolItem(id: 'food_005', category: ChallengeCategory.food, title: '拍一张手捧食物的温暖照', description: '加入人物手部增加食物的温暖感', rewardXP: 45, tip: '自然抓拍手部动作，避免僵硬摆拍', tags: ['手部', '温暖', '抓拍']),
    ChallengePoolItem(id: 'food_006', category: ChallengeCategory.food, title: '拍摄冰淇淋融化瞬间', description: '记录冰淇淋从固态到液态的变化过程', rewardXP: 65, tip: '连拍模式捕捉融化滴落的关键瞬间', tags: ['融化', '连拍', '创意']),
    // 街拍 street
    ChallengePoolItem(id: 'street_001', category: ChallengeCategory.street, title: '拍一张路人的背影故事', description: '通过背影讲述路人的故事和情绪', rewardXP: 50, tip: '保持距离用长焦，抓拍自然的行走姿态', tags: ['背影', '故事', '长焦']),
    ChallengePoolItem(id: 'street_002', category: ChallengeCategory.street, title: '霓虹灯下拍一张街拍', description: '利用城市霓虹灯光作为主光源', rewardXP: 60, tip: '夜晚霓虹灯下，提高 ISO，利用灯光色彩', tags: ['霓虹', '夜景', '色彩']),
    ChallengePoolItem(id: 'street_003', category: ChallengeCategory.street, title: '雨天拍水洼倒影', description: '利用地面水洼创造倒影构图', rewardXP: 55, tip: '低角度贴近水洼，倒置手机拍摄效果更佳', tags: ['雨天', '倒影', '水洼']),
    ChallengePoolItem(id: 'street_004', category: ChallengeCategory.street, title: '拍摄路口的人流轨迹', description: '长曝光记录行人走动的轨迹', rewardXP: 65, tip: '快门 1-2 秒，固定手机，人群自然流动', tags: ['长曝光', '轨迹', '人流']),
    ChallengePoolItem(id: 'street_005', category: ChallengeCategory.street, title: '拍一张橱窗反射的街景', description: '利用玻璃橱窗反射创造双层画面', rewardXP: 55, tip: '斜 45 度拍摄，融合橱窗内外两个世界', tags: ['反射', '橱窗', '双层']),
    ChallengePoolItem(id: 'street_006', category: ChallengeCategory.street, title: '抓拍一个有趣的街头瞬间', description: '捕捉日常生活中幽默或戏剧性的瞬间', rewardXP: 50, tip: '预判场景，提前对焦，快速抓拍', tags: ['抓拍', '瞬间', '趣味']),
    // 夜景 night
    ChallengePoolItem(id: 'night_001', category: ChallengeCategory.night, title: '长曝光拍车流光轨', description: '长曝光记录车灯轨迹', rewardXP: 65, tip: '快门 2-4 秒，找天桥或高处俯拍马路', tags: ['长曝光', '光轨', '车流']),
    ChallengePoolItem(id: 'night_002', category: ChallengeCategory.night, title: '拍一张月光下的建筑轮廓', description: '利用月光勾勒建筑剪影', rewardXP: 60, tip: '满月时拍摄，对建筑轮廓曝光', tags: ['月光', '轮廓', '建筑']),
    ChallengePoolItem(id: 'night_003', category: ChallengeCategory.night, title: '手持拍一张夜景人像', description: '利用城市灯光为人像补光', rewardXP: 55, tip: '找明亮橱窗或路灯旁，提高 ISO 到 1600', tags: ['夜景', '人像', '手持']),
    ChallengePoolItem(id: 'night_004', category: ChallengeCategory.night, title: '拍摄星空与地面景结合', description: '将星空与地面前景组合构图', rewardXP: 70, tip: '远离城市光污染，三脚架固定，30 秒曝光', tags: ['星空', '地面', '长曝光']),
    ChallengePoolItem(id: 'night_005', category: ChallengeCategory.night, title: '拍一张雨夜霓虹倒影', description: '雨夜地面湿润，霓虹倒影格外迷人', rewardXP: 60, tip: '低角度拍摄，同时收入霓虹和倒影', tags: ['雨夜', '霓虹', '倒影']),
    ChallengePoolItem(id: 'night_006', category: ChallengeCategory.night, title: '拍摄城市夜景全景', description: '用全景模式拍摄宽阔的城市夜景', rewardXP: 55, tip: '匀速移动手机，保持水平线一致', tags: ['全景', '城市', '夜景']),
    // 微距 macro
    ChallengePoolItem(id: 'macro_001', category: ChallengeCategory.macro, title: '拍一朵花的微距细节', description: '放大拍摄花瓣纹理和花蕊结构', rewardXP: 50, tip: '用微距模式或外接镜头，稳定手持避免抖动', tags: ['花卉', '微距', '纹理']),
    ChallengePoolItem(id: 'macro_002', category: ChallengeCategory.macro, title: '拍摄水滴的折射效果', description: '捕捉水滴中倒映的微观世界', rewardXP: 65, tip: '在叶面或玻璃上滴水，逆光拍摄折射景象', tags: ['水滴', '折射', '逆光']),
    ChallengePoolItem(id: 'macro_003', category: ChallengeCategory.macro, title: '拍一只昆虫的复眼', description: '极近距离拍摄昆虫眼部细节', rewardXP: 70, tip: '清晨昆虫不活跃时拍摄，连拍多张选最佳', tags: ['昆虫', '复眼', '极限']),
    ChallengePoolItem(id: 'macro_004', category: ChallengeCategory.macro, title: '拍摄布料纤维的纹理', description: '放大拍摄不同材质的纤维结构', rewardXP: 45, tip: '侧光突出纤维立体感，避免反光', tags: ['纤维', '纹理', '材质']),
    ChallengePoolItem(id: 'macro_005', category: ChallengeCategory.macro, title: '拍一颗露珠在叶尖', description: '捕捉清晨露珠悬挂叶尖的瞬间', rewardXP: 55, tip: '逆光拍摄露珠透光，快门速度 1/500 以上', tags: ['露珠', '清晨', '逆光']),
    ChallengePoolItem(id: 'macro_006', category: ChallengeCategory.macro, title: '拍摄雪花的六角结构', description: '捕捉雪花独特的结晶图案', rewardXP: 75, tip: '黑色背景承接雪花，快速拍摄避免融化', tags: ['雪花', '结晶', '冬季']),
    // 静物 still-life
    ChallengePoolItem(id: 'still-life_001', category: ChallengeCategory.stillLife, title: '拍一组复古物件的静物', description: '用旧物营造怀旧氛围的静物构图', rewardXP: 50, tip: '侧光突出物件质感，深色背景营造氛围', tags: ['复古', '静物', '侧光']),
    ChallengePoolItem(id: 'still-life_002', category: ChallengeCategory.stillLife, title: '窗光下拍一本书的质感', description: '利用窗光拍摄翻开的书本', rewardXP: 45, tip: '45 度侧光，突出纸张纹理和书页层次', tags: ['书本', '窗光', '质感']),
    ChallengePoolItem(id: 'still-life_003', category: ChallengeCategory.stillLife, title: '拍一杯水的折射光影', description: '利用光线穿过水杯的折射效果', rewardXP: 55, tip: '逆光拍摄，观察水杯形成的光影图案', tags: ['水杯', '折射', '光影']),
    ChallengePoolItem(id: 'still-life_004', category: ChallengeCategory.stillLife, title: '拍摄一组极简桌面静物', description: '用 2-3 件物品打造极简构图', rewardXP: 50, tip: '留白是关键，物品之间留出呼吸空间', tags: ['极简', '桌面', '留白']),
    ChallengePoolItem(id: 'still-life_005', category: ChallengeCategory.stillLife, title: '拍一组旧照片的怀旧组合', description: '用老照片营造时光感静物', rewardXP: 55, tip: '叠加旧物（怀表、信件）增强故事感', tags: ['怀旧', '旧照', '故事']),
    ChallengePoolItem(id: 'still-life_006', category: ChallengeCategory.stillLife, title: '拍摄玻璃器皿的通透感', description: '利用光线穿透玻璃展现透明质感', rewardXP: 60, tip: '逆光侧逆光，深色背景突出玻璃轮廓', tags: ['玻璃', '通透', '逆光']),
  ];

  static List<ChallengePoolItem> byCategory(String category) =>
      all.where((item) => item.category == category).toList();

  static ChallengePoolItem? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
