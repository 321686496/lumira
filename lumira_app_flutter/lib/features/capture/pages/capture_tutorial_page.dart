import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 拍摄页使用指南（教学页）
///
/// 由拍摄页顶部导航栏的指南 icon 进入，按功能区逐项介绍拍摄页的全部功能：
/// 顶部导航 / 取景器 / 工具栏 / 拍照保存 / 模板模式 / 场景滤镜 / 挑战模式。
class CaptureTutorialPage extends ConsumerWidget {
  const CaptureTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(title: '拍摄指南'),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.standard),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                _IntroCard(tokens: tokens),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '顶部导航',
                    icon: Icons.photo_camera_front_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.arrow_back_ios_new,
                        '返回',
                        '点击返回上一个页面；拍摄中的照片已自动保存，无需担心丢失。',
                      ),
                      _TutorialItem(
                        Icons.tune,
                        '标题区（点击调整参数）',
                        '自由拍摄模式下点击标题即可展开参数面板，调整曝光、ISO、快门等；套用模板时可微调模板参数。',
                      ),
                      _TutorialItem(
                        Icons.fullscreen,
                        '全屏',
                        '隐藏底部工具栏，获得纯净的取景画面，保留拍摄按钮与返回入口。',
                      ),
                      _TutorialItem(
                        Icons.crop_free,
                        '模板叠图',
                        '套用模板后，用半透明叠图辅助对齐构图；再次点击可隐藏。',
                      ),
                      _TutorialItem(
                        Icons.accessibility_new,
                        '剪影',
                        '显示/隐藏模板的姿势剪影，方便摆出与模板一致的姿态。',
                      ),
                      _TutorialItem(
                        Icons.flash_on,
                        '闪光灯',
                        '点击切换手电筒补光（前置摄像头无闪光灯，自动隐藏）。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '取景器',
                    icon: Icons.center_focus_strong_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.touch_app_outlined,
                        '点击对焦',
                        '点击画面任意位置即可对焦，长按可锁定曝光。',
                      ),
                      _TutorialItem(
                        Icons.straighten,
                        '照片比例',
                        '顶部切换 全屏 / 4:3 / 1:1，取景器与成片比例完全一致（所见即所得）。',
                      ),
                      _TutorialItem(
                        Icons.speed,
                        '水平仪',
                        '画面中的水平参考线帮助保持构图水平，横竖屏自动适配。',
                      ),
                      _TutorialItem(
                        Icons.flip,
                        '前置镜像',
                        '前置摄像头拍摄时自动镜像，与预览画面一致。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '工具栏',
                    icon: Icons.settings_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.cameraswitch_outlined,
                        '切换前后摄像头',
                        '一键切换前后置，选择会被记住，下次打开仍是上次使用的镜头。',
                      ),
                      _TutorialItem(
                        Icons.zoom_out_map,
                        '缩放',
                        '滑动或点选倍数（0.5x / 1x / 2x / 3x / 5x）变焦，超广角按设备能力自动显示。',
                      ),
                      _TutorialItem(
                        Icons.light_mode_outlined,
                        '补光灯',
                        '前置拍摄时开启屏幕补光，可调节色温与亮度，让自拍更明亮。',
                      ),
                      _TutorialItem(
                        Icons.palette_outlined,
                        '滤镜',
                        '实时预览并选择滤镜，拍摄后同样可在预览页调整。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '拍照与保存',
                    icon: Icons.photo_camera_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.circle_outlined,
                        '快门',
                        '点击圆形快门拍摄；照片会自动应用当前滤镜、比例与构图设置。',
                      ),
                      _TutorialItem(
                        Icons.photo_library_outlined,
                        '相册角标',
                        '左下角缩略图为最近一张照片，点击可进入相册；右上角提示当前已拍数量。',
                      ),
                      _TutorialItem(
                        Icons.auto_awesome,
                        '水印',
                        '开启水印后，成片自动添加所选水印（日期/签名/杂志排版等），可在「我的-水印」中管理。',
                      ),
                      _TutorialItem(
                        Icons.photo_camera_back_outlined,
                        '连拍',
                        '连续按快门可快速连拍，每张照片独立保存，互不阻塞。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '模板模式',
                    icon: Icons.style_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.grid_view_outlined,
                        '模板选择',
                        '底部模板条可选择系统/自定义/在线模板，点击即套用其相机、后期与构图参数。',
                      ),
                      _TutorialItem(
                        Icons.crop_free,
                        '叠图辅助',
                        '半透明叠图 + 姿势剪影双辅助，照着模板摆姿构图，成片比例与模板一致。',
                      ),
                      _TutorialItem(
                        Icons.tune,
                        '参数微调',
                        '套用模板后可微调曝光/滤镜等，但构图参数保留模板风格。',
                      ),
                      _TutorialItem(
                        Icons.lock_open_outlined,
                        '付费模板',
                        '付费模板可先试用拍摄效果，满意后再用积分解锁完整版。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _SectionCard(
                    tokens: tokens,
                    title: '场景与挑战',
                    icon: Icons.emoji_events_outlined,
                    items: const [
                      _TutorialItem(
                        Icons.explore,
                        '场景灵感',
                        '从「首页-场景灵感」查看不同场景的拍摄建议（光线、构图、参数），拍摄时可直接套用。',
                      ),
                      _TutorialItem(
                        Icons.task_alt,
                        '挑战模式',
                        '从挑战页进入拍摄，拍完照片会自动跳到挑战确认页，提交后获得 XP 与积分奖励。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  child: _PointsTipCard(tokens: tokens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部欢迎卡
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用 Lumira 拍出理想照片',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '拍摄页集中了模板、构图、滤镜与后期能力。下面的指南将带你熟悉每个功能的位置与用法。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组功能卡片
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.tokens,
    required this.title,
    required this.icon,
    required this.items,
  });
  final ThemeTokens tokens;
  final String title;
  final IconData icon;
  final List<_TutorialItem> items;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 16, color: tokens.divider),
            _TutorialItemRow(tokens: tokens, item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _TutorialItemRow extends StatelessWidget {
  const _TutorialItemRow({required this.tokens, required this.item});
  final ThemeTokens tokens;
  final _TutorialItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 16, color: tokens.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.desc,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 积分小贴士
class _PointsTipCard extends StatelessWidget {
  const _PointsTipCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, size: 18, color: tokens.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '顺手赚积分',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '每天首次拍摄 +2 积分、完成挑战 +5 积分、每日签到也有奖励，可在「我的积分」查看余额与流水。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条功能说明
class _TutorialItem {
  final IconData icon;
  final String title;
  final String desc;
  const _TutorialItem(this.icon, this.title, this.desc);
}
