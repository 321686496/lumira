import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import '../../../core/router/route_names.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show ButtonVariant, LumiraButton, LumiraProgress, LumiraTextField;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_mock_data.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 实战作业页
class AcademyAssignmentPage extends ConsumerStatefulWidget {
  const AcademyAssignmentPage({super.key, this.academyId});

  final String? academyId;

  @override
  ConsumerState<AcademyAssignmentPage> createState() => _AcademyAssignmentPageState();
}

class _AcademyAssignmentPageState extends ConsumerState<AcademyAssignmentPage> {
  String? _photoPath;
  String? _photoUrl;
  String _note = '';
  bool _submitting = false;
  AssignmentSubmission? _result;
  bool _loading = true;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingSubmission());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 加载已有提交记录，让用户关闭页面后回来仍能看到上次的照片和评分
  Future<void> _loadExistingSubmission() async {
    if (widget.academyId == null) {
      setState(() => _loading = false);
      return;
    }
    final detail = AcademyMockData.getCourseDetail(widget.academyId!);
    final assignment = detail?.assignment;
    if (assignment == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final repo = await ref.read(academyRepositoryProvider.future);
      final existing = await repo.getSubmission(assignment.id);
      if (mounted && existing != null) {
        setState(() {
          _result = existing;
          _photoPath = existing.photoPath;
          _photoUrl = existing.photoUrl;
          _note = existing.note ?? '';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 将拍摄页返回的临时照片复制到持久化目录，防止 OS 清理临时文件后照片丢失
  Future<String> _persistPhoto(String tempPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final photosDir = Directory(p.join(dbPath, 'assignment_photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = p.extension(tempPath).isNotEmpty ? p.extension(tempPath) : '.jpg';
      final destPath = p.join(
        photosDir.path,
        'assign_${widget.academyId}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(tempPath).copy(destPath);
      return destPath;
    } catch (_) {
      return tempPath;
    }
  }

  Future<void> _pickFromCamera() async {
    // 通过拍摄页拍摄，返回 photoPath
    final result = await GoRouter.of(context).push<String>(
      RouteNames.build(RouteNames.capture, {RouteNames.paramMode: 'return'}),
    );
    if (result != null && mounted) {
      final persistentPath = await _persistPhoto(result);
      if (mounted) {
        setState(() {
          _photoPath = persistentPath;
          _photoUrl = null;
          _result = null;
        });
      }
    }
  }

  Future<void> _pickFromAlbum() async {
    try {
      final file = await FilePickerService.pickSingleImage(withData: false);
      if (file == null) return;
      final path = file.path;
      if (path != null && mounted) {
        setState(() {
          _photoPath = path;
          _photoUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e'), duration: const Duration(milliseconds: 1500)),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (widget.academyId == null) return;
    final detail = AcademyMockData.getCourseDetail(widget.academyId!);
    final assignment = detail?.assignment;
    if (assignment == null) return;

    setState(() => _submitting = true);

    // 模拟评分
    await Future.delayed(const Duration(seconds: 1));
    final score = AcademyMockData.generateScore();
    final feedback = AcademyMockData.generateFeedback(score);

    final submission = AssignmentSubmission(
      id: 'sub_${assignment.id}_${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignment.id,
      courseId: widget.academyId!,
      photoPath: _photoPath,
      photoUrl: _photoUrl,
      note: _note.isNotEmpty ? _note : null,
      status: AssignmentStatus.reviewed,
      score: score,
      feedback: feedback,
      submittedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await ref.read(academyActionsProvider.notifier).submitAssignment(submission);

    if (mounted) {
      setState(() {
        _result = submission;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final academyId = widget.academyId;
    final detail = academyId != null ? ref.watch(courseDetailProvider(academyId)) : null;
    final assignment = detail?.assignment;

    if (assignment == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: const LumiraNav(title: '实战作业', transparent: true),
        body: Center(child: Text('作业不存在', style: TextStyle(color: tokens.textTertiary))),
      );
    }

    if (_loading) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: const LumiraNav(title: '实战作业', transparent: true),
        body: Center(child: LumiraProgress.circular(strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '实战作业', transparent: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 作业标题
              Text(assignment.title, style: TextStyle(
                fontFamily: 'Noto Serif SC', fontSize: 20,
                fontWeight: FontWeight.w600, color: tokens.textPrimary,
              )),
              const SizedBox(height: 8),
              Text(assignment.description, style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.6)),
              const SizedBox(height: 16),
              // 作业要求
              if (assignment.requirements.isNotEmpty) ...[
                Text('作业要求', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 8),
                for (var i = 0; i < assignment.requirements.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Text(assignment.requirements[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6))),
                  ]),
                ],
                const SizedBox(height: 24),
              ],
              // 照片预览或选择按钮
              if (_photoPath != null || _photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _photoPath != null
                        ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                        : Image.network(_photoUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: _pickFromCamera,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt_outlined),
                        SizedBox(width: 8),
                        Text('重新拍摄'),
                      ],
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: _pickFromAlbum,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.photo_library_outlined),
                        SizedBox(width: 8),
                        Text('重新选择'),
                      ],
                    ),
                  )),
                ]),
              ] else ...[
                Row(children: [
                  Expanded(child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: _pickFromCamera,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt_outlined),
                        SizedBox(width: 8),
                        Text('去拍摄'),
                      ],
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: _pickFromAlbum,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.photo_library_outlined),
                        SizedBox(width: 8),
                        Text('从相册选择'),
                      ],
                    ),
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              // 备注
              LumiraTextField(
                controller: _noteController,
                labelText: '备注（可选）',
                maxLines: 3,
                onChanged: (v) => _note = v,
              ),
              const SizedBox(height: 24),
              // 提交按钮
              if (_result == null)
                LumiraButton(
                  variant: ButtonVariant.primary,
                  onPressed: (_photoPath != null || _photoUrl != null) && !_submitting
                      ? _submit
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send),
                      const SizedBox(width: 8),
                      Text(_submitting ? '提交中...' : '提交作业'),
                    ],
                  ),
                )
              else ...[
                // 评分结果
                NeuCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Icon(Icons.emoji_events_outlined, size: 48, color: tokens.brand),
                    const SizedBox(height: 8),
                    Text('${_result!.score} 分', style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: tokens.brand,
                    )),
                    const SizedBox(height: 8),
                    Text(_result!.feedback ?? '', style: TextStyle(
                      fontSize: 13, color: tokens.textSecondary, height: 1.6,
                    ), textAlign: TextAlign.center),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
