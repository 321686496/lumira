import 'package:flutter/material.dart';

import '../../../shared/widgets/poster/poster_common.dart';
import '../../../shared/widgets/poster/poster_ratio.dart';
import '../../../shared/widgets/poster/poster_style_types.dart';
import 'checkin_poster_widgets.dart';

/// 探店足迹海报画布逻辑宽度（预览区 FittedBox 等比缩放）。
const double _kCkW = 320;

/// 4 款探店足迹海报样式：温柔手帐(ckF) / 原版足迹(ckBase) / 金字招牌(ckV4) / 克制奢华(ckM4)。
List<PosterStyle> checkinPosterStyles() => [
      _style('ckF', '温柔手帐', _buildF),
      _style('ckBase', '原版足迹', _buildBase),
      _style('ckV4', '金字招牌', _buildV4),
      _style('ckM4', '克制奢华', _buildM4),
    ];

PosterStyle _style(String id, String name, Widget Function(PosterStyleData) b) =>
    PosterStyle(
      id: id,
      name: name,
      groupName: name,
      kind: PosterKind.checkin,
      ratios: {PosterRatio.ratio34},
      builder: b,
    );

// ---------- 温柔手帐 ckF ----------
Widget _buildF(PosterStyleData d) {
  const pad = 22.0;
  final w = _kCkW - pad * 2;
  final bigH = w * 3 / 4;
  final thumbs = d.thumbBuilders ?? const [];
  final tw = (w - 8 * 3) / 4; // 4 张 3:4 小图并排
  return SizedBox(
    width: _kCkW,
    child: Container(
      padding: const EdgeInsets.all(pad),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F0E6), Color(0xFFFBE9EC)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckinBrandTag(),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                width: w,
                height: bigH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: d.photoBuilder(w, bigH),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(1000),
                    boxShadow: const [BoxShadow(color: Color(0x22900000), blurRadius: 10)],
                  ),
                  child: PosterRatingRow(rating: d.rating, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            d.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: posterSerif(22, letterSpacing: 1, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBD9D2),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text(
                  d.category,
                  style: posterPlain(11, color: const Color(0xFF8C5B4E), weight: FontWeight.w600),
                ),
              ),
              if (d.place.isNotEmpty)
                PosterMetaLine(icon: Icons.place_outlined, text: d.place, size: 11),
              if (d.dateText.isNotEmpty)
                PosterMetaLine(icon: Icons.calendar_today_outlined, text: d.dateText, size: 11),
            ],
          ),
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                d.note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: posterPlain(12, color: const Color(0xFF6B5B52), height: 1.5),
              ),
            ),
          ],
          if (thumbs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < thumbs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: thumbs[i](tw, tw * 4 / 3),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Center(child: PosterWatermark()),
        ],
      ),
    ),
  );
}

// ---------- 原版足迹 ckBase ----------
Widget _buildBase(PosterStyleData d) {
  const pad = 20.0;
  final w = _kCkW - pad * 2;
  final bigH = w * 3 / 4;
  final thumbs = d.thumbBuilders ?? const [];
  final tw = (w - 8 * 3) / 4;
  return SizedBox(
    width: _kCkW,
    child: Container(
      padding: const EdgeInsets.fromLTRB(pad, 24, pad, 22),
      color: PosterPalette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckinBrandTag(),
          const SizedBox(height: 16),
          GoldNotchedFrame(
            child: SizedBox(width: w, height: bigH, child: d.photoBuilder(w, bigH)),
          ),
          const SizedBox(height: 16),
          PosterRatingRow(rating: d.rating, size: 14),
          const SizedBox(height: 8),
          Text(
            d.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: posterSerif(24, letterSpacing: 1, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              PosterCatText(category: d.category, size: 10),
              if (d.place.isNotEmpty)
                PosterMetaLine(icon: Icons.place_outlined, text: d.place, size: 11),
            ],
          ),
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            const PosterHairline(),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 3, height: 26, color: PosterPalette.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: posterPlain(12, color: PosterPalette.text2, height: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const PosterHairline(),
          ],
          if (thumbs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < thumbs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  GoldNotchedFrame(
                    notch: 0.2,
                    child: SizedBox(width: tw, height: tw * 3 / 4, child: thumbs[i](tw, tw * 3 / 4)),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Center(child: PosterWatermark()),
        ],
      ),
    ),
  );
}

// ---------- 金字招牌 ckV4 ----------
Widget _buildV4(PosterStyleData d) {
  const pad = 28.0;
  final w = _kCkW - pad * 2;
  final thumbs = d.thumbBuilders ?? const [];
  final cell = (w - 8) / 2;
  return SizedBox(
    width: _kCkW,
    child: Container(
      padding: const EdgeInsets.fromLTRB(pad, 34, pad, 26),
      color: PosterPalette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CheckinBrandTag(),
          const SizedBox(height: 26),
          PosterCatText(category: d.category, size: 10, letterSpacing: 4),
          const SizedBox(height: 12),
          Text(
            d.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: posterSerif(34, color: PosterPalette.goldDeep, letterSpacing: 6, height: 1.25),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [PosterRatingRow(rating: d.rating, size: 14)],
          ),
          const SizedBox(height: 22),
          if (thumbs.isNotEmpty) ...[
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < thumbs.length; i++)
                    GoldNotchedFrame(
                      notch: 0.18,
                      child: SizedBox(width: cell, height: cell * 3 / 4, child: thumbs[i](cell, cell * 3 / 4)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          _metaLine(d),
          const SizedBox(height: 14),
          const Center(child: PosterWatermark()),
        ],
      ),
    ),
  );
}

Widget _metaLine(PosterStyleData d) {
  final metas = <Widget>[
    if (d.place.isNotEmpty) PosterMetaLine(icon: Icons.place_outlined, text: d.place, size: 11),
    if (d.dateText.isNotEmpty)
      PosterMetaLine(icon: Icons.calendar_today_outlined, text: d.dateText, size: 11),
  ];
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 6,
    children: metas,
  );
}

// ---------- 克制奢华 ckM4 ----------
Widget _buildM4(PosterStyleData d) {
  const pad = 20.0;
  final w = _kCkW - pad * 2;
  final leftW = w * 0.44;
  final leftH = leftW * 4 / 3;
  final thumbs = d.thumbBuilders ?? const [];
  final tw = (w - 8 * 3) / 4;
  return SizedBox(
    width: _kCkW,
    child: Container(
      padding: const EdgeInsets.fromLTRB(pad, 24, pad, 22),
      color: const Color(0xFFFDFBF7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckinBrandTag(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoldNotchedFrame(
                child: SizedBox(width: leftW, height: leftH, child: d.photoBuilder(leftW, leftH)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOOTPRINT',
                      style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 4),
                    ),
                    const SizedBox(height: 7),
                    Container(width: 26, height: 2, color: PosterPalette.gold),
                    const SizedBox(height: 10),
                    Text(
                      d.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: posterSerif(20, letterSpacing: 1, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    PosterRatingRow(rating: d.rating, size: 12),
                    const SizedBox(height: 10),
                    PosterMetaLine(icon: Icons.place_outlined, text: d.place, size: 11),
                    if (d.dateText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: PosterMetaLine(icon: Icons.calendar_today_outlined, text: d.dateText, size: 11),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: PosterPalette.gold, width: 1),
                        borderRadius: BorderRadius.circular(1000),
                      ),
                      child: Text(
                        d.category,
                        style: posterPlain(9, color: PosterPalette.goldDeep, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (thumbs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < thumbs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.only(top: i.isOdd ? 8 : 0),
                    child: GoldNotchedFrame(
                      notch: 0.2,
                      child: SizedBox(width: tw, height: tw * 3 / 4, child: thumbs[i](tw, tw * 3 / 4)),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              color: const Color(0xFFF6F1E8),
              child: Text(
                d.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: posterPlain(11, color: PosterPalette.text2, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Center(child: PosterWatermark()),
        ],
      ),
    ),
  );
}

