import 'academy_models.dart';

// _courseDetails 引用 courses[N]（const 列表索引），在 Dart 2.19 中无法作为 const 表达式，
// 因此 AcademyCourseDetail 不能声明为 const，内部构造也无法进入 const 上下文。
// 为避免对 16 课 × ~10 处内部构造逐一添加 const，此处整体忽略该 lint。
// ignore_for_file: prefer_const_constructors

/// 学院课程内容数据
/// 16 课按难度×主题矩阵组织，8 张知识卡片
class AcademyContent {
  AcademyContent._();

  // === 16 课课程矩阵（列表元数据） ===
  static const courses = <AcademyCourse>[
    // 入门（6 课）
    AcademyCourse(
      id: 'course_01', lessonNumber: 1, title: '找到你的最佳角度',
      level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
      coverImage: 'assets/images/academy/course_01_cover.jpg',
      meta: '8分钟 · 入门', tags: ['角度', '人像'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_02', lessonNumber: 2, title: '光线基础',
      level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
      coverImage: 'assets/images/academy/course_02_cover.jpg',
      meta: '10分钟 · 入门', tags: ['光线', '侧光'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_03', lessonNumber: 3, title: '构图三分法',
      level: AcademyLevel.beginner, topic: AcademyTopic.landscape,
      coverImage: 'assets/images/academy/course_03_cover.jpg',
      meta: '8分钟 · 入门', tags: ['构图', '三分法'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_04', lessonNumber: 4, title: '黄金时段',
      level: AcademyLevel.beginner, topic: AcademyTopic.landscape,
      coverImage: 'assets/images/academy/course_04_cover.jpg',
      meta: '6分钟 · 入门', tags: ['日落', '柔光'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_05', lessonNumber: 5, title: '俯拍平铺',
      level: AcademyLevel.beginner, topic: AcademyTopic.stillLife,
      coverImage: 'assets/images/academy/course_05_cover.jpg',
      meta: '7分钟 · 入门', tags: ['俯拍', '静物'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_06', lessonNumber: 6, title: '决定性瞬间',
      level: AcademyLevel.beginner, topic: AcademyTopic.street,
      coverImage: 'assets/images/academy/course_06_cover.jpg',
      meta: '9分钟 · 入门', tags: ['街拍', '抓拍'], rewardXP: 50,
    ),
    // 进阶（6 课）
    AcademyCourse(
      id: 'course_07', lessonNumber: 7, title: '伦勃朗光',
      level: AcademyLevel.intermediate, topic: AcademyTopic.portrait,
      coverImage: 'assets/images/academy/course_07_cover.jpg',
      meta: '12分钟 · 进阶', tags: ['布光', '伦勃朗'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_08', lessonNumber: 8, title: '情绪表达',
      level: AcademyLevel.intermediate, topic: AcademyTopic.portrait,
      coverImage: 'assets/images/academy/course_08_cover.jpg',
      meta: '10分钟 · 进阶', tags: ['情绪', '人像'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_09', lessonNumber: 9, title: '引导线构图',
      level: AcademyLevel.intermediate, topic: AcademyTopic.landscape,
      coverImage: 'assets/images/academy/course_09_cover.jpg',
      meta: '11分钟 · 进阶', tags: ['构图', '引导线'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_10', lessonNumber: 10, title: '布光法',
      level: AcademyLevel.intermediate, topic: AcademyTopic.stillLife,
      coverImage: 'assets/images/academy/course_10_cover.jpg',
      meta: '13分钟 · 进阶', tags: ['布光', '静物'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_11', lessonNumber: 11, title: '色彩搭配',
      level: AcademyLevel.intermediate, topic: AcademyTopic.stillLife,
      coverImage: 'assets/images/academy/course_11_cover.jpg',
      meta: '10分钟 · 进阶', tags: ['色彩', '搭配'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_12', lessonNumber: 12, title: '街头光影',
      level: AcademyLevel.intermediate, topic: AcademyTopic.street,
      coverImage: 'assets/images/academy/course_12_cover.jpg',
      meta: '11分钟 · 进阶', tags: ['光影', '街拍'], rewardXP: 80,
    ),
    // 高级（4 课）
    AcademyCourse(
      id: 'course_13', lessonNumber: 13, title: '风格化人像',
      level: AcademyLevel.advanced, topic: AcademyTopic.portrait,
      coverImage: 'assets/images/academy/course_13_cover.jpg',
      meta: '15分钟 · 高级', tags: ['风格', '人像'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_14', lessonNumber: 14, title: '黑白风光',
      level: AcademyLevel.advanced, topic: AcademyTopic.landscape,
      coverImage: 'assets/images/academy/course_14_cover.jpg',
      meta: '14分钟 · 高级', tags: ['黑白', '风光'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_15', lessonNumber: 15, title: '极简静物',
      level: AcademyLevel.advanced, topic: AcademyTopic.stillLife,
      coverImage: 'assets/images/academy/course_15_cover.jpg',
      meta: '12分钟 · 高级', tags: ['极简', '静物'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_16', lessonNumber: 16, title: '街头叙事',
      level: AcademyLevel.advanced, topic: AcademyTopic.street,
      coverImage: 'assets/images/academy/course_16_cover.jpg',
      meta: '16分钟 · 高级', tags: ['叙事', '街拍'], rewardXP: 120,
    ),
  ];

  /// 按 ID 获取课程元数据
  static AcademyCourse? getCourse(String courseId) {
    for (final c in courses) {
      if (c.id == courseId) return c;
    }
    return null;
  }

  /// 按等级筛选课程
  static List<AcademyCourse> getCoursesByLevel(AcademyLevel? level) {
    if (level == null) return courses;
    return courses.where((c) => c.level == level).toList();
  }

  // === 8 张知识卡片 ===
  static const knowledgeCards = <KnowledgeCard>[
    KnowledgeCard(
      id: 'kc_01', topic: AcademyTopic.portrait,
      title: '三分法则', subtitle: '构图的核心法则',
      coverImage: 'assets/images/academy/kc_01_cover.jpg',
      body: '将画面分为九宫格，把主体放在交叉点或线条上，能创造出平衡而富有张力的构图。这是摄影最基础也最实用的构图法则。',
      keyPoints: ['将画面横竖各分三等分', '主体放在交叉点上', '地平线对齐水平三分线'],
    ),
    KnowledgeCard(
      id: 'kc_02', topic: AcademyTopic.portrait,
      title: '黄金时刻', subtitle: '一天中最美的光线',
      coverImage: 'assets/images/academy/kc_02_cover.jpg',
      body: '日出后和日落前的一小时，光线柔和、色温暖黄，是拍摄人像和风光的最佳时段。此时的光线角度低，能产生长长的阴影和丰富的纹理。',
      keyPoints: ['日出后1小时内', '日落前1小时内', '色温约 3200K-4500K'],
    ),
    KnowledgeCard(
      id: 'kc_03', topic: AcademyTopic.landscape,
      title: '引导线', subtitle: '用线条引导视线',
      coverImage: 'assets/images/academy/kc_03_cover.jpg',
      body: '道路、河流、栏杆、树列等线条元素可以将观者的视线引导至画面主体，增强照片的纵深感和叙事性。',
      keyPoints: ['寻找自然或人造线条', '线条应指向主体', '可使用汇聚线增强透视'],
    ),
    KnowledgeCard(
      id: 'kc_04', topic: AcademyTopic.landscape,
      title: '前景层次', subtitle: '让风景有深度',
      coverImage: 'assets/images/academy/kc_04_cover.jpg',
      body: '在画面中加入前景元素（如岩石、花朵、树枝），可以建立近-中-远三层结构，让二维照片呈现三维空间感。',
      keyPoints: ['寻找前景元素', '建立三层结构', '使用小光圈保证景深'],
    ),
    KnowledgeCard(
      id: 'kc_05', topic: AcademyTopic.stillLife,
      title: '侧光布光', subtitle: '静物的立体感密码',
      coverImage: 'assets/images/academy/kc_05_cover.jpg',
      body: '从物体侧面 45-90 度角打光，能产生明暗对比，突出物体的质感和立体感。这是静物摄影最常用的布光方式。',
      keyPoints: ['光源在侧面 45-90 度', '暗部可用反光板补光', '注意阴影方向'],
    ),
    KnowledgeCard(
      id: 'kc_06', topic: AcademyTopic.stillLife,
      title: '色彩理论', subtitle: '配色让画面更高级',
      coverImage: 'assets/images/academy/kc_06_cover.jpg',
      body: '互补色（如蓝-橙、红-绿）能产生强烈对比，同类色（如棕-米-橙）则营造和谐感。掌握色彩搭配能让照片视觉层次更丰富。',
      keyPoints: ['互补色产生对比', '同类色营造和谐', '控制色彩数量在 3-4 种'],
    ),
    KnowledgeCard(
      id: 'kc_07', topic: AcademyTopic.street,
      title: '决定性瞬间', subtitle: '布列松的街拍哲学',
      coverImage: 'assets/images/academy/kc_07_cover.jpg',
      body: '在街拍中，形态、姿态、光线和情绪在某一刻完美结合的瞬间就是"决定性瞬间"。预判场景、提前对焦、快速反应是捕捉它的关键。',
      keyPoints: ['预判场景发展', '提前设定对焦和曝光', '反应要快但不慌'],
    ),
    KnowledgeCard(
      id: 'kc_08', topic: AcademyTopic.street,
      title: '光影对比', subtitle: '用明暗讲故事',
      coverImage: 'assets/images/academy/kc_08_cover.jpg',
      body: '在街拍中寻找光与影的交界，将主体放在亮处或暗处，利用强烈的明暗对比营造戏剧感和神秘感。',
      keyPoints: ['寻找光影交界线', '主体放在亮处', '暗部保留细节但不抢戏'],
    ),
  ];

  /// 按 ID 获取知识卡片
  static KnowledgeCard? getKnowledgeCard(String cardId) {
    for (final kc in knowledgeCards) {
      if (kc.id == cardId) return kc;
    }
    return null;
  }

  /// 按主题筛选知识卡片
  static List<KnowledgeCard> getKnowledgeCardsByTopic(AcademyTopic? topic) {
    if (topic == null) return knowledgeCards;
    return knowledgeCards.where((kc) => kc.topic == topic).toList();
  }

  // === 课程详情 ===
  // 每课包含：章节、TipCard、对比网格、实战练习、小贴士、推荐模板、关联知识卡片、作业

  /// 课程详情 map（key = courseId）
  static final Map<String, AcademyCourseDetail> _courseDetails = {
    'course_01': AcademyCourseDetail(
      course: courses[0],
      heroImage: 'assets/images/academy/course_01_cover.jpg',
      sections: [
        LessonSection(title: '为什么角度很重要', paragraphs: [
          '同样的场景、同样的光线，仅仅因为拍摄角度的不同，照片效果可能天差地别。找到你身上最自信的角度，是出片的第一步。',
          '每个人的脸型、身材比例不同，适合的角度也不同。但有一些通用法则可以让你快速找到自己的「最佳出片位」。',
        ]),
        LessonSection(title: '俯拍 vs 平拍', paragraphs: ['两种最常见角度的效果对比：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '45度角拍摄',
      tipCardParagraph: '微微侧身45度，下巴略微前伸，可以让脸部轮廓更立体。这个角度适合绝大多数脸型，尤其对圆脸非常友好。',
      tipCardImage: 'assets/images/academy/course_01_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'arrow_down', name: '俯拍', desc: '相机在眼睛上方，从上往下拍。显脸小、显头身比好。', tagText: '推荐', tagColor: 'green'),
        CompareCell(iconName: 'arrows_left_right', name: '平拍', desc: '相机与眼睛平齐。真实还原，适合证件照、正面照。', tagText: '中性', tagColor: 'gold'),
      ],
      practiceTitle: '试试这个练习',
      practiceParagraph: '打开如画，选择「街拍回眸」模板，在自然光下尝试俯拍角度，拍摄3张不同角度的照片。',
      practiceTags: [
        PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '自然光', color: 'green'),
        PracticeTag(iconName: 'arrow_down', label: '俯拍', color: 'red'),
      ],
      tips: ['手机举高15-30cm，微微俯拍效果最好', '避免完全正面，微微转头更自然', '利用窗光，侧光拍出脸部立体感'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/cafe_portrait.jpg',
        name: '咖啡馆人像', desc: '用「咖啡馆人像」练习角度', badge: '免费',
      ),
      knowledgeCardIds: ['kc_01'],
      assignment: AcademyAssignment(
        id: 'asg_01', courseId: 'course_01',
        title: '拍摄你的最佳角度',
        description: '使用俯拍角度拍摄一张人像照片，注意光线方向和背景简洁度。',
        requirements: ['俯拍角度（相机高于眼睛）', '自然侧光', '背景简洁'],
        rewardXP: 100,
      ),
    ),
    'course_02': AcademyCourseDetail(
      course: courses[1],
      heroImage: 'assets/images/academy/course_02_cover.jpg',
      sections: [
        LessonSection(title: '光线三要素', paragraphs: [
          '摄影一词本意是「用光作画」，理解光线是学好摄影的第一课。光线的三个核心要素是：方向、强度和色温。',
          '方向决定阴影落点，强度决定明暗反差，色温决定画面冷暖。三者共同塑造了照片的氛围与情绪。',
        ]),
        LessonSection(title: '侧光 vs 逆光', paragraphs: ['两种最基础的光线方向，效果截然不同：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '侧光的魅力',
      tipCardParagraph: '让光源从模特侧面 45-90 度照射，会在面部形成明暗过渡，突出立体感和轮廓。这是人像摄影最常用的光线方向。',
      tipCardImage: 'assets/images/academy/course_02_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'sun', name: '侧光', desc: '光源在模特侧面，明暗对比鲜明，立体感强。', tagText: '推荐', tagColor: 'green'),
        CompareCell(iconName: 'sun', name: '逆光', desc: '光源在模特背后，营造剪影或光晕效果，氛围感强。', tagText: '进阶', tagColor: 'gold'),
      ],
      practiceTitle: '光线方向练习',
      practiceParagraph: '在窗边让模特侧坐，分别尝试侧光和逆光拍摄，对比两张照片的立体感和氛围差异。',
      practiceTags: [
        PracticeTag(iconName: 'sun', label: '自然光', color: 'green'),
        PracticeTag(iconName: 'arrow_down', label: '侧光', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '逆光', color: 'red'),
      ],
      tips: ['侧光时让模特微微转向光源，明暗更协调', '逆光拍摄注意对焦在脸部，必要时提高曝光补偿', '避免正午顶光，阴影生硬不讨喜'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/soft_portrait.jpg',
        name: '柔光人像', desc: '用「柔光人像」练习光线', badge: '免费',
      ),
      knowledgeCardIds: ['kc_02'],
      assignment: AcademyAssignment(
        id: 'asg_02', courseId: 'course_02',
        title: '侧光人像练习',
        description: '利用窗光或夕阳侧光拍摄一张人像照片，注意光线方向和明暗过渡。',
        requirements: ['侧光 45-90 度', '明暗过渡自然', '保留暗部细节'],
        rewardXP: 100,
      ),
    ),
    'course_03': AcademyCourseDetail(
      course: courses[2],
      heroImage: 'assets/images/academy/course_03_cover.jpg',
      sections: [
        LessonSection(title: '三分法原理', paragraphs: [
          '三分法是构图最基础的法则：将画面用两条横线、两条竖线均分为九宫格，四条线的四个交点被称为「趣味中心」。',
          '把主体放在趣味中心或线条上，画面会显得更平衡、更有张力。地平线对齐水平三分线，可以让天空或地面占据合适的比例。',
        ]),
        LessonSection(title: '横竖三分法应用', paragraphs: ['横构图与竖构图的三分法应用略有不同：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '地平线位置',
      tipCardParagraph: '拍摄风光时，将地平线对齐上三分线（强调地面）或下三分线（强调天空），避免地平线居中把画面切成两半。',
      tipCardImage: 'assets/images/academy/course_03_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'arrows_left_right', name: '居中构图', desc: '主体放在画面正中央，对称稳定但容易呆板。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'arrows_left_right', name: '三分构图', desc: '主体放在趣味中心，画面更平衡且富有张力。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '三分法风景练习',
      practiceParagraph: '寻找一处有明确主体的风景（如一棵树、一栋小屋），分别用居中构图和三分构图拍摄，对比画面感受。',
      practiceTags: [
        PracticeTag(iconName: 'image', label: '风景', color: 'green'),
        PracticeTag(iconName: 'arrows_left_right', label: '三分法', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '自然光', color: 'red'),
      ],
      tips: ['打开相机网格线，方便对齐三分线', '主体朝向的方向多留空间，避免「撞墙」感', '地平线一定要水平，倾斜会破坏稳定感'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/urban_architecture.jpg',
        name: '城市建筑', desc: '用「城市建筑」练习三分法', badge: '免费',
      ),
      knowledgeCardIds: ['kc_01', 'kc_03'],
      assignment: AcademyAssignment(
        id: 'asg_03', courseId: 'course_03',
        title: '三分法风景练习',
        description: '使用三分法拍摄一张风景照片，主体放在趣味中心，地平线对齐三分线。',
        requirements: ['主体位于趣味中心', '地平线对齐三分线', '画面平衡有张力'],
        rewardXP: 100,
      ),
    ),
    'course_04': AcademyCourseDetail(
      course: courses[3],
      heroImage: 'assets/images/academy/course_04_cover.jpg',
      sections: [
        LessonSection(title: '为什么黄金时段最美', paragraphs: [
          '黄金时段指日出后和日落前的一小时，此时太阳低悬于地平线，光线经过更长的大气路径，蓝光被散射，留下温暖柔和的橙红色光。',
          '这种光线角度低、强度柔、色温暖，能产生长长的阴影、丰富的纹理和梦幻的氛围，是风光与人像摄影的「神仙时段」。',
        ]),
        LessonSection(title: '光线特点', paragraphs: ['黄金时段的光线有几个鲜明特点：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '逆光剪影',
      tipCardParagraph: '在日落前 15 分钟，让模特背对太阳，对焦在亮天空上，人物会形成黑色剪影，轮廓清晰，氛围感极强。',
      tipCardImage: 'assets/images/academy/course_04_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'sun', name: '正午硬光', desc: '太阳在头顶，光线硬、阴影浓、反差大，不适合人像。', tagText: '不推荐', tagColor: 'red'),
        CompareCell(iconName: 'sun', name: '黄金时段柔光', desc: '光线柔和、色温暖、阴影长，氛围感极强。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '黄金时段拍摄练习',
      practiceParagraph: '选择日落前 1 小时出门，拍摄 3 张照片：1 张顺光人像、1 张侧光风景、1 张逆光剪影，感受光线的差异。',
      practiceTags: [
        PracticeTag(iconName: 'sun', label: '日落', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '逆光', color: 'red'),
        PracticeTag(iconName: 'sun', label: '柔光', color: 'green'),
      ],
      tips: ['提前 30 分钟到达机位，黄金时段转瞬即逝', '白平衡设为阴天或阴影模式，强化暖色调', '逆光拍摄时锁定对焦和曝光，避免画面发灰'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/golden_landscape.jpg',
        name: '黄金时刻风光', desc: '用「黄金时刻风光」练习黄金时段', badge: '免费',
      ),
      knowledgeCardIds: ['kc_02'],
      assignment: AcademyAssignment(
        id: 'asg_04', courseId: 'course_04',
        title: '黄金时段拍摄练习',
        description: '在日出后或日落前 1 小时拍摄一张照片，体现黄金时段的柔和暖光。',
        requirements: ['黄金时段光线', '暖色调氛围', '光影层次丰富'],
        rewardXP: 100,
      ),
    ),
    'course_05': AcademyCourseDetail(
      course: courses[4],
      heroImage: 'assets/images/academy/course_05_cover.jpg',
      sections: [
        LessonSection(title: '俯拍的优势', paragraphs: [
          '俯拍（flat lay）是从正上方 90 度拍摄平铺物体的方式，是静物、美食、穿搭摄影中最常用的视角。',
          '俯拍能消除透视变形，呈现物体的平面图案与色彩搭配，特别适合展现桌面布局、餐盘摆设或服饰配件。',
        ]),
        LessonSection(title: '平铺构图法', paragraphs: ['想要拍出好看的平铺，需要掌握几种构图思路：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '留白与对称',
      tipCardParagraph: '在平铺时，主体周围留出适当空白（留白）能让画面更呼吸；对称式排列则营造秩序感和仪式感，适合美食和饰品。',
      tipCardImage: 'assets/images/academy/course_05_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'arrow_down', name: '侧拍', desc: '45 度侧面拍摄，有透视感，适合立体物体。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'arrow_down', name: '俯拍', desc: '正上方 90 度拍摄，平面感强，适合平铺。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '俯拍静物练习',
      practiceParagraph: '选择一组静物（如咖啡杯、笔记本、饰品），在自然光下尝试俯拍平铺，注意构图与色彩搭配。',
      practiceTags: [
        PracticeTag(iconName: 'arrow_down', label: '俯拍', color: 'green'),
        PracticeTag(iconName: 'image', label: '静物', color: 'gold'),
        PracticeTag(iconName: 'arrows_left_right', label: '平铺', color: 'red'),
      ],
      tips: ['手机与桌面保持平行，避免梯形变形', '选择统一色系的背景，突出主体', '加入道具（书、花、餐具）丰富画面层次'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/food_flat_lay.jpg',
        name: '美食俯拍', desc: '用「美食俯拍」练习俯拍', badge: '免费',
      ),
      knowledgeCardIds: ['kc_05'],
      assignment: AcademyAssignment(
        id: 'asg_05', courseId: 'course_05',
        title: '俯拍静物练习',
        description: '使用俯拍角度拍摄一组静物平铺照片，注意构图平衡和色彩搭配。',
        requirements: ['正上方 90 度俯拍', '构图平衡', '色彩搭配协调'],
        rewardXP: 100,
      ),
    ),
    'course_06': AcademyCourseDetail(
      course: courses[5],
      heroImage: 'assets/images/academy/course_06_cover.jpg',
      sections: [
        LessonSection(title: '什么是决定性瞬间', paragraphs: [
          '「决定性瞬间」由摄影大师布列松提出，指场景中形态、姿态、光线和情绪在某一刻完美结合的瞬间。',
          '它不是单纯的「抓拍」，而是摄影师对场景的预判、构图与等待的综合体现。一张好的决定性瞬间照片，往往故事感十足。',
        ]),
        LessonSection(title: '预判与等待', paragraphs: ['捕捉决定性瞬间的关键是预判和等待：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '提前对焦',
      tipCardParagraph: '在预判主体会经过的位置提前对焦并锁定，使用连拍模式提高命中率。不要追逐主体，而是「守株待兔」。',
      tipCardImage: 'assets/images/academy/course_06_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'camera', name: '摆拍', desc: '可控性强，但容易失真、缺乏故事感。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'camera', name: '抓拍', desc: '真实自然，捕捉瞬间情绪，故事感强。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '街拍决定性瞬间练习',
      practiceParagraph: '在人流较多的街头选好背景，提前构图对焦，等待一个有趣的主体进入画面时按下快门。',
      practiceTags: [
        PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
        PracticeTag(iconName: 'camera', label: '抓拍', color: 'green'),
        PracticeTag(iconName: 'camera', label: '瞬间', color: 'red'),
      ],
      tips: ['提前设定好曝光和对焦，反应更快', '使用连拍模式，从中挑选最佳瞬间', '保持低调，不打扰被摄者'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/street_bw.jpg',
        name: '黑白街拍', desc: '用「黑白街拍」练习决定性瞬间', badge: '免费',
      ),
      knowledgeCardIds: ['kc_07'],
      assignment: AcademyAssignment(
        id: 'asg_06', courseId: 'course_06',
        title: '街拍决定性瞬间练习',
        description: '在街头捕捉一张决定性瞬间照片，体现人物、姿态与环境的完美结合。',
        requirements: ['捕捉到关键瞬间', '构图完整', '故事感强'],
        rewardXP: 100,
      ),
    ),
    'course_07': AcademyCourseDetail(
      course: courses[6],
      heroImage: 'assets/images/academy/course_07_cover.jpg',
      sections: [
        LessonSection(title: '什么是伦勃朗光', paragraphs: [
          '伦勃朗光得名于荷兰画家伦勃朗，特点是脸部一侧受光、另一侧形成三角形光斑。这种布光方式能让面部产生强烈的明暗对比，营造出戏剧性和立体感。',
          '伦勃朗光的核心是光源位于人物的侧前方约 45 度角，高于头顶，光线向下投射。在受光面颊上会形成一个倒三角形光斑。',
        ]),
        LessonSection(title: '如何实现伦勃朗光', paragraphs: ['自然光和人造光都可以实现伦勃朗光：']),
        LessonSection(title: '注意事项', paragraphs: []),
      ],
      tipCardTitle: '窗光伦勃朗',
      tipCardParagraph: '让模特侧对窗户（45度角），窗户光线从斜上方投射。调整模特位置直到暗面出现三角形光斑。使用白色反光板微微补光暗部。',
      tipCardImage: 'assets/images/academy/course_07_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'sun', name: '自然光', desc: '利用窗户侧光，成本低、光线柔和自然。', tagText: '推荐', tagColor: 'green'),
        CompareCell(iconName: 'lightbulb', name: '人造光', desc: '使用LED灯精确控制角度和强度，适合室内棚拍。', tagText: '专业', tagColor: 'gold'),
      ],
      practiceTitle: '伦勃朗光实战',
      practiceParagraph: '在窗边让模特侧坐，调整位置观察面部三角形光斑，拍摄3张不同曝光的伦勃朗光人像。',
      practiceTags: [
        PracticeTag(iconName: 'sun', label: '窗光', color: 'green'),
        PracticeTag(iconName: 'face', label: '人像', color: 'gold'),
        PracticeTag(iconName: 'lightbulb', label: '侧光', color: 'red'),
      ],
      tips: ['光源角度约45度，高于头顶', '暗面三角形光斑是标志', '不要过度补光，保留明暗对比'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/elegant_lady_portrait_1.jpg',
        name: '知性优雅轻熟女', desc: '用「知性优雅轻熟女」练习伦勃朗光', badge: '付费',
      ),
      knowledgeCardIds: ['kc_01', 'kc_02'],
      assignment: AcademyAssignment(
        id: 'asg_07', courseId: 'course_07',
        title: '伦勃朗光人像',
        description: '利用窗光拍摄一张伦勃朗光人像照片，确保暗面出现三角形光斑。',
        requirements: ['侧光45度角', '面部三角形光斑', '保留明暗对比'],
        rewardXP: 150,
      ),
    ),
    'course_08': AcademyCourseDetail(
      course: courses[7],
      heroImage: 'assets/images/academy/course_08_cover.jpg',
      sections: [
        LessonSection(title: '情绪与表情', paragraphs: [
          '一张好的人像不只是「拍清楚一张脸」，更要传递情绪。情绪通过表情、姿态、眼神、环境共同营造。',
          '不要让模特僵硬地「笑一下」，而是通过引导让真实情绪自然流露。一句话、一段音乐、一个回忆，都可能成为情绪的开关。',
        ]),
        LessonSection(title: '眼神的力量', paragraphs: ['眼神是人像照片的灵魂：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '环境与情绪',
      tipCardParagraph: '选择与情绪匹配的环境：沉思适合空旷的窗边，欢快适合色彩明亮的街道，忧郁适合雨后或黄昏。环境是情绪的放大器。',
      tipCardImage: 'assets/images/academy/course_08_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'face', name: '微笑', desc: '明亮、亲和，适合日常记录和清新风格。', tagText: '常见', tagColor: 'gold'),
        CompareCell(iconName: 'face', name: '沉思', desc: '深邃、有故事感，适合情绪人像和艺术创作。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '情绪人像练习',
      practiceParagraph: '让模特在窗边沉思或回望，通过引导让情绪自然流露，拍摄 3 张不同情绪的人像照片。',
      practiceTags: [
        PracticeTag(iconName: 'face', label: '情绪', color: 'green'),
        PracticeTag(iconName: 'face', label: '人像', color: 'gold'),
        PracticeTag(iconName: 'face', label: '眼神', color: 'red'),
      ],
      tips: ['不要直说「笑一下」，用故事和情境引导情绪', '眼神方向决定情绪走向：直视强烈、侧望含蓄', '给模特一个动作（如整理头发），更易抓到自然瞬间'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/french_lazy_portrait.jpg',
        name: '法式慵懒高雅', desc: '用「法式慵懒高雅」练习情绪表达', badge: '付费',
      ),
      knowledgeCardIds: ['kc_01'],
      assignment: AcademyAssignment(
        id: 'asg_08', courseId: 'course_08',
        title: '情绪人像练习',
        description: '拍摄一张能传递明确情绪的人像照片，注意眼神和环境的配合。',
        requirements: ['情绪表达清晰', '眼神有故事感', '环境与情绪匹配'],
        rewardXP: 150,
      ),
    ),
    'course_09': AcademyCourseDetail(
      course: courses[8],
      heroImage: 'assets/images/academy/course_09_cover.jpg',
      sections: [
        LessonSection(title: '引导线的类型', paragraphs: [
          '引导线是画面中能将观者视线引向主体的线条元素，可以是实际的线（道路、河流、栏杆），也可以是隐含的线（视线、阴影、色彩边界）。',
          '善用引导线能让照片产生纵深感和方向感，让观者的视线自然落到主体上，是风光摄影的核心技巧之一。',
        ]),
        LessonSection(title: '汇聚线与透视', paragraphs: ['汇聚线是引导线中最有冲击力的一种：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '多重引导线',
      tipCardParagraph: '当画面中存在多条引导线（如铁轨、走廊、桥梁）共同指向主体时，视觉冲击力会成倍增强，观者很难移开视线。',
      tipCardImage: 'assets/images/academy/course_09_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'arrows_left_right', name: '无引导线', desc: '主体孤立，视线游离，画面平淡。', tagText: '不推荐', tagColor: 'red'),
        CompareCell(iconName: 'arrows_left_right', name: '有引导线', desc: '视线被自然引向主体，纵深感强。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '引导线风光练习',
      practiceParagraph: '寻找一处有明显线条的场景（如道路、桥梁、长廊），将主体放在线条汇聚处拍摄，感受引导线带来的纵深感。',
      practiceTags: [
        PracticeTag(iconName: 'arrows_left_right', label: '构图', color: 'green'),
        PracticeTag(iconName: 'arrows_left_right', label: '引导线', color: 'gold'),
        PracticeTag(iconName: 'arrows_left_right', label: '透视', color: 'red'),
      ],
      tips: ['低角度拍摄能强化引导线的透视感', '汇聚点（消失点）最好落在趣味中心', '注意线条不要从画面角落斜出，会显得突兀'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/night_cityscape.jpg',
        name: '夜景城市', desc: '用「夜景城市」练习引导线', badge: '免费',
      ),
      knowledgeCardIds: ['kc_03', 'kc_04'],
      assignment: AcademyAssignment(
        id: 'asg_09', courseId: 'course_09',
        title: '引导线风光练习',
        description: '拍摄一张运用引导线构图的风光照片，线条应自然指向画面主体。',
        requirements: ['明确的引导线', '线条指向主体', '纵深感强烈'],
        rewardXP: 150,
      ),
    ),
    'course_10': AcademyCourseDetail(
      course: courses[9],
      heroImage: 'assets/images/academy/course_10_cover.jpg',
      sections: [
        LessonSection(title: '三点布光法', paragraphs: [
          '三点布光是摄影棚最经典的布光方案，由主光、辅光和轮廓光三盏灯组成，能精准控制物体的立体感、层次和氛围。',
          '主光负责塑造形状和明暗，辅光负责补充暗部细节，轮廓光负责把物体从背景中分离出来，三者协同打造专业质感。',
        ]),
        LessonSection(title: '主光与辅光', paragraphs: ['主辅光的配比决定画面氛围：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '单灯布光',
      tipCardParagraph: '没有三盏灯也能拍出好照片。一盏主灯配合白卡纸反光，就能实现接近三点布光的效果，适合家庭静物摄影入门。',
      tipCardImage: 'assets/images/academy/course_10_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'lightbulb', name: '平光', desc: '左右两侧均匀打光，物体平面化，适合证件照。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'lightbulb', name: '立体光', desc: '主辅光有光比，明暗过渡自然，立体感强。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '三点布光静物练习',
      practiceParagraph: '使用一盏台灯作主光、白纸作辅光反射、再加一盏小灯作轮廓光，拍摄一组静物，体会光比变化。',
      practiceTags: [
        PracticeTag(iconName: 'lightbulb', label: '布光', color: 'green'),
        PracticeTag(iconName: 'image', label: '静物', color: 'gold'),
        PracticeTag(iconName: 'lightbulb', label: '主光', color: 'red'),
      ],
      tips: ['主辅光比建议 2:1 到 4:1，立体感与细节兼顾', '轮廓光从侧后方打来，勾勒物体边缘', '关闭环境光，单独控制每盏灯的效果'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/indoor_still_life.jpg',
        name: '室内静物', desc: '用「室内静物」练习布光', badge: '免费',
      ),
      knowledgeCardIds: ['kc_05'],
      assignment: AcademyAssignment(
        id: 'asg_10', courseId: 'course_10',
        title: '三点布光静物练习',
        description: '使用三点布光法拍摄一张静物照片，体现主光、辅光与轮廓光的协同效果。',
        requirements: ['三点布光结构', '主辅光比合理', '物体轮廓清晰'],
        rewardXP: 150,
      ),
    ),
    'course_11': AcademyCourseDetail(
      course: courses[10],
      heroImage: 'assets/images/academy/course_11_cover.jpg',
      sections: [
        LessonSection(title: '色彩三要素', paragraphs: [
          '色彩的三要素是色相、明度和饱和度。色相决定「是什么颜色」，明度决定「多亮」，饱和度决定「多鲜艳」。',
          '理解三要素后，你就能精准控制画面的色彩表达，而不是被动接受环境的颜色。',
        ]),
        LessonSection(title: '互补与同类色', paragraphs: ['两种核心配色思路：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '莫兰迪色系',
      tipCardParagraph: '莫兰迪色系以低饱和、灰调为特点，色彩之间互相调和，营造出高级、内敛、宁静的氛围，是静物摄影最常用的色系之一。',
      tipCardImage: 'assets/images/academy/course_11_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'image', name: '高饱和', desc: '色彩鲜艳，视觉冲击强，但容易显得廉价。', tagText: '慎用', tagColor: 'red'),
        CompareCell(iconName: 'image', name: '低饱和', desc: '色彩柔和耐看，氛围高级，适合静物与人像。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '色彩搭配静物练习',
      practiceParagraph: '选择 3-4 件色彩协调的物品（如咖啡、书本、花瓶），用同类色或莫兰迪色系搭配，拍摄一组高级感静物。',
      practiceTags: [
        PracticeTag(iconName: 'image', label: '色彩', color: 'green'),
        PracticeTag(iconName: 'image', label: '搭配', color: 'gold'),
        PracticeTag(iconName: 'image', label: '莫兰迪', color: 'red'),
      ],
      tips: ['画面色彩控制在 3-4 种以内，避免杂乱', '互补色搭配时降低饱和度，避免刺眼', '背景色与主体色拉开明度差，主体更突出'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/morandi_minimal_portrait.jpg',
        name: '莫兰迪高级冷淡', desc: '用「莫兰迪高级冷淡」练习色彩', badge: '付费',
      ),
      knowledgeCardIds: ['kc_06'],
      assignment: AcademyAssignment(
        id: 'asg_11', courseId: 'course_11',
        title: '色彩搭配静物练习',
        description: '拍摄一组色彩搭配协调的静物照片，运用互补色或同类色原理。',
        requirements: ['配色协调统一', '色彩数量 3-4 种', '色彩层次分明'],
        rewardXP: 150,
      ),
    ),
    'course_12': AcademyCourseDetail(
      course: courses[11],
      heroImage: 'assets/images/academy/course_12_cover.jpg',
      sections: [
        LessonSection(title: '光影的戏剧性', paragraphs: [
          '街头摄影的灵魂在于光影。城市中随处可见的光影交界——树荫、廊道、楼缝、雨后水洼——都是天然的剧场。',
          '掌握光影的捕捉，能让一张普通街景瞬间充满戏剧感和叙事张力。',
        ]),
        LessonSection(title: '明暗对比', paragraphs: ['明暗对比是街拍最有效的视觉工具：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '隧道光',
      tipCardParagraph: '当阳光穿过两栋楼之间的缝隙形成「光带」时，等待行人走入光带拍摄，主体被强光打亮、四周隐入暗影，戏剧感拉满。',
      tipCardImage: 'assets/images/academy/course_12_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'sun', name: '柔光', desc: '阴天或散射光，过渡柔和，适合纪实叙事。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'sun', name: '硬光', desc: '直射阳光，明暗分明，戏剧感强。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '街头光影练习',
      practiceParagraph: '在城市中寻找一处光影交界处（如树荫边缘、楼缝光带），等待行人走入光区时按下快门，捕捉明暗对比。',
      practiceTags: [
        PracticeTag(iconName: 'sun', label: '光影', color: 'green'),
        PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '对比', color: 'red'),
      ],
      tips: ['降低曝光补偿，让暗部更黑、亮部更亮', '蹲下低角度拍摄，光影对比更强烈', '善用雨后水洼的反光，画面更丰富'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/neon_city_portrait.jpg',
        name: '夜景霓虹人像', desc: '用「夜景霓虹人像」练习光影', badge: '付费',
      ),
      knowledgeCardIds: ['kc_07', 'kc_08'],
      assignment: AcademyAssignment(
        id: 'asg_12', courseId: 'course_12',
        title: '街头光影练习',
        description: '拍摄一张体现明暗对比的街拍照片，主体位于光区，背景隐入暗影。',
        requirements: ['强烈的明暗对比', '主体在光区', '戏剧感强'],
        rewardXP: 150,
      ),
    ),
    'course_13': AcademyCourseDetail(
      course: courses[12],
      heroImage: 'assets/images/academy/course_13_cover.jpg',
      sections: [
        LessonSection(title: '什么是风格化', paragraphs: [
          '风格化人像不是简单地「加滤镜」，而是通过色调、构图、光线、姿态的综合设计，让照片呈现统一的视觉语言和个人辨识度。',
          '成熟的摄影师都有自己的风格签名：日系清新、港风复古、电影感、赛博朋克……风格是作品集的灵魂。',
        ]),
        LessonSection(title: '色调与情绪', paragraphs: ['色调是风格化最直接的表达：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '胶片色调',
      tipCardParagraph: '胶片色调的特点是低对比、偏黄绿、暗部发青，颗粒感明显。它能让数字照片瞬间拥有「时光感」，是复古风格人像的常用色调。',
      tipCardImage: 'assets/images/academy/course_13_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'image', name: '自然风格', desc: '色彩还原真实，适合纪实和商业记录。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'image', name: '风格化', desc: '色调统一有辨识度，适合艺术创作和个人作品。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '风格化人像练习',
      practiceParagraph: '选定一种风格（如港风、日系、电影感），从服装、场景、光线到后期色调全程统一设计，拍摄一组 3 张风格化人像。',
      practiceTags: [
        PracticeTag(iconName: 'image', label: '风格', color: 'green'),
        PracticeTag(iconName: 'face', label: '人像', color: 'gold'),
        PracticeTag(iconName: 'image', label: '色调', color: 'red'),
      ],
      tips: ['先确定风格，再选择服装、场景、道具', '色调统一比单张好看更重要，组照要有「家族感」', '后期色调可以参考电影截图或老照片'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/anime_dream_portrait.jpg',
        name: '动漫温柔青', desc: '用「动漫温柔青」练习风格化', badge: '付费',
      ),
      knowledgeCardIds: ['kc_01', 'kc_06'],
      assignment: AcademyAssignment(
        id: 'asg_13', courseId: 'course_13',
        title: '风格化人像练习',
        description: '拍摄一组（3 张）风格统一的人像照片，从色调、构图、光线综合体现个人风格。',
        requirements: ['统一的视觉风格', '色调与情绪匹配', '组照有家族感'],
        rewardXP: 200,
      ),
    ),
    'course_14': AcademyCourseDetail(
      course: courses[13],
      heroImage: 'assets/images/academy/course_14_cover.jpg',
      sections: [
        LessonSection(title: '为什么用黑白', paragraphs: [
          '黑白摄影剥离了色彩的干扰，让观者专注于形状、线条、光影和情绪。当色彩杂乱或不足以表达主题时，黑白往往是更好的选择。',
          '黑白不是「彩色失败后的退路」，而是一种主动的视觉语言。许多大师的传世之作都是黑白影像。',
        ]),
        LessonSection(title: '去色后的结构', paragraphs: ['转为黑白后，画面的结构会重新凸显：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '高反差黑白',
      tipCardParagraph: '高反差黑白能强化形状和光影，让画面更有力量感。压暗暗部、提亮亮部，但保留中间过渡，避免死黑或死白。',
      tipCardImage: 'assets/images/academy/course_14_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'image', name: '彩色', desc: '信息量大，色彩是主要表达手段。', tagText: '中性', tagColor: 'gold'),
        CompareCell(iconName: 'image', name: '黑白', desc: '剥离色彩，突出结构与光影，情绪更纯粹。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '黑白风光练习',
      practiceParagraph: '选择一处光影强烈的风光场景（如雪山、峡谷、沙漠），拍摄后转为黑白，调整反差突出形状和纹理。',
      practiceTags: [
        PracticeTag(iconName: 'image', label: '黑白', color: 'green'),
        PracticeTag(iconName: 'image', label: '风光', color: 'gold'),
        PracticeTag(iconName: 'image', label: '反差', color: 'red'),
      ],
      tips: ['拍摄时就想好要转黑白，构图关注形状和线条', '寻找强烈光影，黑白对明暗更敏感', '保留中间灰度，避免画面干涩'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/sunset_silhouette.jpg',
        name: '日落逆光剪影', desc: '用「日落逆光剪影」练习黑白风光', badge: '免费',
      ),
      knowledgeCardIds: ['kc_03', 'kc_04'],
      assignment: AcademyAssignment(
        id: 'asg_14', courseId: 'course_14',
        title: '黑白风光练习',
        description: '拍摄一张风光照片并转为黑白，通过反差和结构表达情绪。',
        requirements: ['黑白处理', '光影结构突出', '情绪表达纯粹'],
        rewardXP: 200,
      ),
    ),
    'course_15': AcademyCourseDetail(
      course: courses[14],
      heroImage: 'assets/images/academy/course_15_cover.jpg',
      sections: [
        LessonSection(title: '少即是多', paragraphs: [
          '极简摄影的核心理念是「做减法」——剔除一切与主题无关的元素，让画面只剩下最纯粹的主体和留白。',
          '极简不是「空」，而是「精准」。每一处留白、每一根线条都为强化主题而存在。',
        ]),
        LessonSection(title: '负空间', paragraphs: ['负空间是极简摄影的关键工具：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '单一主体',
      tipCardParagraph: '一张极简照片通常只有一个明确的主体，放在大片留白中。主体的「小」与留白的「大」形成对比，反而更突出。',
      tipCardImage: 'assets/images/academy/course_15_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'image', name: '复杂构图', desc: '元素多，信息量大，适合叙事但易杂乱。', tagText: '慎用', tagColor: 'red'),
        CompareCell(iconName: 'image', name: '极简构图', desc: '单一主体，大片留白，意境纯粹。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '极简静物练习',
      practiceParagraph: '选择一件日常物品（如一只杯子、一朵花），用大片留白背景拍摄，尝试 3 种不同的位置和比例。',
      practiceTags: [
        PracticeTag(iconName: 'image', label: '极简', color: 'green'),
        PracticeTag(iconName: 'image', label: '静物', color: 'gold'),
        PracticeTag(iconName: 'image', label: '留白', color: 'red'),
      ],
      tips: ['背景越简洁越好，纯色墙面或白纸即可', '主体放在三分之一处，留出呼吸空间', '去掉一切干扰元素，包括多余的颜色'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/macro_flower.jpg',
        name: '微距花卉', desc: '用「微距花卉」练习极简', badge: '免费',
      ),
      knowledgeCardIds: ['kc_05', 'kc_06'],
      assignment: AcademyAssignment(
        id: 'asg_15', courseId: 'course_15',
        title: '极简静物练习',
        description: '拍摄一张极简风格静物照片，单一主体搭配大片留白，色彩克制。',
        requirements: ['单一主体', '大片留白', '色彩克制'],
        rewardXP: 200,
      ),
    ),
    'course_16': AcademyCourseDetail(
      course: courses[15],
      heroImage: 'assets/images/academy/course_16_cover.jpg',
      sections: [
        LessonSection(title: '用照片讲故事', paragraphs: [
          '街头叙事不是单张抓拍，而是用一组照片讲述一个完整的故事——人物、环境、情绪、时间、冲突缺一不可。',
          '一张好照片是「句子」，一组好照片是「文章」。学会用组照思考，你的街拍会从「记录」升级为「表达」。',
        ]),
        LessonSection(title: '环境与人物', paragraphs: ['环境与人物是叙事的两大支柱：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '系列照片',
      tipCardParagraph: '一组叙事照片建议 5-8 张：1 张环境交代场景，2-3 张人物特写讲故事，1 张细节（手、物）补充信息，1 张远景收束情绪。',
      tipCardImage: 'assets/images/academy/course_16_cover.jpg',
      compareCells: [
        CompareCell(iconName: 'camera', name: '单张', desc: '瞬间即故事，适合社交媒体传播。', tagText: '常见', tagColor: 'gold'),
        CompareCell(iconName: 'camera', name: '系列', desc: '多张组合叙事，故事更完整有深度。', tagText: '推荐', tagColor: 'green'),
      ],
      practiceTitle: '街头叙事系列练习',
      practiceParagraph: '选择一个主题（如「清晨的菜市场」「雨夜归途」），用 5-8 张照片讲述一个完整的故事，注意景别和情绪节奏。',
      practiceTags: [
        PracticeTag(iconName: 'camera', label: '叙事', color: 'green'),
        PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
        PracticeTag(iconName: 'camera', label: '系列', color: 'red'),
      ],
      tips: ['先确定主题和故事线，再出门拍摄', '组照要有不同景别：远景、中景、特写', '开头和结尾照片最重要，决定整组的基调'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'assets/images/templates/hk_noir_portrait.jpg',
        name: '港风夜景人像', desc: '用「港风夜景人像」练习叙事', badge: '付费',
      ),
      knowledgeCardIds: ['kc_07', 'kc_08'],
      assignment: AcademyAssignment(
        id: 'asg_16', courseId: 'course_16',
        title: '街头叙事系列练习',
        description: '拍摄一组 5-8 张的街头叙事照片，讲述一个完整故事，注意景别和节奏。',
        requirements: ['5-8 张组照', '故事线完整', '景别丰富'],
        rewardXP: 200,
      ),
    ),
  };

  /// 获取课程详情
  static AcademyCourseDetail? getCourseDetail(String courseId) {
    return _courseDetails[courseId];
  }

  /// 获取课程作业
  static AcademyAssignment? getAssignment(String courseId) {
    return _courseDetails[courseId]?.assignment;
  }
}
