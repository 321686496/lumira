/// 搜索范围（scope）。
/// all=全部（跨三类混合）、template=模板、scene=场景、academy=美学院。
enum SearchScope { all, template, scene, academy }

extension SearchScopeExt on SearchScope {
  String get name => toString().split('.').last;

  String get label {
    switch (this) {
      case SearchScope.all:
        return '全部';
      case SearchScope.template:
        return '模板';
      case SearchScope.scene:
        return '场景';
      case SearchScope.academy:
        return '美学院';
    }
  }

  static SearchScope fromName(String? s) {
    for (final v in SearchScope.values) {
      if (v.name == s) return v;
    }
    return SearchScope.all;
  }

  /// 可被搜索的具体内容 scope（不含 all）。
  static const List<SearchScope> searchableScopes = [
    SearchScope.template,
    SearchScope.scene,
    SearchScope.academy,
  ];
}

/// 预置热门词（子项目 B 云端热搜就绪前的本地兜底）。
/// 与自身高频历史取并集后展示。
const Map<SearchScope, List<String>> kPresetHotWords = {
  SearchScope.all: ['人像', '构图', '复古', '窗光', '夜景', '日系'],
  SearchScope.template: ['人像', '复古', '日系', '夜景', '电影感', '美食', '微距', '静物'],
  SearchScope.scene: ['窗光', '逆光', '街拍', '咖啡馆', '日落', '街头'],
  SearchScope.academy: ['构图', '布光', '人像', '风光', '静物', '街头'],
};
