// 一次性工具脚本：将「同模板不同姿势」的内置模板变体合并进主模板文件，
// 删除冗余变体文件，并同步更新 index.dart。
// 运行：cd lumira_app_flutter && dart run tool/merge_template_variants.dart
import 'dart:io';

const templatesDir = 'lib/features/capture/data/templates';
const registryPath = 'lib/features/capture/data/template_registry.dart';
const indexPath = 'lib/features/capture/data/templates/index.dart';

class Member {
  final String id;
  final String file;
  final String tplVar;
  final String type;
  final String majorStyle;
  final String style;
  final String cover;
  final String poseInner; // Pose(...) 内部文本
  Member({
    required this.id,
    required this.file,
    required this.tplVar,
    required this.type,
    required this.majorStyle,
    required this.style,
    required this.cover,
    required this.poseInner,
  });

  String get suiteKey => isPortrait
      ? '$type|$majorStyle|$style'
      : '$type|$style|$id';
  bool get isPortrait => type == 'portrait';
}

int _findClose(List<String> src, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < src.length; i++) {
    final c = src[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _q(String s) =>
    "'" + s.replaceAll(r'\', r'\\').replaceAll("'", r"\'") + "'";

String _indent(String s, int spaces) {
  final pad = ' ' * spaces;
  return s.split('\n').map((l) => l.isEmpty ? l : pad + l).join('\n');
}

void main() {
  final dir = Directory(templatesDir);
  final files = dir.listSync().whereType<File>()
      .where((f) => f.path.endsWith('.dart')).toList();

  final registryText = File(registryPath).readAsStringSync();
  final idOrder = <String>[
    ...RegExp(r"'([a-z_0-9]+)':\s*\w+Template")
        .allMatches(registryText)
        .map((m) => m.group(1)!),
  ];
  final registryPos = <String, int>{};
  for (var i = 0; i < idOrder.length; i++) {
    registryPos[idOrder[i]] = i;
  }

  final members = <String, Member>{};
  for (final f in files) {
    final text = f.readAsStringSync();
    final id = RegExp(r"id: '([a-z_0-9]+)'").firstMatch(text)?.group(1);
    if (id == null) {
      stderr.writeln('SKIP (no id): ${f.path}');
      continue;
    }
    final tplVar = RegExp(r'const PhotoTemplate (\w+)Template =')
        .firstMatch(text)?.group(1);
    final type = RegExp(r"type: '([a-z_0-9]+)'").firstMatch(text)?.group(1) ?? '';
    final majorStyle =
        RegExp(r"majorStyle: '([a-z_0-9]+)'").firstMatch(text)?.group(1) ?? '';
    final style = RegExp(r"style: '([a-z_0-9]+)'").firstMatch(text)?.group(1) ?? '';
    final cover = RegExp(r"cover: '([^']+)'").firstMatch(text)?.group(1) ?? '';

    final poseKw = 'pose: Pose(';
    final poseIdx = text.indexOf(poseKw);
    String poseInner = '';
    if (poseIdx >= 0) {
      final openIdx = text.indexOf('(', poseIdx);
      final closeIdx =
          _findClose(text.split(''), openIdx);
      poseInner = text.substring(openIdx + 1, closeIdx);
    }
    members[id] = Member(
      id: id,
      file: f.path,
      tplVar: tplVar ?? '${id}Template',
      type: type,
      majorStyle: majorStyle,
      style: style,
      cover: cover,
      poseInner: poseInner,
    );
  }

  final groups = <String, List<String>>{};
  for (final id in members.keys) {
    groups.putIfAbsent(members[id]!.suiteKey, () => []).add(id);
  }
  final multiMember = groups.values
      .where((g) => g.length > 1 && members[g.first]!.isPortrait)
      .toList();
  for (final g in multiMember) {
    g.sort(
        (a, b) => (registryPos[a] ?? 999999).compareTo(registryPos[b] ?? 999999));
  }

  final deletedFiles = <String>[];
  final deletedIds = <String>[];

  for (final group in multiMember) {
    final main = members[group.first]!;
    final variants = group.skip(1);

    // 合并 images（去重 url）
    final urls = <String>[];
    void addUrl(String u) {
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }
    for (final id in group) {
      addUrl(members[id]!.cover);
    }

    // 合并 poses（每个元素带尾逗号，元素间换行即可正确分隔）
    final poses = <String>[];
    for (final id in group) {
      final m = members[id]!;
      if (m.poseInner.isEmpty) continue;
      poses.add('    Pose(\n${_indent(m.poseInner.trim(), 6)}\n    ),');
    }

    var out = File(main.file).readAsStringSync();

    // 1) meta cover → images（Dart RegExp 无 replaceFirstMapped，改用 firstMatch + replaceRange）
    final coverRe = RegExp(r"(\n\s*)cover: '[^']*',");
    final coverMatch = coverRe.firstMatch(out);
    if (coverMatch != null) {
      final indent = coverMatch.group(1)!; // 形如 "\n    "（换行 + 4 空格）
      final buf = StringBuffer('${indent}images: [');
      for (final u in urls) {
        buf.write('\n${indent}  TemplateImage(url: ${_q(u)}),');
      }
      buf.write('\n${indent}],');
      out = out.replaceRange(
          coverMatch.start, coverMatch.end, buf.toString());
    } else {
      stderr.writeln('WARN: main ${main.id} has no cover block, skipped images merge');
    }

    // 2) pose 参数 → poses 列表（在更新后的文本上重新定位）
    //    posesBlock 结尾不带逗号，由原 `pose: Pose(...),` 的收尾逗号补齐，
    //    避免 `],,` 双逗号。
    final poseKw = 'pose: Pose(';
    final poseIdx = out.indexOf(poseKw);
    if (poseIdx >= 0) {
      final openIdx = out.indexOf('(', poseIdx);
      final closeIdx = _findClose(out.split(''), openIdx);
      final posesBlock = <String>['  poses: [', ...poses, '  ]'].join('\n');
      out = out.substring(0, poseIdx) + posesBlock + out.substring(closeIdx + 1);
    } else {
      stderr.writeln('WARN: main ${main.id} has no pose block, skipped');
    }

    File(main.file).writeAsStringSync(out);
    stdout.writeln('MERGED -> ${main.file} poses=${poses.length} images=${urls.length}');

    for (final id in variants) {
      deletedFiles.add(members[id]!.file);
      deletedIds.add(id);
      stdout.writeln('DELETE  ${members[id]!.file}');
    }
  }

  // 更新 index.dart：移除已删除文件的 export，保留注释及其它行
  {
    final src = File(indexPath).readAsStringSync();
    final delSet =
        deletedFiles.map((p) => p.split(Platform.pathSeparator).last).toSet();
    final lines = src.split('\n').where((l) {
      final m = RegExp(r"export '([a-z_0-9]+)\.dart';").firstMatch(l);
      if (m == null) return true;
      return !delSet.contains('${m.group(1)}.dart');
    });
    File(indexPath).writeAsStringSync(lines.join('\n'));
  }

  // 删除变体文件
  for (final f in deletedFiles) {
    File(f).deleteSync();
  }

  // ===== 重新生成 template_registry.dart =====
  // 移除运行时归并（_buildSuitesById/_mergeSuite），改为直接在 _templates 中：
  // 变体 id → 所属主模板常量（主模板数据文件已继承多姿势/多图）。
  // 保持 id 顺序与 getTemplate / allTemplates 行为不变。
  {
    // group 成员 → 主模板（在 registry 顺序中最靠前者）
    final mainBySuite = <String, String>{};
    for (final members2 in groups.values) {
      if (members2.length <= 1) {
        mainBySuite[members2.first] = members2.first;
        continue;
      }
      final sorted = [...members2]..sort((a, b) =>
          (registryPos[a] ?? 999999).compareTo(registryPos[b] ?? 999999));
      final mainId = sorted.first;
      for (final id in members2) {
        mainBySuite[id] = mainId;
      }
    }

    final lines = <String>[];
    lines.add('// lib/features/capture/data/template_registry.dart');
    lines.add("import '../domain/photo_template.dart';");
    lines.add("import 'templates/index.dart';");
    lines.add('');
    lines.add('class TemplateRegistry {');
    lines.add('  TemplateRegistry._();');
    lines.add('');
    lines.add('  /// 内置模板表：id → PhotoTemplate。');
    lines.add('  ///');
    lines.add('  /// 「同模板不同姿势」已按分类在数据文件层面合并为多姿势/多图主模板，');
    lines.add('  /// 不再于运行时归并（历史版本曾用 _mergeSuite 在 getTemplate 时合并）。');
    lines.add('  /// 变体 id（如 blue_night_wide）作为别名指向所属主模板常量，');
    lines.add('  /// 保证历史缓存/收藏中的旧 id 仍可通过 getTemplate 解析。');
    lines.add('  static const Map<String, PhotoTemplate> _templates = {');
    for (final id in idOrder) {
      final mainId = mainBySuite[id] ?? id;
      final varName = (members[mainId]?.tplVar ?? _camel(id)) + 'Template';
      lines.add("    '$id': $varName,");
    }
    lines.add('  };');
    lines.add('');
    lines.add('  static PhotoTemplate? getTemplate(String id) {');
    lines.add('    final tpl = _templates[id];');
    lines.add('    if (tpl == null) return null;');
    lines.add('    return tpl.copyWith();');
    lines.add('  }');
    lines.add('');
    lines.add('  /// 去重后的全部内置模板（每个分类主模板只占一项）。');
    lines.add('  static List<PhotoTemplate> get allTemplates =>');
    lines.add('      _templates.values.toSet().map((t) => t.copyWith()).toList();');
    lines.add('');
    lines.add('  static List<PhotoTemplate> getRecentTemplates(int count) =>');
    lines.add('      allTemplates.take(count).toList();');
    lines.add('}');
    lines.add('');
    File(registryPath).writeAsStringSync(lines.join('\n'));
    stdout.writeln('REGENERATED $registryPath');
  }

  stdout.writeln('\nTotal multi-member suites handled: ${multiMember.length}');
  stdout.writeln(
      'Deleted variant ids (${deletedIds.length}): ${deletedIds.join(', ')}');
  stdout.writeln(
      'Remaining template files: ${dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).length}');
}

String _camel(String id) {
  final parts = id.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}