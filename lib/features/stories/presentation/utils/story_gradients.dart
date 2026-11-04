import 'package:flutter/material.dart';

class StoryGradients {
  static const List<List<Color>> gradients = [
    // 0: Deep Violet & Pink (Classic Telegram)
    [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
    // 1: Ocean Neon Blue & Cyan
    [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
    // 2: Sunset Orange & Purple
    [Color(0xFFFF512F), Color(0xFFDD2476)],
    // 3: Emerald Mint & Forest
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    // 4: Cosmic Night & Magenta
    [Color(0xFF141E30), Color(0xFF243B55), Color(0xFF6C63FF)],
    // 5: Cyber Neon & Electric Violet
    [Color(0xFFFC00FF), Color(0xFF00DBDE)],
    // 6: Deep Royal Obsidian
    [Color(0xFF232526), Color(0xFF414345)],
  ];

  static LinearGradient getGradient(int index) {
    final colors = gradients[index % gradients.length];
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
