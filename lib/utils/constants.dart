import 'package:flutter/material.dart';

// SHARED PREFERENCES KEYS ───────────────────────────────────────────────────────────────────────────
class PrefKeys {
  PrefKeys._(); // prevent instantiation

  static const String isLoggedIn = 'is_logged_in';
  static const String taskList   = 'task_list';
  static const String username   = 'username';
}

// DEMO CREDENTIALS  (swap for real auth later)───────────────────────────────────────────────────────────────────────────
class DemoCredentials {
  DemoCredentials._();

  static const String email    = 'student@demo.com';
  static const String password = '1234';
  static const String name     = 'Student';
}

// APP COLOURS───────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary       = Color(0xFF1565C0);
  static const Color primaryLight  = Color(0xFF5E92F3);
  static const Color accent        = Color(0xFF00BCD4);
  static const Color scaffoldBg    = Color(0xFFF4F6FB);
  static const Color cardBg        = Colors.white;
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider       = Color(0xFFE5E7EB);

  // Semantic colours (used for status badges, swipe backgrounds, etc.)
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color danger  = Color(0xFFE53935);
}

// SUBJECT LIST  (dropdown options)───────────────────────────────────────────────────────────────────────────
const List<String> kSubjects = [
  'Mathematics',
  'Cloud Computing',
  'Software Engineering',
  'Artificial Intelligence',
  'Data Science',
  'Operating Systems ',
  'Machine Learning',
  'DSA',
  'Cyber Security',
  'Other',
];

// PRIORITY LIST  (dropdown options)───────────────────────────────────────────────────────────────────────────
const List<String> kPriorities = ['High', 'Medium', 'Low'];

// HELPER FUNCTIONS


// Returns the display colour for a given priority string.
Color priorityColor(String priority) {
  switch (priority) {
    case 'High':   return AppColors.danger;
    case 'Medium': return AppColors.warning;
    case 'Low':    return AppColors.success;
    default:       return Colors.grey;
  }
}

// Each subject gets a consistent colour from this palette.
const List<Color> _subjectPalette = [
  Color(0xFF5C6BC0), // Mathematics
  Color(0xFF26A69A), // Science
  Color(0xFFEF5350), // English
  Color(0xFF8D6E63), // History
  Color(0xFF78909C), // Geography
  Color(0xFF66BB6A), // Computer Science
  Color(0xFFAB47BC), // Physics
  Color(0xFF29B6F6), // Chemistry
  Color(0xFFFF7043), // Biology
  Color(0xFFEC407A), // Economics
  Color(0xFF9E9E9E), // Other
];

// Returns the display colour for a given subject string.
Color subjectColor(String subject) {
  final index = kSubjects.indexOf(subject);
  return _subjectPalette[index < 0 ? 0 : index % _subjectPalette.length];
}