import 'package:flutter/material.dart';

import '../config/app_config.dart';

class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MochiPalette.ink, width: 2.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1).toDouble(),
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
