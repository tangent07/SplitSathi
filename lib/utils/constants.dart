import 'package:flutter/material.dart';

class AppColors {
  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFEA580C);
  static const cream = Color(0xFFFDF6EC);
  static const peach = Color(0xFFFFEEDD);
  static const border = Color(0xFFFDE8CC);
  static const muted = Color(0xFFD97706);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFEF4444);
  static const yellow = Color(0xFFFCD34D);

  // Dark mode
  static const darkBg = Color(0xFF0A0A0F);
  static const darkSurface = Color(0xFF13131A);
  static const darkSurface2 = Color(0xFF1C1C28);
  static const darkBorder = Color(0xFF2A2A3D);
  static const darkMuted = Color(0xFF6B6B85);
}

class AppConstants {
  static const List<String> groupEmojis = [
    '🍕', '✈️', '🏠', '🎉', '🏕️', '💼', '🎮', '🏋️',
    '🚗', '🎵', '🏖️', '🍺', '📚', '💊', '🛒', '🎭',
  ];

  static const List<String> expenseCategories = [
    '🍽️', '🚗', '🏨', '🎉', '🛒', '💡',
  ];

  static const List<Color> avatarColors = [
    Color(0xFFF7C948),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFA78BFA),
    Color(0xFF51CF66),
    Color(0xFFFF8B94),
    Color(0xFF74C0FC),
    Color(0xFFF783AC),
  ];

  static const List<Color> pieColors = [
    Color(0xFFF7C948),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFA78BFA),
    Color(0xFF51CF66),
    Color(0xFFFF8B94),
    Color(0xFFFFD700),
    Color(0xFF74C0FC),
  ];

  static Color getAvatarColor(int index) {
    return avatarColors[index % avatarColors.length];
  }

  static Color getPieColor(int index) {
    return pieColors[index % pieColors.length];
  }
}

class AppTextStyles {
  static TextStyle heading({bool dark = false}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: dark ? Colors.white : const Color(0xFF1C1C1C),
  );

  static TextStyle subheading({bool dark = false}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: dark ? Colors.white : const Color(0xFF1C1C1C),
  );

  static TextStyle body({bool dark = false}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: dark ? Colors.white70 : const Color(0xFF1C1C1C),
  );

  static TextStyle amount({Color? color}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: color ?? AppColors.orange,
  );

  static TextStyle muted({bool dark = false}) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: dark ? AppColors.darkMuted : AppColors.muted,
  );
}