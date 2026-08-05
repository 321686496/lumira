/// 系统内置头像池与昵称池（与后端 profile-constants.ts 保持一致）
class BuiltinProfiles {
  BuiltinProfiles._();

  /// 内置头像 seed 池（8 个）
  static const List<String> avatarSeeds = [
    'lumira-avatar-01', 'lumira-avatar-02', 'lumira-avatar-03', 'lumira-avatar-04',
    'lumira-avatar-05', 'lumira-avatar-06', 'lumira-avatar-07', 'lumira-avatar-08',
  ];

  /// 内置昵称池（24 个中文诗意昵称）
  static const List<String> usernames = [
    '追光的小鹿', '胶片旅人', '云边记录者', '晚风摄影师',
    '拾光少女', '光影漫游者', '春日快门', '银河捕手',
    '晨雾漫游', '暮色收藏家', '窗边诗人', '胶片收藏家',
    '星野旅人', '海盐汽水', '青柠快门', '山间清风',
    '雨后晴天', '微光日记', '星河漫游者', '温柔捕光者',
    '麦田守望者', '旧巷拾影', '月亮邮差', '森林呼吸',
  ];

  /// 根据 seed 拼出头像 URL
  static String avatarUrl(String seed) =>
      'https://picsum.photos/seed/$seed/200/200';
}
