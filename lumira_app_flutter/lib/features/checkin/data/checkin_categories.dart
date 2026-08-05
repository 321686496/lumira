import 'package:flutter/material.dart';

/// 探店分类定义（延续灵感页 mock 的彩色图标风格；other 用固定中性色）
class CheckinCategory {
  const CheckinCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
}

const List<CheckinCategory> kCheckinCategories = [
  CheckinCategory(key: 'coffee', label: '咖啡', icon: Icons.coffee_outlined, iconColor: Color(0xFFB8860B), iconBgColor: Color(0xFFFFF5E6)),
  CheckinCategory(key: 'dessert', label: '甜品美食', icon: Icons.cake_outlined, iconColor: Color(0xFFC47C7C), iconBgColor: Color(0xFFFFF0F0)),
  CheckinCategory(key: 'art', label: '艺术展览', icon: Icons.account_balance_outlined, iconColor: Color(0xFF6B5E4E), iconBgColor: Color(0xFFEDE8E0)),
  CheckinCategory(key: 'bookstore', label: '书店', icon: Icons.menu_book_outlined, iconColor: Color(0xFF7B5EA7), iconBgColor: Color(0xFFF0E6FF)),
  CheckinCategory(key: 'fashion', label: '时尚买手', icon: Icons.checkroom_outlined, iconColor: Color(0xFFC4783C), iconBgColor: Color(0xFFFFF0E0)),
  CheckinCategory(key: 'nature', label: '公园自然', icon: Icons.park_outlined, iconColor: Color(0xFF5A7A48), iconBgColor: Color(0xFFE8F5E4)),
  CheckinCategory(key: 'other', label: '其他', icon: Icons.place_outlined, iconColor: Color(0xFF6B7280), iconBgColor: Color(0xFFF0F0F2)),
];

/// 按 key 查找分类，未知/空 key 返回 other
CheckinCategory checkinCategoryOf(String key) {
  for (final c in kCheckinCategories) {
    if (c.key == key) return c;
  }
  return kCheckinCategories.last;
}
