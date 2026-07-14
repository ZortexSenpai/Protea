import 'package:flutter/material.dart';

/// A simple avatar that shows the first letter of [name] on a color derived
/// from the name itself, so every user and room gets a stable color.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  static const _palette = [
    Color(0xFFC2185B),
    Color(0xFF7B1FA2),
    Color(0xFF303F9F),
    Color(0xFF0288D1),
    Color(0xFF00796B),
    Color(0xFF689F38),
    Color(0xFFF57C00),
    Color(0xFF5D4037),
  ];

  /// The stable color derived from [name], also used for banner fallbacks.
  static Color colorFor(String name) {
    final cleaned = name.replaceAll(RegExp(r'^[@!#]'), '').trim();
    return _palette[cleaned.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = name.replaceAll(RegExp(r'^[@!#]'), '').trim();
    final initial = cleaned.isEmpty ? '?' : cleaned[0].toUpperCase();
    final color = colorFor(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
