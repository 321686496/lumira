import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/questionnaire_answers.dart';
import '../data/questionnaire_data.dart';
import '../services/questionnaire_sync_providers.dart';
import 'widgets/progress_indicator.dart';
import 'widgets/question_step.dart';

/// 新用户问卷页（多步向导）
///
/// 7 题分步展示，每题可跳过，整体可跳过。
/// 从 splash 进入：提交后跳 home
/// 从设置页进入：提交后 pop 返回设置页
class QuestionnairePage extends ConsumerStatefulWidget {
  final bool fromSettings;

  const QuestionnairePage({super.key, this.fromSettings = false});

  @override
  ConsumerState<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends ConsumerState<QuestionnairePage> {
  int _currentStep = 0;
  final Map<String, Set<String>> _answers = {
    for (final q in kQuestionnaireQuestions) q.id: <String>{}
  };
  bool _submitting = false;
  /// 分级题的二级风格分组缓存（按已选大类签名失效重取）
  String _lastStyleSig = '';
  Future<List<StyleSection>>? _styleFuture;

  bool get _isLast => _currentStep == kQuestionnaireQuestions.length - 1;

  QuestionDef get _currentQuestion => kQuestionnaireQuestions[_currentStep];

  /// favorite_categories 题的类名映射，用于分级题的区段标题
  List<QuestionOption> get _categoryOptions => kQuestionnaireQuestions
      .firstWhere((q) => q.id == 'favorite_categories',
          orElse: () => const QuestionDef(id: '', title: '', type: QuestionType.multi, options: []))
      .options;

  Future<void> _toggleOption(String key) async {
    final currentId = _currentQuestion.id;
    final selected = _answers[currentId]!;
    final isSingle = _currentQuestion.type == QuestionType.single;
    // 取消「大类」时，一并清掉其下已选的二级风格
    final isUncheckCategory =
        currentId == 'favorite_categories' && selected.contains(key);
    if (isUncheckCategory) {
      try {
        final dao = await ref.read(templatesDaoProvider.future);
        final styles = await dao.getStylesForType(key);
        final styleKeys = styles.map((s) => s.key).toSet();
        _answers['favorite_styles']!
            .removeWhere((styleKey) => styleKeys.contains(styleKey));
      } catch (_) {
        // 读取失败则只移除大类本身，风格保留
      }
    }
    if (!mounted) return;
    setState(() {
      if (isSingle) {
        selected
          ..clear()
          ..add(key);
      } else {
        if (selected.contains(key)) {
          selected.remove(key);
        } else {
          selected.add(key);
        }
      }
    });
    // 单选题：选中后自动进入下一题（带延迟）
    if (isSingle) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _next();
      });
    }
  }

  /// 已选大类的签名，用于判断是否需要重取风格分组
  String _styleSig() {
    final cats = (_answers['favorite_categories'] ?? <String>{}).toList()..sort();
    return cats.join(',');
  }

  /// 异步构建「大类 → 二级风格」分组
  Future<List<StyleSection>> _buildStyleSections() async {
    final cats = (_answers['favorite_categories'] ?? <String>{}).toList();
    final sections = <StyleSection>[];
    if (cats.isEmpty) return sections;
    final labelOf = {for (final o in _categoryOptions) o.key: o.label};
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      for (final c in cats) {
        final styles =
            (await dao.getStylesForType(c)).where((s) => s.isActive).toList();
        if (styles.isEmpty) continue;
        sections.add(StyleSection(
          labelOf[c] ?? c,
          styles
              .map((s) => QuestionOption(s.key, s.name))
              .toList(growable: false),
        ));
      }
    } catch (_) {
      // 分类数据未就绪时给出空分组，页面显示提示而非崩溃
    }
    return sections;
  }

  void _next() {
    if (_isLast) {
      _submit();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _skipAll() {
    _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final answers = QuestionnaireAnswers(
      gender: _answers['gender']?.isEmpty == true
          ? null
          : _answers['gender']?.first,
      source: _answers['source']?.isEmpty == true
          ? null
          : _answers['source']?.first,
      favoriteCategories: _answers['favorite_categories']?.toList() ?? [],
      favoriteStyles: _answers['favorite_styles']?.toList() ?? [],
      painPoints: _answers['pain_points']?.toList() ?? [],
      skillLevel: _answers['skill_level']?.isEmpty == true
          ? null
          : _answers['skill_level']?.first,
      expectations: _answers['expectations']?.toList() ?? [],
      commonScenes: _answers['common_scenes']?.toList() ?? [],
      shootFrequency: _answers['shoot_frequency']?.isEmpty == true
          ? null
          : _answers['shoot_frequency']?.first,
    );

    try {
      final syncService =
          await ref.read(questionnaireSyncServiceProvider.future);
      await syncService.submit(answers);
    } catch (_) {
      // 同步失败不阻塞跳转（本地已落库）
    }

    final current = await ref.read(profileDataProvider.future);
    if (current != null) {
      final updated = current.copyWith(
        gender: answers.gender,
        favoriteCategories: answers.favoriteCategories.isNotEmpty
            ? answers.favoriteCategories
            : current.favoriteCategories,
        painPoints: answers.painPoints.isNotEmpty
            ? answers.painPoints
            : current.painPoints,
        skillLevel: answers.skillLevel,
        expectations: answers.expectations.isNotEmpty
            ? answers.expectations
            : current.expectations,
        commonScenes: answers.commonScenes.isNotEmpty
            ? answers.commonScenes
            : current.commonScenes,
        shootFrequency: answers.shootFrequency,
      );
      try {
        final profileSync = await ref.read(profileSyncServiceProvider.future);
        await profileSync.save(updated);
        ref.invalidate(profileDataProvider);
      } catch (_) {
        // 个人资料同步失败不阻塞问卷跳转（后端 Task3 仍会同步偏好）
      }
    }

    if (!mounted) return;
    if (widget.fromSettings) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '关于你',
        centerTitle: false,
        transparent: true,
        showBackButton: false,
        leading: TextButton(
          onPressed: _submitting ? null : _skipAll,
          child: Text(
            '跳过',
            style: TextStyle(fontSize: 14, color: tokens.textTertiary),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.3),
              tokens.canvas.withOpacity(0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              QuestionnaireProgress(
                current: _currentStep,
                total: kQuestionnaireQuestions.length,
                tokens: tokens,
              ),
              Expanded(
                child: FadeUp(
                  key: ValueKey(_currentStep),
                  child: _buildQuestionStep(tokens),
                ),
              ),
              _buildBottomBar(tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionStep(ThemeTokens tokens) {
    if (_currentQuestion.type != QuestionType.hierarchical) {
      return QuestionStep(
        question: _currentQuestion,
        selectedKeys: _answers[_currentQuestion.id]!,
        onToggle: _toggleOption,
        tokens: tokens,
      );
    }
    // 分级题：二级风格分组需异步从分类树读取，用 Future 缓存避免重复查询
    final sig = _styleSig();
    if (sig != _lastStyleSig) {
      _lastStyleSig = sig;
      _styleFuture = _buildStyleSections();
    }
    return FutureBuilder<List<StyleSection>>(
      future: _styleFuture,
      builder: (context, snap) => QuestionStep(
        question: _currentQuestion,
        selectedKeys: _answers[_currentQuestion.id]!,
        onToggle: _toggleOption,
        tokens: tokens,
        styleSections: snap.data,
      ),
    );
  }

  Widget _buildBottomBar(ThemeTokens tokens) {
    final isMulti = _currentQuestion.type == QuestionType.multi ||
        _currentQuestion.type == QuestionType.hierarchical;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prev,
              child: Text(
                '上一题',
                style: TextStyle(fontSize: 14, color: tokens.textSecondary),
              ),
            )
          else
            const SizedBox(width: 64),
          const Spacer(),
          if (isMulti)
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: _submitting ? null : _next,
              child: Text(_isLast ? '完成' : '下一题'),
            )
          else if (_isLast)
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: _submitting ? null : _next,
              child: const Text('完成'),
            ),
        ],
      ),
    );
  }
}
