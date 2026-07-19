import 'package:flutter/material.dart';

import 'challenge_models.dart';

/// Challenge mock 数据
///
/// 来源：lumira-app/src/pages/challenge/index.vue 和 detail.vue 的硬编码字面量。
/// 未来 Task 2.x 接入 DAO 时替换为真实数据。
class ChallengeMockData {
  ChallengeMockData._();

  /// 主挑战
  static const mainChallenge = MainChallenge(
    title: '今日挑战已完成',
    description: '用模板拍一张人像照',
    rewardXP: 30,
    status: ChallengeStatus.done,
    coverImage: 'https://picsum.photos/seed/733872/400/600',
    tags: [
      ChallengeTag(label: '+30 XP', color: ChallengeTagColor.gold),
      ChallengeTag(label: '已完成', color: ChallengeTagColor.green, showCheckIcon: true),
    ],
  );

  /// 附加挑战列表
  static const subChallenges = <SubChallenge>[
    SubChallenge(
      id: 'sub_3_templates',
      title: '3个不同模板分别拍一张',
      icon: Icons.check_circle_outline,
      status: ChallengeStatus.done,
      progressCurrent: 3,
      progressTotal: 3,
      rewardXP: 15,
      tags: [ChallengeTag(label: '+15 XP', color: ChallengeTagColor.gold)],
    ),
    SubChallenge(
      id: 'sub_color_export',
      title: '拍一张照片完成调色并导出',
      icon: Icons.palette_outlined,
      status: ChallengeStatus.pending,
      progressCurrent: 0,
      progressTotal: 1,
      rewardXP: 20,
      tags: [
        ChallengeTag(label: '+20 XP', color: ChallengeTagColor.gold),
        ChallengeTag(label: '碎片机会', color: ChallengeTagColor.red),
      ],
    ),
  ];

  /// 明日预览
  static const tomorrowPreview = TomorrowPreview(
    mainTitle: '在日落时分拍一张剪影照',
    subTitles: [
      '附加挑战：使用「黄金时刻」模板',
      '附加挑战：完成一次胶片调色导出',
    ],
    locked: true,
  );

  /// 连续打卡
  static const streak = StreakInfo(
    currentStreak: 7,
    totalDays: 7,
    nextRewardXP: 50,
    tipMessage: '再坚持 1 天获得额外 50 XP',
  );

  /// 挑战详情（按 id 查找，当前 mock 只有一个详情）
  static const challengeDetail = ChallengeDetail(
    id: 'tpl_portrait_thirds',
    badge: '今日主挑战',
    title: '用三分法构图拍一张人像',
    description: '利用三分法构图，将人物置于画面三分之一处，配合自然光线拍摄，捕捉人物的生动瞬间。',
    rewardXP: 30,
    progressCurrent: 1,
    progressTotal: 1,
    status: ChallengeStatus.done,
    requirements: [
      Requirement(
        index: 1,
        title: '使用三分法构图',
        description: '将画面横竖各分三份，把主体放在交叉点或线上',
        done: true,
      ),
      Requirement(
        index: 2,
        title: '拍摄人像照片',
        description: '可以是自拍或他拍，人物为主体',
        done: true,
      ),
      Requirement(
        index: 3,
        title: '自然光线',
        description: '使用自然光拍摄，不使用闪光灯',
        done: true,
      ),
    ],
    tips: [
      Tip(
        icon: Icons.wb_sunny_outlined,
        iconColor: ChallengeTagColor.gold,
        title: '光线选择',
        description: '侧光或逆光拍摄，轮廓更立体',
      ),
      Tip(
        icon: Icons.crop_free,
        iconColor: ChallengeTagColor.green,
        title: '构图技巧',
        description: '开启相机网格线辅助构图',
      ),
      Tip(
        icon: Icons.camera_alt_outlined,
        iconColor: ChallengeTagColor.red,
        title: '推荐模板',
        description: '使用「自然光人像」模板效果更佳',
      ),
    ],
    completedWork: Work(
      imageUrl: 'https://picsum.photos/seed/challenge-work-1/600/800',
      date: '2026年7月10日',
      title: '午后窗边人像',
      tags: [
        ChallengeTag(label: '三分法', color: ChallengeTagColor.gold),
        ChallengeTag(label: '人像', color: ChallengeTagColor.green),
      ],
    ),
  );

  /// 根据 id 获取挑战详情（mock：永远返回 challengeDetail）
  static ChallengeDetail? getDetailById(String? id) {
    // mock 阶段忽略 id，永远返回同一个详情
    return challengeDetail;
  }
}
