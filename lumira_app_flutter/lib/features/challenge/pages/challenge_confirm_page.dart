import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/tables.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/challenge_models.dart';
import '../data/challenge_pool.dart';
import '../data/challenge_providers.dart';
import '../../profile/providers/growth_providers.dart';

/// 挑战确认页
///
/// 闭环最后一环前的"确认提交"步骤：
/// 拍摄保存（已落库 gallery_items）→ 此页 → 用户确认提交 → 回写挑战状态 done + XP → XP 完成页
///
/// 入参：
/// - challengeId：本次挑战 id（来自拍摄页透传）
/// - photoId：刚保存到 gallery_items 的记录 id
///
/// UI：
/// 1. LumiraNav（标题"确认挑战作品" + 关闭按钮）
/// 2. 大图预览（3:4，铺满宽度）
/// 3. 挑战信息卡（badge + 标题 + 描述 + 奖励 + tip）
/// 4. 底部双按钮：「重拍」secondary + 「作为挑战作品提交」primary
class ChallengeConfirmPage extends ConsumerStatefulWidget {
  const ChallengeConfirmPage({
    super.key,
    required this.challengeId,
    required this.photoId,
  });

  final String challengeId;
  final String photoId;

  @override
  ConsumerState<ChallengeConfirmPage> createState() =>
      _ChallengeConfirmPageState();
}

class _ChallengeConfirmPageState extends ConsumerState<ChallengeConfirmPage> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final poolItem = ChallengePool.byId(widget.challengeId);

    if (poolItem == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: SafeArea(
          child: Center(
            child: Text('挑战不存在',
                style: TextStyle(color: tokens.textSecondary)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '确认挑战作品',
              transparent: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _onClose,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // 1. 大图预览
                  FadeUp(
                    child: _PhotoPreview(
                      photoId: widget.photoId,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 2. 挑战信息卡
                  FadeUp(
                    delay: const Duration(milliseconds: 80),
                    child: _ChallengeInfoCard(
                      poolItem: poolItem,
                      tokens: tokens,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 3. 提示文案
                  FadeUp(
                    delay: const Duration(milliseconds: 160),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: tokens.textTertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '提交后视为完成本次挑战，XP 将立即发放。重拍会丢弃当前照片的挑战关联（照片仍保留在画廊）。',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textTertiary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 4. 底部双按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: LumiraButton(
                      variant: ButtonVariant.secondary,
                      onPressed:
                          _submitting ? null : () => _onRetake(widget.challengeId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.camera_alt_outlined),
                          SizedBox(width: 8),
                          Text('重拍'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumiraButton(
                      variant: ButtonVariant.primary,
                      onPressed: _submitting
                          ? null
                          : () => _onSubmit(poolItem),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_submitting)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            const Icon(Icons.check_circle_outline),
                          const SizedBox(width: 8),
                          Text(_submitting ? '提交中...' : '提交挑战'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 关闭：返回挑战主页（用户放弃本次确认）
  void _onClose() {
    GoRouter.of(context).go(RouteNames.challenge);
  }

  /// 重拍：携带 challengeId 跳回拍摄页（清栈，避免返回到预览页）
  void _onRetake(String challengeId) {
    GoRouter.of(context).go(
      '${RouteNames.capture}'
      '?${RouteNames.paramChallengeId}=${Uri.encodeComponent(challengeId)}',
    );
  }

  /// 提交：回写挑战状态 done + 累加 XP + 关联 photoId 到挑战历史
  Future<void> _onSubmit(ChallengePoolItem poolItem) async {
    setState(() => _submitting = true);
    try {
      final dao = await ref.read(challengeDaoProvider.future);
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final historyId = '${dateStr}_${poolItem.id}';
      final nowMs = now.millisecondsSinceEpoch;

      // 1. 回写挑战状态为 done（含完成时间戳）
      //    每日挑战在翻牌时已插入记录，直接更新；
      //    附加挑战没有翻牌/选中动作、历史无记录，需要先插入一条 done 记录，
      //    否则 updateStatus/attachPhoto 更新 0 行，附加挑战永远显示未完成。
      final existing = await dao.getById(historyId);
      if (existing == null) {
        await dao.insert(ChallengeHistoryRecord(
          id: historyId,
          date: dateStr,
          challengeId: poolItem.id,
          category: poolItem.category,
          title: poolItem.title,
          rewardXP: poolItem.rewardXP,
          status: ChallengeStatus.done,
          selectedAt: nowMs,
          completedAt: nowMs,
          isDaily: false,
        ));
      } else {
        await dao.updateStatus(
          historyId,
          ChallengeStatus.done,
          timestamp: nowMs,
        );
      }

      // 2. 关联 photoId 到挑战历史记录（用于详情页"完成的作品"展示）
      await dao.attachPhoto(historyId, widget.photoId);

      // 3. 累加 XP 到 user_progress（单行表 id=1）
      final db = await ref.read(databaseProvider.future);
      await db.rawInsert('''
        INSERT OR IGNORE INTO ${Tables.userProgress}
          (${Tables.colId}, ${Tables.colXp}, ${Tables.colTotalPhotos}, ${Tables.colUpdatedAt})
        VALUES (1, 0, 0, ?)
      ''', [nowMs]);
      await db.rawUpdate('''
        UPDATE ${Tables.userProgress}
        SET ${Tables.colXp} = ${Tables.colXp} + ?,
            ${Tables.colUpdatedAt} = ?
        WHERE ${Tables.colId} = 1
      ''', [poolItem.rewardXP, nowMs]);

      // 4. 失效相关 provider 触发刷新
      ref.invalidate(growthDaoProvider);
      ref.invalidate(growthLevelProvider);
      ref.invalidate(weeklyHistoryProvider);
      ref.invalidate(dailyChallengeStateProvider);
      ref.invalidate(subChallengesProvider);

      if (!mounted) return;
      // 5. 跳转 XP 完成页（清栈）
      GoRouter.of(context).go(
        '${RouteNames.challengeComplete}'
        '?${RouteNames.paramChallengeId}=${Uri.encodeComponent(poolItem.id)}'
        '&rewardXp=${poolItem.rewardXP}'
        '&title=${Uri.encodeComponent(poolItem.title)}',
      );
    } catch (e) {
      debugPrint('[challenge] submit failed: $e');
      if (mounted) {
        LumiraToast.show(context, '提交失败：$e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// 大图预览：从 gallery_items 加载 photoId 对应的照片
class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.photoId, required this.tokens});

  final String photoId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryDaoProvider.future);

    return FutureBuilder<GalleryItemRecord?>(
      future: () async {
        final dao = await galleryAsync;
        return dao.getById(photoId);
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: tokens.surfaceAlt,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final item = snapshot.data!;
        // 优先级：filePath > originalPath > dataUrl
        final filePath = item.filePath ?? item.originalPath;
        final dataUrl = item.dataUrl;

        Widget image;
        if (filePath != null && filePath.isNotEmpty) {
          image = Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _Placeholder(tokens: tokens),
          );
        } else if (dataUrl != null && dataUrl.isNotEmpty) {
          // dataUrl 形如 data:image/png;base64,xxxx
          image = _DataUrlImage(
            dataUrl: dataUrl,
            tokens: tokens,
          );
        } else {
          image = _Placeholder(tokens: tokens);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: image,
          ),
        );
      },
    );
  }
}

class _DataUrlImage extends StatelessWidget {
  const _DataUrlImage({required this.dataUrl, required this.tokens});

  final String dataUrl;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    // 简化处理：若以 data: 开头，提取 base64 部分解码
    try {
      final idx = dataUrl.indexOf('base64,');
      if (idx == -1) return _Placeholder(tokens: tokens);
      final b64 = dataUrl.substring(idx + 7);
      final bytes = Uri.parse('data:;base64,$b64').data!.contentAsBytes();
      return Image.memory(bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Placeholder(tokens: tokens));
    } catch (_) {
      return _Placeholder(tokens: tokens);
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surfaceAlt,
      child: Center(
        child: Icon(Icons.broken_image_outlined,
            size: 40, color: tokens.textTertiary),
      ),
    );
  }
}

/// 挑战信息卡：badge + 标题 + 描述 + 奖励 + tip
class _ChallengeInfoCard extends StatelessWidget {
  const _ChallengeInfoCard({required this.poolItem, required this.tokens});

  final ChallengePoolItem poolItem;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // badge 行
          Row(
            children: [
              Icon(Icons.my_location, size: 14, color: tokens.brandText),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ChallengeCategory.label(poolItem.category),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.brandText,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 14, color: tokens.brand),
                  const SizedBox(width: 4),
                  Text(
                    '+${poolItem.rewardXP} XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 标题
          Text(
            poolItem.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            poolItem.description,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.6,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 分隔线
          Container(height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          // 拍摄提示
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 16, color: tokens.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '拍摄提示',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      poolItem.tip,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
