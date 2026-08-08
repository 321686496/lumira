import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/database_provider.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../shared/widgets/nav/lumira_nav.dart';
import '../data/watermark_providers.dart';
import '../models/watermark_template.dart';
import '../widgets/watermark_preview.dart';

/// 水印编辑页：基于预置模板复制为自定义模板，可编辑文本与全局样式参数。
///
/// 布局：
/// - 顶部：200×260 灰色预览区（[WatermarkPreview]）
/// - 底部：参数 ListView
///   - 每个文本元素一个 [TextField]（文本内容）
///   - 全局样式：字号 / 透明度 / X / Y / 旋转 Slider + 粗体 / 斜体 FilterChip
///
/// 字号 Slider 范围 6~40（对应参考宽度 400px 下的绝对像素），存储为相对值
/// （`element.fontSize = sliderValue / 400`），与 [WatermarkRenderer] 约定一致。
/// 全局样式控件作用于所有文本元素（水印视为整体：统一字号/透明度/位置/旋转/粗斜体）。
class WatermarkEditorPage extends ConsumerStatefulWidget {
  const WatermarkEditorPage({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<WatermarkEditorPage> createState() =>
      _WatermarkEditorPageState();
}

class _WatermarkEditorPageState extends ConsumerState<WatermarkEditorPage> {
  static const double _referenceWidth = 400.0;

  late final WatermarkTemplate _template;
  late final List<TextEditingController> _textControllers;
  late final List<WatermarkElement> _textElements;

  // X/Y 滑块拖动前的初始位置快照：以 DELTA 方式应用调整，
  // 避免将同一绝对值写入所有文本元素而破坏多元素相对布局
  // （例如四角水印会塌缩到同一坐标）。
  final Map<String, double> _initialX = {};
  final Map<String, double> _initialY = {};
  late final double _initialSliderX;
  late final double _initialSliderY;

  @override
  void initState() {
    super.initState();
    final presets = ref.read(presetWatermarksProvider);
    WatermarkTemplate? source;
    if (widget.templateId != null) {
      for (final t in presets) {
        if (t.id == widget.templateId) {
          source = t;
          break;
        }
      }
    }
    source ??= presets.isNotEmpty ? presets.first : _fallbackTemplate();

    // 复制为自定义模板（独立元素实例，避免污染预置列表）
    _template = WatermarkTemplate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '${source.name}（副本）',
      type: WatermarkTemplateType.custom,
      createdAt: DateTime.now(),
      elements: source.elements
          .map((e) => e.copyWith(id: '${e.id}_copy'))
          .toList(),
    );

    _textElements = _template.elements
        .where((e) => e.type != WatermarkElementType.image)
        .toList();

    // Capture each text element's initial position so X/Y sliders can apply
    // a delta from this baseline rather than overwriting with an absolute
    // value (which would collapse multi-element layouts).
    for (final e in _textElements) {
      _initialX[e.id] = e.x;
      _initialY[e.id] = e.y;
    }
    _initialSliderX = _textElements.isNotEmpty ? _textElements.first.x : 0.5;
    _initialSliderY = _textElements.isNotEmpty ? _textElements.first.y : 0.5;

    _textControllers = _textElements
        .map((e) => TextEditingController(text: e.text))
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// 预置列表为空时的兜底模板（极端情况，正常不会触发）。
  WatermarkTemplate _fallbackTemplate() {
    return WatermarkTemplate(
      id: 'preset_empty',
      name: '空白水印',
      type: WatermarkTemplateType.preset,
      createdAt: DateTime.now(),
      elements: [
        WatermarkElement(
          id: 'fallback_text',
          type: WatermarkElementType.text,
          text: 'LUMIRA',
          x: 0.5,
          y: 0.9,
          fontSize: 0.04,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  WatermarkElement? get _firstText =>
      _textElements.isNotEmpty ? _textElements.first : null;

  /// 将变更应用到所有文本元素并刷新预览。
  void _applyToAllText(void Function(WatermarkElement) mutate) {
    for (final e in _textElements) {
      mutate(e);
    }
    setState(() {});
  }

  Future<void> _save() async {
    // 在 await 之前捕获 container，避免 async gap 后使用 BuildContext
    final container = ProviderScope.containerOf(context, listen: false);
    // 1. 持久化自定义模板到 DAO
    try {
      final dao = await ref.read(watermarkDaoProvider.future);
      await dao.insert(_template);
      // 2. 同步追加到内存缓存，使 currentWatermarkTemplateProvider 立即命中
      ref.read(customWatermarksProvider.notifier).state = [
        ...ref.read(customWatermarksProvider),
        _template,
      ];
    } catch (e) {
      debugPrint('[watermark-editor] persist custom template failed: $e');
    }
    // 3. 切换 settings.activeTemplateId 到刚保存的模板
    final current = ref.read(watermarkSettingsProvider);
    ref.read(watermarkSettingsProvider.notifier).state =
        current.copyWith(activeTemplateId: _template.id);
    // 4. 防抖持久化 settings
    scheduleWatermarkPersist(container);
    // 5. 返回上一页（await 后需检查 mounted）
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '编辑水印',
        transparent: true,
        actions: [
          GestureDetector(
            onTap: _save,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                '保存',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 顶部预览区
            WatermarkPreview(
              template: _template,
              width: 200,
              height: 260,
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: tokens.divider),
            // 底部参数区
            Expanded(
              child: _textElements.isEmpty
                  ? _emptyState(tokens)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        ..._buildTextFields(tokens),
                        const SizedBox(height: 8),
                        _sectionTitle('样式', tokens),
                        _buildSlider(
                          tokens: tokens,
                          label: '字号',
                          valueLabel:
                              '${((_firstText?.fontSize ?? 0.04) * _referenceWidth).round()}',
                          value: (_firstText?.fontSize ?? 0.04) *
                              _referenceWidth,
                          min: 6,
                          max: 40,
                          divisions: 34,
                          onChanged: (v) => _applyToAllText(
                              (e) => e.fontSize = v / _referenceWidth),
                        ),
                        _buildSlider(
                          tokens: tokens,
                          label: '透明度',
                          valueLabel: (_firstText?.opacity ?? 1.0)
                              .toStringAsFixed(2),
                          value: _firstText?.opacity ?? 1.0,
                          min: 0.1,
                          max: 1.0,
                          divisions: 18,
                          onChanged: (v) =>
                              _applyToAllText((e) => e.opacity = v),
                        ),
                        _buildSlider(
                          tokens: tokens,
                          label: 'X 位置',
                          valueLabel: (_firstText?.x ?? 0.0)
                              .toStringAsFixed(2),
                          value: _firstText?.x ?? 0.0,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) {
                            final delta = v - _initialSliderX;
                            _applyToAllText(
                              (e) => e.x = ((_initialX[e.id] ?? 0.0) + delta)
                                  .clamp(0.0, 1.0),
                            );
                          },
                        ),
                        _buildSlider(
                          tokens: tokens,
                          label: 'Y 位置',
                          valueLabel: (_firstText?.y ?? 0.0)
                              .toStringAsFixed(2),
                          value: _firstText?.y ?? 0.0,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) {
                            final delta = v - _initialSliderY;
                            _applyToAllText(
                              (e) => e.y = ((_initialY[e.id] ?? 0.0) + delta)
                                  .clamp(0.0, 1.0),
                            );
                          },
                        ),
                        _buildSlider(
                          tokens: tokens,
                          label: '旋转',
                          valueLabel: (_firstText?.rotation ?? 0.0)
                              .toStringAsFixed(2),
                          value: _firstText?.rotation ?? 0.0,
                          min: -0.5,
                          max: 0.5,
                          divisions: 20,
                          onChanged: (v) =>
                              _applyToAllText((e) => e.rotation = v),
                        ),
                        const SizedBox(height: 8),
                        _buildChips(tokens),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeTokens tokens) {
    return Center(
      child: Text(
        '该模板无可编辑的文本元素',
        style: TextStyle(fontSize: 13, color: tokens.textTertiary),
      ),
    );
  }

  List<Widget> _buildTextFields(ThemeTokens tokens) {
    final List<Widget> fields = [];
    for (var i = 0; i < _textElements.length; i++) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '文本 ${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textControllers[i],
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.brand, width: 1.2),
                  ),
                ),
                onChanged: (value) {
                  _textElements[i].text = value;
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      );
    }
    return fields;
  }

  Widget _sectionTitle(String text, ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: tokens.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required ThemeTokens tokens,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: tokens.brand,
              thumbColor: tokens.brand,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips(ThemeTokens tokens) {
    final bold = _firstText?.bold ?? false;
    final italic = _firstText?.italic ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          FilterChip(
            label: const Text('粗体'),
            selected: bold,
            selectedColor: tokens.brandSubtle,
            checkmarkColor: tokens.brandText,
            labelStyle: TextStyle(
              fontSize: 13,
              color: bold ? tokens.brandText : tokens.textSecondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: tokens.divider),
            ),
            onSelected: (v) => _applyToAllText((e) => e.bold = v),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('斜体'),
            selected: italic,
            selectedColor: tokens.brandSubtle,
            checkmarkColor: tokens.brandText,
            labelStyle: TextStyle(
              fontSize: 13,
              color: italic ? tokens.brandText : tokens.textSecondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: tokens.divider),
            ),
            onSelected: (v) => _applyToAllText((e) => e.italic = v),
          ),
        ],
      ),
    );
  }
}
