import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/file_picker_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../shared/widgets/cards/neu_card.dart';
import '../../../../shared/widgets/lumira/feedback/lumira_toast.dart';
import '../../../../shared/widgets/lumira/form/lumira_text_field.dart';
import '../../../../shared/widgets/lumira/buttons/lumira_button.dart';
import '../../../../shared/widgets/nav/lumira_nav.dart';
import '../data/feedback_models.dart';
import '../data/feedback_repository.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String? _selectedType;
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  final List<Uint8List> _images = [];
  final List<String> _imageNames = [];
  bool _submitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    const max = 3;
    final remain = max - _images.length;
    if (remain <= 0) return;
    final result = await FilePickerService.pickImages(allowMultiple: true);
    if (result == null) return;
    for (final f in result.take(remain)) {
      final full = await FilePickerService.ensureFullBytes(f);
      final bytes = full.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      setState(() {
        _images.add(Uint8List.fromList(bytes));
        _imageNames.add(full.name.isNotEmpty ? full.name : 'shot.png');
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  String? _validate() {
    if (_selectedType == null) return '请选择反馈类型';
    if (_contentController.text.trim().isEmpty) return '请填写反馈内容';
    return null;
  }

  void _submit() {
    final err = _validate();
    if (err != null) {
      LumiraToast.show(context, err);
      return;
    }
    _doSubmit();
  }

  Future<void> _doSubmit() async {
    setState(() => _submitting = true);
    try {
      final repo = ref.read(feedbackRepositoryProvider);
      await repo.submit(SubmittedFeedback(
        type: _selectedType!,
        content: _contentController.text.trim(),
        contact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        screenshots: List.of(_images),
        screenshotNames: List.of(_imageNames),
      ));
      if (!mounted) return;
      LumiraToast.show(context, '已收到你的反馈，感谢！');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '提交失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '意见反馈',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 类型
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '反馈类型',
                        style:
                            TextStyle(fontSize: 13, color: tokens.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: feedbackTypes.map((t) {
                        final selected = _selectedType == t.key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = t.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? tokens.brandSubtle : tokens.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? tokens.brand : tokens.divider,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: selected ? tokens.brand : tokens.textSecondary,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 正文
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: LumiraTextField(
                  controller: _contentController,
                  labelText: '反馈内容',
                  hintText: '说说你的想法：使用不便、Bug、想要的功能、想要的模板/场景…',
                  maxLines: 6,
                  maxLength: 1000,
                ),
              ),
              const SizedBox(height: 16),
              // 联系方式
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: LumiraTextField(
                  controller: _contactController,
                  labelText: '联系方式（选填）',
                  hintText: '邮箱或微信号，便于我们联系你',
                  maxLength: 200,
                ),
              ),
              const SizedBox(height: 16),
              // 截图
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '截图（可选，最多 3 张）',
                        style:
                            TextStyle(fontSize: 13, color: tokens.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _images.length; i++)
                          _Thumb(
                            imageBytes: _images[i],
                            onRemove: () => _removeImage(i),
                            tokens: tokens,
                          ),
                        if (_images.length < 3)
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: tokens.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.divider),
                              ),
                              child: Icon(Icons.add_a_photo_outlined,
                                  color: tokens.textTertiary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中…' : '提交反馈'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(
      {required this.imageBytes, required this.onRemove, required this.tokens});
  final Uint8List imageBytes;
  final VoidCallback onRemove;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(imageBytes,
              width: 88, height: 88, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new,
            size: 20, color: tokens.textPrimary),
      ),
    );
  }
}