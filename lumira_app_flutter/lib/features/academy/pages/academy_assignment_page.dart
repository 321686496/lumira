import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
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

  Future<void> _pickFromCamera() async {
    // 通过拍摄页拍摄，返回 photoPath
    final result = await GoRouter.of(context).push<String>(
      RouteNames.build(RouteNames.capture, {RouteNames.paramMode: 'return'}),
    );
    if (result != null && mounted) {
      setState(() {
        _photoPath = result;
        _photoUrl = null;
      });
    }
  }

  Future<void> _pickFromAlbum() async {
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (pickResult == null || pickResult.files.isEmpty) return;
      final file = pickResult.files.first;
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
                    label: '重新拍摄', icon: Icons.camera_alt_outlined,
                    onPressed: _pickFromCamera,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    label: '重新选择', icon: Icons.photo_library_outlined,
                    onPressed: _pickFromAlbum,
                  )),
                ]),
              ] else ...[
                Row(children: [
                  Expanded(child: LumiraButton(
                    label: '去拍摄', icon: Icons.camera_alt_outlined,
                    onPressed: _pickFromCamera,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    label: '从相册选择', icon: Icons.photo_library_outlined,
                    onPressed: _pickFromAlbum,
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              // 备注
              TextField(
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  labelStyle: TextStyle(color: tokens.textTertiary, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.brand)),
                ),
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                onChanged: (v) => _note = v,
              ),
              const SizedBox(height: 24),
              // 提交按钮
              if (_result == null)
                LumiraButton(
                  label: _submitting ? '提交中...' : '提交作业',
                  icon: Icons.send,
                  onPressed: (_photoPath != null || _photoUrl != null) && !_submitting ? _submit : null,
                  enabled: (_photoPath != null || _photoUrl != null) && !_submitting,
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
