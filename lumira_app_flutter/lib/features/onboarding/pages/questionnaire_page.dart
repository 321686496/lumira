import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
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

  bool get _isLast => _currentStep == kQuestionnaireQuestions.length - 1;

  QuestionDef get _currentQuestion => kQuestionnaireQuestions[_currentStep];

  void _toggleOption(String key) {
    setState(() {
      final selected = _answers[_currentQuestion.id]!;
      if (_currentQuestion.type == QuestionType.single) {
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
    if (_currentQuestion.type == QuestionType.single) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _next();
      });
    }
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
      source: _answers['source']?.isEmpty == true
          ? null
          : _answers['source']?.first,
      favoriteCategories: _answers['favorite_categories']?.toList() ?? [],
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
                  child: QuestionStep(
                    question: _currentQuestion,
                    selectedKeys: _answers[_currentQuestion.id]!,
                    onToggle: _toggleOption,
                    tokens: tokens,
                  ),
                ),
              ),
              _buildBottomBar(tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeTokens tokens) {
    final isMulti = _currentQuestion.type == QuestionType.multi;
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
