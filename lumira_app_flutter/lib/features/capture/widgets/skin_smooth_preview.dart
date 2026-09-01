import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 磨皮实时预览渲染组件：用 FragmentShader 逐片元磨皮。
///
/// - `enabled && strength>0` 且着色器程序加载成功 → 走 shader 渲染（GPU，零读回）。
/// - 否则快速路径：直接画 [image]。
/// - [loadProgram] 供测试注入 / 降级探测；缺省时组件内部用
///   `FragmentProgram.fromAsset('shaders/skin_smooth.frag')` 异步加载。
/// - 渲染期异常一律降级：捕获后画原图，不抛出（不阻塞编辑页、不白屏）。
class SkinSmoothPreview extends StatefulWidget {
  const SkinSmoothPreview({
    super.key,
    required this.image,
    required this.strength,
    this.enabled = true,
    this.loadProgram,
  });

  final ui.Image image;
  final double strength;
  final bool enabled;

  /// 自定义着色器程序加载器（测试注入 / 降级探测）。
  /// 返回非 `FragmentProgram` 或抛异常均视为加载失败 → 降级画原图。
  final Future<Object?> Function()? loadProgram;

  /// 纯逻辑快速路径判定（便于测试）。
  static bool staticShouldRender({required bool enabled, required double strength}) =>
      enabled && strength > 0;

  @override
  State<SkinSmoothPreview> createState() => _SkinSmoothPreviewState();
}

class _SkinSmoothPreviewState extends State<SkinSmoothPreview> {
  bool _programOk = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadProgram();
  }

  @override
  void didUpdateWidget(SkinSmoothPreview old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled ||
        old.strength != widget.strength ||
        old.loadProgram != widget.loadProgram) {
      _maybeLoadProgram();
    }
  }

  /// 外层仅负责「快速路径 + 注入探测」判定；真正的着色器加载由
  /// `_ShaderCanvas` 异步完成（生产默认 `FragmentProgram.fromAsset`）。
  Future<void> _maybeLoadProgram() async {
    final usesShader = widget.enabled && widget.strength > 0;
    final loader = widget.loadProgram;
    if (!usesShader || loader == null) {
      if (mounted) {
        setState(() {
          _programOk = usesShader;
          _loadFailed = false;
        });
      }
      return;
    }
    try {
      final result = await loader();
      if (!mounted) return;
      setState(() {
        _programOk = result is ui.FragmentProgram;
        _loadFailed = result is! ui.FragmentProgram;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _programOk = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useShader =
        widget.enabled && widget.strength > 0 && _programOk && !_loadFailed;
    return useShader
        ? _ShaderCanvas(
            image: widget.image,
            strength: widget.strength,
            loadProgram: widget.loadProgram,
          )
        : RawImage(image: widget.image, fit: BoxFit.contain);
  }
}

/// 真正使用 FragmentProgram + CustomPainter 渲染 shader 的层。
///
/// 在其 `initState` 中异步加载 FragmentProgram（生产默认
/// `FragmentProgram.fromAsset('shaders/skin_smooth.frag')`），
/// 成功后在 [build] 中把已加载的 program 交给 [SkinSmoothPainter]；
/// 加载失败 / 抛异常则将 [_prog] 置 null 并降级画原图，不白屏。
class _ShaderCanvas extends StatefulWidget {
  const _ShaderCanvas({
    required this.image,
    required this.strength,
    this.loadProgram,
  });

  final ui.Image image;
  final double strength;
  final Future<Object?> Function()? loadProgram;

  @override
  State<_ShaderCanvas> createState() => _ShaderCanvasState();
}

class _ShaderCanvasState extends State<_ShaderCanvas> {
  ui.FragmentProgram? _prog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ShaderCanvas old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image || old.strength != widget.strength) {
      setState(() {}); // 重绘用，program 无需重载
    }
    if (old.loadProgram != widget.loadProgram) {
      _load();
    }
  }

  Future<void> _load() async {
    ui.FragmentProgram? prog;
    try {
      final loader = widget.loadProgram;
      final result = loader != null
          ? await loader()
          : await ui.FragmentProgram.fromAsset('shaders/skin_smooth.frag');
      prog = result is ui.FragmentProgram ? result : null;
    } catch (_) {
      prog = null; // 加载异常 → 降级
    }
    if (!mounted) return;
    setState(() => _prog = prog);
  }

  @override
  Widget build(BuildContext context) {
    final prog = _prog;
    if (prog == null) {
      // 加载失败 / 尚未就绪：直接画原图，保证不白屏。
      return RawImage(image: widget.image, fit: BoxFit.contain);
    }
    return CustomPaint(
      painter: SkinSmoothPainter(
        image: widget.image,
        strength: widget.strength,
        program: prog,
      ),
      child: RawImage(image: widget.image, fit: BoxFit.contain),
    );
  }
}

/// 逐片元 shader 画家。painter 内部 paint 期异常同样降级画原图。
class SkinSmoothPainter extends CustomPainter {
  SkinSmoothPainter({
    required this.image,
    required this.strength,
    required this.program,
  });

  final ui.Image image;
  final double strength;
  final ui.FragmentProgram program;

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final shader = program.fragmentShader()
        // float 与 sampler 是两套独立的索引空间：
        // - float：setFloat 索引只数 float uniform（uSize→vec2，占 0,1；uStrength→2）。
        // - sampler：setImageSampler 索引从 0 重新开始，只数 sampler（uTexture→0）。
        // 本 Flutter 版本 setFloat 每次仅写入一个值，vec2 需按分量调用。
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, strength)
        ..setImageSampler(0, image);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (_) {
      _fallback(canvas, size);
    }
  }

  /// 渲染期异常时的兜底：不抛出不白屏，直接画原图。
  void _fallback(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant SkinSmoothPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.strength != strength ||
      oldDelegate.program != program;
}