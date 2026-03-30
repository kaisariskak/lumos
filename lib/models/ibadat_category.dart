import 'package:flutter/material.dart';

class IbadatCategory {
  final String key;
  final String label;
  final String unit;
  final String icon;
  final Color color;
  final int weekMax;
  final int monthMax;

  const IbadatCategory({
    required this.key,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.weekMax,
    required this.monthMax,
  });

  static const List<IbadatCategory> all = [
    IbadatCategory(
      key: 'quran_pages',
      label: 'Құран',
      unit: 'бет',
      icon: '📖',
      color: Color(0xFF0D9488),
      weekMax: 100,
      monthMax: 400,
    ),
    IbadatCategory(
      key: 'book_pages',
      label: 'Кітап',
      unit: 'бет',
      icon: '📚',
      color: Color(0xFF7C3AED),
      weekMax: 50,
      monthMax: 200,
    ),
    IbadatCategory(
      key: 'jawshan_count',
      label: 'Жевшен',
      unit: 'рет',
      icon: '📜',
      color: Color(0xFFDB2777),
      weekMax: 100,
      monthMax: 400,
    ),
    IbadatCategory(
      key: 'fasting_days',
      label: 'Ораза',
      unit: 'күн',
      icon: '⭐',
      color: Color(0xFFF59E0B),
      weekMax: 7,
      monthMax: 30,
    ),
    IbadatCategory(
      key: 'risale_pages',
      label: 'Рисале',
      unit: 'бет',
      icon: '📗',
      color: Color(0xFF2563EB),
      weekMax: 50,
      monthMax: 200,
    ),
    IbadatCategory(
      key: 'audio_minutes',
      label: 'Аудио',
      unit: 'мін',
      icon: '🎧',
      color: Color(0xFF059669),
      weekMax: 300,
      monthMax: 1200,
    ),
    IbadatCategory(
      key: 'salawat_count',
      label: 'Салауат',
      unit: 'рет',
      icon: '🌹',
      color: Color(0xFFE11D48),
      weekMax: 1000,
      monthMax: 4000,
    ),
    IbadatCategory(
      key: 'istighfar_count',
      label: 'Істіғфар',
      unit: 'рет',
      icon: '🤲',
      color: Color(0xFF8B5CF6),
      weekMax: 1000,
      monthMax: 4000,
    ),
    IbadatCategory(
      key: 'tahajjud_count',
      label: 'Тəжаджуд',
      unit: 'рет',
      icon: '🌙',
      color: Color(0xFF0EA5E9),
      weekMax: 10,
      monthMax: 40,
    ),
    IbadatCategory(
      key: 'zikir_count',
      label: 'Зікір',
      unit: 'рет',
      icon: '📿',
      color: Color(0xFF10B981),
      weekMax: 5000,
      monthMax: 20000,
    ),
  ];
}
