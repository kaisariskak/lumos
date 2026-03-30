import 'package:flutter/material.dart';

/// Mini 4-bar trend chart (last 4 weeks)
class MiniBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  final double height;

  const MiniBarChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold<int>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final fraction = values[i] / maxVal;
          final isLast = i == values.length - 1;
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 5,
              height: (fraction * height).clamp(3.0, height),
              decoration: BoxDecoration(
                color: isLast ? color : color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
