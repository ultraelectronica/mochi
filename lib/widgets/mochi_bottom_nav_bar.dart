import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

// Hallmark · component: bottom-navigation · genre: playful
// Redesign: compact floating pill. Smaller icon-only buttons, no top pixels,
// rounded capsule shape with margin, and a lighter footprint.
class MochiBottomNavBar extends StatelessWidget {
  const MochiBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double baseHeight = 68;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static double overlayPadding(BuildContext context) {
    return baseHeight + MediaQuery.paddingOf(context).bottom;
  }

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(
      label: 'Chat',
      assetPath: 'assets/icons/svg/chat_svg.svg',
      accent: MochiPalette.lightPink,
    ),
    _NavItemData(
      label: 'Home',
      assetPath: 'assets/icons/svg/home_svg.svg',
      accent: MochiPalette.cloudBlue,
    ),
    _NavItemData(
      label: 'Settings',
      assetPath: 'assets/icons/svg/settings_svg.svg',
      accent: MochiPalette.yellow,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: MochiPalette.cloudBlue.withValues(alpha: 0.45),
                  offset: const Offset(4, 4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MochiPalette.background.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: MochiPalette.ink, width: 3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: List<Widget>.generate(_items.length, (int index) {
                        final _NavItemData item = _items[index];
                        return Expanded(
                          child: _NavButton(
                            item: item,
                            selected: selectedIndex == index,
                            onTap: () => onSelected(index),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.assetPath,
    required this.accent,
  });

  final String label;
  final String assetPath;
  final Color accent;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? item.accent.withValues(alpha: 0.38)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? MochiPalette.ink : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: item.accent.withValues(alpha: 0.85),
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MochiPalette.ink, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: _SvgAssetIcon(assetPath: item.assetPath),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SvgAssetIcon extends StatelessWidget {
  const _SvgAssetIcon({required this.assetPath});

  final String assetPath;

  static final RegExp _embeddedPngPattern = RegExp(
    'data:image/png;base64,([^"\']+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? svgText = snapshot.data;
        if (svgText == null) {
          return const SizedBox.shrink();
        }

        final RegExpMatch? match = _embeddedPngPattern.firstMatch(svgText);
        if (match == null) {
          return const SizedBox.shrink();
        }

        final Uint8List bytes = base64Decode(match.group(1)!);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
        );
      },
    );
  }
}
