import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';

class MoodTile extends StatelessWidget {
  const MoodTile({
    super.key,
    required this.mood,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MochiMood mood;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? mood.color.withValues(alpha: 0.32)
              : mood.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: enabled
                ? MochiPalette.ink
                : MochiPalette.ink.withValues(alpha: 0.25),
            width: selected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(mood.icon, size: 28, color: MochiPalette.ink),
            const SizedBox(height: 10),
            Text(
              mood.label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              mood.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
