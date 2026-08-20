/// 问卷题型
enum QuestionType { single, multi }

/// 问卷选项
class QuestionOption {
  final String key;
  final String label;
  const QuestionOption(this.key, this.label);
}

/// 问卷题目定义
class QuestionDef {
  final String id;
  final String title;
  final String? subtitle;
  final QuestionType type;
  final List<QuestionOption> options;

  const QuestionDef({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.options,
  });
}

/// 8 道问卷题目（文案集中此文件，便于未来抽 i18n）
const List<QuestionDef> kQuestionnaireQuestions = [
  QuestionDef(
    id: 'gender',
    title: '你的性别？',
    type: QuestionType.single,
    options: [
      QuestionOption('male', '男'),
      QuestionOption('female', '女'),
      QuestionOption('prefer_not', '不方便透露'),
    ],
  ),
  QuestionDef(
    id: 'source',
    title: '你从哪里知道 Lumira？',
    type: QuestionType.single,
    options: [
      QuestionOption('app_store', '应用商店'),
      QuestionOption('social_media', '社交媒体'),
      QuestionOption('friend', '朋友推荐'),
      QuestionOption('search', '搜索引擎'),
      QuestionOption('article', '文章博客'),
      QuestionOption('other', '其他'),
    ],
  ),
  QuestionDef(
    id: 'favorite_categories',
    title: '你喜欢拍什么？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('portrait', '人像'),
      QuestionOption('landscape', '风光'),
      QuestionOption('food', '美食'),
      QuestionOption('street', '街拍'),
      QuestionOption('night', '夜景'),
      QuestionOption('macro', '微距'),
      QuestionOption('still-life', '静物'),
    ],
  ),
  QuestionDef(
    id: 'pain_points',
    title: '拍摄中你有哪些烦恼？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('composition', '构图困难'),
      QuestionOption('lighting', '光线处理'),
      QuestionOption('posing', '摆姿不自然'),
      QuestionOption('camera_settings', '参数设置'),
      QuestionOption('post_processing', '后期修图'),
      QuestionOption('no_subject', '找不到拍摄对象'),
      QuestionOption('no_time', '没时间拍'),
    ],
  ),
  QuestionDef(
    id: 'skill_level',
    title: '你的摄影水平？',
    type: QuestionType.single,
    options: [
      QuestionOption('beginner', '新手'),
      QuestionOption('intermediate', '进阶'),
      QuestionOption('advanced', '高级'),
      QuestionOption('pro', '专业'),
    ],
  ),
  QuestionDef(
    id: 'expectations',
    title: '你希望从 Lumira 获得？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('learn_photo', '学摄影'),
      QuestionOption('inspiration', '找灵感'),
      QuestionOption('better_composition', '提升构图'),
      QuestionOption('master_camera', '玩转相机'),
      QuestionOption('share_works', '分享作品'),
      QuestionOption('record_life', '记录生活'),
    ],
  ),
  QuestionDef(
    id: 'common_scenes',
    title: '你常在哪些场景拍摄？',
    subtitle: '可多选',
    type: QuestionType.multi,
    options: [
      QuestionOption('indoor_home', '家中'),
      QuestionOption('cafe', '咖啡馆'),
      QuestionOption('outdoor_park', '户外公园'),
      QuestionOption('street', '街头'),
      QuestionOption('travel', '旅行'),
      QuestionOption('office', '办公室'),
      QuestionOption('studio', '影棚'),
    ],
  ),
  QuestionDef(
    id: 'shoot_frequency',
    title: '你的拍摄频率？',
    type: QuestionType.single,
    options: [
      QuestionOption('rarely', '偶尔'),
      QuestionOption('monthly', '每月'),
      QuestionOption('weekly', '每周'),
      QuestionOption('daily', '每天'),
    ],
  ),
];
