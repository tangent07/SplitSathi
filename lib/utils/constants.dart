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

  // ALL global country codes
  static const List<String> countryCodes = [
    '+1', '+7', '+20', '+27', '+30', '+31', '+32', '+33', '+34', '+36', '+39',
    '+40', '+41', '+43', '+44', '+45', '+46', '+47', '+48', '+49', '+51', '+52',
    '+53', '+54', '+55', '+56', '+57', '+58', '+60', '+61', '+62', '+63', '+64',
    '+65', '+66', '+81', '+82', '+84', '+86', '+90', '+91', '+92', '+93', '+94',
    '+95', '+98', '+211', '+212', '+213', '+216', '+218', '+220', '+221', '+222',
    '+223', '+224', '+225', '+226', '+227', '+228', '+229', '+230', '+231', '+232',
    '+233', '+234', '+235', '+236', '+237', '+238', '+239', '+240', '+241', '+242',
    '+243', '+244', '+245', '+246', '+247', '+248', '+249', '+250', '+251', '+252',
    '+253', '+254', '+255', '+256', '+257', '+258', '+260', '+261', '+262', '+263',
    '+264', '+265', '+266', '+267', '+268', '+269', '+290', '+291', '+297', '+298',
    '+299', '+350', '+351', '+352', '+353', '+354', '+355', '+356', '+357', '+358',
    '+359', '+370', '+371', '+372', '+373', '+374', '+375', '+376', '+377', '+378',
    '+379', '+380', '+381', '+382', '+385', '+386', '+387', '+389', '+420', '+421',
    '+423', '+500', '+501', '+502', '+503', '+504', '+505', '+506', '+507', '+508',
    '+509', '+590', '+591', '+592', '+593', '+594', '+595', '+596', '+597', '+598',
    '+599', '+670', '+672', '+673', '+674', '+675', '+676', '+677', '+678', '+679',
    '+680', '+681', '+682', '+683', '+685', '+686', '+687', '+688', '+689', '+690',
    '+691', '+692', '+850', '+852', '+853', '+855', '+856', '+880', '+886', '+960',
    '+961', '+962', '+963', '+964', '+965', '+966', '+967', '+968', '+970', '+971',
    '+972', '+973', '+974', '+975', '+976', '+977', '+992', '+993', '+994', '+995',
    '+996', '+998',
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