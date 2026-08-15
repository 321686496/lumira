import 'tutorial_models.dart';

/// 拍摄小课堂内容库：20 篇（6 通用 + 14 分类专项）
class TutorialContent {
  TutorialContent._();

  static ShootingTutorial? getById(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static const List<ShootingTutorial> all = [
    // ===== 通用技巧（general）=====
    ShootingTutorial(
      id: 'tut_general_premium',
      title: '如何拍出高级感',
      subtitle: '留白与克制，比华丽更耐看',
      coverImage: 'assets/images/tutorials/cover_tut_general_premium.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['高级感', '留白'],
      intro: '高级感不是滤镜堆出来的，而是「做减法」。画面里每多一样东西，就多一分嘈杂。',
      steps: [
        TutorialStep(
          title: '减少画面元素',
          body: '拍照前先问自己：这个画面里，什么是不必要的？移走它。',
        ),
        TutorialStep(
          title: '统一色调',
          body: '让画面主体颜色不超过 3 个，同色系更显质感。',
          imageAsset: 'assets/images/tutorials/step_tut_general_premium_1.png',
        ),
        TutorialStep(
          title: '留出呼吸感',
          body: '主体不要占满画面，留出一块干净的背景空间。',
        ),
      ],
      tips: ['低饱和 + 低对比，质感更高级', '背景越简单，主体越高级'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_13',
    ),
    ShootingTutorial(
      id: 'tut_general_vibe',
      title: '如何拍出氛围感',
      subtitle: '用光、雾与故事感，让照片会说话',
      coverImage: 'assets/images/tutorials/cover_tut_general_vibe.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['氛围感', '逆光'],
      intro: '氛围感的秘密：让观者「猜故事」。逆光、侧逆光、薄雾，都是氛围的催化剂。',
      steps: [
        TutorialStep(
          title: '找逆光',
          body: '把主体放在光源与镜头之间，轮廓会镀上一层光边。',
          imageAsset: 'assets/images/tutorials/step_tut_general_vibe_1.png',
        ),
        TutorialStep(
          title: '加一层前景',
          body: '用树叶、纱帘做前景虚化，画面立刻有了纵深感。',
        ),
        TutorialStep(
          title: '降低曝光',
          body: '故意欠曝半档，暗调让情绪更浓。',
        ),
      ],
      tips: ['黄昏前 30 分钟氛围最佳', '雾气、蒸汽都是免费的氛围道具'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'sunset-silhouette'),
      academyCourseId: 'course_07',
    ),
    ShootingTutorial(
      id: 'tut_general_angle',
      title: '找好角度，照片就赢了一半',
      subtitle: '同一个场景，角度不同天差地别',
      coverImage: 'assets/images/tutorials/cover_tut_general_angle.png',
      category: 'general',
      readMinutes: '2分钟',
      tags: ['角度', '构图'],
      intro: '俯拍显小、仰拍显高、平视最亲切。拍摄前先绕主体走一圈，找到最佳机位。',
      steps: [
        TutorialStep(
          title: '平视最真实',
          body: '与主体眼睛同高，最符合日常视角，最自然。',
        ),
        TutorialStep(
          title: '微微仰拍',
          body: '拍人像时镜头略低于视线，显高显精神。',
          imageAsset: 'assets/images/tutorials/step_tut_general_angle_1.png',
        ),
        TutorialStep(
          title: '俯拍看全貌',
          body: '拍食物、桌面时垂直俯拍，把布局拍得整整齐齐。',
        ),
      ],
      tips: ['拍摄前先走一圈找机位', '同主体连拍 3 个角度，选最满意的'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'golden-rim-portrait'),
      academyCourseId: 'course_01',
    ),
    ShootingTutorial(
      id: 'tut_general_light',
      title: '光影：一张照片的灵魂',
      subtitle: '学会看光，就学会了拍照',
      coverImage: 'assets/images/tutorials/cover_tut_general_light.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['光影', '光线'],
      intro: '摄影是用光的艺术。侧光塑形、逆光勾边、顶光显层次，先学会分辨光的方向。',
      steps: [
        TutorialStep(
          title: '侧光塑形',
          body: '光从侧面来，主体一半亮一半暗，立体感最强。',
          imageAsset: 'assets/images/tutorials/step_tut_general_light_1.png',
        ),
        TutorialStep(
          title: '逆光勾边',
          body: '逆光时给主体镀上轮廓光，适合剪影和发丝光。',
        ),
        TutorialStep(
          title: '窗光最温柔',
          body: '室内拍照首选窗边，天然柔光箱。',
        ),
      ],
      tips: ['正午顶光最硬，避开它', '阴天是免费的柔光罩'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'rainy-window'),
      academyCourseId: 'course_02',
    ),
    ShootingTutorial(
      id: 'tut_general_composition',
      title: '三分法构图入门',
      subtitle: '把画面分成九宫格，主体放交点',
      coverImage: 'assets/images/tutorials/cover_tut_general_composition.png',
      category: 'general',
      readMinutes: '2分钟',
      tags: ['构图', '三分法'],
      intro: '把画面横向竖向各分三份，四条线四个交点是天然的视觉重心。',
      steps: [
        TutorialStep(
          title: '打开网格线',
          body: '在取景器中打开三分线辅助，新手友好。',
        ),
        TutorialStep(
          title: '主体放交点',
          body: '人物、主体放在四条线的交点附近，画面立刻舒服。',
          imageAsset: 'assets/images/tutorials/step_tut_general_composition_1.png',
        ),
        TutorialStep(
          title: '地平线对齐',
          body: '拍风景时把地平线压在上/下三分之一处。',
        ),
      ],
      tips: ['拍完再裁切，二次构图也是三分法', '人物视线方向留出空间'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'golden_landscape'),
      academyCourseId: 'course_03',
    ),
    ShootingTutorial(
      id: 'tut_general_color',
      title: '用色彩讲故事',
      subtitle: '色温、色调、配色，都在悄悄说话',
      coverImage: 'assets/images/tutorials/cover_tut_general_color.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['色彩', '配色'],
      intro: '暖色热闹、冷色安静、低饱和高级。颜色定调，情绪自现。',
      steps: [
        TutorialStep(
          title: '先定主色调',
          body: '一张照片只讲一种情绪，冷调或暖调二选一。',
        ),
        TutorialStep(
          title: '相邻色和谐',
          body: '同色系、相邻色搭配最安全，最出氛围。',
          imageAsset: 'assets/images/tutorials/step_tut_general_color_1.png',
        ),
        TutorialStep(
          title: '一点撞色点睛',
          body: '大面积统一色里放一点对比色，是记忆点。',
        ),
      ],
      tips: ['后期调整白平衡可瞬间改情绪', '莫兰迪色系最容易拍出高级感'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'morandi_minimal_portrait'),
      academyCourseId: 'course_11',
    ),

    // ===== 人像（portrait）=====
    ShootingTutorial(
      id: 'tut_portrait_window',
      title: '窗边人像：把光框进画里',
      subtitle: '一扇窗，一个天然柔光箱',
      coverImage: 'assets/images/tutorials/cover_tut_portrait_window.png',
      category: 'portrait',
      readMinutes: '3分钟',
      tags: ['人像', '窗光'],
      intro: '窗边光是拍人像最容易出片的光：方向明确、质地柔软，还有窗框天然构图。',
      steps: [
        TutorialStep(
          title: '让人物侧对窗',
          body: '光从侧面来，脸部一半亮一半暗，立体又瘦脸。',
        ),
        TutorialStep(
          title: '眼神里留高光',
          body: '让眼睛里映出窗光，眼睛立刻有神。',
          imageAsset: 'assets/images/tutorials/step_tut_portrait_window_1.png',
        ),
        TutorialStep(
          title: '用窗框做前景',
          body: '隔着窗拍，画中画的层次感。',
        ),
      ],
      tips: ['白纱窗帘 = 免费柔光', '别让人物正对窗，光太平'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_01',
    ),
    ShootingTutorial(
      id: 'tut_portrait_backlight',
      title: '逆光人像：镀一层金边',
      subtitle: '发丝光与轮廓光，浪漫感拉满',
      coverImage: 'assets/images/tutorials/cover_tut_portrait_backlight.png',
      category: 'portrait',
      readMinutes: '3分钟',
      tags: ['人像', '逆光'],
      intro: '逆光人像的秘诀：对脸测光会变剪影，对背景测光会过曝。折中，让人物补点光。',
      steps: [
        TutorialStep(
          title: '黄金时刻拍逆光',
          body: '日落前后 30 分钟，光最柔最金。',
        ),
        TutorialStep(
          title: '点测光对准脸部边缘',
          body: '保留发丝金边，脸部也不会死黑。',
          imageAsset: 'assets/images/tutorials/step_tut_portrait_backlight_1.png',
        ),
        TutorialStep(
          title: '加一点点补光',
          body: '反光板或手机屏幕光，让脸部不死黑。',
        ),
      ],
      tips: ['逆光时注意不要直视镜头太久', '局部光斑是氛围加分项'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'golden-rim-portrait'),
      academyCourseId: 'course_07',
    ),

    // ===== 风光（landscape）=====
    ShootingTutorial(
      id: 'tut_landscape_golden',
      title: '黄金时刻：风光片的最佳时间',
      subtitle: '日出日落前后一小时，光比任何滤镜都好用',
      coverImage: 'assets/images/tutorials/cover_tut_landscape_golden.png',
      category: 'landscape',
      readMinutes: '3分钟',
      tags: ['风光', '黄金时刻'],
      intro: '风光摄影只有一个黄金法则：在黄金时刻按快门。柔和、温暖、拉长的影子，都是它给的。',
      steps: [
        TutorialStep(
          title: '提前踩点',
          body: '黄金时刻很短暂，提前 30 分钟到场架好机位。',
        ),
        TutorialStep(
          title: '侧光看纹理',
          body: '黄金时刻的侧光让山峦、沙丘的纹理最立体。',
          imageAsset: 'assets/images/tutorials/step_tut_landscape_golden_1.png',
        ),
        TutorialStep(
          title: '留出天空',
          body: '天空的暖色渐变，是这张照片最值钱的部分。',
        ),
      ],
      tips: ['黄金时刻指日出后/日落前约 1 小时', '阴天别急走，云缝光更惊艳'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'golden_landscape'),
      academyCourseId: 'course_04',
    ),
    ShootingTutorial(
      id: 'tut_landscape_leading',
      title: '引导线构图：让视线去旅行',
      subtitle: '路、栏杆、河流，都是天然的导游',
      coverImage: 'assets/images/tutorials/cover_tut_landscape_leading.png',
      category: 'landscape',
      readMinutes: '2分钟',
      tags: ['风光', '构图'],
      intro: '画面里的线条会"带路"。路、栈道、河流把视线引向主体，纵深感和故事感一起出现。',
      steps: [
        TutorialStep(
          title: '找一条线',
          body: '地面上的路、墙、栏杆，先找到一条。',
        ),
        TutorialStep(
          title: '线从画面一角进入',
          body: '引导线斜着进入画面，比横平竖直更有张力。',
          imageAsset: 'assets/images/tutorials/step_tut_landscape_leading_1.png',
        ),
        TutorialStep(
          title: '线指向主体',
          body: '让线条终点是兴趣点，不要指空。',
        ),
      ],
      tips: ['低角度拍路，线条感最强', 'S 形曲线比直线更耐看'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'seaside-beach'),
      academyCourseId: 'course_09',
    ),

    // ===== 美食（food）=====
    ShootingTutorial(
      id: 'tut_food_flatlay',
      title: '俯拍平铺：美食摆盘的艺术',
      subtitle: '从上往下看，餐桌上全是构图',
      coverImage: 'assets/images/tutorials/cover_tut_food_flatlay.png',
      category: 'food',
      readMinutes: '2分钟',
      tags: ['美食', '俯拍'],
      intro: '俯拍 45-90 度角，把餐具、食物、手部动作都装进画面，是美食摄影的经典拍法。',
      steps: [
        TutorialStep(
          title: '垂直俯拍最稳',
          body: '手机与桌面平行，从上往下拍，线条不变形。',
        ),
        TutorialStep(
          title: '餐具当画框',
          body: '盘子、杯子、餐巾，都是天然的构图元素。',
          imageAsset: 'assets/images/tutorials/step_tut_food_flatlay_1.png',
        ),
        TutorialStep(
          title: '留一点"吃过的痕迹"',
          body: '缺一角的面包、喝过一口的咖啡，更有生活感。',
        ),
      ],
      tips: ['找靠窗的桌位，光最好', '俯拍时手入镜端杯，故事感更强'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'food_flat_lay'),
      academyCourseId: 'course_05',
    ),
    ShootingTutorial(
      id: 'tut_food_natural',
      title: '自然光美食：窗边就是天然柔光箱',
      subtitle: '不用打灯，一扇窗拍出美食大片',
      coverImage: 'assets/images/tutorials/cover_tut_food_natural.png',
      category: 'food',
      readMinutes: '2分钟',
      tags: ['美食', '自然光'],
      intro: '美食摄影最怕顶灯直射。把食物搬到窗边，用白纸补光，就能得到柔和干净的光。',
      steps: [
        TutorialStep(
          title: '座位选窗边',
          body: '进店先找靠窗位，侧光最立体。',
        ),
        TutorialStep(
          title: '白纸补阴影',
          body: '暗面放一张白纸/纸巾，反光填暗。',
          imageAsset: 'assets/images/tutorials/step_tut_food_natural_1.png',
        ),
        TutorialStep(
          title: '别开闪光灯',
          body: '闪光灯会把食物拍得油腻发白。',
        ),
      ],
      tips: ['蒸腾的热气是氛围感来源', '手动对焦到食物最诱人的部位'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'foodie_portrait'),
      academyCourseId: 'course_02',
    ),

    // ===== 街拍（street）=====
    ShootingTutorial(
      id: 'tut_street_decisive',
      title: '决定性瞬间：街头摄影的抓拍',
      subtitle: '按下快门的那一刻，就是故事',
      coverImage: 'assets/images/tutorials/cover_tut_street_decisive.png',
      category: 'street',
      readMinutes: '3分钟',
      tags: ['街拍', '抓拍'],
      intro: '布列松说：摄影就是抓住决定性的瞬间。街拍没有重来，只有预判和手速。',
      steps: [
        TutorialStep(
          title: '蹲点等画面',
          body: '找一个有戏剧性的路口，等人物走进你的构图。',
        ),
        TutorialStep(
          title: '预对焦',
          body: '先对焦到预期人物出现的位置，人来了直接拍。',
          imageAsset: 'assets/images/tutorials/step_tut_street_decisive_1.png',
        ),
        TutorialStep(
          title: '连拍不心疼',
          body: '街头瞬间稍纵即逝，多拍几张回去选。',
        ),
      ],
      tips: ['尊重路人，拍完微笑示意', '盲拍（不看取景器）能抓到最自然的表情'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'night-street'),
      academyCourseId: 'course_06',
    ),
    ShootingTutorial(
      id: 'tut_street_shadow',
      title: '街头光影：在明暗交界处按快门',
      subtitle: '一束光洒下来，平凡街道变成舞台',
      coverImage: 'assets/images/tutorials/cover_tut_street_shadow.png',
      category: 'street',
      readMinutes: '2分钟',
      tags: ['街拍', '光影'],
      intro: '光影交界处是街拍的最佳机位。有人走进光里，画面就有了主角。',
      steps: [
        TutorialStep(
          title: '找明暗交界',
          body: '上午或下午，建筑影子在地面上切割出光带。',
        ),
        TutorialStep(
          title: '等一个人走进光里',
          body: '人物进入光带的一瞬间按下快门。',
          imageAsset: 'assets/images/tutorials/step_tut_street_shadow_1.png',
        ),
        TutorialStep(
          title: '拍影子也精彩',
          body: '拉长的影子本身就是一张照片。',
        ),
      ],
      tips: ['黑白模式更突出光影', '正午影子太短，早晚更合适'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'street_bw'),
      academyCourseId: 'course_12',
    ),

    // ===== 夜景（night）=====
    ShootingTutorial(
      id: 'tut_night_bluetime',
      title: '蓝调时刻：天黑后的第一抹浪漫',
      subtitle: '日落后的 20 分钟，天空是克莱因蓝',
      coverImage: 'assets/images/tutorials/cover_tut_night_bluetime.png',
      category: 'night',
      readMinutes: '3分钟',
      tags: ['夜景', '蓝调'],
      intro: '日落完全黑透前的 20 分钟，天空是深邃的蓝，灯刚亮起——城市最美的时刻。',
      steps: [
        TutorialStep(
          title: '卡准时间',
          body: '日落后再等 15-20 分钟，蓝调浓度最佳。',
        ),
        TutorialStep(
          title: '找路灯当点缀',
          body: '暖色灯光和蓝调天空是天生一对。',
          imageAsset: 'assets/images/tutorials/step_tut_night_bluetime_1.png',
        ),
        TutorialStep(
          title: '手机要稳住',
          body: '蓝调时刻光线暗，手持稍不稳就会糊。',
        ),
      ],
      tips: ['用夜景/长曝光模式', '水面能反射天空，蓝调翻倍'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'night_cityscape'),
      academyCourseId: 'course_04',
    ),
    ShootingTutorial(
      id: 'tut_night_neon',
      title: '霓虹人像：把夜色穿在身上',
      subtitle: '彩色霓虹灯，是最便宜的影棚灯',
      coverImage: 'assets/images/tutorials/cover_tut_night_neon.png',
      category: 'night',
      readMinutes: '2分钟',
      tags: ['夜景', '人像'],
      intro: '霓虹灯的光色就是最好的氛围灯：粉、蓝、紫，直接照亮人脸还自带电影感。',
      steps: [
        TutorialStep(
          title: '让霓虹灯在身后',
          body: '霓虹做背景光斑，人物轮廓清晰。',
        ),
        TutorialStep(
          title: '脸要朝向光源',
          body: '保证脸有一盏主光，不然会变成剪影。',
          imageAsset: 'assets/images/tutorials/step_tut_night_neon_1.png',
        ),
        TutorialStep(
          title: '加一点冷调',
          body: '白平衡偏冷一点，霓虹更艳，皮肤更通透。',
        ),
      ],
      tips: ['雨天霓虹倒影是加成', '避开路灯直射头顶的光'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'neon_portrait'),
      academyCourseId: 'course_06',
    ),

    // ===== 微距（macro）=====
    ShootingTutorial(
      id: 'tut_macro_detail',
      title: '微距入门：看见另一个世界',
      subtitle: '把镜头贴近，平凡之物皆是宇宙',
      coverImage: 'assets/images/tutorials/cover_tut_macro_detail.png',
      category: 'macro',
      readMinutes: '2分钟',
      tags: ['微距', '细节'],
      intro: '微距的快乐在于"发现"。水珠、布料、键盘——离得够近，万物都有纹理。',
      steps: [
        TutorialStep(
          title: '用微距模式',
          body: '手机切到微距/超级微距模式，或在镜头前贴一张水滴。',
        ),
        TutorialStep(
          title: '找好支撑',
          body: '微距下抖动被放大，手肘撑桌或固定手机。',
          imageAsset: 'assets/images/tutorials/step_tut_macro_detail_1.png',
        ),
        TutorialStep(
          title: '对焦到眼睛/核心',
          body: '微距景深极浅，只对焦最重要的一个点。',
        ),
      ],
      tips: ['拍水珠时让背景有彩色光源', '雨后是微距的黄金时间'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'macro_flower'),
      academyCourseId: 'course_10',
    ),
    ShootingTutorial(
      id: 'tut_macro_flower',
      title: '花卉微距：拍出晨露的呼吸',
      subtitle: '花蕊、露珠、绒毛，微观世界的美',
      coverImage: 'assets/images/tutorials/cover_tut_macro_flower.png',
      category: 'macro',
      readMinutes: '2分钟',
      tags: ['微距', '花卉'],
      intro: '花卉微距的秘诀：清晨露水未干时，花的精神头最好；侧光会让绒毛和露珠发光。',
      steps: [
        TutorialStep(
          title: '清晨去拍',
          body: '露珠是免费的钻石，清晨是唯一拥有它的时间。',
        ),
        TutorialStep(
          title: '侧光拍质感',
          body: '侧逆光下，花瓣绒毛、露珠都会发光。',
          imageAsset: 'assets/images/tutorials/step_tut_macro_flower_1.png',
        ),
        TutorialStep(
          title: '对焦花蕊',
          body: '花蕊是花卉的"眼睛"，对焦它最传神。',
        ),
      ],
      tips: ['喷壶洒点水，人造露珠也行', '背景选暗色，花朵更突出'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'macro_flower'),
      academyCourseId: 'course_10',
    ),

    // ===== 静物（still-life）=====
    ShootingTutorial(
      id: 'tut_still_minimal',
      title: '极简静物：少即是多',
      subtitle: '一个主体，一块背景，一束光',
      coverImage: 'assets/images/tutorials/cover_tut_still_minimal.png',
      category: 'still-life',
      readMinutes: '2分钟',
      tags: ['静物', '极简'],
      intro: '极简静物的公式：一个主体 + 一块干净背景 + 一束侧光。剩下的交给留白。',
      steps: [
        TutorialStep(
          title: '清空桌面',
          body: '只留一个主体，其他全部移出画面。',
        ),
        TutorialStep(
          title: '背景用纯色纸',
          body: '白纸、浅色墙纸、亚克力板都行。',
          imageAsset: 'assets/images/tutorials/step_tut_still_minimal_1.png',
        ),
        TutorialStep(
          title: '侧光塑形',
          body: '一束窗光从侧面来，主体阴影干净利落。',
        ),
      ],
      tips: ['主体居中或放三分点，别歪着', '影子也是构图的一部分'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'indoor_still_life'),
      academyCourseId: 'course_15',
    ),
    ShootingTutorial(
      id: 'tut_still_warm',
      title: '温暖静物：阳光是最好的滤镜',
      subtitle: '午后斜阳，把物件镀成蜜糖色',
      coverImage: 'assets/images/tutorials/cover_tut_still_warm.png',
      category: 'still-life',
      readMinutes: '2分钟',
      tags: ['静物', '暖调'],
      intro: '午后斜阳是最廉价的"金色滤镜"。咖啡杯、书本、绿植，在暖光里都有了温度。',
      steps: [
        TutorialStep(
          title: '等午后斜阳',
          body: '下午 3-5 点，光斜、色暖、影子长。',
        ),
        TutorialStep(
          title: '把光斑拍进画面',
          body: '桌面的光斑是静物摄影的高级感来源。',
          imageAsset: 'assets/images/tutorials/step_tut_still_warm_1.png',
        ),
        TutorialStep(
          title: '同色系摆件',
          body: '米白、浅棕、原木同色系，画面立刻高级。',
        ),
      ],
      tips: ['窗帘半掩，光更柔和', '绿植入镜，暖中带一点生机'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'home-cozy'),
      academyCourseId: 'course_10',
    ),
  ];
}